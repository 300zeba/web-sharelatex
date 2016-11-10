define [
	"ace/ace"
	"utils/EventEmitter"
	"ide/editor/directives/aceEditor/track-changes/ChangesTracker"
	"ide/colors/ColorManager"
], (_, EventEmitter, ChangesTracker, ColorManager) ->
	class TrackChangesManager
		Range = ace.require("ace/range").Range
		
		constructor: (@$scope, @editor, @element) ->
			@changesTracker = new ChangesTracker()
			@changeIdToMarkerIdMap = {}
			window.trackChangesManager ?= @

			@changesTracker.on "insert:added", (change) =>
				sl_console.log "[insert:added]", change
				@_onInsertAdded(change)
			@changesTracker.on "insert:removed", (change) =>
				sl_console.log "[insert:removed]", change
				@_onInsertRemoved(change)
			@changesTracker.on "delete:added", (change) =>
				sl_console.log "[delete:added]", change
				@_onDeleteAdded(change)
			@changesTracker.on "delete:removed", (change) =>
				sl_console.log "[delete:removed]", change
				@_onDeleteRemoved(change)
			@changesTracker.on "changes:moved", (changes) =>
				sl_console.log "[changes:moved]", changes
				@_onChangesMoved(changes)

			@changesTracker.on "comment:added", (comment) =>
				sl_console.log "[comment:added]", comment
				@_onCommentAdded(comment)
			@changesTracker.on "comment:moved", (comment) =>
				sl_console.log "[comment:moved]", comment
				@_onCommentMoved(comment)
			
			@editor.on "changeSelection", (e) =>
				# TODO: Make this only update focus when we get a more optimised updating system
				@updateReviewEntriesScope()
			
			@$scope.$on "comment:add", (e, comment) =>
				@addCommentToSelection(comment)

			@$scope.$on "comment:select_line", (e) =>
				@selectLineIfNoSelection()
			
			@$scope.$on "change:accept", (e, change_id) =>
				@acceptChangeId(change_id)
			
			@$scope.$on "change:reject", (e, change_id) =>
				@rejectChangeId(change_id)

			onChange = (e) =>
				if !@editor.initing and @enabled
					# This change is trigger by a sharejs 'change' event, which is before the
					# sharejs 'remoteop' event. So wait until the next event loop when the 'remoteop'
					# will have fired, before we decide if it was a remote op.
					setTimeout () =>
						if @nextUpdateMetaData?
							user_id = @nextUpdateMetaData.user_id
							# The remote op may have contained multiple atomic ops, each of which is an Ace
							# 'change' event (i.e. bulk commenting out of lines is a single remote op
							# but gives us one event for each % inserted). These all come in a single event loop
							# though, so wait until the next one before clearing the metadata.
							setTimeout () =>
								@nextUpdateMetaData = null
						else
							user_id = window.user.id

						@applyChange(e, { user_id })
						
						# TODO: Just for debugging, remove before going live.
						setTimeout () =>
							@checkMapping()
						, 100

			@editor.on "changeSession", (e) =>
				e.oldSession?.getDocument().off "change", onChange
				e.session.getDocument().on "change", onChange
			@editor.getSession().getDocument().on "change", onChange
			
			@editor.renderer.on "resize", () =>
				@recalculateReviewEntriesScreenPositions()
		
		enable: () ->
			@enabled = true
	
		disable: () ->
			@disabled = false
		
		turn_on_tracking: () ->
			@changesTracker.track_changes = true
		
		turn_off_tracking: () ->
			@changesTracker.track_changes = false

		addComment: (offset, length, content) ->
			@changesTracker.addComment offset, length, {
				thread: [{
					content: content
					user_id: window.user_id
					ts: new Date()
				}]
			}
		
		addCommentToSelection: (content) ->
			range = @editor.getSelectionRange()
			offset = @_aceRangeToShareJs(range.start)
			end = @_aceRangeToShareJs(range.end)
			length = end - offset
			@addComment(offset, length, content)
		
		selectLineIfNoSelection: () ->
			if @editor.selection.isEmpty()
				@editor.selection.selectLine()
		
		acceptChangeId: (change_id) ->
			@changesTracker.removeChangeId(change_id)
		
		rejectChangeId: (change_id) ->
			change = @changesTracker.getChange(change_id)
			return if !change?
			@changesTracker.removeChangeId(change_id)
			is_tracking = @changesTracker.track_changes
			@changesTracker.track_changes = false
			session = @editor.getSession()
			if change.op.d?
				content = change.op.d
				position = @_shareJsOffsetToAcePosition(change.op.p)
				session.insert(position, content)
			else if change.op.i?
				start = @_shareJsOffsetToAcePosition(change.op.p)
				end = @_shareJsOffsetToAcePosition(change.op.p + change.op.i.length)
				editor_text = session.getDocument().getTextRange({start, end})
				if editor_text != change.op.i
					throw new Error("Op to be removed (#{JSON.stringify(change.op)}), does not match editor text, '#{editor_text}'")
				session.remove({start, end})
			else
				throw new Error("unknown change: #{JSON.stringify(change)}")
			setTimeout () =>
				@changesTracker.track_changes = is_tracking
			, 0

		checkMapping: () ->
			session = @editor.getSession()

			# Make a copy of session.getMarkers() so we can modify it
			markers = {}
			for marker_id, marker of session.getMarkers()
				markers[marker_id] = marker

			expected_markers = []
			for change in @changesTracker.changes
				op = change.op
				{background_marker_id, callout_marker_id} = @changeIdToMarkerIdMap[change.id]
				start = @_shareJsOffsetToAcePosition(op.p)
				if op.i?
					end = @_shareJsOffsetToAcePosition(op.p + op.i.length)
				else if op.d?
					end = start
				expected_markers.push { marker_id: background_marker_id, start, end }
				expected_markers.push { marker_id: callout_marker_id, start, end: start }
			
			for comment in @changesTracker.comments
				{background_marker_id, callout_marker_id} = @changeIdToMarkerIdMap[comment.id]
				start = @_shareJsOffsetToAcePosition(comment.offset)
				end = @_shareJsOffsetToAcePosition(comment.offset + comment.length)
				expected_markers.push { marker_id: background_marker_id, start, end }
				expected_markers.push { marker_id: callout_marker_id, start, end: start }
			
			for {marker_id, start, end} in expected_markers
				marker = markers[marker_id]
				delete markers[marker_id]
				if marker.range.start.row != start.row or
						marker.range.start.column != start.column or
						marker.range.end.row != end.row or
						marker.range.end.column != end.column
					console.error "Change doesn't match marker anymore", {change, marker, start, end}
			
			for marker_id, marker of markers
				if marker.clazz.match("track-changes")
					console.error "Orphaned ace marker", marker
		
		applyChange: (delta, metadata) ->
			op = @_aceChangeToShareJs(delta)
			@changesTracker.applyOp(op, metadata)
		
		updateReviewEntriesScope: () ->
			# TODO: Update in place so Angular doesn't have to redo EVERYTHING
			@$scope.reviewPanel.entries = {}
			for change in @changesTracker.changes
				@$scope.reviewPanel.entries[change.id] = {
					type: if change.op.i then "insert" else "delete"
					content: change.op.i or change.op.d
					offset: change.op.p
					metadata: change.metadata
				}
			for comment in @changesTracker.comments
				@$scope.reviewPanel.entries[comment.id] = {
					type: "comment"
					thread: comment.metadata.thread
					offset: comment.offset
				}
			@updateFocus()
			@recalculateReviewEntriesScreenPositions()
		
		updateFocus: () ->
			@$scope.reviewPanel.entries["focus-position"] = {
				type: "focus-position"
				offset: @_aceRangeToShareJs(@editor.getSelectionRange().start)
			}
			@recalculateReviewEntriesScreenPositions()
		
		recalculateReviewEntriesScreenPositions: () ->
			session = @editor.getSession()
			renderer = @editor.renderer
			for entry_id, entry of (@$scope.reviewPanel?.entries or {})
				doc_position = @_shareJsOffsetToAcePosition(entry.offset)
				screen_position = session.documentToScreenPosition(doc_position.row, doc_position.column)
				y = screen_position.row * renderer.lineHeight
				entry.screenPos = { y }

			@$scope.$apply()

		_makeZeroWidthRange: (position) ->
			ace_range = new Range(position.row, position.column, position.row, position.column)
			# Our delete marker is zero characters wide, but Ace doesn't draw ranges
			# that are empty. So we monkey patch the range to tell Ace it's not empty.
			# This is the code we need to trick:
			#   var range = marker.range.clipRows(config.firstRow, config.lastRow);
			#   if (range.isEmpty()) continue;
			_clipRows = ace_range.clipRows
			ace_range.clipRows = (args...) ->
				range = _clipRows.apply(ace_range, args)
				range.isEmpty = () ->
					false
				return range
			return ace_range
		
		_createCalloutMarker: (position, klass) ->
			session = @editor.getSession()
			callout_range = @_makeZeroWidthRange(position)
			markerLayer = @editor.renderer.$markerBack
			callout_marker_id = session.addMarker callout_range, klass, (html, range, left, top, config) ->
				markerLayer.drawSingleLineMarker(html, range, "#{klass} ace_start", config, 0, "width: auto; right: 0;")

		_onInsertAdded: (change) ->
			start = @_shareJsOffsetToAcePosition(change.op.p)
			end = @_shareJsOffsetToAcePosition(change.op.p + change.op.i.length)
			session = @editor.getSession()
			doc = session.getDocument()
			background_range = new Range(start.row, start.column, end.row, end.column)
			background_marker_id = session.addMarker background_range, "track-changes-added-marker", "text"
			callout_marker_id = @_createCalloutMarker(start, "track-changes-added-marker-callout")
			@changeIdToMarkerIdMap[change.id] = { background_marker_id, callout_marker_id }
			@updateReviewEntriesScope()

		_onDeleteAdded: (change) ->
			position = @_shareJsOffsetToAcePosition(change.op.p)
			session = @editor.getSession()
			doc = session.getDocument()

			markerLayer = @editor.renderer.$markerBack
			klass = "track-changes-deleted-marker"
			background_range = @_makeZeroWidthRange(position)
			background_marker_id = session.addMarker background_range, klass, (html, range, left, top, config) ->
				markerLayer.drawSingleLineMarker(html, range, "#{klass} ace_start", config, 0, "")

			callout_marker_id = @_createCalloutMarker(position, "track-changes-deleted-marker-callout")
			@changeIdToMarkerIdMap[change.id] = { background_marker_id, callout_marker_id }
			@updateReviewEntriesScope()
		
		_onInsertRemoved: (change) ->
			{background_marker_id, callout_marker_id} = @changeIdToMarkerIdMap[change.id]
			session = @editor.getSession()
			session.removeMarker background_marker_id
			session.removeMarker callout_marker_id
			@updateReviewEntriesScope()
		
		_onDeleteRemoved: (change) ->
			{background_marker_id, callout_marker_id} = @changeIdToMarkerIdMap[change.id]
			session = @editor.getSession()
			session.removeMarker background_marker_id
			session.removeMarker callout_marker_id
			@updateReviewEntriesScope()
		
		_onCommentAdded: (comment) ->
			start = @_shareJsOffsetToAcePosition(comment.offset)
			end = @_shareJsOffsetToAcePosition(comment.offset + comment.length)
			session = @editor.getSession()
			doc = session.getDocument()
			background_range = new Range(start.row, start.column, end.row, end.column)
			background_marker_id = session.addMarker background_range, "track-changes-comment-marker", "text"
			callout_marker_id = @_createCalloutMarker(start, "track-changes-comment-marker-callout")
			@changeIdToMarkerIdMap[comment.id] = { background_marker_id, callout_marker_id }
			@updateReviewEntriesScope()

		_aceRangeToShareJs: (range) ->
			lines = @editor.getSession().getDocument().getLines 0, range.row
			offset = 0
			for line, i in lines
				offset += if i < range.row
					line.length
				else
					range.column
			offset += range.row # Include newlines

		_aceChangeToShareJs: (delta) ->
			offset = @_aceRangeToShareJs(delta.start)

			text = delta.lines.join('\n')
			switch delta.action
				when 'insert'
					return { i: text, p: offset }
				when 'remove'
					return { d: text, p: offset }
				else throw new Error "unknown action: #{delta.action}"
		
		_shareJsOffsetToAcePosition: (offset) ->
			lines = @editor.getSession().getDocument().getAllLines()
			row = 0
			for line, row in lines
				break if offset <= line.length
				offset -= lines[row].length + 1 # + 1 for newline char
			return {row:row, column:offset}
		
		_onChangesMoved: (changes) ->
			# TODO: PERFORMANCE: Only run through the Ace lines once, and calculate all
			# change positions as we go.
			for change in changes
				start = @_shareJsOffsetToAcePosition(change.op.p)
				if change.op.i?
					end = @_shareJsOffsetToAcePosition(change.op.p + change.op.i.length)
				else
					end = start
				@_updateMarker(change.id, start, end)
			@editor.renderer.updateBackMarkers()
			@updateReviewEntriesScope()
		
		_onCommentMoved: (comment) ->
			start = @_shareJsOffsetToAcePosition(comment.offset)
			end = @_shareJsOffsetToAcePosition(comment.offset + comment.length)
			@_updateMarker(comment.id, start, end)
			@editor.renderer.updateBackMarkers()
			@updateReviewEntriesScope()
	
		_updateMarker: (change_id, start, end) ->
			session = @editor.getSession()
			markers = session.getMarkers()
			{background_marker_id, callout_marker_id} = @changeIdToMarkerIdMap[change_id]
			background_marker = markers[background_marker_id]
			background_marker.range.start = start
			background_marker.range.end = end
			callout_marker = markers[callout_marker_id]
			callout_marker.range.start = start
			callout_marker.range.end = start

