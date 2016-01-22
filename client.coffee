Comments = require 'comments'
Db = require 'db'
Dom = require 'dom'
Modal = require 'modal'
Obs = require 'obs'
App = require 'app'
Page = require 'page'
Server = require 'server'
Ui = require 'ui'
Form = require 'form'
Time = require 'time'
Chess = require 'chess'
{tr} = require 'i18n'

exports.renderSettings = if Db.shared then false else !->
	userCnt = App.users.count().get()
	selUserId = null
	if userCnt is 2
		for userId, v of App.users.get()
			if +userId isnt App.userId()
				selUserId = userId
				break

	selectMember
		name: 'opponent'
		value: selUserId
		title: tr("Opponent")

	Form.condition (val) ->
		tr("Please select an opponent") if !val.opponent


exports.render = !->
	whiteId = Db.shared.get('white')
	blackId = Db.shared.get('black')
	color = if App.userId() is whiteId
			'white'
		else if App.userId() is blackId
			'black'
	Obs.observe !->
		Page.setTitle tr("Chess - %1 to move", Db.shared.get('turn'));

	if challenge=Db.shared.get('challenge')
		Dom.div !->
			Dom.style
				textAlign: 'center'
				fontSize: '120%'

			Dom.text tr("%1 (white) vs %2 (black), no time limit",
				App.userName(whiteId), App.userName(blackId))

			if challenge[App.userId()]
				Dom.div tr("%1 challenged you for a game of Chess.", App.userName(App.ownerId()))

				Ui.bigButton tr("Accept"), !->
					Server.call 'accept'

			else
				break for id of challenge
				Dom.div tr("Waiting for %1 to accept...", App.userName(id))

	else

		isBlack = Db.shared.get('black') is App.userId() and Db.shared.get('white') isnt App.userId()

		renderSide = (side) !->
			Dom.div !->
				Dom.style
					textAlign: 'center'
					fontSize: '130%'
					padding: '8px 0'
					color: 'inherit'
					fontWeight: 'normal'
				id = Db.shared.get(side)
				Dom.div !->
					Dom.style
						Box: 'inline middle'
						padding: '6px'
					Ui.avatar App.userAvatar(id)
					if id is App.userId()
						Dom.text tr("You")
					else
						Dom.text App.userName(id)
						Dom.onTap !->
							App.showMemberInfo(id)

					if result = Db.shared.get('result')
						Dom.style fontWeight: 'bold'
						if result is side
							Dom.text " - wins!"
						else if result is 'draw'
							Dom.text " - draw"
						else if result
							Dom.text " - lost"

					else if Db.shared.get('turn') is side
						if id is App.userId()
							Dom.style color: App.colors().highlight, fontWeight: 'bold'
						Dom.text " - to move"

		renderSide if isBlack then 'white' else 'black'

		Dom.div !->
			Dom.style
				Box: 'center'
				margin: '4px 0'

			selected = Obs.create false
			markers = Obs.create {}
				# chess field index indicating last-moved-piece, king-under-attack, selected, possible-move

			Obs.observe !->
				if last=Db.shared.get('last')
					markers.set last[0], 'last'
					markers.set last[1], 'last'

				if check = Chess.isCheck(Db.shared.get('board'), Db.shared.get('turn')?[0])
					markers.set check, 'check'

				if s = selected.get()
					markers.set s, 'selected'
					for square of Chess.find(s)
						markers.set square, 'move'

				Obs.onClean !->
					markers.set {}

			Dom.div !->
				size = 0|Math.max(200, Math.min(Page.width()-16, 480)) / 8
				Dom.cls 'board'
				Dom.style
					width: "#{size*8}px"

				(if isBlack then '12345678' else '87654321').split('').forEach (y,yi) !->
					Dom.div !->
						(if isBlack then 'hgfedcba' else 'abcdefgh').split('').forEach (x,xi) !->
							Dom.div !->
								Dom.cls 'square'
								Dom.cls if (xi%2)==(yi%2) then 'white' else 'black'

								piece = Db.shared.get('board', x+y)

								if marker = markers.get(x+y)
									Dom.div !->
										blue = marker in ['last', 'check']
										Dom.style
											position: 'absolute'
											width: if piece then '90%' else '50%'
											height: if piece then '90%' else '50%'
											left: if piece then '5%' else '25%'
											top: if piece then '5%' else '25%'
											background: if marker in ['last', 'check']
													App.colors().bar
												else
													App.colors().highlight
											opacity: if marker is 'last' then .6 else 1
											borderRadius: '999px'

								if piece
									Dom.div !->
										Dom.style
											position: 'absolute'
											left: 0
											top: 0
											width: '100%'
											height: '100%'
											background: "url(#{App.resourceUri piece+'.png'}) no-repeat 50% 50%"
											backgroundSize: "#{0|size*.75}px"

								Dom.onTap !->
									turn = Db.shared.get('turn')
									if turn is color
										s = selected.get()
										if !s and piece and piece[0] is turn[0]
											selected.set x+y
											return

										if s and s isnt x+y and Db.shared.peek('board', x+y)?[0] isnt turn[0]
											log 'move', s, '>', x+y
											type = Chess.canMove(s, x+y)
											if type is 'promotion'
												t = turn[0]
												choosePiece [t+'q',t+'r',t+'b',t+'n'], (piece) ->
													Server.call 'move', s, x+y, piece[1] if piece
											else if type
												Server.call 'move', s, x+y
											else if markers.get(x+y) is 'move'
												# we had a move marker here, but cant move here because we are checked or will be in check
												require('toast').show tr("Invalid move - you are checked!")

									selected.set false

		renderSide if isBlack then 'black' else 'white'

	Comments.enable
		legacyStore: "default"
		messages:
			move: (c) ->
				Dom.text tr("%1 moved %2", App.userName(c.u), c.custom.move) + " "
				Dom.div !->
					Dom.style
						height: '15px'
						width: '15px'
						background: "url(#{App.resourceUri c.custom.piece+'.png'}) no-repeat 50% 50%"
						backgroundSize: "15px"
						display: 'inline-block'
						margin: '-1px 0 -2px'
				return ""

