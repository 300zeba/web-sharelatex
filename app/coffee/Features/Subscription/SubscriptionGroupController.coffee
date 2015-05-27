SubscriptionGroupHandler = require("./SubscriptionGroupHandler")
logger = require("logger-sharelatex")
SubscriptionLocator = require("./SubscriptionLocator")

ErrorsController = require("../Errors/ErrorController")
settings = require("settings-sharelatex")

SubscriptionDomainAllocator = require("./SubscriptionDomainAllocator")
_ = require("underscore")

module.exports =

	addUserToGroup: (req, res)->
		adminUserId = req.session.user._id
		newEmail = req.body.email
		logger.log adminUserId:adminUserId, newEmail:newEmail, "adding user to group subscription"
		SubscriptionGroupHandler.addUserToGroup adminUserId, newEmail, (err, user)->
			result = 
				user:user
			if err and err.limitReached
				result.limitReached = true
			res.json(result)

	removeUserFromGroup: (req, res)->
		adminUserId = req.session.user._id
		userToRemove_id = req.params.user_id
		logger.log adminUserId:adminUserId, userToRemove_id:userToRemove_id, "removing user from group subscription"
		SubscriptionGroupHandler.removeUserFromGroup adminUserId, userToRemove_id, ->
			res.send()

	renderSubscriptionGroupAdminPage: (req, res)->
		user_id = req.session.user._id
		SubscriptionLocator.getUsersSubscription user_id, (err, subscription)->
			if !subscription.groupPlan
				return res.redirect("/")
			SubscriptionGroupHandler.getPopulatedListOfMembers user_id, (err, users)->
				res.render "subscriptions/group_admin",
					title: 'group_admin'
					users: users
					subscription: subscription

	renderGroupInvitePage: (req, res)->
		subscription_id = req.params.subscription_id
		user_id = req.session.user._id
		licence = SubscriptionDomainAllocator.findDomainLicenceBySubscriptionId(subscription_id)
		if !licence?
			return ErrorsController.notFound(req, res)
		SubscriptionGroupHandler.isUserPartOfGroup user_id, licence.subscription_id, (err, partOfGroup)->
			if partOfGroup
				return res.redirect("/user/subscription/custom_account")
			else
				res.render "subscriptions/group/invite",
					title: "Group Invitation"
					subscription_id:subscription_id
					licenceName:licence.name

	beginJoinGroup: (req, res)->
		subscription_id = req.params.subscription_id
		user_id = req.session.user._id
		licence = SubscriptionDomainAllocator.findDomainLicenceBySubscriptionId(subscription_id)
		if !licence?
			return ErrorsController.notFound(req, res)
		SubscriptionGroupHandler.sendVerificationEmail subscription_id, licence.name, req.session.user.email, (err)->
			if err?
				res.send 500
			else
				res.send 200

	completeJoin: (req, res)->
		subscription_id = req.params.subscription_id
		if !SubscriptionDomainAllocator.findDomainLicenceBySubscriptionId(subscription_id)?
			return ErrorsController.notFound(req, res)
		SubscriptionGroupHandler.processGroupVerification req.session.user.email, subscription_id, req.query.token, (err)->
			if err?
				res.send 500
			else
				res.redirect "/user/subscription/#{subscription_id}/group/successful-join"

	renderSuccessfulJoinPage: (req, res)->
		subscription_id = req.params.subscription_id
		licence = SubscriptionDomainAllocator.findDomainLicenceBySubscriptionId(subscription_id)
		if !SubscriptionDomainAllocator.findDomainLicenceBySubscriptionId(subscription_id)?
			return ErrorsController.notFound(req, res)
		res.render "subscriptions/group/successful_join",
			title: "Sucessfully joined group"
			licenceName:licence.name	

