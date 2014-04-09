sinon = require('sinon')
chai = require('chai')
should = chai.should()
expect = chai.expect
modulePath = "../../../../app/js/Features/User/UserController.js"
SandboxedModule = require('sandboxed-module')
events = require "events"
MockResponse = require "../helpers/MockResponse"
MockRequest = require "../helpers/MockRequest"
ObjectId = require("mongojs").ObjectId

describe "UserController", ->
	beforeEach ->
		@UserController = SandboxedModule.require modulePath, requires:
			"./UserDeleter": @UserDeleter
			"logger-sharelatex": {log:->}


		@req = new MockRequest()
		@res = new MockResponse()
		@next = sinon.stub()

	describe "deleteUser", ->

		it "should delete the user", (done)->
			user_id = "323123"
			@req.session.user =
				_id = user_id
			@res.send = (code)=>
				@UserDeleter.deleteUser.calledWith(user_id)
				code.should.equal 200
				done()
			@UserController.deleteUser @req, @res


