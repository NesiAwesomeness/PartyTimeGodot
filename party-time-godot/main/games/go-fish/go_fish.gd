extends GameScene
class_name GoFish

signal quick_time_concluded

@export var hand_scene : PackedScene
@export var player_nodes : Node
@export var my_hand_node : CardHand

@export_category("Ask")
@export var ask_panel : Control
@export var request_label : Label

@export_category("Actions")
@export var action_labels : VBoxContainer
@export var action_label_scene : PackedScene
@export var status_label : Label

static var selected_player_name = ""
static var selected_rank = ""
static var selected_power_up = ""

const REQUEST_TIME = 2.5

enum Tier {
	STANDARD = 4,
	RARE = 3,
	LEGENDARY = 2,
}

const suites = ['R', 'G', 'B', 'Y']

const CARDS = {
	"boots": { "name": "Old Boots", "tier": Tier.STANDARD, "points": 1},
	"coins": { "name": "Rusty Coins", "tier": Tier.STANDARD, "points": 1},
	"soggy_socks": { "name": "Soggy Socks", "tier": Tier.STANDARD, "points": 1 },
	"tin_cans": { 'name': "Tin Cans", 'tier': Tier.STANDARD, 'points': 1 },
	"fishbones": { 'name': "Fish Bones", 'tier': Tier.STANDARD, 'points': 1 },
	"salmon": { 'name': "Salmon", 'tier': Tier.STANDARD, 'points': 1 },
	"rubber_duck": { 'name': "Rubber Duck", 'tier': Tier.STANDARD, 'points': 1 },
	"broken_shades": { 'name': "Broken Shades", 'tier': Tier.STANDARD, 'points': 1 },
	"silver_tooth": { 'name': "Silver Tooth", 'tier': Tier.STANDARD, 'points': 1 },
	"missing_card": { 'name': "Missing Card", 'tier': Tier.RARE, 'points': 3 },
	"fuzzy_dice": { 'name': "Fuzzy Dice", 'tier': Tier.RARE, 'points': 3 },
	"soggy_shoes": { 'name': "Soggy Shoes", 'tier': Tier.RARE, 'points': 3 },
	"tuna": { 'name': "Tuna", 'tier': Tier.RARE, 'points': 3 },
	"diamond_rings": {"name": "Diamond Rings", "tier": Tier.LEGENDARY, "points": 5},
	"cell_phone": { "name": "Cell Phone", "tier": Tier.LEGENDARY, 'points': 5 },
}

const POWERS = {
	#can use on others, but only when it's 
	#not your turn and not their turn.
	"magnifying_glass": "Magnifying Glass", #one card someone has that matches yours.
	"fast_hands": "Fast Hands" #swap junk cards with someone.
}

const PASSIVES = {
	"silver_tongue" : "Silver Tongue", 
}

var turn = 1
var is_my_turn : bool = false
var deck : Array = []

#this contains a list of cards that I have booked.
static var booked_cards = []

enum MOVES {
	DEAL=0, ASK=1, TAKE=2, PASSIVE=3, DROP=4, DRAW=5, TURN=6, USE=7, END=8
}

func initialize_game() -> Dictionary:
	var my_name = get_player_name(GameManager.my_uid)
	
	return {
		'name' : "Go Fish",
		'key' : 'GoFish',
		'turn' : 1,
		
		'seed' : randi(),
		'moves' : {
			"balls" : { "player" : my_name, "type" : MOVES.DEAL, "hand_size" : 5}
		}
	}

@onready var rng = RandomNumberGenerator.new()

var move_index := 0
var move_count := 0

func start_game(game_data : Dictionary):
	add_to_group("HandListener")
	add_to_group("CardListener")
	
	ask_panel.hide()
	
	for member in GameManager.chat_data.members: if member != GameManager.my_uid:
		#add opponent visuals.
		var hand_node : CardHand = hand_scene.instantiate()
		hand_node.name = member
		hand_node.hand_name = GameManager.chat_data.members[member]
		player_nodes.add_child(hand_node)
	
	rng.seed = game_data.get("seed")
	turn = game_data.get("turn")
	is_my_turn = turn == GameManager.chat_data.playerIndex
	
	var moves : Dictionary = game_data.get("moves") if game_data.has("moves") else {}
	move_count = moves.size()
	
	update_turn()

