define [
	"auto-complete/SuggestionManager"
	"auto-complete/Snippets"
	"ace/autocomplete/util"
	"ace/range"
	"ace/ext/language_tools"
], (SuggestionManager, Snippets, Util) ->
	Range = require("ace/range").Range

	Util.retrievePrecedingIdentifier = (text, pos, regex) ->
		currentLineOffset = 0
		for i in [(pos-1)..0]
			if text[i] == "\n"
				currentLineOffset = i + 1
				break
		currentLine = text.slice(currentLineOffset, pos)
		fragment = getLastCommandFragment(currentLine) or ""
		return fragment

	getLastCommandFragment = (lineUpToCursor) ->
		if m = lineUpToCursor.match(/(\\[^\\ ]+)$/)
			return m[1]
		else
			return null

	class AutoCompleteManager
		constructor: (@ide) ->
			@aceEditor = @ide.editor.aceEditor
			@aceEditor.setOptions({
				enableBasicAutocompletion: true,
				enableSnippets: true
			})

			SnippetCompleter =
				getCompletions: (editor, session, pos, prefix, callback) ->
					callback null, Snippets
			@suggestionManager = new SuggestionManager()

			@aceEditor.completers = [@suggestionManager, SnippetCompleter]

			@bindToEditorEvents()

		bindToEditorEvents: () ->
			@ide.editor.on "change:doc", (@aceSession) =>
				@aceSession.on "change", (change) => @onChange(change)

		onChange: (change) ->
			cursorPosition = @aceEditor.getCursorPosition()
			end = change.data.range.end
			# Check that this change was made by us, not a collaborator
			# (Cursor is still one place behind)
			if end.row == cursorPosition.row and end.column == cursorPosition.column + 1
				if change.data.action == "insertText"
					range = new Range(end.row, 0, end.row, end.column)
					lineUpToCursor = @aceSession.getTextRange(range)
					commandFragment = getLastCommandFragment(lineUpToCursor)

					if commandFragment? and commandFragment.length > 2
					 	setTimeout () =>
					 		@aceEditor.execCommand("startAutocomplete")
					 	, 0
