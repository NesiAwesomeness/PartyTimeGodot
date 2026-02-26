class_name GameScene
extends Node

var game_data : Dictionary
var chat_data : Dictionary
var game_state : Dictionary

#whe something has changed from the server.
func on_server_update(data : Dictionary):
	var gd : Dictionary = data.gameData
	
	game_data = gd
	chat_data = data.chatData
	
	if gd.has("gameState"): game_state = gd.gameState
	_on_server_update(game_data, chat_data, game_state)

func _on_server_update(_game_data, _chat_data, _game_state):
	pass
	#print("Not been told what to do with this: ", _game_data)

#this just reconstructs the game data.
func get_data(new_game_state : Dictionary):
	game_data["gameState"] = new_game_state
	return game_data

#this will tell the game scene to get the data ready and send it
func on_user_send():
	GameManager.send_data("Raw game data: ", game_data)