func on_new_move( move : Dictionary ):
	move_index += 1
	
	print( move, " last move")
	apply_move( move )
	
	#update the visuals.
	for player in players:
		var hand : Array = players[player]["hand"]
		var score : int = players[player]["score"]
		
		var hand_node : CardHand = player_nodes.get_node_or_null(player)
		if not hand_node:
			hand_node = my_hand_node
		
		hand_node.update_score( score )
		hand_node.update_hand( hand )

var request_timestamp := 0.0
var target_player_id := ''

var elapsed_time := 0.0
var quick_time_on_going : bool

func apply_move( move, _set_up:bool=false ):
	match int(move.type):
		MOVES.DEAL:
			#arrange the cards.
			for card_id in CARDS.keys():
				var card_data = CARDS[card_id]
				var copies_to_add = card_data["tier"]
				for i in range(copies_to_add):
					deck.append({
						"rank" : card_id,
						"suite" : suites[i]
					})
			
			#then shuffle
			shuffle_deck()
			
			#deal the cards.
			for member in GameManager.chat_data.members:
				players[member] = {}
				
				var hand = []
				for card in move.hand_size:
					hand.append( deck.pop_back() )
				
				players[member]["hand"] = hand
				players[member]["score"] = 0
				players[member]["passive"] = ""
			
			print(move.player, " started this game")
		MOVES.ASK:
			#tell everyone who is being asked.
			request_timestamp = move.timestamp
			target_player_id = move.target
			
			#we are being asked.
			if move.target == GameManager.my_uid:
				my_hand_node.shake_card( move.rank )
			
			if not _set_up:
				action_message(
					str(get_player_name(move.player), " is asking ", get_player_name(move.target), " for some ", move.rank)
				)
		MOVES.TAKE:
			var ranks : Array = players[move.target]["hand"].filter( func(card): return card.rank == move.rank )
			players[move.player]["hand"].append_array(ranks)
			
			players[move.target]["hand"] = players[move.target]["hand"].filter( 
				func(card): return card.rank != move.rank )
			
			if not _set_up:
				action_message(
					str(get_player_name(move.player), " took ", move.rank, " from ", get_player_name(move.target))
				)
		MOVES.PASSIVE:
			players[move.player]["passive"] = move.passive
		MOVES.DROP:
			#remove all the cards.
			var new_player_hand = players[move.player]["hand"].filter(func(card): return card.rank != move.rank)
			var cards = players[move.player]["hand"].filter(func(card): return card.rank == move.rank)
			
			deck.append_array(cards)
			shuffle_deck()
			players[move.player]["hand"] = new_player_hand
		MOVES.DRAW:
			draw_from_deck(move.player)
		MOVES.TURN:
			turn = move.turn
			is_my_turn = turn == GameManager.chat_data.playerIndex
			update_turn()
		MOVES.USE:
			#remove all the cards.
			var new_player_hand = players[move.player]["hand"].filter(func(card): return card.rank != move.rank)
			var cards = players[move.player]["hand"].filter(func(card): return card.rank == move.rank)
			
			print(cards, " before removal")
			
			if not cards.is_empty():
				cards.remove_at(0)
				new_player_hand.append_array(cards)
			
			print(cards, " after removal")
			
			players[move.player]["hand"] = new_player_hand
		MOVES.END:
			turn = -1
			is_my_turn = false
	
	for id in players:
		var player : Dictionary = players[id]
		var me = id == GameManager.my_uid
		
		#normal cards.
		var hand : Array = player['hand'].filter( 
			func(card): return CARDS.has(card.rank) 
		)
		
		#any empty hand should take from the deck.
		if hand.is_empty():
			draw_from_deck(id)
		else:
			var rank_counts : Dictionary = {}
			for card in hand:
				var rank = card.rank
				if rank_counts.has(rank): rank_counts[rank] += 1
				else: rank_counts[rank] = 1
			
			for rank in rank_counts.keys():
				if rank_counts[rank] >= CARDS[rank]["tier"]:
					#remove that card from the hand.
					player['hand'] = player['hand'].filter( 
						func(card): return rank != card.rank 
					)
					
					player["score"] += CARDS[rank]["points"]
					if me:
						booked_cards.append(rank)
						print("BOOK! ", CARDS[rank]["name"])
		
		players[id] = player

