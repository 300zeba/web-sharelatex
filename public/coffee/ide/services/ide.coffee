define [
	"base"
], (App) ->
	# We create and provide this as service so that we can access the global ide
	# from within other parts of the angular app.
	App.factory "ide", ["$http", "$modal", "event_tracking", ($http, $modal, event_tracking) ->
		ide = {}
		ide.$http = $http
		ide.event_tracking = event_tracking

		@recentEvents = []
		ide.pushEvent = (type, meta = {}) =>
			@recentEvents.push type: type, meta: meta, date: new Date()
			if @recentEvents.length > 40
				@recentEvents.shift()

		ide.reportError = (error, meta = {}) =>
			meta.client_id = @socket?.socket?.sessionid
			meta.transport = @socket?.socket?.transport?.name
			meta.client_now = new Date()
			meta.recent_events = @recentEvents
			errorObj = {}
			if typeof error == "object"
				for key in Object.getOwnPropertyNames(error)
					errorObj[key] = error[key]
			else if typeof error == "string"
				errorObj.message = error
			$http.post "/error/client", {
				error: errorObj
				meta: meta
				_csrf: window.csrfToken
			}

		ide.showGenericMessageModal = (title, message) ->
			$modal.open {
				templateUrl: "genericMessageModalTemplate"
				controller:  "GenericMessageModalController"
				resolve:
					title:   -> title
					message: -> message
			}

		return ide
	]

	App.controller "GenericMessageModalController", ["$scope", "$modalInstance", "title", "message", ($scope, $modalInstance, title, message) ->
		$scope.title = title
		$scope.message = message

		$scope.done = () ->
			$modalInstance.close()
	]
