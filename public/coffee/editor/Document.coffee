define [
	"editor/ShareJsDoc"
	"libs/backbone"
], (ShareJsDoc) ->
	class Document
		@getDocument: (ide, doc_id) ->
			@openDocs ||= {}
			if !@openDocs[doc_id]?
				@openDocs[doc_id] = new Document(ide, doc_id)
			return @openDocs[doc_id]

		constructor: (@ide, @doc_id) ->
			@connected = @ide.socket.socket.connected
			@joined = false
			@wantToBeJoined = false
			@_bindToEditorEvents()
			@_bindToSocketEvents()

		attachToAce: (ace) ->
			@doc?.attachToAce(ace)

		detachFromAce: () ->
			@doc?.detachFromAce()

		getSnapshot: () ->
			@doc?.getSnapshot()

		getType: () ->
			@doc?.getType()

		_bindToSocketEvents: () ->
			@_onUpdateAppliedHandler = (update) => @_onUpdateApplied(update)
			@ide.socket.on "otUpdateApplied", @_onUpdateAppliedHandler
			@_onErrorHandler = (error, update) => @_onError(error, update)
			@ide.socket.on "otUpdateError", @_onErrorHandler
			@_onDisconnectHandler = (error) => @_onDisconnect(error)
			@ide.socket.on "disconnect", @_onDisconnectHandler

		_bindToEditorEvents: () ->
			@_onReconnectHandler = (update) => @_onReconnect(update)
			@ide.on "afterJoinProject", @_onReconnectHandler

		unBindFromSocketEvents: () ->
			@ide.socket.removeListener "otUpdateApplied", @_onUpdateAppliedHandler
			@ide.socket.removeListener "otUpdateError", @_onUpdateErrorHandler
			@ide.socket.removeListener "disconnect", @_onDisconnectHandler

		unBindFromEditorEvents: () ->
			@ide.off "afterJoinProject", @_onReconnectHandler

		leaveAndCleanUp: () ->
			@leave (error) =>
				@_cleanUp()

		join: (callback = (error) ->) ->
			@wantToBeJoined = true
			@_cancelLeave()
			if @connected
				return @_joinDoc callback
			else
				@_joinCallbacks ||= []
				@_joinCallbacks.push callback

		leave: (callback = (error) ->) ->
			@wantToBeJoined = false
			@_cancelJoin()
			if (@doc? and @doc.hasBufferedOps())
				@_leaveCallbacks ||= []
				@_leaveCallbacks.push callback
			else if !@connected
				callback()
			else
				@_leaveDoc(callback)

		_cancelLeave: () ->
			if @_leaveCallbacks?
				delete @_leaveCallbacks

		_cancelJoin: () ->
			if @_joinCallbacks?
				delete @_joinCallbacks

		_onUpdateApplied: (update) ->
			@ide.pushEvent "received-update",
				doc_id: @doc_id
				remote_doc_id: update?.doc
				wantToBeJoined: @wantToBeJoined
				update: update

			if Math.random() < (@ide.disconnectRate or 0)
				console.log "Simulating disconnect"
				@ide.connectionManager.disconnect()
				return

			if update?.doc == @doc_id and @doc?
				@doc.processUpdateFromServer update

				if !@wantToBeJoined
					@leave()

		_onDisconnect: () ->
			@connected = false
			@joined = false
			@doc?.updateConnectionState "disconnected"

		_onReconnect: () ->
			@ide.pushEvent "reconnected:afterJoinProject"

			@connected = true
			if @wantToBeJoined or @doc?.hasBufferedOps()
				@_joinDoc (error) =>
					return @_onError(error) if error?
					@doc.updateConnectionState "ok"
					@doc.flushPendingOps()
					@_callJoinCallbacks()

		_callJoinCallbacks: () ->
			for callback in @_joinCallbacks or []
				callback()
			delete @_joinCallbacks

		_joinDoc: (callback = (error) ->) ->
			if @doc?
				@ide.socket.emit 'joinDoc', @doc_id, @doc.getVersion(), (error, docLines, version, updates) =>
					return callback(error) if error?
					@joined = true
					@doc.catchUp( updates )
					callback()
			else
				@ide.socket.emit 'joinDoc', @doc_id, (error, docLines, version) =>
					return callback(error) if error?
					@joined = true
					@doc = new ShareJsDoc @doc_id, docLines, version, @ide.socket
					@_bindToShareJsDocEvents()
					callback()

		_leaveDoc: (callback = (error) ->) ->
			@ide.socket.emit 'leaveDoc', @doc_id, (error) =>
				return callback(error) if error?
				@joined = false
				for callback in @_leaveCallbacks or []
					callback(error)
				delete @_leaveCallbacks
				callback(error)

		_cleanUp: () ->
			delete Document.openDocs[@doc_id]
			@unBindFromEditorEvents()
			@unBindFromSocketEvents()

		_bindToShareJsDocEvents: () ->
			@doc.on "error", (error, meta) => @_onError error, meta
			@doc.on "externalUpdate", () => 
				@ide.pushEvent "externalUpdate",
					doc_id: @doc_id
				@trigger "externalUpdate"
			@doc.on "remoteop", () => 
				@ide.pushEvent "remoteop",
					doc_id: @doc_id
				@trigger "remoteop"
			@doc.on "op:sent", (op) =>
				@ide.pushEvent "op:sent",
					doc_id: @doc_id
					op: op
				@trigger "op:sent"
			@doc.on "op:acknowledged", (op) =>
				@ide.pushEvent "op:acknowledged",
					doc_id: @doc_id
					op: op
				@trigger "op:acknowledged"
			@doc.on "op:timeout", (op) =>
				@ide.pushEvent "op:timeout",
					doc_id: @doc_id
					op: op
				@trigger "op:timeout"
				ga?('send', 'event', 'error', "op timeout", "Op was now acknowledged - #{ide.socket.socket.transport.name}" )
				@ide.connectionManager.reconnectImmediately()
			@doc.on "flush", (inflightOp, pendingOp, version) =>
				@ide.pushEvent "flush",
					doc_id: @doc_id,
					inflightOp: inflightOp,
					pendingOp: pendingOp
					v: version

		_onError: (error, meta = {}) ->
			console.error "ShareJS error", error, meta
			ga?('send', 'event', 'error', "shareJsError", "#{error.message} - #{ide.socket.socket.transport.name}" )
			@ide.socket.disconnect()
			meta.doc_id = @doc_id
			@ide.reportError(error, meta)
			@doc?.clearInflightAndPendingOps()
			@_cleanUp()
			@trigger "error", error

	_.extend(Document::, Backbone.Events)

	return Document



	
