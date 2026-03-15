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

func initialize_game() -> Dictionary:
	var deck : Array = []
	for card_id in CARDS.keys():
		var card_data = CARDS[card_id]
		var copies_to_add = card_data["tier"]
		for i in range(copies_to_add):
			deck.append({
				"rank" : card_id,
				"suite" : suites[i]
			})
		deck.shuffle()
	
	var hand_size = 5
	var hands = {}
	var scores = {}
	#this is a list of power_ups a user is actively using.
	var passives = {}
	
	for member in GameManager.chat_data.members:
		var hand = []
		for card in hand_size:
			hand.append( deck.pop_back() )
		
		hands[member] = hand
		scores[member] = 0
		passives[member] = ""
	 
	print("Deck generated with %d cards." % deck.size())
	
	return {
		'name' : "Go Fish",
		'key' : 'GoFish',
		'gameState' : {
			'playerTurn' : 1,
			'deck' : deck,
			'hands' : hands,
			'scores' : scores,
			'passives' : passives,
			
			"action" : "cards dealt",
			
			#this means no one can do anything for 
			#3 seconds after this timestamp...
			'lastRequest': 0.0,
			#the player that can play...
			'lastRequestedPlayer': "",
			'requestedCard' : "balls"
		}
	}

var is_my_turn : bool = false
var is_set_up : bool = false

func on_set_up():
	is_set_up = true
	
	add_to_group("HandListener")
	add_to_group("CardListener")
	
	ask_panel.hide()
	
	for uid in game_state.hands:
		var hand : Array = game_state.hands[uid]
		var score : int = game_state.scores[uid]
		
		var hand_node : CardHand = my_hand_node
		var is_me = uid == GameManager.my_uid
		
		if not is_me:
			hand_node = hand_scene.instantiate()
			hand_node.name = uid
			hand_node.hand_name = GameManager.chat_data.members[uid]
			
			player_nodes.add_child(hand_node)
			continue
		
		hand_node.update_score( score )
		hand_node.update_hand( hand, true )
	
	on_game_state_update( game_state )

func on_game_state_update( new_game_state ):
	if not is_set_up: return
	
	get_tree().call_group("PassiveCard", "on_passive_update", new_game_state.passives[GameManager.my_uid])
	
	if not game_state.has("deck"):
		end_game()
		return
	
	#UPDATE TURN.
	is_my_turn = new_game_state.playerTurn == GameManager.chat_data.playerIndex
	get_tree().call_group("TurnListener", "on_turn_changed", new_game_state.playerTurn, is_my_turn)
	
	status_label.text = ( "Your Turn" if is_my_turn else 
	"Waiting for "+ GameManager.chat_data.members.values()[new_game_state.playerTurn] )
	
	#UPDATE HANDS.
	for uid in new_game_state.hands:
		var hand = new_game_state.hands[uid]
		var score : int = new_game_state.scores[uid]
		var hand_node : CardHand = player_nodes.get_node_or_null(uid)
		
		if not hand_node:
			hand_node = my_hand_node
			if hand.filter( func(card): return CARDS.has(card.rank) ).is_empty():
				draw_card()
				continue
		
		hand_node.update_score( score )
		hand_node.update_hand( hand )
	
	#DISPLAY MESSAGE.
	if new_game_state.action != game_state.action:
		var action_label : Label = action_label_scene.instantiate()
		action_labels.add_child(action_label)
		action_label.text = new_game_state.action
	
		create_tween().tween_property(action_label, "modulate:a", 0.0, 1.0).set_delay(6.0)
		create_tween().tween_callback(action_label.queue_free).set_delay(6.0)
	
	if new_game_state.lastRequestedPlayer == GameManager.my_uid:
		var card_node : Card = my_hand_node.hand_container.get_node_or_null( new_game_state.requestedCard )
		
		#move the card down if we have it.
		if card_node: 
			var jiggle_tween : Tween = card_node.card_body.create_tween().set_loops()
			
			var shake_dist: float = 4.0
			var speed: float = 0.1
			
			jiggle_tween.tween_property(card_node.card_body, "position:x", 
			shake_dist, speed).as_relative().set_trans(Tween.TRANS_SINE)
			
			jiggle_tween.tween_property(card_node.card_body, "position:x", 
			-(shake_dist * 2.0), speed * 2.0).as_relative().set_trans(Tween.TRANS_SINE)
			
			jiggle_tween.tween_property(card_node.card_body, "position:x", 
			shake_dist, speed).as_relative().set_trans(Tween.TRANS_SINE)
			
			quick_time_concluded.connect( func(): if jiggle_tween: jiggle_tween.kill() )
	
	#replace other things.
	game_state = new_game_state

