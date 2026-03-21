extends GameScene
class_name GoFish

@export var hand_scene : PackedScene
@export var player_nodes : Node
@export var my_hand_node : CardHand

@export_category("Actions")
@export var action_labels : VBoxContainer
@export var action_label_scene : PackedScene
@export var status_label : Label

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
	"tin_cans": { 'name': "Tin Can", 'tier': Tier.STANDARD, 'points': 1 },
	"empty_mustard": { 'name': "Mustard Can", 'tier': Tier.STANDARD, 'points': 1 },
	"fishbones": { 'name': "Fish Bones", 'tier': Tier.STANDARD, 'points': 1 },
	"salmon": { 'name': "Salmon", 'tier': Tier.STANDARD, 'points': 1 },
	"rubber_duck": { 'name': "Rubber Duck", 'tier': Tier.STANDARD, 'points': 1 },
	"broken_shades": { 'name': "Broken Shades", 'tier': Tier.STANDARD, 'points': 1 },
	"silver_tooth": { 'name': "Silver Tooth", 'tier': Tier.STANDARD, 'points': 1 },
	"missing_card": { 'name': "Missing Card", 'tier': Tier.RARE, 'points': 3 },
	"fuzzy_dice": { 'name': "Fuzzy Dice", 'tier': Tier.RARE, 'points': 3 },
	"soggy_shoes": { 'name': "Soggy Shoes", 'tier': Tier.RARE, 'points': 3 },
	"tuna": { 'name': "Tuna", 'tier': Tier.RARE, 'points': 3 },
	"fes": { 'name': "Fes's Watch", 'tier': Tier.RARE, 'points': 3 },
	"diamond_rings": {"name": "Ariyike's Ring", "tier": Tier.LEGENDARY, "points": 5},
	"cell_phone": { "name": "Cell Phone", "tier": Tier.LEGENDARY, 'points': 5 },
}

const POWERS = {
	#can use on others, but only when it's 
	#not your turn and not their turn.
	"magnifying_glass": "Magnifying Glass", #one card someone has that matches yours.
	"fast_hands": "Fast Hands" #swap junk cards with someone.
}

const PASSIVES = {
	"silver_tongue" : "Block!", 
}

var turn = 1
static var is_my_turn : bool = false
var deck : Array = []

#this contains a list of cards that I have booked.
static var booked_cards = []

enum MOVES {
	ASK, TAKE, PASSIVE, USE, END, GOFISH
}

func initialize_game() -> Dictionary:
	return {
		'name' : "Go Fish",
		'key' : 'GoFish',
		'turn' : 1,
		"hand_size" : 5,
		'dealer' : get_player_name(GameManager.my_uid),
		'seed' : randi(),
	}

@onready var rng = RandomNumberGenerator.new()

var move_index := 0
var move_count := 0

func start_game( game_data ):
	add_to_group("HandListener")
	
	rng.seed = int( game_data.seed )
	print( "the seed is ", int( game_data.seed ) )
	
	var hand_size = game_data.hand_size
	
	for card_id in CARDS.keys():
		var card_data = CARDS[card_id]
		var copies_to_add = card_data["tier"]
		for i in range(copies_to_add):
			deck.append({
				"rank" : card_id,
				"suite" : suites[i]
			})
	
	#then shuffle...
	shuffle_deck()
	shuffle_deck()
	
	for member in GameManager.chat_data.members: 
		players[member] = {}
		
		var hand = []
		for card in hand_size:
			hand.append( deck.pop_back() )
		
		players[member]["hand"] = hand
		players[member]["score"] = 0
		
		#this is a list of cards that will be blocked if asked for.
		players[member]["block_list"] = []
		
		if member != GameManager.my_uid:
			#add opponent visuals.
			var hand_node : CardHand = hand_scene.instantiate()
			hand_node.name = member
			hand_node.hand_name = GameManager.chat_data.members[member]
			player_nodes.add_child(hand_node)
	
	print( game_data.dealer , " just dealt the cards")
	update_turn( int( game_data.turn ) )
	
	move_count = game_data.moves
	
	check_game()
	#only do this at the start of the game
	if move_count == 0:
		display_cards()

func on_new_move( move : String ):
	move_index += 1
	var is_setting_up = move_index < move_count
	
	print( move )
	apply_move( move , is_setting_up )
	
	if not is_setting_up: display_cards()

func display_cards():
	#update the visuals.
	for player in players:
		var hand : Array = players[player]["hand"]
		var score : int = players[player]["score"]
		
		var hand_node : CardHand = player_nodes.get_node_or_null(player)
		if not hand_node:
			hand_node = my_hand_node
			my_hand_node.update_hand( hand, players[player]['block_list'] )
		else:
			hand_node.update_hand( hand )
		hand_node.update_score( score )

