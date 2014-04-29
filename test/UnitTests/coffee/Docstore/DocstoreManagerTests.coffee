chai = require('chai')
chai.should()
sinon = require("sinon")
modulePath = "../../../../app/js/Features/Docstore/DocstoreManager"
SandboxedModule = require('sandboxed-module')

describe "DocstoreManager", ->
	beforeEach ->
		@requestDefaults = sinon.stub().returns(@request = sinon.stub())
		@DocstoreManager = SandboxedModule.require modulePath, requires:
			"request" : defaults: @requestDefaults
			"settings-sharelatex": @settings =
				apis:
					docstore:
						url: "docstore.sharelatex.com"
			"logger-sharelatex": @logger = {log: sinon.stub(), error: sinon.stub()}

		@requestDefaults.calledWith(jar: false).should.equal true

		@project_id = "project-id-123"
		@doc_id = "doc-id-123"
		@callback = sinon.stub()

	describe "deleteDoc", ->
		describe "with a successful response code", ->
			beforeEach ->
				@request.del = sinon.stub().callsArgWith(1, null, statusCode: 204, "")
				@DocstoreManager.deleteDoc @project_id, @doc_id, @callback

			it "should delete the doc in the docstore api", ->
				@request.del
					.calledWith("#{@settings.apis.docstore.url}/project/#{@project_id}/doc/#{@doc_id}")
					.should.equal true

			it "should call the callback without an error", ->
				@callback.calledWith(null).should.equal true

		describe "with a failed response code", ->
			beforeEach ->
				@request.del = sinon.stub().callsArgWith(1, null, statusCode: 500, "")
				@DocstoreManager.deleteDoc @project_id, @doc_id, @callback

			it "should call the callback with an error", ->
				@callback.calledWith(new Error("docstore api responded with non-success code: 500")).should.equal true

			it "should log the error", ->
				@logger.error
					.calledWith({
						err: new Error("docstore api responded with a non-success code: 500")
						project_id: @project_id
						doc_id: @doc_id
					}, "error deleting doc in docstore")
					.should.equal true

