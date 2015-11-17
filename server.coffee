Db = require 'db'
Plugin = require 'plugin'
Event = require 'event'
Chess = require 'chess'

exports.onInstall = (config) !->
	if config and config.opponent
		config = if Math.random()>.5
				{white: Plugin.userId(), black: config.opponent}
			else
				{black: Plugin.userId(), white: config.opponent}
	if config and config.white and config.black
		challenge = {}
		challenge[+config.white] = true
		challenge[+config.black] = true
		Db.shared.set
			white: +config.white
			black: +config.black
			challenge: challenge

		accept(Plugin.userId())
			# todo: this currently shows some error due to a framework Db issue

exports.getInitialEvent = ->
	opponentId = if Db.shared.get('white') is Plugin.userId()
			Db.shared.get('black')
		else
			Db.shared.get('white')
	for: [Db.shared.get('white'), Db.shared.get('black')]
	text: "Chess: #{Plugin.userName()} challenges you"
	sender: Plugin.userId()
	senderText: "Chess: you challenged #{Plugin.userName(opponentId)}"

exports.onUpgrade = !->
	if !Db.shared.get('board') and game=Db.shared.get('game')
		# version 2.0 clients had their data in /game
		log 'upgrading'
		Db.shared.merge game
		# we'll let the old data linger

exports.onConfig = !->
	# currently, no config can be changed

exports.getTitle = ->
	Plugin.userName(Db.shared.get('white')) + ' vs ' + Plugin.userName(Db.shared.get('black'))

exports.client_accept = !->
	accept(Plugin.userId())

accept = (userId) !->
	log 'accept', userId
	Db.shared.remove 'challenge', userId
	if !Object.keys(Db.shared.get('challenge')).length # objEmpty(...)
		log 'game begin'
		Db.shared.remove 'challenge'
		Event.create
			for: [Db.shared.get('white'), Db.shared.get('black')]
			text: "Chess game has begun!"
		Chess.init()

exports.client_move = (from, to, promotionPiece) !->
	game = Db.shared.ref('game')
	if Db.shared.get(Db.shared.get('turn')) is Plugin.userId()
		m = Chess.move from, to, promotionPiece

		Event.create
			for: [Db.shared.get('white'), Db.shared.get('black')]
			text: "Chess: #{Plugin.userName()} moved #{m}"
			sender: Plugin.userId()
			senderText: "Chess: you moved #{m}"

