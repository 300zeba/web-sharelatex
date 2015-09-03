define [
	"base"
], (App) ->
	App.controller "FileTreeRootFolderController", ["$scope", "ide", "$http", ($scope, ide, $http) ->
		rootFolder = $scope.rootFolder

		$http.get "/project/#{$scope.project_id}/output"
			.success (files) ->
				$scope.project.outputFiles = files?.outputFiles

		$scope.onDrop = (events, ui) ->
			source = $(ui.draggable).scope().entity
			return if !source?
			ide.fileTreeManager.moveEntity(source, rootFolder)
	]
