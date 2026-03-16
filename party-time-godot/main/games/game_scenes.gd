class_name GameScene
extends Node

var game_data : Dictionary
var game_state : Dictionary

var await_count : int = 0
var game_closing = false

func _ready():
	pass
	#NetworkManager.player_connected.connect(player_joined)
	#NetworkManager.player_disconnected.connect(player_exited)
	#
	#NetworkManager.server_setup.connect( on_server_setup )

func initialize_game() -> Dictionary:
	print("There is not initialization for this game")
	return {}

func on_server_setup(_id):
	pass

func player_joined(_id):
	pass

func player_exited(_id):
	pass

#this is called at the start.
func set_up(_game_data : Dictionary):
	game_data = _game_data
	if _game_data.has("gameState"): game_state = _game_data.gameState
	on_set_up()

func on_game_state_update(new_game_state):
	game_state = new_game_state

func on_chat_update():
	pass

func has_cloud_authority() -> bool:
	return false
	#return NetworkManager.cloud_master_id != NetworkManager.my_peer_id 

func on_set_up():
	#print("Not been told what to do with this: ", _game_data)
	pass

func on_await(decrement : bool):
	await_count += -1 if decrement else 1
	
	print("the await count is ", await_count)
	if game_closing:
		close_game()

func close_game():
	game_closing = true
	print("closing game await ", await_count)
	#this half second will ensure that all rpc calls will happen before the player leaves.
	if await_count == 0: get_tree().create_timer(0.5).timeout.connect( delete_game )

func delete_game():
	if game_closing and is_inside_tree():
		cloud_save(game_state)
		
		GameManager.send_data("end_game", {})
		queue_free()

var _pending_cloud_data : Dictionary = {}
var _is_save_queued : bool = false

func cloud_save(change : Dictionary) -> void:
	# Deep merge the new change into our pending data dictionary
	_deep_merge(_pending_cloud_data, change)
	
	if not _is_save_queued:
		_is_save_queued = true
		_execute_batched_save.call_deferred()

func _execute_batched_save() -> void:
	if not _pending_cloud_data.is_empty():
		GameManager.send_data("batch_update", _pending_cloud_data)
		print("Batched Save Executed!")
		_pending_cloud_data.clear()
	_is_save_queued = false

func _deep_merge(target : Dictionary, source : Dictionary) -> void:
	for key in source:
		if target.has(key) and typeof(target[key]) == TYPE_DICTIONARY and typeof(source[key]) == TYPE_DICTIONARY:
			_deep_merge(target[key], source[key])
		else:
			
			if typeof(source[key]) == TYPE_DICTIONARY or typeof(source[key]) == TYPE_ARRAY:
				target[key] = source[key].duplicate(true)
			else: target[key] = source[key]

#this just reconstructs the game data.
func get_data(new_game_state : Dictionary):
	game_data["gameState"] = new_game_state
	return game_data

#this will tell the game scene to get the data ready and send it
func on_user_send():
	GameManager.send_data("Raw game data: ", game_data)
