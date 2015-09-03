Settings = require "settings-sharelatex"
logger = require "logger-sharelatex"
_ = require "underscore"

if !Settings.mysql.analytics?
	module.exports =
		recordEvent: (user_id, event, metadata, callback = () ->) ->
			logger.log {user_id, event, metadata}, "no event tracking configured, logging event"
			callback()
else
	Sequelize = require "sequelize"
	options = _.extend {logging:false}, Settings.mysql.analytics

	sequelize = new Sequelize(
		Settings.mysql.analytics.database,
		Settings.mysql.analytics.username,
		Settings.mysql.analytics.password,
		options
	)
	
	Event = sequelize.define("Event", {
		user_id: Sequelize.STRING,
		event: Sequelize.STRING,
		metadata: Sequelize.STRING
	})

	module.exports =
		recordEvent: (user_id, event, metadata = {}, callback = (error) ->) ->
			if typeof(metadata) != "string"
				metadata = JSON.stringify(metadata)
			if user_id? and typeof(user_id) != "string"
				user_id = user_id.toString()
			if user_id == Settings.smokeTest?.userId
				# Don't record smoke tests analytics
				return callback()
			Event
				.create({ user_id, event, metadata })
				.then(
					(result) -> callback(),
					(error) ->
						logger.err {err: error, user_id, event, metadata}, "error recording analytics event"
						callback(error)
				)
			
		sync: () -> sequelize.sync()