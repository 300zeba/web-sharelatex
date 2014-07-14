_ = require("underscore")
async = require("async")
Settings = require('settings-sharelatex')
logger = require("logger-sharelatex")
redis = require('redis')
rclient = redis.createClient(Settings.redis.web.port, Settings.redis.web.host)
rclient.auth(Settings.redis.web.password)


ONE_HOUR_IN_S = 60 * 60
ONE_DAY_IN_S = ONE_HOUR_IN_S * 24
FOUR_DAYS_IN_S = ONE_DAY_IN_S * 4

USER_TIMEOUT_IN_S = ONE_HOUR_IN_S

buildProjectSetKey = (project_id)-> return "users_in_project:#{project_id}"
buildUserKey = (project_id, user_id)-> return "connected_user:#{project_id}:#{user_id}"


module.exports =

	markUserAsConnected: (project_id, user_id, callback = (err)->)->
		logger.log project_id:project_id, user_id:user_id, "marking user as connected"

		multi = rclient.multi()
		multi.sadd buildProjectSetKey(project_id), user_id
		multi.expire buildProjectSetKey(project_id), FOUR_DAYS_IN_S
		multi.hset buildUserKey(project_id, user_id), "connected_at", new Date()
		multi.expire buildUserKey(project_id, user_id), USER_TIMEOUT_IN_S
		multi.exec (err)->
			if err?
				logger.err err:err, project_id:project_id, user_id:user_id, "problem marking user as connected"
			callback(err)

	markUserAsDisconnected: (project_id, user_id, callback)->
		logger.log project_id:project_id, user_id:user_id, "marking user as disconnected"
		multi = rclient.multi()
		multi.srem buildProjectSetKey(project_id), user_id
		multi.expire buildProjectSetKey(project_id), FOUR_DAYS_IN_S
		multi.del buildUserKey(project_id, user_id)
		multi.exec callback


	_getConnectedUser: (project_id, user_id, callback)->
		rclient.hgetall buildUserKey(project_id, user_id), (err, result)->
			if !result?
				result =
					connected : false
					user_id:user_id
			else
				result.connected = true
				result.user_id = user_id
				if result.cursorData?
					result.cursorData = JSON.parse(result.cursorData)
					result.email = result.cursorData.email
					result.name = result.cursorData.name
			callback err, result

	setUserCursorPosition: (project_id, user_id, cursorData, callback)->
		multi = rclient.multi()
		multi.hset buildUserKey(project_id, user_id), "cursorData", JSON.stringify(cursorData)
		multi.expire buildUserKey(project_id, user_id), USER_TIMEOUT_IN_S
		multi.exec callback


	getConnectedUsers: (project_id, callback)->
		self = @
		rclient.smembers buildProjectSetKey(project_id), (err, results)->
			jobs = results.map (user_id)->
				(cb)->
					self._getConnectedUser(project_id, user_id, cb)
			async.series jobs, (err, users)->
				users = _.filter users, (user)->
					user.connected
				callback err, users