var elapsed_time := 0.0
var quick_time_on_going : bool

func _process(_delta):
	elapsed_time = abs(game_state.lastRequest - Time.get_unix_time_from_system())
	
	if quick_time_on_going != (elapsed_time < REQUEST_TIME):
		if quick_time_on_going:
			quick_time_concluded.emit()
		quick_time_on_going = elapsed_time < REQUEST_TIME
	
	var hand_node : CardHand = player_nodes.get_node_or_null(game_state.lastRequestedPlayer)
	if not hand_node:
		hand_node = my_hand_node
	
	hand_node.quick_time.visible = quick_time_on_going
	hand_node.quick_time.value = (elapsed_time / REQUEST_TIME) * 100.0

func get_player_passives(player_id) -> String:
	return game_state.passives[player_id]

var last_card_source : String = "DRAW"

func on_ask(player_name, card_rank):
	selected_rank = ""
	selected_player_name = ""
	
	ask_panel.hide()
	
	if card_rank == "":
		print("No rank selected")
		return
	
	get_tree().call_group("HandListener", "on_player_deselect")
	print("Hey ", player_name, ", Do you have any ", CARDS[card_rank].name, "?")
	
	var player_id : String = get_player_id(player_name)
	
	cloud_save({ 
		"action" : str( GameManager.chat_data.members[GameManager.my_uid]," asked ",
			player_name," for ", CARDS[card_rank].name),
		
		"lastRequestedPlayer" : player_id, 
		"lastRequest" : Time.get_unix_time_from_system(),
		"requestedCard" : card_rank
	})
	
	#this has to happen outside of the game (i.e even if the game has been closed)
	on_await(false)
	
	await quick_time_concluded
	
	var player_hand : Array = game_state.hands[player_id]
	var rank_cards : Array = player_hand.filter( func(card): return card.rank == card_rank )
	
	var opp_passives : String = get_player_passives(player_id)
	
	if rank_cards.is_empty():
		#GO FISH
		draw_card()
	else:
		#remove the card from that player and passives.
		var new_player_hand = player_hand.filter(
			func(card): return card.rank != card_rank
			).filter(
			func(card): return card.rank != opp_passives)
		
		var passives = player_hand.filter(func(card): return card.rank == opp_passives)
		
		print(passives, " before removal")
		
		if not passives.is_empty():
			passives.remove_at(0)
			new_player_hand.append_array(passives)
		
		print(passives, " after removal")
		
		var my_hand = game_state.hands[GameManager.my_uid]
		
		if opp_passives == "silver_tongue":
			#GO FISH
			print("opponent used: ", opp_passives)
			
			#add cards back to deck
			if game_state.has("deck"):
				game_state.deck.append_array(rank_cards)
				#shuffle the deck...
				game_state.deck.shuffle()
			
			cloud_save({ 
				"passives" : { player_id : "" }, 
				"hands" : { player_id : new_player_hand }
			})
			
			#then I'll draw a card.
			draw_card()
		else:
			print("opponent didn't use any passive. ", rank_cards)
			
			my_hand.append_array(rank_cards)
			
			cloud_save({ 
				"hands" : { GameManager.my_uid : my_hand, player_id : new_player_hand },
			 })
			last_card_source = player_name
		
		
	on_await(true)

func draw_card():
	#draw cards and skip your turn.
	if game_state.has("deck"):
		print("I'm going to fish")
		if game_state.deck.is_empty():
			end_game()
			return
		
		var new_card = game_state.deck.pop_front()
		
		var my_hand = game_state.hands[GameManager.my_uid]
		print("I got ", new_card.rank, " from the draw")
		my_hand.append( new_card )
		
		if randi() % 2 == 0:
			var pool : Dictionary = POWERS.merged(PASSIVES)
			var power_card = { "rank" : pool.keys().pick_random(), "suite" : "R" }
			if not my_hand.has(power_card): my_hand.append( power_card )
			print("I also got: ", power_card.rank, " from draw")
		
		last_card_source = "DRAW"
		
		cloud_save({ 
			"deck" : game_state.deck,
			"hands" : { GameManager.my_uid : my_hand },
			"action" : GameManager.chat_data.members[GameManager.my_uid] +" went FISHING",
			"playerTurn" : wrapi(
				GameManager.chat_data.playerIndex + 1, 0, int(GameManager.chat_data.memberCount)
			) if is_my_turn else game_state.playerTurn
		})
		
		action_message("GO FISH")
	else:
		end_game()

