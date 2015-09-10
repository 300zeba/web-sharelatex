AdminController = require('./Features/ServerAdmin/AdminController')
ErrorController = require('./Features/Errors/ErrorController')
ProjectController = require("./Features/Project/ProjectController")
ProjectApiController = require("./Features/Project/ProjectApiController")
SpellingController = require('./Features/Spelling/SpellingController')
SecurityManager = require('./managers/SecurityManager')
AuthorizationManager = require('./Features/Security/AuthorizationManager')
EditorController = require("./Features/Editor/EditorController")
EditorRouter = require("./Features/Editor/EditorRouter")
Settings = require('settings-sharelatex')
TpdsController = require('./Features/ThirdPartyDataStore/TpdsController')
SubscriptionRouter = require './Features/Subscription/SubscriptionRouter'
UploadsRouter = require './Features/Uploads/UploadsRouter'
metrics = require('./infrastructure/Metrics')
ReferalController = require('./Features/Referal/ReferalController')
ReferalMiddleware = require('./Features/Referal/ReferalMiddleware')
AuthenticationController = require('./Features/Authentication/AuthenticationController')
TagsController = require("./Features/Tags/TagsController")
CollaboratorsRouter = require('./Features/Collaborators/CollaboratorsRouter')
UserInfoController = require('./Features/User/UserInfoController')
UserController = require("./Features/User/UserController")
UserPagesController = require('./Features/User/UserPagesController')
DocumentController = require('./Features/Documents/DocumentController')
CompileManager = require("./Features/Compile/CompileManager")
CompileController = require("./Features/Compile/CompileController")
HealthCheckController = require("./Features/HealthCheck/HealthCheckController")
ProjectDownloadsController = require "./Features/Downloads/ProjectDownloadsController"
FileStoreController = require("./Features/FileStore/FileStoreController")
TrackChangesController = require("./Features/TrackChanges/TrackChangesController")
PasswordResetRouter = require("./Features/PasswordReset/PasswordResetRouter")
StaticPagesRouter = require("./Features/StaticPages/StaticPagesRouter")
ChatController = require("./Features/Chat/ChatController")
BlogController = require("./Features/Blog/BlogController")
WikiController = require("./Features/Wiki/WikiController")
Modules = require "./infrastructure/Modules"
RateLimiterMiddlewear = require('./Features/Security/RateLimiterMiddlewear')
RealTimeProxyRouter = require('./Features/RealTimeProxy/RealTimeProxyRouter')
InactiveProjectController = require("./Features/InactiveData/InactiveProjectController")
AnalyticsMiddlewear = require "./Features/Analytics/AnalyticsMiddlewear"
LinkController = require("./Features/Link/LinkController")
AnalyticsRouter = require('./Features/Analytics/AnalyticsRouter')
PreviewController = require('./Features/Previews/PreviewController')

logger = require("logger-sharelatex")
_ = require("underscore")

