define [
	"base"
], (App) ->
	# We create and provide this as service so that we can access the global ide
	# from within other parts of the angular app.
	App.factory "jupyterRunner", ($http, $timeout, ide, ansi2html, $sce, localStorage) ->
		# Ordered list of preferred formats
		FORMATS = ["text/html_escaped", "image/png", "image/svg+xml", "image/jpeg", "application/pdf", "text/plain"]
		IMAGE_FORMATS = ["image/png", "image/svg+xml", "image/jpeg", "application/pdf"]
		
		ide.socket.on "clsiOutput", (message) ->
			engine_and_request_id = message.request_id
			return if !engine_and_request_id?
			[engine,request_id] = engine_and_request_id?.split(":")
			if !request_id? or !engine?
				# The message isn't a jupyter message, likely from commandRunner instead.
				return
			
			cell = jupyterRunner.findOrCreateCell(request_id, engine)
			
			jupyterRunner.stopIniting()

			if message.header.msg_type == "shutdown_reply"
				cell.restarted = true
				if message.content.exit_code == 137 # SIGKILL
					cell.memory_limit_exceeded = true
				else
					cell.restart_intentional = true
			
			if message.header.msg_type == "execute_input"
				cell.input.push message
			
			if message.header.msg_type in ["execute_input", "execute_reply", "execute_result"]
				if message.content.execution_count?
					cell.execution_count = message.content.execution_count
					
					# If the session has reset, but we didn't do it or haven't been told
					# about it, then it's likely that the server crashed/reset.
					# Do this before we create the cell, so we can see if the previous
					# cell was a shutdown request easily.
					if cell.execution_count == 1 and # Are we at the start of a session?
						jupyterRunner.cellCount(engine) > 1 and # Ignore if it's just our first run, this is expected
						!jupyterRunner.hasJustRestarted(engine) # Ignore if the previous message was a shutdown request, also expected
							# We've reset for some reason
							cell.restarted = true
			
			if message.header.msg_type in ["error", "stream", "display_data", "execute_result", "file_modified"]
				if not cell.restart_intentional # suppress any errors from the restart
					cell.output.push message
			
			if message.header.msg_type == "stream"
				message.content.text_escaped = ansiToSafeHtml(message.content.text)
			
			if message.header.msg_type == "error"
				message.content.traceback_escaped = message.content.traceback.map ansiToSafeHtml
				if m = message.content.evalue?.match(/^No module named (.*)$/)
					packageName = m[1]
					message.content.type = "missing_package"
					message.content.package = packageName
					message.content.language = "python"
				else if m = message.content.evalue?.match(/there is no package called ‘(.*)’/)
					packageName = m[1]
					message.content.type = "missing_package"
					message.content.package = packageName
					message.content.language = "R"
				else if m = message.content.ename == "MemoryError"
					cell.memory_limit_exceeded = true

			if message.header.msg_type.match(/^file_(created|moved|deleted)/)
				# need to refresh the output file listing when files change
				# but wait until final reply is received before updating
				cell?.refresh_output_files = true

			if message.header.msg_type in ["execute_reply"]
				if cell?.refresh_output_files
					ide.$scope.$broadcast "reload-output-files"
					delete cell.refresh_output_files
				else if cell.execution_count == 1
					# If the container has just inited we may need to update the
					# output file list
					ide.$scope.$broadcast "first-cell-execution"

			if message.header.msg_type == "file_modified"
				path = message.content.data['text/path']
				message.content.data['text/url'] = "/project/#{ide.$scope.project_id}/output/#{path}?cache_bust=#{Date.now()}"
				parts = path.split(".")
				if parts.length == 1
					extension = null
				else
					extension = parts[parts.length - 1].toLowerCase()
				if extension in ["png", "jpg", "jpeg", "svg", "gif"]
					message.content.file_type = "image"
			
			if message.header.msg_type == "display_data"
				if message.content.data['text/html']?
					message.content.data['text/html_escaped'] = $sce.trustAsHtml(message.content.data['text/html'])
				if message.content.data['image/svg+xml']?
					message.content.data['image/svg+xml'] = $sce.trustAsHtml(message.content.data['image/svg+xml'])
				if message.content.data['application/pdf']?
					message.content.data['application/pdf+url'] = $sce.trustAsResourceUrl("data:application/pdf;base64," + message.content.data['application/pdf'])
				
				for type in ['image/png', 'image/jpeg', 'application/pdf']
					if message.content.data[type]?
						message.content.data["#{type}+url"] =
							$sce.trustAsResourceUrl("data:#{type};base64,#{message.content.data[type]}")
					
				preferred_format = localStorage("preferred_format")
				if preferred_format? and preferred_format in FORMATS and message.content.data[preferred_format]?
					message.content.format = preferred_format
				else
					# Pick the first format we understand to show.
					for format in FORMATS
						if message.content.data[format]?
							message.content.format = format
							break
				
				if message.content.format in IMAGE_FORMATS
					message.content.image = true
					message.content.available_formats = _.intersection(Object.keys(message.content.data), IMAGE_FORMATS)
				
			if message.header.msg_type == "status"
				if message.content.execution_state == "busy"
					jupyterRunner.status.running = true
				else if message.content.execution_state == "idle"
					jupyterRunner.status.running = false
			
			if message.header.msg_type == "system_status" and message.content.status == "exported"
				cell.exported = true
		
			if message.header.msg_type == "system_status" and message.content.status == "timed_out"
				cell.timed_out = true
		
			ide.$scope.$apply()
		
		ansiToSafeHtml = (input) ->
			input = input
				.replace(/&/g, "&amp;")
				.replace(/</g, "&lt;")
				.replace(/>/g, "&gt;")
				.replace(/"/g, "&quot;")
				.replace(/'/g, "&#039;")
			return $sce.trustAsHtml(ansi2html.toHtml(input))
		
		jupyterRunner =
			CELL_LIST: {}
			CELLS: {}
			
			status: {
				running: false,
				stopping: false,
				error: false,
				initing: false
			}
			
			current_request_id: null
		
			executeRequest: (code, engine) ->
				request_id = Math.random().toString().slice(2)
				@current_request_id = "#{engine}:#{request_id}"
				@status.running = true
				@status.error = false
				
				@_initingTimeout = $timeout () =>
					@status.initing = true
				, 2000

				url = "/project/#{ide.$scope.project_id}/request"
				options = {
					request_id: "#{engine}:#{request_id}"
					msg_type: "execute_request"
					content: {
						code: code,
						silent: false,
						store_history: true,
						user_expressions: {},
						allow_stdin: false,
						stop_on_error: false
					}
					engine: engine
					_csrf: window.csrfToken
				}
				$http
					.post(url, options)
					.success (data) =>
						@stopIniting()
						@status.running = false
					.error () =>
						@stopIniting()
						@status.error = true
						@status.running = false
			
			stopIniting: () ->
				if @_initingTimeout?
					$timeout.cancel(@_initingTimeout)
					delete @_initingTimeout
				@status.initing = false
			
			findOrCreateCell: (request_id, engine) ->
				if jupyterRunner.CELLS[request_id]?
					return jupyterRunner.CELLS[request_id]
				else
					cell = {
						request_id: request_id
						engine: engine
						input: []
						output: []
					}
					jupyterRunner.CELLS[request_id] = cell
					jupyterRunner.CELL_LIST[engine] ||= []
					jupyterRunner.CELL_LIST[engine].push cell
					return cell
			
			cellCount: (engine) ->
				return jupyterRunner.CELL_LIST[engine]?.length or 0
			
			hasJustRestarted: (engine) ->
				cells = jupyterRunner.CELL_LIST[engine] or []
				return false if cells.length < 2
				last_cell = cells[cells.length - 1]
				second_last_cell = cells[cells.length - 2]
				return !!last_cell.restarted or !!second_last_cell.restarted
			
			stop: () ->
				request_id = @current_request_id
				return if !request_id?
				url = "/project/#{_ide.$scope.project_id}/request/#{request_id}/interrupt"
				$http
					.post(url, {
						_csrf: window.csrfToken
					})
			
			shutdown: (engine) ->
				request_id = Math.random().toString().slice(2)
				@current_request_id = "#{engine}:#{request_id}"
				url = "/project/#{ide.$scope.project_id}/request"
				options = {
					request_id: "#{engine}:#{request_id}"
					msg_type: "shutdown_request"
					content: {
						restart: true
					}
					engine: engine
					_csrf: window.csrfToken
				}
				$http
					.post(url, options)
					.error () =>
						@status.error = true

		return jupyterRunner
