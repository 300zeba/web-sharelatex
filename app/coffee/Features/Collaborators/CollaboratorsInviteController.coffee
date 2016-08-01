ProjectGetter = require "../Project/ProjectGetter"
LimitationsManager = require "../Subscription/LimitationsManager"
UserGetter = require "../User/UserGetter"
Project = require("../../models/Project").Project
User = require("../../models/User").User
CollaboratorsInviteHandler = require('./CollaboratorsInviteHandler')
mimelib = require("mimelib")
logger = require('logger-sharelatex')

module.exports = CollaboratorsInviteController =

	getAllInvites: (req, res, next) ->
		projectId = req.params.Project_id
		logger.log {projectId}, "getting all active invites for project"
		CollaboratorsInviteHandler.getAllInvites projectId, (err, invites) ->
			if err?
				logger.err {projectId}, "error getting invites for project"
				return next(err)
			res.json({invites: invites})

	inviteToProject: (req, res, next) ->
		projectId = req.params.Project_id
		email = req.body.email
		sendingUserId = req.session?.user?._id
		logger.log {projectId, email, sendingUserId}, "inviting to project"
		LimitationsManager.canAddXCollaborators projectId, 1, (error, allowed) =>
			return next(error) if error?
			if !allowed
				logger.log {projectId, email, sendingUserId}, "not allowed to invite more users to project"
				return res.json {invite: null}
			{email, privileges} = req.body
			email = mimelib.parseAddresses(email or "")[0]?.address?.toLowerCase()
			if !email? or email == ""
				logger.log {projectId, email, sendingUserId}, "invalid email address"
				return res.sendStatus(400)
			CollaboratorsInviteHandler.inviteToProject projectId, sendingUserId, email, privileges, (err, invite) ->
				if err?
					logger.err {projectId, email, sendingUserId}, "error creating project invite"
					return next(err)
				logger.log {projectId, email, sendingUserId}, "invite created"
				return res.json {invite: invite}

	revokeInvite: (req, res, next) ->
		projectId = req.params.Project_id
		inviteId = req.params.invite_id
		logger.log {projectId, inviteId}, "revoking invite"
		CollaboratorsInviteHandler.revokeInvite projectId, inviteId, (err) ->
			if err?
				logger.err {projectId, inviteId}, "error revoking invite"
				return next(err)
			res.sendStatus(201)

	viewInvite: (req, res, next) ->
		projectId = req.params.Project_id
		token = req.params.token
		currentUser = req.session.user
		_renderInvalidPage = () ->
			logger.log {projectId, token}, "invite not valid, rendering not-valid page"
			res.render "project/invite/not-valid", {title: "Invalid Invite"}
		# get the target project
		Project.findOne {_id: projectId}, {owner_ref: 1, name: 1, collaberator_refs: 1, readOnly_refs: 1}, (err, project) ->
			if err?
				logger.err {err, projectId}, "error getting project"
				return next(err)
			if !project
				logger.log {projectId}, "no project found"
				return _renderInvalidPage()
			# check if user is already a member of the project, redirect to project if so
			allMembers = (project.collaberator_refs || []).concat(project.readOnly_refs || []).map((oid) -> oid.toString())
			if currentUser._id in allMembers
				logger.log {projectId, userId: currentUser._id}, "user is already a member of this project, redirecting"
				return res.redirect "/project/#{projectId}"
			# get the invite
			CollaboratorsInviteHandler.getInviteByToken projectId, token, (err, invite) ->
				if err?
					logger.err {projectId, token}, "error getting invite by token"
					return next(err)
				# check if invite is gone, or otherwise non-existent
				if !invite
					logger.log {projectId, token}, "no invite found for this token"
					return _renderInvalidPage()
				# check the user who sent the invite exists
				User.findOne {_id: invite.sendingUserId}, {email: 1, first_name: 1, last_name: 1}, (err, owner) ->
					if err?
						logger.err {err, projectId}, "error getting project owner"
						return next(err)
					if !owner
						logger.log {projectId}, "no project owner found"
						return _renderInvalidPage()
					# finally render the invite
					res.render "project/invite/show", {invite, project, owner, title: "Project Invite"}

	acceptInvite: (req, res, next) ->
		projectId = req.params.Project_id
		inviteId = req.params.invite_id
		{token} = req.body
		currentUser = req.session.user
		logger.log {projectId, inviteId, userId: currentUser._id}, "accepting invite"
		CollaboratorsInviteHandler.acceptInvite projectId, inviteId, token, currentUser, (err) ->
			if err?
				logger.err {projectId, inviteId}, "error accepting invite by token"
				return next(err)
			res.redirect "/project/#{projectId}"
