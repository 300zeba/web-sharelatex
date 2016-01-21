define [
], () ->
	class ReferencesSearchManager
		constructor: (@ide, @$scope) ->

			@$scope.$root._references = @state = keys: []

			@$scope.$on 'document:closed', (e, doc) =>
				if doc.doc_id
				 	entity = @ide.fileTreeManager.findEntityById doc.doc_id
					if entity?.name?.match /.*\.bib$/
						@$scope.$emit 'references:changed', entity
						@indexReferences doc.doc_id

			@$scope.$on 'project:joined', (e) =>
				@loadReferencesKeys()

		loadReferencesKeys: () ->
			if window._ENABLE_REFERENCES_AUTOCOMPLETE != true
				return
			$.post(
				"/project/#{@$scope.project_id}/referenceskeys",
				{
					shouldBroadcast: false
					_csrf: window.csrfToken
				},
				(data) =>
					console.log ">> ", data
			)

		indexReferences: (doc_id) ->
			if window._ENABLE_REFERENCES_AUTOCOMPLETE != true
				return
			$.post(
				"/project/#{@$scope.project_id}/references",
				{
					docId: doc_id,
					_csrf: window.csrfToken
				},
				(data) =>
					setTimeout(
						( () -> @getReferenceKeys() ).bind(this),
						500
					)
			)

		getReferenceKeys: (callback) ->
			if window._ENABLE_REFERENCES_AUTOCOMPLETE != true
				return
			$.get(
				"/project/#{@$scope.project_id}/references/keys",
				{
					_csrf: window.csrfToken
				},
				(data) =>
					@$scope.$root._references.keys = data.keys
					if callback
						callback(data.keys)
			)
