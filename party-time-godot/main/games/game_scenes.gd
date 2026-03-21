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

static func make_move( move ):
	var window = JavaScriptBridge.get_interface("window")
	window.makeMove( move )
