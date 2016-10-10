define [
	"ide/editor/directives/aceEditor/markers/MarkerManager"
], (MarkerManager) ->
	class OtherCursorPositionManager
		constructor: (@$scope, @editor, @element) ->
			@markerManager = new MarkerManager(@editor, enableLabels: true)
			@markers = []

			@$scope.$watch "otherCursorMarkers", (markers = []) =>
				@markers = markers
				@refreshMarkers()
		
		refreshMarkers: () ->
			console.log "Updating other cursors", @markers
			@markerManager.removeAllMarkers()
			for marker in @markers
				@markerManager.addMarker(marker)
			