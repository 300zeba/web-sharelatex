define [
	"base"
], (App) ->
	App.controller "ScriptOutputController", ($scope, $http, ide, jupyterRunner, event_tracking, localStorage) ->
		$scope.status = jupyterRunner.status
		$scope.cells = jupyterRunner.CELL_LIST
		ide.$scope.engine = 'python'

		$scope.determineDefaultEngine = () ->
			# check all document extensions in the project,
			# if .r files outnumber .py files, set the engine to 'r'
			# otherwise leave it as the default 'python'
			filenames = ide.fileTreeManager.getAllActiveDocs().map((doc) -> doc.name.toLowerCase())
			extensions = filenames.map((filename) -> filename.split('.').pop())
			py_count = extensions.filter( (ext) -> ext == 'py').length
			r_count = extensions.filter(  (ext) -> ext == 'r' ).length
			if r_count > py_count
				ide.$scope.engine = 'r'
		$scope.determineDefaultEngine()

		ide.$scope.$watch "editor.ace_mode", () ->
			ace_mode = ide.$scope.editor.ace_mode
			# If the selected file mode is either R or Python set the engine type.
			# This way we remember the last selected 'valid' engine,
			# so that the user can (for example) run python code while looking
			# at a Json file in the editor.
			if ace_mode in ['r', 'python']
				ide.$scope.engine = ace_mode

		$scope.$on "editor:run-line", () ->
			$scope.runSelection()
		
		$scope.$on "editor:run-all", () ->
			$scope.runAll()
		
		run_count = 0
		EVENT_COOL_DOWN = ONE_MINUTE = 60 * 1000
		last_script_event = null
		trackScriptRun = () ->
			run_count++
			if run_count == 5
				event_tracking.send("script", "multiple-run")
			
			now = new Date()
			if !last_script_event? or now - last_script_event > EVENT_COOL_DOWN
				event_tracking.send("script", "run")
				last_script_event = now
		
		last_command_event = null
		trackCommandRun = () ->
			now = new Date()
			if !last_command_event? or now - last_command_event > EVENT_COOL_DOWN
				event_tracking.send("command", "run")
				last_command_event = now
		
		$scope.runSelection = () ->
			ide.$scope.$broadcast("editor:focus") # Don't steal focus from editor on click
			ide.$scope.$broadcast("flush-changes")
			trackScriptRun()
			ide.$scope.$broadcast("editor:gotoNextLine")
			code   = ide.$scope.editor.selection.lines.join("\n")
			engine = ide.$scope.engine
			jupyterRunner.executeRequest code, engine
			$scope._scrollOutput()

		$scope.runAll = () ->
			ide.$scope.$broadcast("editor:focus") # Don't steal focus from editor on click
			ide.$scope.$broadcast("flush-changes")
			trackScriptRun()
			engine = ide.$scope.engine
			path = ide.fileTreeManager.getEntityPath(ide.$scope.editor.open_doc)
			if engine == "python"
				code = "%run #{path}"
				jupyterRunner.executeRequest code, engine
			else if engine == "r"
				code = "source('#{path}', print.eval=TRUE)"
				jupyterRunner.executeRequest code, engine
			else
				throw new Error("not implemented yet")
			$scope._scrollOutput()

		$scope.manualInput = ""
		$scope.runManualInput = () ->
			trackCommandRun()
			code   = $scope.manualInput
			engine = ide.$scope.engine
			jupyterRunner.executeRequest code, engine
			$scope._scrollOutput()
			$scope.manualInput = ""

		$scope._scrollOutput = () ->
			try
				container = document.querySelector('.jupyter-output-inner')
				container.scrollTop = container.scrollHeight
			catch error
				console.log error

		$scope.stop = () ->
			jupyterRunner.stop()
		
		$scope.restart = () ->
			jupyterRunner.shutdown(ide.$scope.engine)
		
		$scope.installPackage = (packageName, language) ->
			ide.$scope.$broadcast "installPackage", packageName, language
		
		$scope.showFormat = (message, format) ->
			message.content.format = format
			localStorage("preferred_format", format)
		
		$scope.clearCells = () ->
			jupyterRunner.clearCells()