func draw_from_deck(target_id : String):
	action_message( str(get_player_name(target_id), " went fishing.") )
	players[target_id]['hand'].append( deck.pop_back() )

func update_turn():
	get_tree().call_group("TurnListener", "on_turn_changed", turn, is_my_turn)
	status_label.text = ( "Your Turn" if is_my_turn else 
	"Waiting for "+ GameManager.chat_data.members.values()[turn] )

func _process(_delta):
	#TODO use browsers system time from now on.
	elapsed_time = abs(request_timestamp - Time.get_unix_time_from_system())
	if quick_time_on_going != (elapsed_time < REQUEST_TIME):
		if quick_time_on_going: quick_time_concluded.emit()
		quick_time_on_going = elapsed_time < REQUEST_TIME
	
	var hand_node : CardHand = player_nodes.get_node_or_null(target_player_id)
	if not hand_node:
		hand_node = my_hand_node
	hand_node.quick_time.visible = quick_time_on_going
	hand_node.quick_time.value = (elapsed_time / REQUEST_TIME) * 100.0

func action_message(message : String, bruh:bool=false):
	if not bruh: if move_index < move_count - 4: return

	var action_label : Label = action_label_scene.instantiate()
	action_labels.add_child(action_label)
	action_label.text = message
	
	create_tween().tween_property(action_label, "modulate:a", 0.0, 1.0).set_delay(6.0)
	create_tween().tween_callback(action_label.queue_free).set_delay(6.0)