func apply_move( move : String, _set_up:bool=false ):
	var details = move.split(" ")
	
	var move_type = int( details[0] )
	var player = details[1]
	
	print(move_type, " ", MOVES.keys()[int(move_type)])
	
	match move_type:
		MOVES.ASK:
			var rank = details[2]
			var target = details[3]
			
			if not _set_up:
				#we are being asked.
				if target == GameManager.my_uid:
					my_hand_node.shake_card( rank )
			
			action_message(
				str(get_player_name(player), " asked ", 
				get_player_name(target), " for some ", CARDS[rank].name),
				Color(0.235, 0.286, 0.428, 0.773)
			)
			
			var ranks : Array = players[target]["hand"
			].filter( func(card): return card.rank == rank )
			
			var block_list : Array = players[target]["block_list"]
			
			#Go Fish if the player is me then I should go fish.
			if ranks.is_empty():
				if player == GameManager.my_uid: go_fish()
				
				draw_from_deck( player )
				update_turn( get_next_turn( turn ) )
			else:
				if block_list.has(rank):
					
					#remove rank from block list
					players[target]["block_list"] = block_list.filter(
						func(_rank): return _rank != rank
					)
					
					#Player will draw.
					#if the player is me then I should go fish.
					if player == GameManager.my_uid:
						go_fish()
					
					draw_from_deck( player )
					action_message( str(get_player_name(target) , " used block!"))
					
					#Move the turn
					update_turn( get_next_turn(turn) )
				else: #no block
					players[player]["hand"].append_array(ranks)
					players[target]["hand"] = players[target]["hand"].filter( 
						func(card): return card.rank != rank )
					
					action_message(
						str(get_player_name(player), " took ", 
						CARDS[rank].name, " from ", get_player_name(target))
					)
		MOVES.GOFISH:
			var score = float(details[2])
			draw_from_deck( player , score )
		MOVES.PASSIVE:
			var passive = details[2]
			var rank = details[3]
			
			print(" on passive use ", passive, player )
			
			delete_one_card(passive, player )
			match passive:
				"silver_tongue": players[player ]["block_list"].append(rank)
		MOVES.USE:
			var power = details[2]
			var target = details[3]
			
			delete_one_card(power, player )
			var pool = PASSIVES.merged(POWERS)
			
			match power:
				"magnifying_glass":
					if not _set_up:
						var target_hand : Array = players[target].hand
						var player_hand : Array = players[player].hand
						
						var union : Array = player_hand.map(func(card): return card.rank).filter(
							func(rank): return (target_hand.filter(
							#	filter the power cards from this person.
							func(card): return not pool.has(card.rank)
							#	make an array of ranks.
							).map( func(card): return card.rank)).has(rank) )
						
						#only display it to me.
						if player  == GameManager.my_uid:
							var display_rank : String
							
							if not union.is_empty():
								display_rank = union[rng.randi() % union.size()]
								action_message(str("they have ", CARDS[display_rank].name, "!"))
							else:
								action_message("We have nothing in common")
				"fast_hands":
					
					var target_hand : Array = players[target].hand
					var player_hand : Array = players[player ].hand
					
					var t = target_hand.filter(func(card): return not pool.has(card.rank))
					var p = player_hand.filter(func(card): return not pool.has(card.rank))
					
					# 1. Pick the ranks
					var target_rank = t[rng.randi() % t.size()]['rank']
					var player_rank = p[rng.randi() % p.size()]['rank']
					
					# 2. Extract the actual cards
					var cards_from_target = target_hand.filter(func(c): return c.rank == target_rank)
					var cards_from_player = player_hand.filter(func(c): return c.rank == player_rank)
					
					# 3. Filter them out of the original hands
					var new_target_hand = target_hand.filter(func(c): return c.rank != target_rank)
					var new_player_hand = player_hand.filter(func(c): return c.rank != player_rank)
					
					# 4. Add the SWAPPED cards to the other person's hand
					new_target_hand.append_array(cards_from_player)
					new_player_hand.append_array(cards_from_target)
					
					# 5. Update the state
					players[target].hand = new_target_hand
					players[player ].hand = new_player_hand
					
					if not _set_up:
						print(get_player_name(player )," just took ", CARDS[target_rank].name, " from ", 
						get_player_name(target), " and gave them ", CARDS[player_rank].name)
		MOVES.END:
			turn = -1
			is_my_turn = false
	check_game()

#spawn the fishing visuals
func go_fish():
	print(" I went finishing ")

func on_fish(score : float):
	make_move(str(MOVES.GOFISH," ",GameManager.my_uid," ", score ))

#this can also be used to remove one card from someone's inventory
func delete_one_card(rank, id):
	var x = players[id]["hand"].filter(func(card): return card.rank != rank)
	var power : Array = players[id]["hand"].filter(func(card): return card.rank == rank)
	
	print(power, " before removal")
	
	if not power.is_empty():
		power.remove_at(0)
		x.append_array(power)
	
	print(power, " after removal")
	
	players[id]["hand"] = x

