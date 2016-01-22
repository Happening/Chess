Comments = require 'comments'
Db = require 'db'
App = require 'app'
Event = require 'event'
Chess = require 'chess'
{tr} = require 'i18n'

exports.onInstall = (config) !->
	if config and (black = +config.opponent)
		white = App.userId()
		if Math.random()>.5
			[black,white] = [white,black]
		challenge = {}
		challenge[white] = true
		challenge[black] = true
		Db.shared.set
			white: white
			black: black
			challenge: challenge
		App.setTitle App.userName(white) + ' vs ' + App.userName(black)

		accept(App.userId())
			# todo: this currently shows some error due to a framework Db issue


exports.getInitialEvent = ->
	opponentId = if Db.shared.get('white') is App.userId()
			Db.shared.get('black')
		else
			Db.shared.get('white')
	for: [Db.shared.get('white'), Db.shared.get('black')]
	text: "Chess: #{App.userName()} challenges you"
	sender: App.userId()
	senderText: "Chess: you challenged #{App.userName(opponentId)}"

exports.onUpgrade = !->
	if !Db.shared.get('board') and game=Db.shared.get('game')
		# version 2.0 clients had their data in /game
		log 'upgrading'
		Db.shared.merge game
		# we'll let the old data linger

exports.onConfig = !->
	# currently, no config can be changed

exports.client_accept = !->
	accept(App.userId())

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
	if Db.shared.get(Db.shared.get('turn')) is App.userId()
		m = Chess.move from, to, promotionPiece

		Event.create
			for: [Db.shared.get('white'), Db.shared.get('black')]
			text: "Chess: #{App.userName()} moved #{m}"
			sender: App.userId()
			senderText: "Chess: you moved #{m}"

	#write to comments
	piece = Db.shared.get 'board', from
	Comments.post
		legacyStore: "default"
		s: 'move'
		u: App.userId() if Db.shared.get(Db.shared.get('turn')) is App.userId()
		custom: {piece: piece, move: m}