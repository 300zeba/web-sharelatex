UserDeleter = require("./UserDeleter")
UserLocator = require("./UserLocator")
User = require("../../models/User").User
newsLetterManager = require('../Newsletter/NewsletterManager')
sanitize = require('sanitizer')
UserRegistrationHandler = require("./UserRegistrationHandler")
logger = require("logger-sharelatex")
metrics = require("../../infrastructure/Metrics")
Url = require("url")
AuthenticationController = require("../Authentication/AuthenticationController")
module.exports =

	deleteUser: (req, res)->
		user_id = req.session.user._id
		UserDeleter.deleteUser user_id, (err)->
			if !err?
				req.session.destroy()
			res.send(200)

	unsubscribe: (req, res)->
		UserLocator.findById req.session.user._id, (err, user)->
			newsLetterManager.unsubscribe user, ->
				res.send()

	updateUserSettings : (req, res)->
		logger.log user: req.session.user, "updating account settings"
		User.findById req.session.user._id, (err, user)->
			if err? or !user?
				logger.err err:err, user_id:req.session.user._id, "problem updaing user settings"
				return res.send 500
			user.first_name   = sanitize.escape(req.body.first_name).trim()
			user.last_name    = sanitize.escape(req.body.last_name).trim()
			user.ace.mode     = sanitize.escape(req.body.mode).trim()
			user.ace.theme    = sanitize.escape(req.body.theme).trim()
			user.ace.fontSize = sanitize.escape(req.body.fontSize).trim()
			user.ace.autoComplete = req.body.autoComplete == "true"
			user.ace.spellCheckLanguage = req.body.spellCheckLanguage
			user.ace.pdfViewer = req.body.pdfViewer
			user.save ->
				res.send()

	logout : (req, res)->
		metrics.inc "user.logout"
		logger.log user: req?.session?.user, "logging out"
		req.session.destroy (err)->
			if err
				logger.err err: err, 'error destorying session'
			res.redirect '/login'

	register : (req, res, next = (error) ->)->
		logger.log email: req.body.email, "attempted register"
		redir = Url.parse(req.body.redir or "/project").path
		UserRegistrationHandler.registerNewUser req.body, (err, user)->
			console.log err
			if err == "EmailAlreadyRegisterd"
				return AuthenticationController.login req, res
			else if err?
				next(err)
			else
				metrics.inc "user.register.success"
				req.session.user = user
				req.session.justRegistered = true
				res.send
					redir:redir
					id:user._id.toString()
					first_name: user.first_name
					last_name: user.last_name
					email: user.email
					created: Date.now()


