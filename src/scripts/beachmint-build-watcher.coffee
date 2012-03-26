# notify all chat rooms of changes to the build statuses
Backbone  = require 'backbone'
request   = require 'request'
buildUrl  = ''
detailUrl = ''

class BuildModel extends Backbone.Model
	statusChanged: () =>
		@previous 'previous_result' is not @get 'previous_result'

class BuildMonitor extends Backbone.Collection
	model: BuildModel
	initialize: () ->
		@poll()

	# poll the server for new data
	poll: () =>
		request.get {url: buildUrl}, (error, response, body) =>
			# recurse through the returned build data
			# persisting each build to a model in the builds collection
			json = JSON.parse body
			for build in json.data
				data = build.building_info

				# get the corresponding model if one exists and update
				model = @where({ project_name: data.project_name })[0]
				if model then model.set(data) else @add(data)

			# set poll interval
			setTimeout @poll, 30000

# broadcast message to multiple rooms
class Broadcaster
	constructor: (robot, msg, rooms) ->
		exempts =
			[ '491280' #analytics
			, '490315' #product
			]
		rooms = rooms ? process.env.HUBOT_CAMPFIRE_ROOMS.split(',')
		robot.send({ room: room }, msg) for room in rooms when room not in exempts

# external api
module.exports = (robot) ->
	# kick off the build monitor
	builds = new BuildMonitor

	# watch for changes to status or result
	builds.on 'change:previous_result', (model, result) ->
		status = model.get 'current_status'
		name = model.get 'project_name'

		# trigger message if build is not running
		if status is 'Waiting'
			new Broadcaster robot, "Build #{result}! (#{name}) #{detailUrl}/#{name}", ['491417','490314']