func check_game():
	for id in players:
		var player : Dictionary = players[id]
		var me = id == GameManager.my_uid
		
		#normal cards.
		var hand : Array = player['hand'].filter( 
			func(card): return CARDS.has(card.rank) 
		)
		
		#any empty hand should take from the deck.
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
					
					action_message( str( get_player_name(id), " just completed ", CARDS[rank]["name"] ) )
					print("BOOK! ", CARDS[rank]["name"])
		
		var _hand : Array = player['hand'].filter( 
			func(card): return CARDS.has(card.rank) 
		)
		
		if _hand.is_empty():
			draw_from_deck(id)
		players[id] = player
	
	#if deck has finished end game.
	if deck.is_empty():
		end_game()

func end_game():
	turn = -1
	is_my_turn = false
	
	var winning_score = -1
	var winners : Array = []
	
	for player in players:
		var score = players[player]['score']
		if score > winning_score:
			winning_score = score
			winners = [player]
		elif score == winning_score:
			winners.append(player)
	
	for winner in winners: 
		action_message(str( 
			get_player_name(winner), " Won with ", winning_score, " points!"))

func draw_from_deck(target_id : String, _score: float=0.2):
	action_message( str(get_player_name(target_id), " went fishing.") )
	if deck.is_empty(): return
	
	var new_card = deck.pop_back()
	
	#var cards_to_add = []
	#var power_card_chance = 0.0
	
	players[target_id]['hand'].append( new_card )
	
	if target_id == GameManager.my_uid:
		action_message( str("I got ", CARDS[new_card.rank].name) )
	
	#roll a dice to get a power up
	if rng.randi() % 3 == 0:
		var pool : Dictionary = POWERS.merged(PASSIVES)
		var power_card = { "rank" : pool.keys()[rng.randi() % pool.size()], "suite" : "R" }
	
		#if they don't already have it
		if not players[target_id]['hand'].has(power_card):
			players[target_id]['hand'].append( power_card )
			
			if target_id != GameManager.my_uid:
				action_message( str( get_player_name(target_id), " found something special!") )
	
	action_message( str( deck.size(), " cards left in the deck") )

func _draw_needed_card(target_id: String):
	if deck.size() == 0:
		return null
		
	var player_hand = players[target_id]['hand']
	var needed_ranks = []
	
	# Collect the ranks the player currently has in their hand
	for card in player_hand:
		if card.has("rank") and not needed_ranks.has(card.rank):
			needed_ranks.append(card.rank)
	
	# Search the deck from top to bottom for a matching rank
	for i in range(deck.size() - 1, -1, -1):
		if needed_ranks.has(deck[i].rank):
			var found_card = deck[i]
			deck.remove_at(i)
			return found_card
	return deck.pop_back()

func get_next_turn( _turn ) -> int:
	if is_my_turn:
		#update the turn value here
		pass
	return wrapi( _turn + 1, 0, int(GameManager.chat_data.memberCount) )

func update_turn(_turn : int):
	turn = _turn
	is_my_turn = _turn == int( GameManager.chat_data.playerIndex )
	
	print("it my turn right? ", is_my_turn, " ", turn)
	
	get_tree().call_group("TurnListener", "on_turn_changed", turn, is_my_turn)
	
	status_label.text = ( "Your Turn" if is_my_turn else 
	"Waiting for "+ GameManager.chat_data.members.values()[turn] )

func _process(_delta):
	pass

func action_message(message : String, color:Color=Color('303030ff')):
	if move_index < move_count - 2: return

	var action_label : ActionLabel = action_label_scene.instantiate()
	action_label.set_up(color)
	action_labels.add_child(action_label)
	action_label.text = message
	
	var tween = create_tween()
	
	tween.tween_property(action_label, "modulate:a", 0.0, 3.0).set_delay(10.0)
	tween.chain().tween_callback( action_label.queue_free )

func shuffle_deck():
	for i in range(deck.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = deck[i]
		deck[i] = deck[j]
		deck[j] = temp

func get_player_name(id) -> String:
	if id == GameManager.my_uid: return "You"
	return GameManager.chat_data.members[id]

func on_ask(player_name, card_rank):
	print("Hey ", player_name, ", Do you have any ", CARDS[card_rank].name, "?")
	
	var player_id : String = get_player_id(player_name)
	make_move(str(MOVES.ASK, " ", GameManager.my_uid, " ", card_rank, " ", player_id))
	
	#TODO if the last move was us and was of type "ASK" and we
	#have exceded the time of asking then the just execute

func get_player_id(player_name):
	return GameManager.chat_data.members.find_key(player_name)

func on_ask_panel_ask(player, rank):
	var cannot_ask_that = players[GameManager.my_uid]["hand"].filter(
		func(card): return card.rank == rank
	).is_empty()
	
	if cannot_ask_that:
		print("hmmmm")
		return
	
	on_ask(player, rank)

func on_passive_use(passive, target_rank):
	make_move(str(MOVES.PASSIVE, " ", GameManager.my_uid, " ",passive , " ", target_rank))

func on_ask_panel_use_power(player, power):
	var target_id : String = get_player_id(player)
	
	make_move(str(MOVES.USE, " ",GameManager.my_uid, " ", power, " ", target_id ))
