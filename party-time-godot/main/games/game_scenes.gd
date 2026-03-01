class_name GameScene
extends Node

var game_data : Dictionary
var game_state : Dictionary

func _ready():
	NetworkManager.player_connected.connect(player_joined)
	NetworkManager.player_disconnected.connect(player_exited)
	NetworkManager.server_setup.connect(on_server_setup)

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
	return NetworkManager.cloud_master_id != NetworkManager.my_peer_id 

func on_set_up():
	pass
	#print("Not been told what to do with this: ", _game_data)

#this just reconstructs the game data.
func get_data(new_game_state : Dictionary):
	game_data["gameState"] = new_game_state
	return game_data

#this will tell the game scene to get the data ready and send it
func on_user_send():
	GameManager.send_data("Raw game data: ", game_data)
