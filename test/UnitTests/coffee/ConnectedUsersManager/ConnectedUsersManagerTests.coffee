
should = require('chai').should()
SandboxedModule = require('sandboxed-module')
assert = require('assert')
path = require('path')
sinon = require('sinon')
modulePath = path.join __dirname, "../../../../app/js/Features/ConnectedUsers/ConnectedUsersManager"
expect = require("chai").expect
tk = require("timekeeper")


describe "ConnectedUsersManager", ->

	beforeEach ->

		@settings =
			redis:
				web:{}
		@rClient =
			auth:->
			setex:sinon.stub()
			sadd:sinon.stub()
			get: sinon.stub()
		tk.freeze(new Date())

		@ConnectedUsersManager = SandboxedModule.require modulePath, requires:
			"settings-sharelatex":@settings
			"logger-sharelatex": log:->
			"redis": createClient:=> 
				return @rClient
		@user_id = "32132132"
		@project_id = "dskjh2u21321"

	afterEach -> 
		tk.reset()

	describe "markUserAsConnected", ->
		beforeEach ->
			@rClient.setex.callsArgWith(3)
			@rClient.sadd.callsArgWith(2)


		it "should set a key with the date and give it a ttl", (done)->
			@ConnectedUsersManager.markUserAsConnected @project_id, @user_id, (err)=>
				@rClient.setex.calledWith("connected_user:#{@project_id}:#{@user_id}", new Date(), 60 * 60 * 6).should.equal true
				done()

		it "should push the user_id on to the project list", (done)->
			@ConnectedUsersManager.markUserAsConnected @project_id, @user_id, (err)=>
				@rClient.sadd.calledWith("connected_user:#{@project_id}", @user_id).should.equal true
				done()


	describe "_getConnectedUser", ->

		it "should get the user returning connected if there is a value", (done)->
			@rClient.get.callsArgWith(1, null, new Date())
			@ConnectedUsersManager._getConnectedUser @project_id, @user_id, (err, result)=>
				result.connected.should.equal true
				result.user_id.should.equal @user_id
				done()

		it "should get the user returning connected if there is a value", (done)->
			@rClient.get.callsArgWith(1)
			@ConnectedUsersManager._getConnectedUser @project_id, @user_id, (err, result)=>
				result.connected.should.equal false
				result.user_id.should.equal @user_id
				done()



	describe "getConnectedUsers", ->

		beforeEach ->
			@users = ["1234", "5678", "9123"]
			@rClient.get.callsArgWith(1, null, @users)
			@ConnectedUsersManager._getConnectedUser = sinon.stub()
			@ConnectedUsersManager._getConnectedUser.withArgs(@project_id, @users[0]).callsArgWith(2, null, {connected:true, user_id:@users[0]})
			@ConnectedUsersManager._getConnectedUser.withArgs(@project_id, @users[1]).callsArgWith(2, null, {connected:false, user_id:@users[1]})
			@ConnectedUsersManager._getConnectedUser.withArgs(@project_id, @users[2]).callsArgWith(2, null, {connected:true, user_id:@users[2]})


		it "should only return the users in the list which are still in redis", (done)->
			@ConnectedUsersManager.getConnectedUsers @project_id, (err, users)=>
				users.length.should.equal 2
				users[0].should.equal @users[0]
				users[1].should.equal @users[2]
				done()