func on_book(rank):
	print("BOOK! ", CARDS[rank].name)
	
	var my_hand = game_state.hands[GameManager.my_uid]
	my_hand = my_hand.filter(func(card): return card.rank != rank)
	
	var score = game_state.scores[GameManager.my_uid] + CARDS[rank].points
	
	cloud_save({
		"hands" : { GameManager.my_uid : my_hand },
		"action" : str( GameManager.chat_data.members[GameManager.my_uid], " completed ",CARDS[rank].name," from ",last_card_source ),
		"scores" : { GameManager.my_uid : score }
	})

func action_message(message : String):
	var action_label : Label = action_label_scene.instantiate()
	action_labels.add_child(action_label)
	action_label.text = message
	
	create_tween().tween_property(action_label, "modulate:a", 0.0, 1.0).set_delay(6.0)
	create_tween().tween_callback(action_label.queue_free).set_delay(6.0)


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
	
	#remove card from my hand...
	game_state.hands[GameManager.my_uid].erase({ "rank" : power, "suite" : "R" })
	var my_hand : Array = game_state.hands[GameManager.my_uid]
	
	match power:
		"magnifying_glass":
			cloud_save({ "hands" : { GameManager.my_uid : my_hand } })
			
			var union : Array = my_hand.map(func(card): return card.rank).filter(
				func(rank): return (player_hand.filter(
#					filter the power cards from this person.
					func(card): return not pool.has(card.rank)
#					make an array of ranks.
					).map(func(card): return card.rank)).has(rank)
			)
			
			#I only need to display one out of this union.
			var display_rank : String
			if not union.is_empty():
				display_rank = union.pick_random()
				action_message(str("they have ", CARDS[display_rank].name, "!"))
			else:
				action_message("We have nothing in common")
			
			
		"fast_hands":
			var swap_rank : String = player_hand.filter(
				#filter the power cards from this person.
				func(card): return not pool.has(card.rank)
				#make an array of ranks.
				).map(func(card): return card.rank).pick_random()
			
			var our_swap : String = my_hand.filter(
				#filter the power cards from this person.
				func(card): return not pool.has(card.rank)
				#make an array of ranks.
				).map(func(card): return card.rank).pick_random()
			
			#collect cards
			var player_cards : Array = player_hand.filter(func(card): return card.rank == swap_rank)
			var my_cards : Array = my_hand.filter(func(card): return card.rank == our_swap)
			
			#remove cards
			player_hand = player_hand.filter(func(card): return card.rank != swap_rank)
			my_hand = my_hand.filter(func(card): return card.rank != our_swap)
			
			#add cards
			player_hand.append_array(my_cards)
			my_hand.append_array(player_cards)
			
			last_card_source = player_name
			
			print("I just took ", CARDS[swap_rank].name, " from ", player_name)
			print("and gave them ", CARDS[our_swap].name)
			
			cloud_save({ "hands" : { player_id : player_hand , GameManager.my_uid : my_hand } })
	
	print("I just used ", pool[power], " on ", player_name)

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
	if game_state.lastRequestedPlayer == player_id and quick_time_on_going:
		print("can select them yet...")
	print( str("Hey, ", player_name) )
	
	ask_panel.show()

func on_power_selected(power):
	#shouldn't be able to use power when it's your turn.
	if PASSIVES.has(power):
		if game_state.passives[GameManager.my_uid] == power: power = ""
		cloud_save({ "passives" : { GameManager.my_uid : power } })
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
	if game_state["playerTurn"] != GameManager.chat_data["playerIndex"]:
		if not ask_mode:
			on_power(selected_player_name, selected_power_up)
			print("I'm using powers on ", selected_player_name)
			return
		print("not your turn")
		return
	
	ask_panel.hide()
	request_label.text = ""
	
	#check if my hand still has the card.
	if game_state.hands[GameManager.my_uid].filter(func(card): return card.rank == selected_rank).is_empty():
		print("hmmmm")
		return
	
	if ask_mode: on_ask(selected_player_name, selected_rank)

func end_game():
	pass