choosePiece = (pieces, cb) !->
	require('modal').show tr("Choose piece"), !->
		pieces.forEach (piece) !->
			Dom.div !->
				Dom.style
					display: 'inline-block'
					height: '40px'
					width: '40px'
					margin: '4px'
					background: "url(#{App.resourceUri piece+'.png'}) no-repeat 50% 50%"
					backgroundSize: '32px'

				Dom.onTap !->
					require('modal').remove()
					cb(piece)
	, !->
		cb()
	, ['cancel', tr("Cancel")]


# input that handles selection of a member
selectMember = (opts) !->
	usersAvailable = Obs.create false
	Obs.observe !->
		usersAvailable.set App.users.count().get() > 1
	opts ||= {}
	[handleChange, initValue] = Form.makeInput opts, (v) -> 0|v

	value = Obs.create(initValue)
	Obs.observe !->
		if !App.users.get(value.get())
			value.set false
		handleChange value.get()

	Form.box !->
		Dom.style fontSize: '125%', paddingRight: '56px'
		Dom.text opts.title||tr("Selected member")
		v = value.get()
		Dom.div !->
			Dom.style color: (if v then 'inherit' else '#aaa')
			Dom.text (if v then App.userName(v) else tr("Nobody"))
		if v
			Ui.avatar App.userAvatar(v), style: position: 'absolute', right: '-30px', top: '50%', marginTop: '-16px'

		Dom.onTap !->
			if !usersAvailable.get()
				Modal.show "First select some people to add to the app"
			else
				Modal.show opts.selectTitle||tr("Select opponent"), !->
					App.users.iterate (user) !->
						Ui.item !->
							Ui.avatar user.get('avatar')
							Dom.text user.get('name')

							if +user.key() is +value.get()
								Dom.style fontWeight: 'bold'

								Dom.div !->
									Dom.style
										Flex: 1
										padding: '0 10px'
										textAlign: 'right'
										fontSize: '150%'
										color: App.colors().highlight
									Dom.text "✓"

							Dom.onTap !->
								value.set user.key()
								Modal.remove()
					, (user) ->
						+user.key() if +user.key() isnt App.userId()
				, (choice) !->
					log 'choice', choice
					if choice is 'clear'
						handleChange ''
						value.set ''
				, ['cancel', tr("Cancel"), 'clear', tr("Clear")]
	# Autoselect first user
	App.users.iterate (user) !->
		if +user.key() isnt 1 and (!value.peek() or value.peek() is 0)
			value.set user.key()

Dom.css
	'.board':
		boxShadow: '0 0 8px #000'
	'.square':
		display: 'inline-block'
		width: '12.5%'
		padding: '12.5% 0 0' # use padding-top trick to maintain aspect ratio
		position: 'relative'
	'.square.white':
		backgroundColor: 'rgb(244,234,193)'
	'.square.black':
		backgroundColor: 'rgb(223,180,135)'

