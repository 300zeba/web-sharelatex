sinon = require('sinon')
chai = require('chai')
should = chai.should()
expect = chai.expect
modulePath = "../../../../app/js/Features/Project/ProjectGetter.js"
SandboxedModule = require('sandboxed-module')
ObjectId = require("mongojs").ObjectId
assert = require("chai").assert

describe "ProjectGetter", ->
	beforeEach ->
		@callback = sinon.stub()
		@ProjectGetter = SandboxedModule.require modulePath, requires:
			"../../infrastructure/mongojs":
				db: @db =
					projects: {}
					users: {}
				ObjectId: ObjectId
			"metrics-sharelatex": timeAsyncMethod: sinon.stub()
			"../../models/Project": Project: @Project = {}
			"../Collaborators/CollaboratorsHandler": @CollaboratorsHandler = {}
			"../../infrastructure/LockManager": @LockManager =
					runWithLock : sinon.spy((namespace, id, runner, callback) -> runner(callback))
			'./ProjectEntityMongoUpdateHandler':
					lockKey: (project_id) -> project_id
			"logger-sharelatex":
				err:->
				log:->

	describe "getProjectWithoutDocLines", ->
		beforeEach ->
			@project =
				_id: @project_id = "56d46b0a1d3422b87c5ebcb1"
			@ProjectGetter.getProject = sinon.stub().yields()

		describe "passing an id", ->
			beforeEach ->
				@ProjectGetter.getProjectWithoutDocLines @project_id, @callback

			it "should call find with the project id", ->
				@ProjectGetter.getProject
					.calledWith(@project_id)
					.should.equal true

			it "should exclude the doc lines", ->
				excludes =
					"rootFolder.docs.lines": 0
					"rootFolder.folders.docs.lines": 0
					"rootFolder.folders.folders.docs.lines": 0
					"rootFolder.folders.folders.folders.docs.lines": 0
					"rootFolder.folders.folders.folders.folders.docs.lines": 0
					"rootFolder.folders.folders.folders.folders.folders.docs.lines": 0
					"rootFolder.folders.folders.folders.folders.folders.folders.docs.lines": 0
					"rootFolder.folders.folders.folders.folders.folders.folders.folders.docs.lines": 0

				@ProjectGetter.getProject
					.calledWith(@project_id, excludes)
					.should.equal true

			it "should call the callback", ->
				@callback.called.should.equal true


	describe "getProjectWithOnlyFolders", ->

		beforeEach ()->
			@project =
				_id: @project_id = "56d46b0a1d3422b87c5ebcb1"
			@ProjectGetter.getProject = sinon.stub().yields()

		describe "passing an id", ->
			beforeEach ->
				@ProjectGetter.getProjectWithOnlyFolders @project_id, @callback

			it "should call find with the project id", ->
				@ProjectGetter.getProject
					.calledWith(@project_id)
					.should.equal true

			it "should exclude the docs and files linesaaaa", ->
				excludes =
					"rootFolder.docs": 0
					"rootFolder.fileRefs": 0
					"rootFolder.folders.docs": 0
					"rootFolder.folders.fileRefs": 0
					"rootFolder.folders.folders.docs": 0
					"rootFolder.folders.folders.fileRefs": 0
					"rootFolder.folders.folders.folders.docs": 0
					"rootFolder.folders.folders.folders.fileRefs": 0
					"rootFolder.folders.folders.folders.folders.docs": 0
					"rootFolder.folders.folders.folders.folders.fileRefs": 0
					"rootFolder.folders.folders.folders.folders.folders.docs": 0
					"rootFolder.folders.folders.folders.folders.folders.fileRefs": 0
					"rootFolder.folders.folders.folders.folders.folders.folders.docs": 0
					"rootFolder.folders.folders.folders.folders.folders.folders.fileRefs": 0
					"rootFolder.folders.folders.folders.folders.folders.folders.folders.docs": 0
					"rootFolder.folders.folders.folders.folders.folders.folders.folders.fileRefs": 0
				@ProjectGetter.getProject
					.calledWith(@project_id, excludes)
					.should.equal true

			it "should call the callback with the project", ->
				@callback.called.should.equal true


	describe "getProject", ->
		beforeEach ()->
			@project =
				_id: @project_id = "56d46b0a1d3422b87c5ebcb1"
			@db.projects.find = sinon.stub().callsArgWith(2, null, [@project])

		describe "without projection", ->
			describe "with project id", ->
				beforeEach ->
					@ProjectGetter.getProject @project_id, @callback

				it "should call find with the project id", ->
					expect(@db.projects.find.callCount).to.equal 1
					expect(@db.projects.find.lastCall.args[0]).to.deep.equal {
						_id: ObjectId(@project_id)
					}

			describe "without project id", ->
				beforeEach ->
					@ProjectGetter.getProject null, @callback

				it "should callback with error", ->
					expect(@db.projects.find.callCount).to.equal 0
					expect(@callback.lastCall.args[0]).to.be.instanceOf Error

		describe "with projection", ->
			beforeEach ->
				@projection = {_id: 1}

			describe "with project id", ->
				beforeEach ->
					@ProjectGetter.getProject @project_id, @projection, @callback

				it "should call find with the project id", ->
					expect(@db.projects.find.callCount).to.equal 1
					expect(@db.projects.find.lastCall.args[0]).to.deep.equal {
						_id: ObjectId(@project_id)
					}
					expect(@db.projects.find.lastCall.args[1]).to.deep.equal @projection

			describe "without project id", ->
				beforeEach ->
					@ProjectGetter.getProject null, @callback

				it "should callback with error", ->
					expect(@db.projects.find.callCount).to.equal 0
					expect(@callback.lastCall.args[0]).to.be.instanceOf Error

	describe "getProjectWithoutLock", ->
		beforeEach ()->
			@project =
				_id: @project_id = "56d46b0a1d3422b87c5ebcb1"
			@db.projects.find = sinon.stub().callsArgWith(2, null, [@project])

		describe "without projection", ->
			describe "with project id", ->
				beforeEach ->
					@ProjectGetter.getProjectWithoutLock @project_id, @callback

				it "should call find with the project id", ->
					expect(@db.projects.find.callCount).to.equal 1
					expect(@db.projects.find.lastCall.args[0]).to.deep.equal {
						_id: ObjectId(@project_id)
					}

			describe "without project id", ->
				beforeEach ->
					@ProjectGetter.getProjectWithoutLock null, @callback

				it "should callback with error", ->
					expect(@db.projects.find.callCount).to.equal 0
					expect(@callback.lastCall.args[0]).to.be.instanceOf Error

		describe "with projection", ->
			beforeEach ->
				@projection = {_id: 1}

			describe "with project id", ->
				beforeEach ->
					@ProjectGetter.getProjectWithoutLock @project_id, @projection, @callback

				it "should call find with the project id", ->
					expect(@db.projects.find.callCount).to.equal 1
					expect(@db.projects.find.lastCall.args[0]).to.deep.equal {
						_id: ObjectId(@project_id)
					}
					expect(@db.projects.find.lastCall.args[1]).to.deep.equal @projection

			describe "without project id", ->
				beforeEach ->
					@ProjectGetter.getProjectWithoutLock null, @callback

				it "should callback with error", ->
					expect(@db.projects.find.callCount).to.equal 0
					expect(@callback.lastCall.args[0]).to.be.instanceOf Error

	describe "findAllUsersProjects", ->
		beforeEach ->
			@fields = {"mock": "fields"}
			@Project.find = sinon.stub()
			@Project.find.withArgs({owner_ref: @user_id}, @fields).yields(null, ["mock-owned-projects"])
			@CollaboratorsHandler.getProjectsUserIsMemberOf = sinon.stub()
			@CollaboratorsHandler.getProjectsUserIsMemberOf.withArgs(@user_id, @fields).yields(
				null,
				{
					readAndWrite: ["mock-rw-projects"],
					readOnly: ["mock-ro-projects"],
					tokenReadAndWrite: ['mock-token-rw-projects'],
					tokenReadOnly: ['mock-token-ro-projects']
				}
			)
			@ProjectGetter.findAllUsersProjects @user_id, @fields, @callback

		it "should call the callback with all the projects", ->
			@callback
				.calledWith(null, {
					owned: ["mock-owned-projects"],
					readAndWrite: ["mock-rw-projects"],
					readOnly: ["mock-ro-projects"]
					tokenReadAndWrite: ['mock-token-rw-projects'],
					tokenReadOnly: ['mock-token-ro-projects']
				})
				.should.equal true

	describe "getProjectIdByReadAndWriteToken", ->
		describe "when project find returns project", ->
			@beforeEach ->
				@Project.findOne = sinon.stub().yields(null, {_id: "project-id"})
				@ProjectGetter.getProjectIdByReadAndWriteToken "token", @callback

			it "should find project with token", ->
				@Project.findOne.calledWithMatch(
					{'tokens.readAndWrite': "token"}
				).should.equal true

			it "should callback with project id", ->
				@callback.calledWith(null, "project-id").should.equal true

		describe "when project not found", ->
			@beforeEach ->
				@Project.findOne = sinon.stub().yields()
				@ProjectGetter.getProjectIdByReadAndWriteToken "token", @callback

			it "should callback empty", ->
				expect(@callback.firstCall.args.length).to.equal 0

		describe "when project find returns error", ->
			@beforeEach ->
				@Project.findOne = sinon.stub().yields("error")
				@ProjectGetter.getProjectIdByReadAndWriteToken "token", @callback

			it "should callback with error", ->
				@callback.calledWith("error").should.equal true
