define [
	"ide/track-changes/TrackChangesListController"
], () ->
	class TrackChangesManager
		constructor: (@ide, @$scope) ->
			@reset()

			@$scope.toggleTrackChanges = () =>
				if @$scope.ui.view == "track-changes"
					@$scope.ui.view = "editor"
				else
					@$scope.ui.view = "track-changes"
					@onShow()

			@$scope.$watch "trackChanges.selection.updates", (updates) =>
				if updates? and updates.length > 0
					@_selectDocFromUpdates()
					@reloadDiff()

			@$scope.$on "entity:selected", (event, entity) =>
				if (@$scope.ui.view == "track-changes") and (entity.type == "doc")
					@$scope.trackChanges.selection.doc = entity
					@reloadDiff()

		onShow: () ->
			@reset()
			@fetchNextBatchOfChanges()
				.success () =>
					@autoSelectRecentUpdates()

		reset: () ->
			@$scope.trackChanges = {
				updates: []
				nextBeforeTimestamp: null
				atEnd: false
				selection: {
					updates: []
					doc: null
					range: {
						fromV: null
						toV: null
						start_ts: null
						end_ts: null
					}
				}
				diff: null
			}

		autoSelectRecentUpdates: () ->
			console.log "AUTO SELECTING UPDATES", @$scope.trackChanges.updates.length
			return if @$scope.trackChanges.updates.length == 0

			@$scope.trackChanges.updates[0].selectedTo = true

			indexOfLastUpdateNotByMe = 0
			for update, i in @$scope.trackChanges.updates
				if @_updateContainsUserId(update, @$scope.user.id)
					break
				indexOfLastUpdateNotByMe = i

			@$scope.trackChanges.updates[indexOfLastUpdateNotByMe].selectedFrom = true

		BATCH_SIZE: 4
		fetchNextBatchOfChanges: () ->
			url = "/project/#{@ide.project_id}/updates?min_count=#{@BATCH_SIZE}"
			if @nextBeforeTimestamp?
				url += "&before=#{@$scope.trackChanges.nextBeforeTimestamp}"
			@ide.$http
				.get(url)
				.success (data) =>
					@_loadUpdates(data.updates)
					@$scope.trackChanges.nextBeforeTimestamp = data.nextBeforeTimestamp
					if !data.nextBeforeTimestamp?
						@$scope.trackChanges.atEnd = true

		reloadDiff: () ->

			diff = @$scope.trackChanges.diff
			{updates, doc} = @$scope.trackChanges.selection
			{fromV, toV}   = @_calculateRangeFromSelection()

			console.log "Checking if diff has changed", doc?.id, fromV, toV, updates

			return if !doc?

			return if diff? and
				diff.doc   == doc   and
				diff.fromV == fromV and
				diff.toV   == toV

			console.log "Loading diff", fromV, toV, doc?.id

			@$scope.trackChanges.diff = diff = {
				fromV:   fromV
				toV:     toV
				doc:     doc
				loading: true
				error:   false
			}

			url = "/project/#{@$scope.project_id}/doc/#{diff.doc.id}/diff"
			if diff.fromV? and diff.toV?
				url += "?from=#{diff.fromV}&to=#{diff.toV}"

			@ide.$http
				.get(url)
				.success (data) =>
					diff.loading = false
					{text, annotations} = @_parseDiff(data)
					diff.text = text
					diff.annotations = annotations
				.error () ->
					diff.loading = false
					diff.error = true

		_parseDiff: (diff) ->
			row    = 0
			column = 0
			annotations = []
			text   = ""
			for entry, i in diff.diff or []
				content = entry.u or entry.i or entry.d
				content ||= ""
				text += content
				lines   = content.split("\n")
				startRow    = row
				startColumn = column
				if lines.length > 1
					endRow    = startRow + lines.length - 1
					endColumn = lines[lines.length - 1].length
				else
					endRow    = startRow
					endColumn = startColumn + lines[0].length
				row    = endRow
				column = endColumn

				range = {
					start:
						row: startRow
						column: startColumn
					end:
						row: endRow
						column: endColumn
				}

				if entry.i? or entry.d?
					name = "#{entry.meta.user.first_name} #{entry.meta.user.last_name}"
					if entry.meta.user.id == @$scope.user.id
						name = "you"
					date = moment(entry.meta.end_ts).format("Do MMM YYYY, h:mm a")
					if entry.i?
						annotations.push {
							label: "Added by #{name} on #{date}"
							highlight: range
							hue: @ide.onlineUsersManager.getHueForUserId(entry.meta.user.id)
						}
					else if entry.d?
						annotations.push {
							label: "Deleted by #{name} on #{date}"
							strikeThrough: range
							hue: @ide.onlineUsersManager.getHueForUserId(entry.meta.user.id)
						}

			return {text, annotations}

		_loadUpdates: (updates = []) ->
			previousUpdate = @$scope.trackChanges.updates[@$scope.trackChanges.updates.length - 1]

			for update in updates
				for doc_id, doc of update.docs or {}
					doc.entity = @ide.fileTreeManager.findEntityById(doc_id)

				for user in update.meta.users or []
					user.hue = @ide.onlineUsersManager.getHueForUserId(user.id)

				if !previousUpdate? or !moment(previousUpdate.meta.end_ts).isSame(update.meta.end_ts, "day")
					update.meta.first_in_day = true

				update.selectedFrom = false
				update.selectedTo = false
				update.inSelection = false

				previousUpdate = update

			@$scope.trackChanges.updates =
				@$scope.trackChanges.updates.concat(updates)

		_calculateRangeFromSelection: () ->
			fromV = toV = start_ts = end_ts = null

			selected_doc_id = @$scope.trackChanges.selection.doc?.id

			for update in @$scope.trackChanges.selection.updates or []
				for doc_id, doc of update.docs
					if doc_id == selected_doc_id
						if fromV? and toV?
							fromV = Math.min(fromV, doc.fromV)
							toV = Math.max(toV, doc.toV)
							start_ts = Math.min(start_ts, update.meta.start_ts)
							end_ts = Math.max(end_ts, update.meta.end_ts)
						else
							fromV = doc.fromV
							toV = doc.toV
							start_ts = update.meta.start_ts
							end_ts = update.meta.end_ts
						break

			return {fromV, toV, start_ts, end_ts}

		# Set the track changes selected doc to one of the docs in the range
		# of currently selected updates. If we already have a selected doc
		# then prefer this one if present.
		_selectDocFromUpdates: () ->
			affected_docs = {}
			for update in @$scope.trackChanges.selection.updates
				for doc_id, doc of update.docs
					affected_docs[doc_id] = true

			selected_doc = @$scope.trackChanges.selection.doc
			if selected_doc? and affected_docs[selected_doc.id]
				console.log "An affected doc is already open, bravo!"
				selected_doc_id = selected_doc.id
			else
				console.log "selected doc is not open, selecting first one"
				for doc_id, doc of affected_docs
					selected_doc_id = doc_id
					break

			doc = @$scope.trackChanges.selection.doc = @ide.fileTreeManager.findEntityById(selected_doc_id)
			@ide.fileTreeManager.selectEntity(doc)

		_updateContainsUserId: (update, user_id) ->
			for user in update.meta.users
				return true if user.id == user_id
			return false
