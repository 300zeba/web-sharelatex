CollaboratorsController = require('./CollaboratorsController')
AuthenticationController = require('../Authentication/AuthenticationController')
AuthorizationMiddlewear = require('../Authorization/AuthorizationMiddlewear')
CollaboratorsInviteController = require('./CollaboratorsInviteController')

module.exports =
	apply: (webRouter, apiRouter) ->
		webRouter.post '/project/:Project_id/leave', AuthenticationController.requireLogin(), CollaboratorsController.removeSelfFromProject

		webRouter.post   '/project/:Project_id/users', AuthorizationMiddlewear.ensureUserCanAdminProject, CollaboratorsController.addUserToProject
		webRouter.delete '/project/:Project_id/users/:user_id', AuthorizationMiddlewear.ensureUserCanAdminProject, CollaboratorsController.removeUserFromProject

		# invites
		webRouter.post(
			'/project/:Project_id/invite',
			AuthorizationMiddlewear.ensureUserCanAdminProject,
			CollaboratorsInviteController.inviteToProject
		)

		webRouter.get(
			'/project/:Project_id/invite',
			AuthorizationMiddlewear.ensureUserCanAdminProject,
			CollaboratorsInviteController.getAllInvites
		)

		webRouter.delete(
			'/project/:Project_id/invite/:invite_id',
			AuthorizationMiddlewear.ensureUserCanAdminProject,
			CollaboratorsInviteController.revokeInvite
		)

		webRouter.post(
			'/project/:Project_id/invite/:invite_id/resend',
			AuthorizationMiddlewear.ensureUserCanAdminProject,
			CollaboratorsInviteController.resendInvite
		)

		webRouter.get(
			'/project/:Project_id/invite/token/:token',
			AuthenticationController.requireLogin(),
			CollaboratorsInviteController.viewInvite
		)

		webRouter.post(
			'/project/:Project_id/invite/:invite_id/accept',
			AuthenticationController.requireLogin(),
			CollaboratorsInviteController.acceptInvite
		)
