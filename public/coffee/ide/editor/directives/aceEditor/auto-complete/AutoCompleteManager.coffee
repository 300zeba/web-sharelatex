define [
	"ide/editor/directives/aceEditor/auto-complete/SuggestionManager"
	"ide/editor/directives/aceEditor/auto-complete/Snippets"
	"ace/ace"
	"ace/ext-language_tools"
], (SuggestionManager, Snippets) ->
	Range = ace.require("ace/range").Range

	getLastCommandFragment = (lineUpToCursor) ->
		if m = lineUpToCursor.match(/(\\[^\\ ]+)$/)
			return m[1]
		else
			return null

	class AutoCompleteManager
		constructor: (@$scope, @editor) ->
			@suggestionManager = new SuggestionManager()

			@$scope.$watch "autoComplete", (autocomplete) =>
				if autocomplete
					@enable()
				else
					@disable()

			onChange = (change) =>
				@onChange(change)

			@editor.on "changeSession", (e) =>
				e.oldSession.off "change", onChange
				e.session.on "change", onChange

		enable: () ->
			console.log "ENABLE auto complete"

			@editor.setOptions({
				enableBasicAutocompletion: true,
				enableSnippets: true,
				enableLiveAutocompletion: true
			})
			@editor.commands.addCommand {
				name: 'tabComplete'
				bindKey: 'TAB'
				exec: (editor) =>
					pos = editor.getCursorPosition()
					current_line = editor.getSession().getLine(pos.row)
					line_to_cursor = current_line.slice(0, pos.column)
					line_beyond_cursor = current_line.slice(pos.column)
					if line_to_cursor.match(/(\w|\.)$/) and line_beyond_cursor == ''
						setTimeout () =>
							editor.execCommand("startAutocomplete")
						, 0
					else
						editor.indent()
					setTimeout =>
						@_attachSpinner(@$scope)
					, 1
			}
			@editor.completers.push @suggestionManager

			window._e = @editor

		disable: () ->
			@editor.setOptions({
				enableBasicAutocompletion: false,
				enableSnippets: false
			})

		_attachSpinner: (scope) ->
			# early return if we've already got a spinner from a
			# previous run
			if scope._autocomplete_spinner
				return

			# get the autocomplete popup, if it exists in the page
			autocomplete = $('.ace_autocomplete')
			if autocomplete.length == 1
				# try to find the spinner (it may already exist)
				spinner = $('.dj_ace_autocomplete_spinner')[0]
				if !spinner
					# patch styles on the autocomplete popup
					ac = autocomplete[0]
					ac.style.position = 'relative'
					ac.style.overflow = 'visible'  # required to make the spinner visible

					# create the spinner elements
					inner = document.createElement('div')
					inner.classList.add('loading')
					inner.style.visibility = 'visible'
					for i in [1..3]
						dot = document.createElement('span')
						dot.textContent = '.'
						inner.appendChild(dot)
					spinner = document.createElement('div')
					spinner.classList.add('dj_ace_autocomplete_spinner')
					spinner.appendChild(inner)

					spinner.style.position = 'absolute'
					spinner.style.bottom = '-20px'
					spinner.style.left = '4px'

					# append the spinner to the autocomplete popup
					$(ac).append(spinner)

					# keep track of how many completion requests are in flight.
					# show/hide the spinner visuals as appropriate
					spinner._request_count = 0
					scope.$on 'completion_request:start', () ->
						spinner._request_count++
						if spinner._request_count > 0
							inner.style.visibility = 'visible'

					scope.$on 'completion_request:end', () ->
						spinner._request_count--
						if spinner._request_count <= 0
							inner.style.visibility = 'hidden'

				scope._autocomplete_spinner = spinner


		onChange: (change) ->
			cursorPosition = @editor.getCursorPosition()
			end = change.end
			# Check that this change was made by us, not a collaborator
			# (Cursor is still one place behind)
			if end.row == cursorPosition.row and end.column == cursorPosition.column + 1
				if change.action == "insert"
					range = new Range(end.row, 0, end.row, end.column)
					lineUpToCursor = @editor.getSession().getTextRange(range)
					commandFragment = getLastCommandFragment(lineUpToCursor)
					# console.log ">> onChange: #{lineUpToCursor} - #{commandFragment}"

					if commandFragment? and commandFragment.length > 2
						setTimeout () =>
							@editor.execCommand("startAutocomplete")
						, 0

					# fire autocomplete if line ends in `some_identifier.`
					if lineUpToCursor.match(/(\w+)\.$/)
						setTimeout () =>
							@editor.execCommand("startAutocomplete")
						, 0
			setTimeout =>
				@_attachSpinner(@$scope)
			, 1
