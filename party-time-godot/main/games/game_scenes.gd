class_name GameScene
extends Node

var players : Dictionary
var game_state : Dictionary

var await_count : int = 0
var game_closing = false

func initialize_game() -> Dictionary:
	print("There is not initialization for this game")
	return {}

#this is called at the start.
func set_up(_game_data : Dictionary):
	#this is going to have a seed value, and a moves value
	on_set_up()

func start_game( new_game_data ):
	print( new_game_data )

func on_game_state_update(new_game_state):
	print( new_game_state )

func on_player_state_update( new_player_state ):
	print( new_player_state )

func on_chat_update():
	pass

func has_cloud_authority() -> bool:
	return false

func on_set_up():
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

static func make_move( move ):
	var window = JavaScriptBridge.get_interface("window")
	window.makeMove( JSON.stringify(move) )
