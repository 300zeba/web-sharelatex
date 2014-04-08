async = require("async")
logger = require("logger-sharelatex")
projectDeleter = require("./ProjectDeleter")
projectDuplicator = require("./ProjectDuplicator")
projectCreationHandler = require("./ProjectCreationHandler")
metrics = require('../../infrastructure/Metrics')
sanitize = require('sanitizer')
Project = require('../../models/Project').Project
TagsHandler = require("../Tags/TagsHandler")
SubscriptionLocator = require("../Subscription/SubscriptionLocator")
_ = require("underscore")

module.exports =

	deleteProject: (req, res)->
		project_id = req.params.Project_id
		logger.log project_id:project_id, "deleting project"
		projectDeleter.deleteProject project_id, (err)->
			if err?
				res.send 500
			else
				res.send 200

	cloneProject: (req, res)->
		metrics.inc "cloned-project"
		project_id = req.params.Project_id
		projectName = req.body.projectName
		logger.log project_id:project_id, projectName:projectName, "cloning project"
		if !req.session.user?
			return res.send redir:"/register"
		projectDuplicator.duplicate req.session.user, project_id, projectName, (err, project)->
			if err?
				logger.error err:err, project_id: project_id, user_id: req.session.user._id, "error cloning project"
				return next(err)
			res.send(project_id:project._id)


	newProject: (req, res)->
		user = req.session.user
		projectName = sanitize.escape(req.body.projectName)
		template = sanitize.escape(req.body.template)
		logger.log user: user, type: template, name: projectName, "creating project"
		async.waterfall [
			(cb)->
				if template == 'example'
					projectCreationHandler.createExampleProject user._id, projectName, cb
				else
					projectCreationHandler.createBasicProject user._id, projectName, cb
		], (err, project)->
			if err?
				logger.error err: err, project: project, user: user, name: projectName, type: template, "error creating project"
				res.send 500
			else
				logger.log project: project, user: user, name: projectName, type: template, "created project"
				res.send {project_id:project._id}


	projectListPage: (req, res, next)->
		timer = new metrics.Timer("project-list")
		user_id = req.session.user._id
		async.parallel {
			subscription: (cb)->
				SubscriptionLocator.getUsersSubscription user_id, cb
			tags: (cb)->
				TagsHandler.getAllTags user_id, cb
			projects: (cb)->
				Project.findAllUsersProjects user_id, 'name lastUpdated publicAccesLevel', cb
			}, (err, results)->
				logger.log results:results, user_id:user_id, "rendering project list"
				viewModel = _buildListViewModel results.projects[0], results.projects[1], results.projects[2], results.tags[0], results.tags[1], results.subscription[0]
				res.render 'project/list', viewModel
				timer.done()


_buildListViewModel = (projects, collabertions, readOnlyProjects, tags, tagsGroupedByProject, subscription)->
	# TODO: Remove this one month after the ability to start free trials was removed
	if subscription? and subscription.freeTrial? and subscription.freeTrial.expiresAt?
		freeTrial =
			expired: !!subscription.freeTrial.downgraded
			expiresAt: SubscriptionFormatters.formatDate(subscription.freeTrial.expiresAt)

	for project in projects
		project.accessLevel = "owner"
	for project in collabertions
		project.accessLevel = "readWrite"
	for project in readOnlyProjects
		project.accessLevel = "readOnly"
	projects = projects.concat(collabertions).concat(readOnlyProjects)
	projects = projects.map (project)->
		project.tags = tagsGroupedByProject[project._id] || []
		return project
	tags = _.sortBy tags, (tag)->
		-tag.project_ids.length
	sortedProjects = _.sortBy projects, (project)->
		return - project.lastUpdated

	return {
		title:'Your Projects'
		priority_title: true
		projects: sortedProjects
		freeTrial: freeTrial
		tags:tags
		projectTabActive: true
	}