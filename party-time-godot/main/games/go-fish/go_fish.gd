extends GameScene
class_name GoFish

@export var hand_scene : PackedScene
@export var players_node : Node
@export var my_hand_node : CardHand

@export_category("Ask")
@export var ask_panel : Control

@export var player_name_label : Label
@export var request_label : Label
@export var rank_label : Label

@export_category("Actions")
@export var action_labels : VBoxContainer
@export var action_label_scene : PackedScene
@export var status_label : Label

static var selected_player_name = ""
static var selected_rank = ""

func on_server_setup(_id):
	add_to_group("HandListener")
	add_to_group("CardListener")
	
	ask_panel.hide()
	
	for uid in game_state.hands:
		var hand : Array = game_state.hands[uid]
		var score : int = game_state.scores[uid]
		
		if uid != GameManager.my_uid:
			var hand_node : CardHand = players_node.get_node_or_null(uid)
			if not hand_node:
				hand_node = hand_scene.instantiate()
				hand_node.name = uid
				hand_node.hand_name = chat_data.members[uid]
				
				players_node.add_child(hand_node)
			hand_node.update_hand( hand )
			hand_node.update_score( score )
			continue
		
		my_hand_node.update_hand( hand )
		my_hand_node.update_score( score )

func on_player_selected(player_name):
	selected_player_name = player_name
	player_name_label.text = player_name
	
	ask_panel.show()
	rank_label.hide()

func on_card_selected(rank):
	selected_rank = rank
	
	request_label.show()
	request_label.text = ", Do you have any: "
	
	rank_label.show()
	rank_label.text = rank+"s?"

func on_ask(player_name, card_rank):
	selected_rank = ""
	selected_player_name = ""
	
	request_label.hide()
	ask_panel.hide()
	rank_label.hide()
	
	
	get_tree().call_group("HandListener", "on_player_deselect")
	print("Hey ", player_name, ", Do you have any ", card_rank, "s?")
	
	rpc("action_message", str(
		chat_data.members[GameManager.my_uid]," asked ",player_name," for ",card_rank,"s"))
	
	var player_id : String = chat_data.members.find_key(player_name)
	var player_hand : Array = game_state.hands[player_id]
	
	var rank_cards : Array = player_hand.filter( func(card): return card.rank == card_rank )
	
	var fish_from = ""
	if rank_cards.is_empty():
		draw_card()
		fish_from = " from DRAW"
	else:
		#remove the card from that player
		var new_player_cards = player_hand.filter(func(card): return card.rank != card_rank)
		rpc("update_hand", player_id, new_player_cards)
		
		var my_hand = game_state.hands[GameManager.my_uid]
		#add the cards to your hand
		my_hand.append_array(rank_cards)
		rpc("update_hand", GameManager.my_uid, my_hand)
		fish_from = " from "+ player_name
	
	check_for_books(fish_from)
	#save to the cloud.
	GameManager.send_data("batch_update", game_state)

func _on_server_update(_game_data, _chat_data, _game_state):
	status_label.text = ("Your Turn" 
	if game_state.playerTurn == chat_data.playerIndex 
	else "Waiting for "+ chat_data.members.values()[game_state.playerTurn])

func draw_card():
	#draw cards and skip your turn.
	
	if game_state.has("deck"):
		if game_state.deck.is_empty():
			end_game()
			return
		
		var new_card = game_state.deck.pop_front()
		rpc("update_deck", game_state.deck)
		
		var my_hand = game_state.hands[GameManager.my_uid]
		my_hand.append( new_card )
		
		rpc("update_hand", GameManager.my_uid, my_hand)
		
		#if it's your turn move to the next person.
		if game_state.playerTurn == chat_data.playerIndex:
			game_state.playerTurn = wrapi( 
				chat_data["playerIndex"] + 1, 0, int(chat_data["memberCount"]) )
		
		rpc("action_message", chat_data.members[GameManager.my_uid] +" went FISHING")
		action_message("GO FISH")
	else:
		end_game()

func check_for_books(message):
	# Logic to find 4 of a kind and remove them
	var my_hand = game_state.hands[GameManager.my_uid]
	
	var counts = {}
	for card in my_hand:
		if counts.has(card.rank): counts[card.rank] += 1 
		else: counts[card.rank] = 1
	
	for rank in counts: if counts[rank] == 4:
		print("BOOK! ", rank)
		my_hand = my_hand.filter(func(card): return card.rank != rank)
		
		rpc("update_hand", GameManager.my_uid, my_hand)
		rpc("action_message", chat_data.members[GameManager.my_uid] +" completed "+rank+"s"+message)
		rpc("add_point", GameManager.my_uid)

@rpc("any_peer", "call_local", "reliable")
func add_point(player_id):
	game_state.scores[player_id] += 1
	var score = game_state.scores[player_id]
	
	if player_id == GameManager.my_uid: my_hand_node.update_score(score)
	else: players_node.get_node(player_id).update_score(score)

@rpc("any_peer", "call_local", "reliable")
func update_hand(player_id, new_hand : Array):
	game_state.hands[player_id] = new_hand
	if player_id == GameManager.my_uid:
		if new_hand.is_empty():
			draw_card()
			return
		my_hand_node.update_hand(new_hand)
	else: players_node.get_node(player_id).update_hand(new_hand)

@rpc("any_peer", "call_remote", "reliable")
func update_deck(new_deck):
	game_state.deck = new_deck

@rpc("any_peer", "call_remote", "reliable")
func action_message(message):
	var action_label : Label = action_label_scene.instantiate()
	action_labels.add_child(action_label)
	action_label.text = message
	
	create_tween().tween_property(action_label, "modulate:a", 0.0, 1.0).set_delay(6.0)
	create_tween().tween_callback(action_label.queue_free).set_delay(7.0)

func end_game():
	pass

func on_send_ask_pressed():
	if game_state["playerTurn"] != chat_data["playerIndex"]:
		print("not your turn")
		return
	ask_panel.hide()
	
	#check if my hand still have the card.
	if my_hand_node.hand.filter(
		func(card): return card.rank == selected_rank).is_empty():
		print("hmmmm")
		return
	
	on_ask(selected_player_name, selected_rank)
