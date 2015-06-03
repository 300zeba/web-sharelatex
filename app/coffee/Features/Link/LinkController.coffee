logger = require('logger-sharelatex')
FileStoreHandler = require("../FileStore/FileStoreHandler")
CompileController = require("../Compile/CompileController")
LinkCreator = require("./LinkCreator")
Settings = require "settings-sharelatex"
request = require "request"
Link = require("../../models/Link").Link
Path = require "path"
base64 = require "base64-stream"
Readable = require('stream').Readable

module.exports = LinkController =
	generateLink : (req, res) ->
		user_id = req.session.user._id
		project_id = req.params.Project_id # this has been checked by the middleware
		path = req.body.path # this will be checked by the clsi
		logger.log project_id: project_id, user_id: user_id, path: path, "generate link"
		# Copy file from clsi to filestore using link._id as the identifier
		LinkController._getSrcStream project_id, req.body, (err, srcStream) ->
			# Get the stream from the CLSI
			srcStream.on "error", (err) ->
				logger.err err:err, "error on get stream"
				res.status(500).send {error: err}

			# N.B. make sure the srcStream/response stream are discard if needed
			# Create the link in mongo
			path = path.replace /^\.output\//, '' # strip leading directory for diverted images
			LinkCreator.createNewLink {user_id, project_id, path}, (err, link) ->
				if err?
					srcStream.resume()
					logger.err {err:err, project_id}, "error creating link"
					return res.status(500).send()
				logger.log link, "created new link"
				# Send the stream to the filestore at /project/:project_id/public/:public_file_id
				destUrl = "#{Settings.apis.filestore.url}/project/#{project_id}/public/#{link._id}"
				destStream = request.post destUrl, {timeout: 60*1000}, (err, response, body) ->
					if err? or response.statusCode != 200
						logger.err {err: err, project_id, body: body}, "error posting data to filestore" 
						res.status(response?.statusCode || 500).send()
					else
						short_id = link.public_id
						if Settings.publicLinkUrl?
							link_url = "#{Settings.publicLinkUrl}/#{short_id}/#{link.path}"
						else
							link_url = "#{Settings.siteUrl}/public/#{short_id}/#{link.path}"
						res.send {
							link: link_url
						}
				srcStream.pipe(destStream)
				srcStream.resume()
	
	_getSrcStream: (project_id, body, callback = (error, srcStream) ->) ->
		if body.base64?
			stream = base64.decode()
			stream.pause()
			callback null, stream
			stream.write(body.base64)
			stream.end()
		else if body.data?
			stream = new Readable()
			stream.pause()
			callback null, stream
			stream.push body.data
			stream.push null
		else
			CompileController.getClsiStream project_id, body.path, (error, srcStream) ->
				return callback(error) if error?
				srcStream.pause()
				srcStream.on "response", (response) ->
					logger.log {statusCode:response.statusCode, project_id}, "get response code"
					callback null, srcStream

	getFile : (req, res) ->
		# We need to be able to put this on a cdn, so we allow for a separate subdomain
		if Settings.publicLinkRestrictions?
			# hash of key value pairs which must match the request headers
			for key, value of Settings.publicLinkRestrictions
				if req.headers[key] != value
					return res.send(403)
		# Check that the public id is valid
		public_id = req.params.public_id
		if not public_id? or not public_id.match(/^[0-9a-zA-Z]+$/)
			return res.send(404, "Invalid link id")
		# Look up the link from its public id
		Link.findOne {public_id: public_id}, (err, link) ->
			if err? or !link?
				return res.send(404, err)
			url = "#{Settings.apis.filestore.url}/project/#{link.project_id}/public/#{link._id}"
			oneMinute = 60 * 1000
			options = { url: url, method: req.method,	timeout: oneMinute }
			proxy = request.get url
			proxy.on "error", (err) ->
				logger.warn err: err, url: url, "filestore proxy error"
				res.send(500)
			# Force plain treatment of other file types to prevent hosting of HTTP/JS files
			# that could be used in same-origin/XSS attacks.
			switch Path.extname(link.path)
				when ".png" then res.set "Content-Type", "image/png"
				when ".jpg" then res.set "Content-Type", "image/jpeg"
				#when ".svg" then res.set "Content-Type", "image/svg+xml" # disabled for possible XSS
				when ".pdf" then res.set "Content-Type", "application/pdf"
				else res.set "Content-Type", "text/plain"
			res.set "Cache-Control", "public, max-age=86400"
			res.set "Last-Modified", link.created.toUTCString()
			res.set "ETag", link._id
			proxy.pipe(res)
