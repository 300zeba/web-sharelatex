logger = require('logger-sharelatex')
ProjectLocator = require("../Project/ProjectLocator")
PreviewHandler = require('./PreviewHandler')
_build_filestore_url = require('../FileStore/FileStoreHandler')._buildUrl


module.exports = PreviewController =

	getPreviewCsv: (req, res) ->
		project_id = req.params.Project_id
		file_id = req.params.file_id
		logger.log project_id: project_id, file_id: file_id, "getting preview of csv file"
		ProjectLocator.findElement project_id: project_id, element_id: file_id, type: 'file', (err, file) ->
			if err?
				logger.log err: err, project_id: project_id, file_id: file_id, "error finding element for file"
				return res.sendStatus 500

			file_url = _build_filestore_url(project_id, file_id)

			PreviewHandler.getPreviewCsv file_url, (err, preview) ->
				if err?
					logger.log err: err, project_id: project_id, file_id: file_id, "error getting preview"
					return res.sendStatus 500
				res.send preview

	getPreviewText: (req, res) ->
		project_id = req.params.Project_id
		file_id = req.params.file_id
		logger.log project_id: project_id, file_id: file_id, "getting preview of text file"
		ProjectLocator.findElement project_id: project_id, element_id: file_id, type: 'file', (err, file) ->
			if err?
				logger.log err: err, project_id: project_id, file_id: file_id, "error finding element for file"
				return res.sendStatus 500

			file_url = _build_filestore_url(project_id, file_id)

			PreviewHandler.getPreviewText file_url, (err, preview) ->
				if err?
					logger.log err: err, project_id: project_id, file_id: file_id, "error getting preview"
					return res.sendStatus 500
				res.send preview
