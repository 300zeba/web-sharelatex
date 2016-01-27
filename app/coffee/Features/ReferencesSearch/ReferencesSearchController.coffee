logger = require('logger-sharelatex')
ReferencesSearchHandler = require('./ReferencesSearchHandler')
settings = require('settings-sharelatex')
EditorRealTimeController = require("../Editor/EditorRealTimeController")

module.exports = ReferencesSearchController =


	index: (req, res) ->
		projectId = req.params.Project_id
		shouldBroadcast = req.body.shouldBroadcast
		docIds = req.body.docIds
		if (!docIds or !(docIds instanceof Array))
			logger.err {projectId, docIds}, "docIds is not valid, should be either Array or String 'ALL'"
			return res.send 400
		logger.log {projectId, docIds: docIds}, "index references for project"
		ReferencesSearchHandler.index projectId, docIds, (err, data) ->
			if err
				logger.err {err, projectId}, "error indexing all references"
				return res.send 500
			ReferencesSearchController._handleIndexResponse(req, res, projectId, shouldBroadcast, data)

	indexAll: (req, res) ->
		projectId = req.params.Project_id
		shouldBroadcast = req.body.shouldBroadcast
		logger.log {projectId}, "index all references for project"
		ReferencesSearchHandler.indexAll projectId, (err, data) ->
			if err
				logger.err {err, projectId}, "error indexing all references"
				return res.send 500
			ReferencesSearchController._handleIndexResponse(req, res, projectId, shouldBroadcast, data)

	_handleIndexResponse: (req, res, projectId, shouldBroadcast, data) ->
		if shouldBroadcast
			logger.log {projectId}, "emitting new references keys to connected clients"
			EditorRealTimeController.emitToRoom projectId, 'references:keys:updated', data.keys
		return res.json data
