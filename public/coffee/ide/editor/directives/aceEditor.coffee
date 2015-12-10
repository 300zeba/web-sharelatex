define [
	"base"
	"ace/ace"
	"ace/ext-searchbox"
	"ide/editor/directives/aceEditor/undo/UndoManager"
	"ide/editor/directives/aceEditor/auto-complete/AutoCompleteManager"
	"ide/editor/directives/aceEditor/highlights/HighlightsManager"
	"ide/editor/directives/aceEditor/cursor-position/CursorPositionManager"
], (App, Ace, SearchBox, UndoManager, AutoCompleteManager, HighlightsManager, CursorPositionManager) ->
	EditSession = ace.require('ace/edit_session').EditSession

	# Ace loads its script itself, so we need to hook in to be able to clear
	# the cache.
	if !ace.config._moduleUrl?
		ace.config._moduleUrl = ace.config.moduleUrl
		ace.config.moduleUrl = (args...) ->
			url = ace.config._moduleUrl(args...) + "?fingerprint=#{window.aceFingerprint}"
			return url

	ENTER = 13
	UP    = 38
	DOWN  = 40
	TAB   = 9
	END   = -1

	class CommandLine

		@init: (editor, rootElement, getValue, setValue, onRun) ->
			commandLine = new CommandLine(editor, rootElement, getValue, setValue, onRun)
			editor._dj_commandLine = commandLine

		constructor: (@editor, @rootElement, @getValueFn, @setValueFn, @onRunFn) ->
			@history = []
			@cursor = END
			@pendingCommand = ""

			rootElement.bind "keydown", (event) =>
				@handleKeyDown(event)

		handleKeyDown: (event) ->
			console.log ">> keydown"
			if event.which == ENTER and not event.shiftKey
				event.preventDefault()
				@runCommand()
			else if event.which == UP
				event.preventDefault()
				if @cursor == END and @history.length > 0
					@savePendingCommand()
					@moveToHistoryEntry(@history.length - 1)
				else if @cursor > 0
					@moveToHistoryEntry(@cursor - 1)
			else if event.which == DOWN
				event.preventDefault()
				if @cursor != END and @cursor < history.length - 1
					@moveToHistoryEntry(@cursor + 1)
				else if @cursor == @history.length - 1
					@moveToHistoryEntry(END)

		savePendingCommand: () ->
			console.log ">> save command"
			@pendingCommand = @getValueFn()

		moveToHistoryEntry: (index) ->
			console.log ">> move to hist entry"
			@cursor = index
			if index == END
				@setValueFn(@pendingCommand)
			else
				@setValueFn(@history[index])

		runCommand: () ->
			console.log ">> run command"
			@history.push @getValueFn()
			@cursor = END
			@onRunFn()


	App.directive "aceEditor", ($timeout, $compile, $rootScope, event_tracking, localStorage) ->
		monkeyPatchSearch($rootScope, $compile)

		return  {
			scope: {
				theme: "="
				showPrintMargin: "="
				keybindings: "="
				fontSize: "="
				autoComplete: "="
				lineWrap: "="
				sharejsDoc: "="
				highlights: "="
				text: "="
				readOnly: "="
				annotations: "="
				navigateHighlights: "="
				aceMode: "="
				wrapLines: "="
				selection: "=?"
			}
			link: (scope, element, attrs) ->
				# Don't freak out if we're already in an apply callback
				scope.$originalApply = scope.$apply
				scope.$apply = (fn = () ->) ->
					phase = @$root.$$phase
					if (phase == '$apply' || phase == '$digest')
						fn()
					else
						@$originalApply(fn);

				editor = ace.edit(element.find(".ace-editor-body")[0])
				editor.$blockScrolling = Infinity
				window.editors ||= []
				window.editors.push editor

				scope.name = attrs.aceEditor
				scope.autocompleteDelegate = attrs.autocompleteDelegate

				editor._dj_name = scope.name

				autoCompleteManager   = new AutoCompleteManager(scope, editor, element)
				undoManager           = new UndoManager(scope, editor, element)
				highlightsManager     = new HighlightsManager(scope, editor, element)
				cursorPositionManager = new CursorPositionManager(scope, editor, element, localStorage)

				if attrs.commandLine == 'true'
					console.log ">> it's command line #{scope.name}"
					editor.setOption('showLineNumbers', false)
					editor.setOption('showGutter', false)
					editor.setOption('maxLines', 20)
					editor.setOption('highlightActiveLine', false)
					editor.on 'change', () ->
						editor.resize()

					getValueFn = scope.$parent[attrs.commandLineGetValue]
					setValueFn = scope.$parent[attrs.commandLineSetValue]
					onRunFn = scope.$parent[attrs.commandLineOnRun]

					# set up a placeholder text
					# watch for changes to the editor, if the text is empty,
					# add a div with the placeholder text, otherwise remove it
					_updatePlaceholder = () ->
						shouldShow = editor.getValue().length == 0
						existingMessage = editor.renderer.emptyMessageNode
						if (!shouldShow and existingMessage)
							editor.renderer.scroller.removeChild(existingMessage)
							editor.renderer.emptyMessageNode = null
						else if (shouldShow and !existingMessage)
							newMessage = editor.renderer.emptyMessageNode = document.createElement("div")
							newMessage.textContent = 'Command...'
							newMessage.className = 'ace_invisible ace_emptyMessage'
							newMessage.style.padding = "0 8px"
							editor.renderer.scroller.appendChild(newMessage)
					editor.on('input', _updatePlaceholder)
					setTimeout(_updatePlaceholder, 0)

					CommandLine.init(editor, element, getValueFn, setValueFn, onRunFn)


				# Prevert Ctrl|Cmd-S from triggering save dialog
				editor.commands.addCommand
					name: "save",
					bindKey: win: "Ctrl-S", mac: "Command-S"
					exec: () ->
					readOnly: true
				editor.commands.removeCommand "transposeletters"
				editor.commands.removeCommand "showSettingsMenu"
				editor.commands.removeCommand "foldall"

				# Trigger search AND replace on CMD+F
				editor.commands.addCommand
					name: "find",
					bindKey: win: "Ctrl-F", mac: "Command-F"
					exec: (editor) ->
						ace.require("ace/ext/searchbox").Search(editor, true)
					readOnly: true
				editor.commands.removeCommand "replace"

				editor.commands.addCommand
					name: "run-all",
					bindKey: win: "Ctrl-Shift-Enter", mac: "Command-Shift-Enter"
					exec: (editor) =>
						event = "#{scope.name}:run-all"
						$rootScope.$broadcast event
					readOnly: true

				editor.commands.addCommand
					name: "run-line",
					bindKey: win: "Ctrl-Enter", mac: "Command-Enter"
					exec: (editor) =>
						event = "#{scope.name}:run-line"
						$rootScope.$broadcast event
					readOnly: true

				# Make '/' work for search in vim mode.
				editor.showCommandLine = (arg) =>
					if arg == "/"
						ace.require("ace/ext/searchbox").Search(editor, true)

				if attrs.resizeOn?
					for event in attrs.resizeOn.split(",")
						scope.$on event, () ->
							editor.resize()

				scope.$watch "theme", (value) ->
					editor.setTheme("ace/theme/#{value}")

				scope.$watch "showPrintMargin", (value) ->
					editor.setShowPrintMargin(value)

				scope.$watch "keybindings", (value) ->
					if value in ["vim", "emacs"]
						editor.setKeyboardHandler("ace/keyboard/#{value}")
					else
						editor.setKeyboardHandler(null)

				scope.$watch "fontSize", (value) ->
					element.find(".ace_editor, .ace_content").css({
						"font-size": value + "px"
					})

				scope.$watch "sharejsDoc", (sharejs_doc, old_sharejs_doc) ->
					if old_sharejs_doc?
						detachFromAce(old_sharejs_doc)

					if sharejs_doc?
						attachToAce(sharejs_doc)

				scope.$watch "text", (text) ->
					if text?
						editor.setValue(text, -1)
						session = editor.getSession()
						session.setUseWrapMode(scope.wrapLines)
						session.setMode("ace/mode/#{scope.aceMode}")

				scope.$watch "aceMode", (mode) ->
					if mode?
						session = editor.getSession()
						session.setMode("ace/mode/#{mode}")

				scope.$watch "wrapLines", (wrap) ->
					if wrap?
						session = editor.getSession()
						session.setUseWrapMode(wrap)

				scope.$watch "annotations", (annotations) ->
					session = editor.getSession()
					session.setAnnotations annotations

				scope.$watch "readOnly", (value) ->
					editor.setReadOnly !!value

				scope.$watch "lineWrap", (lineWrap) =>
					if lineWrap?
						editor.getSession().setUseWrapMode(lineWrap)

				editor.setOption("scrollPastEnd", true)

				scope.$on "#{scope.name}:focus", () ->
					editor.focus()

				resetSession = () ->
					session = editor.getSession()
					session.setUseWrapMode(scope.wrapLines)
					session.setMode("ace/mode/#{scope.aceMode}")
					session.setAnnotations scope.annotations

				updatingSelection = false
				updateSelection = () ->
					range = editor.selection.getRange()
					lines = editor.getSession().getDocument().getLines(range.start.row, range.end.row)
					scope.$apply () ->
						scope.selection = {
							lines: lines
						}

				onSelectionChange = () ->
					# the changeSelection event is emitted multiple times
					# per change, so make sure we only run our update code once.
					if !updatingSelection
						updatingSelection = true
						setTimeout () ->
							updateSelection()
							updatingSelection = false
						, 0

				editor.on "changeSelection", onSelectionChange

				updateCount = 0
				last_sent_event = null
				onChange = () ->
					updateCount++
					if updateCount == 100
						event_tracking.send 'document', 'significantly-edit'

					# Send 'document-edit' events at a max rate of one per minute
					ONE_MINUTE = 60 * 1000
					now = new Date()
					if !last_sent_event? or now - last_sent_event > ONE_MINUTE
						event_tracking.send 'document', 'edit'
						last_sent_event = now

					scope.$emit "#{scope.name}:change"

				attachToAce = (sharejs_doc) ->
					lines = sharejs_doc.getSnapshot().split("\n")
					editor.setSession(new EditSession(lines))
					resetSession()
					session = editor.getSession()

					if scope.lineWrap
						editor.getSession().setUseWrapMode(true)

					doc = session.getDocument()
					doc.on "change", onChange

					sharejs_doc.on "remoteop.recordForUndo", () =>
						undoManager.nextUpdateIsRemote = true

					sharejs_doc.attachToAce(editor)
					# need to set annotations after attaching because attaching
					# deletes and then inserts document content
					session.setAnnotations scope.annotations

					updateSelection()

					editor.focus()

				detachFromAce = (sharejs_doc) ->
					sharejs_doc.detachFromAce()
					sharejs_doc.off "remoteop.recordForUndo"

					session = editor.getSession()
					doc = session.getDocument()
					doc.off "change", onChange

			template: """
				<div class="ace-editor-wrapper">
					<div
						class="undo-conflict-warning alert alert-danger small"
						ng-show="undo.show_remote_warning"
					>
						<strong>Watch out!</strong>
						We had to undo some of your collaborators changes before we could undo yours.
						<a
							href="#"
							class="pull-right"
							ng-click="undo.show_remote_warning = false"
						>Dismiss</a>
					</div>
					<div class="ace-editor-body"></div>
					<div
						class="dropdown context-menu spell-check-menu"
						ng-show="spellingMenu.open"
						ng-style="{top: spellingMenu.top, left: spellingMenu.left}"
						ng-class="{open: spellingMenu.open}"
					>
						<ul class="dropdown-menu">
							<li ng-repeat="suggestion in spellingMenu.highlight.suggestions | limitTo:8">
								<a href ng-click="replaceWord(spellingMenu.highlight, suggestion)">{{ suggestion }}</a>
							</li>
							<li class="divider"></li>
							<li>
								<a href ng-click="learnWord(spellingMenu.highlight)">Add to Dictionary</a>
							</li>
						</ul>
					</div>
					<div
						class="annotation-label"
						ng-show="annotationLabel.show"
						ng-style="{
							position: 'absolute',
							left:     annotationLabel.left,
							right:    annotationLabel.right,
							bottom:   annotationLabel.bottom,
							top:      annotationLabel.top,
							'background-color': annotationLabel.backgroundColor
						}"
					>
						{{ annotationLabel.text }}
					</div>

					<a
						href
						class="highlights-before-label btn btn-info btn-xs"
						ng-show="updateLabels.highlightsBefore > 0"
						ng-click="gotoHighlightAbove()"
					>
						<i class="fa fa-fw fa-arrow-up"></i>
						{{ updateLabels.highlightsBefore }} more update{{ updateLabels.highlightsBefore > 1 && "" || "s" }} above
					</a>

					<a
						href
						class="highlights-after-label btn btn-info btn-xs"
						ng-show="updateLabels.highlightsAfter > 0"
						ng-click="gotoHighlightBelow()"
					>
						<i class="fa fa-fw fa-arrow-down"></i>
						{{ updateLabels.highlightsAfter }} more update{{ updateLabels.highlightsAfter > 1 && "" || "s" }} below

					</a>
				</div>
			"""
		}

	monkeyPatchSearch = ($rootScope, $compile) ->
		SearchBox = ace.require("ace/ext/searchbox").SearchBox
		searchHtml = """
			<div class="ace_search right">
				<a href type="button" action="hide" class="ace_searchbtn_close">
					<i class="fa fa-fw fa-times"></i>
				</a>
				<div class="ace_search_form">
					<input class="ace_search_field form-control input-sm" placeholder="Search for" spellcheck="false"></input>
					<div class="btn-group">
						<button type="button" action="findNext" class="ace_searchbtn next btn btn-default btn-sm">
							<i class="fa fa-chevron-down fa-fw"></i>
						</button>
						<button type="button" action="findPrev" class="ace_searchbtn prev btn btn-default btn-sm">
							<i class="fa fa-chevron-up fa-fw"></i>
						</button>
					</div>
				</div>
				<div class="ace_replace_form">
					<input class="ace_search_field form-control input-sm" placeholder="Replace with" spellcheck="false"></input>
					<div class="btn-group">
						<button type="button" action="replaceAndFindNext" class="ace_replacebtn btn btn-default btn-sm">Replace</button>
						<button type="button" action="replaceAll" class="ace_replacebtn btn btn-default btn-sm">All</button>
					</div>
				</div>
				<div class="ace_search_options">
					<div class="btn-group">
						<span action="toggleRegexpMode" class="btn btn-default btn-sm" tooltip-placement="bottom" tooltip-append-to-body="true" tooltip="RegExp Search">.*</span>
						<span action="toggleCaseSensitive" class="btn btn-default btn-sm" tooltip-placement="bottom" tooltip-append-to-body="true" tooltip="CaseSensitive Search">Aa</span>
						<span action="toggleWholeWords" class="btn btn-default btn-sm" tooltip-placement="bottom" tooltip-append-to-body="true" tooltip="Whole Word Search">"..."</span>
					</div>
				</div>
			</div>
		"""

		# Remove Ace CSS
		$("#ace_searchbox").remove()

		$init = SearchBox::$init
		SearchBox::$init = () ->
			@element = $compile(searchHtml)($rootScope.$new())[0];
			$init.apply(@)