func shuffle_deck():
	for i in range(deck.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = deck[i]
		deck[i] = deck[j]
		deck[j] = temp

func get_player_name(id) -> String:
	return GameManager.chat_data.members[id]

func get_player_passive(player_id) -> String:
	return players[player_id]["passive"]

var last_card_source : String = "DRAW"

func on_ask(player_name, card_rank):
	selected_rank = ""
	selected_player_name = ""
	
	ask_panel.hide()
	
	if card_rank == "":
		print("No rank selected")
		return
	
	print("Hey ", player_name, ", Do you have any ", CARDS[card_rank].name, "?")
	
	var player_id : String = get_player_id(player_name)
	
	#TODO if the last move was us and was of type "ASK" and we
	#have exceded the time of asking then the just execute
	make_move({
		"player" : GameManager.my_uid, "type" : MOVES.ASK, "rank": card_rank,
		"timestamp" : Time.get_unix_time_from_system(), "target": player_id
	})
	
	#this has to happen outside of the game (i.e even if the game has been closed)
	on_await(false)
	
	await quick_time_concluded
	
	var player_hand : Array = players[player_id]["hand"]
	var rank_cards : Array = player_hand.filter( func(card): return card.rank == card_rank )
	
	var target_passive : String = get_player_passive(player_id)
	
	if rank_cards.is_empty():
		#I'll Go Fish
		make_move({ "player" : GameManager.my_uid, "type" : MOVES.DRAW })
		next_player()
	else:
		if target_passive == "silver_tongue":
			#They'll use their passive.
			make_move({ "player" : player_id, "type" : MOVES.USE, "rank": target_passive })
			#They'll drop.
			make_move({ "player" : player_id, "type" : MOVES.DROP, "rank": card_rank })
			#I'll draw.
			make_move({ "player" : GameManager.my_uid, "type" : MOVES.DRAW })
			#I'll pass the torch.
			next_player()
		else:
			#I'll take it.
			make_move({
				"player" : GameManager.my_uid, "target": player_id, "type" : MOVES.TAKE, "rank": card_rank 
			})
		
	on_await(true)

func next_player():
	var nt = wrapi( GameManager.chat_data.playerIndex + 1, 0, int(GameManager.chat_data.memberCount) )
	make_move({ "type" : MOVES.TURN, "turn" : nt if is_my_turn else turn })

func on_power(player_name, power):
	var player_id : String = get_player_id(player_name)
	
	if quick_time_on_going and player_id == game_state.lastRequestedPlayer:
		print("I can't use powers on ", player_name, " right now")
		return
	
	selected_player_name = ""
	selected_power_up = ""
	
	ask_panel.hide()
	
	var pool = PASSIVES.merged(POWERS)
	var player_hand : Array = game_state.hands[player_id]
	
	#game_state.hands[GameManager.my_uid].erase({ "rank" : power, "suite" : "R" })
	return
	#
	#
	##remove card from my hand...
	#var my_hand : Array = game_state.hands[GameManager.my_uid]
	#
	#match power:
		#"magnifying_glass":
			#cloud_save({ "hands" : { GameManager.my_uid : my_hand } })
			#
			#var union : Array = my_hand.map(func(card): return card.rank).filter(
				#func(rank): return (player_hand.filter(
##					filter the power cards from this person.
					#func(card): return not pool.has(card.rank)
##					make an array of ranks.
					#).map(func(card): return card.rank)).has(rank)
			#)
			#
			##I only need to display one out of this union.
			#var display_rank : String
			#if not union.is_empty():
				#display_rank = union.pick_random()
				#action_message(str("they have ", CARDS[display_rank].name, "!"))
			#else:
				#action_message("We have nothing in common")
			#
			#
		#"fast_hands":
			#var swap_rank : String = player_hand.filter(
				##filter the power cards from this person.
				#func(card): return not pool.has(card.rank)
				##make an array of ranks.
				#).map(func(card): return card.rank).pick_random()
			#
			#var our_swap : String = my_hand.filter(
				##filter the power cards from this person.
				#func(card): return not pool.has(card.rank)
				##make an array of ranks.
				#).map(func(card): return card.rank).pick_random()
			#
			##collect cards
			#var player_cards : Array = player_hand.filter(func(card): return card.rank == swap_rank)
			#var my_cards : Array = my_hand.filter(func(card): return card.rank == our_swap)
			#
			##remove cards
			#player_hand = player_hand.filter(func(card): return card.rank != swap_rank)
			#my_hand = my_hand.filter(func(card): return card.rank != our_swap)
			#
			##add cards
			#player_hand.append_array(my_cards)
			#my_hand.append_array(player_cards)
			#
			#last_card_source = player_name
			#
			#print("I just took ", CARDS[swap_rank].name, " from ", player_name)
			#print("and gave them ", CARDS[our_swap].name)
			#
			#cloud_save({ "hands" : { player_id : player_hand , GameManager.my_uid : my_hand } })
	#
	#print("I just used ", pool[power], " on ", player_name)

var ask_mode : bool = true

func set_power_use_text():
	ask_mode = false
	var pool : Dictionary = POWERS.merged(PASSIVES)
	
	if selected_power_up and selected_player_name:
		request_label.text = str("Using ", pool[selected_power_up], " on ", selected_player_name)

func set_up_ask_text():
	ask_mode = true
	if selected_rank and selected_player_name:
		request_label.text = str("Hey, ", selected_player_name, " you got any ", CARDS[selected_rank].name)

func get_player_id(player_name):
	return GameManager.chat_data.members.find_key(player_name)

func on_player_selected(player_name):
	selected_power_up = ""
	selected_rank = ""
	selected_player_name = player_name
	
	request_label.text = str("Hey, ", player_name)
	
	var player_id = get_player_id(player_name)
	if target_player_id == player_id and quick_time_on_going: print("can't select them yet...")
	
	print( str("Hey, ", player_name) )
	
	ask_panel.show()

func on_power_selected(power):
	#shouldn't be able to use power when it's your turn.
	if PASSIVES.has(power):
		print("can't use that yet.")
		#if players[GameManager.my_uid]["passive"] == power: power = ""
		#make_move({  })
		return
	
	if is_my_turn:
		#can't use power when it's your turn.
		print("still your turn")
		return
	
	selected_power_up = power
	
	request_label.text = str("Using ", power, " on...")
	set_power_use_text()

func on_card_selected(rank):
	selected_rank = rank
	set_up_ask_text()

func on_send_ask_pressed():
	if not is_my_turn:
		if not ask_mode:
			on_power(selected_player_name, selected_power_up)
			print("I'm using powers on ", selected_player_name)
			return
		print("not your turn")
		return
	
	ask_panel.hide()
	request_label.text = ""
	
	#check if my hand still has the card.
	var cannot_ask_that = players[GameManager.my_uid]["hand"].filter(
		func(card): return card.rank == selected_rank
	).is_empty()
	
	if cannot_ask_that:
		print("hmmmm")
		return
	
	if ask_mode: on_ask(selected_player_name, selected_rank)

func end_game():
	pass