module.exports = class Router
	constructor: (webRouter, apiRouter)->
		if !Settings.allowPublicAccess
			webRouter.all '*', AuthenticationController.requireGlobalLogin

		
		webRouter.get  '/login', UserPagesController.loginPage
		AuthenticationController.addEndpointToLoginWhitelist '/login'

		webRouter.post '/login', AuthenticationController.login
		webRouter.get  '/logout', UserController.logout
		webRouter.get  '/restricted', SecurityManager.restricted

		# Left as a placeholder for implementing a public register page
		webRouter.get  '/register', UserPagesController.registerPage
		AuthenticationController.addEndpointToLoginWhitelist '/register'


		EditorRouter.apply(webRouter, apiRouter)
		CollaboratorsRouter.apply(webRouter, apiRouter)
		SubscriptionRouter.apply(webRouter, apiRouter)
		UploadsRouter.apply(webRouter, apiRouter)
		PasswordResetRouter.apply(webRouter, apiRouter)
		StaticPagesRouter.apply(webRouter, apiRouter)
		RealTimeProxyRouter.apply(webRouter, apiRouter)
		AnalyticsRouter.apply(webRouter, apiRouter)
		
		Modules.applyRouter(webRouter, apiRouter)

		if Settings.enableSubscriptions
			webRouter.get  '/user/bonus', AuthenticationController.requireLogin(), ReferalMiddleware.getUserReferalId, ReferalController.bonus

		webRouter.get '/blog', BlogController.getIndexPage
		webRouter.get '/blog/*', BlogController.getPage
		
		webRouter.get '/user/usage', AuthenticationController.requireLogin(), UserPagesController.useCasePage

		webRouter.get  '/user/settings', AuthenticationController.requireLogin(), UserPagesController.settingsPage
		webRouter.post '/user/settings', AuthenticationController.requireLogin(), UserController.updateUserSettings
		webRouter.post '/user/password/update', AuthenticationController.requireLogin(), UserController.changePassword

		webRouter.delete '/user/newsletter/unsubscribe', AuthenticationController.requireLogin(), UserController.unsubscribe
		webRouter.delete '/user', AuthenticationController.requireLogin(), UserController.deleteUser

		webRouter.get  '/user/auth_token', AuthenticationController.requireLogin(), AuthenticationController.getAuthToken
		webRouter.get  '/user/personal_info', AuthenticationController.requireLogin(allow_auth_token: true), UserInfoController.getLoggedInUsersPersonalInfo
		apiRouter.get  '/user/:user_id/personal_info', AuthenticationController.httpAuth, UserInfoController.getPersonalInfo

		webRouter.get  '/project', AuthenticationController.requireLogin(), AnalyticsMiddlewear.injectIntercomDetails, ProjectController.projectListPage
		webRouter.post '/project/new', AuthenticationController.requireLogin(), ProjectController.newProject

		webRouter.get  '/Project/:Project_id', RateLimiterMiddlewear.rateLimit({
			endpointName: "open-project"
			params: ["Project_id"]
			maxRequests: 10
			timeInterval: 60
		}), SecurityManager.requestCanAccessProject, AnalyticsMiddlewear.injectIntercomDetails, ProjectController.loadEditor
		webRouter.get  '/Project/:Project_id/file/:File_id', SecurityManager.requestCanAccessProject, FileStoreController.getFile
		webRouter.post '/project/:Project_id/settings', SecurityManager.requestCanModifyProject, ProjectController.updateProjectSettings

		webRouter.post '/project/:Project_id/compile', SecurityManager.requestCanAccessProject, CompileController.compile
		webRouter.post '/project/:Project_id/compile/:session_id/stop', SecurityManager.requestCanAccessProject, CompileController.stopCompile
		webRouter.post '/project/:Project_id/request', SecurityManager.requestCanAccessProject, CompileController.sendJupyterRequest
		webRouter.post '/project/:Project_id/reply', SecurityManager.requestCanAccessProject, CompileController.sendJupyterReply
		webRouter.post '/project/:Project_id/request/:request_id/interrupt', SecurityManager.requestCanAccessProject, CompileController.interruptRequest
		webRouter.get  '/Project/:Project_id/output/output.pdf', SecurityManager.requestCanAccessProject, CompileController.downloadPdf
		webRouter.get  /^\/project\/([^\/]*)\/output\/(.*)$/,
			((req, res, next) ->
				params =
					"Project_id": req.params[0]
					"file":       req.params[1]
				req.params = params
				next()
			), SecurityManager.requestCanAccessProject, CompileController.getFileFromClsi

		webRouter.delete '/project/:Project_id/output/:file(\\S+)', SecurityManager.requestCanAccessProject, CompileController.deleteOutputFile
		webRouter.delete "/project/:Project_id/output", SecurityManager.requestCanAccessProject, CompileController.deleteAuxFiles
		webRouter.get '/project/:Project_id/output', SecurityManager.requestCanAccessProject, CompileController.listFiles
		webRouter.get "/project/:Project_id/sync/code", SecurityManager.requestCanAccessProject, CompileController.proxySync
		webRouter.get "/project/:Project_id/sync/pdf", SecurityManager.requestCanAccessProject, CompileController.proxySync

		webRouter.delete '/Project/:Project_id', SecurityManager.requestIsOwner, ProjectController.deleteProject
		webRouter.post '/Project/:Project_id/restore', SecurityManager.requestIsOwner, ProjectController.restoreProject
		webRouter.post '/Project/:Project_id/clone', SecurityManager.requestCanAccessProject, ProjectController.cloneProject

		webRouter.post '/project/:Project_id/rename', SecurityManager.requestIsOwner, ProjectController.renameProject

		webRouter.get  "/project/:Project_id/updates", SecurityManager.requestCanAccessProject, TrackChangesController.proxyToTrackChangesApi
		webRouter.get  "/project/:Project_id/doc/:doc_id/diff", SecurityManager.requestCanAccessProject, TrackChangesController.proxyToTrackChangesApi
		webRouter.post "/project/:Project_id/doc/:doc_id/version/:version_id/restore", SecurityManager.requestCanAccessProject, TrackChangesController.proxyToTrackChangesApi

		webRouter.get  '/Project/:Project_id/download/zip', SecurityManager.requestCanAccessProject, ProjectDownloadsController.downloadProject
		webRouter.get  '/project/download/zip', SecurityManager.requestCanAccessMultipleProjects, ProjectDownloadsController.downloadMultipleProjects

		webRouter.get '/tag', AuthenticationController.requireLogin(), TagsController.getAllTags
		webRouter.post '/project/:project_id/tag', AuthenticationController.requireLogin(), TagsController.processTagsUpdate

		# Deprecated in favour of /internal/project/:project_id but still used by versioning
		apiRouter.get  '/project/:project_id/details', AuthenticationController.httpAuth, ProjectApiController.getProjectDetails

		# New 'stable' /internal API end points
		apiRouter.get  '/internal/project/:project_id',     AuthenticationController.httpAuth, ProjectApiController.getProjectDetails
		apiRouter.get  '/internal/project/:Project_id/zip', AuthenticationController.httpAuth, ProjectDownloadsController.downloadProject
		apiRouter.post '/internal/project/:Project_id/run', AuthenticationController.httpAuth, CompileController.compile
		
		apiRouter.get  '/internal/project/:project_id/content', AuthenticationController.httpAuth, ProjectApiController.getProjectContent

		apiRouter.post '/internal/deactivateOldProjects', AuthenticationController.httpAuth, InactiveProjectController.deactivateOldProjects
		apiRouter.post '/internal/project/:project_id/deactivate', AuthenticationController.httpAuth, InactiveProjectController.deactivateProject

		apiRouter.get  /^\/internal\/project\/([^\/]*)\/output\/(.*)$/,
			((req, res, next) ->
				params =
					"Project_id": req.params[0]
					"file":       req.params[1]
				req.params = params
				next()
			), AuthenticationController.httpAuth, CompileController.getFileFromClsi

		apiRouter.get  '/project/:Project_id/doc/:doc_id', AuthenticationController.httpAuth, DocumentController.getDocument
		apiRouter.post '/project/:Project_id/doc/:doc_id', AuthenticationController.httpAuth, DocumentController.setDocument

		apiRouter.post '/user/:user_id/update/*', AuthenticationController.httpAuth, TpdsController.mergeUpdate
		apiRouter.delete '/user/:user_id/update/*', AuthenticationController.httpAuth, TpdsController.deleteUpdate
		
		apiRouter.post '/project/:project_id/contents/*', AuthenticationController.httpAuth, TpdsController.updateProjectContents
		apiRouter.delete '/project/:project_id/contents/*', AuthenticationController.httpAuth, TpdsController.deleteProjectContents

		webRouter.post "/spelling/check", AuthenticationController.requireLogin(), SpellingController.proxyRequestToSpellingApi
		webRouter.post "/spelling/learn", AuthenticationController.requireLogin(), SpellingController.proxyRequestToSpellingApi

		webRouter.get  "/project/:Project_id/messages", SecurityManager.requestCanAccessProject, ChatController.getMessages
		webRouter.post "/project/:Project_id/messages", SecurityManager.requestCanAccessProject, ChatController.sendMessage

		webRouter.post  "/project/:Project_id/link", SecurityManager.requestCanAccessProject, LinkController.generateLink
		webRouter.get   "/public/:public_id/*", LinkController.getFile # public image links
		
		webRouter.get  /learn(\/.*)?/, AnalyticsMiddlewear.injectIntercomDetails, WikiController.getPage

		webRouter.get "/project/:Project_id/file/:file_id/preview/csv", SecurityManager.requestCanAccessProject, PreviewController.getPreviewCsv

		#Admin Stuff
		webRouter.get  '/admin', SecurityManager.requestIsAdmin, AdminController.index
		webRouter.get  '/admin/register', SecurityManager.requestIsAdmin, AdminController.registerNewUser
		webRouter.post '/admin/register', SecurityManager.requestIsAdmin, UserController.register
		webRouter.post '/admin/closeEditor', SecurityManager.requestIsAdmin, AdminController.closeEditor
		webRouter.post '/admin/dissconectAllUsers', SecurityManager.requestIsAdmin, AdminController.dissconectAllUsers
		webRouter.post '/admin/syncUserToSubscription', SecurityManager.requestIsAdmin, AdminController.syncUserToSubscription
		webRouter.post '/admin/flushProjectToTpds', SecurityManager.requestIsAdmin, AdminController.flushProjectToTpds
		webRouter.post '/admin/pollDropboxForUser', SecurityManager.requestIsAdmin, AdminController.pollDropboxForUser
		webRouter.post '/admin/messages', SecurityManager.requestIsAdmin, AdminController.createMessage
		webRouter.post '/admin/messages/clear', SecurityManager.requestIsAdmin, AdminController.clearMessages

		apiRouter.get '/perfTest', (req,res)->
			res.send("hello")

		apiRouter.get '/status', (req,res)->
			res.send("websharelatex is up")
		

		webRouter.get '/health_check', HealthCheckController.check
		webRouter.get '/health_check/redis', HealthCheckController.checkRedis

		apiRouter.get "/status/compiler/:Project_id", SecurityManager.requestCanAccessProject, (req, res) ->
			sendRes = _.once (statusCode, message)->
				res.writeHead statusCode
				res.end message
			CompileManager.compile req.params.Project_id, "test-compile", "test_compile_session_id", {}, () ->
				sendRes 200, "Compiler returned in less than 10 seconds"
			setTimeout (() ->
				sendRes 500, "Compiler timed out"
			), 10000

		apiRouter.get "/ip", (req, res, next) ->
			res.send({
				ip: req.ip
				ips: req.ips
				headers: req.headers
			})

		apiRouter.get '/oops-express', (req, res, next) -> next(new Error("Test error"))
		apiRouter.get '/oops-internal', (req, res, next) -> throw new Error("Test error")
		apiRouter.get '/oops-mongo', (req, res, next) ->
			require("./models/Project").Project.findOne {}, () ->
				throw new Error("Test error")

		apiRouter.get '/opps-small', (req, res, next)->
			logger.err "test error occured"
			res.send()

		webRouter.post '/error/client', (req, res, next) ->
			logger.error err: req.body.error, meta: req.body.meta, "client side error"
			res.sendStatus(204)

		webRouter.get '*', ErrorController.notFound
