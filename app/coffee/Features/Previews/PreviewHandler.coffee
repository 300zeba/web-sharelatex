logger = require("logger-sharelatex")
request = require("request")
settings = require("settings-sharelatex")

oneMinInMs = 60 * 1000
fiveMinsInMs = oneMinInMs * 5

module.exports = PreviewHandler =

	getPreviewText: (file_url, callback) ->
		logger.log file_url: file_url, "getting preview of file"
		opts =
			method: 'get'
			uri: @_build_text_url file_url
			timeout: fiveMinsInMs
		request opts, (err, response, body) ->
			return callback(err, null) if err?
			if 200 <= response.statusCode < 300
				callback(null, body)
			else
				logger.log file_url: file_url, status_code: response.statusCode, "Got non-ok response from Previewer"
				callback(new Error("Got non-ok response from Previewer service: #{response.statusCode}"), null)

	getPreviewCsv: (file_url, callback) ->
		logger.log file_url: file_url, "getting preview of file"
		opts =
			method: 'get'
			uri: @_build_csv_url file_url
			timeout: fiveMinsInMs
		request opts, (err, response, body) ->
			return callback(err, null) if err?
			if 200 <= response.statusCode < 300
				callback(null, body)
			else
				logger.log file_url: file_url, status_code: response.statusCode, "Got non-ok response from Previewer"
				callback(new Error("Got non-ok response from Previewer service: #{response.statusCode}"), null)

	_build_csv_url: (file_url) ->
		return "#{settings.apis.previewer.url}/preview/csv?fileUrl=#{file_url}"

	_build_text_url: (file_url) ->
		return "#{settings.apis.previewer.url}/preview/text?fileUrl=#{file_url}"
