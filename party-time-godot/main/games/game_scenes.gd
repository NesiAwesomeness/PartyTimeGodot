class_name GameScene
extends Node

var game_data : Dictionary
var chat_data : Dictionary
var game_state : Dictionary

func _init():
	add_to_group("GameScene")

#whe something has changed from the server.
func on_server_update(data : Dictionary):
	var gd : Dictionary = data.gameData
	_on_server_update(data.gameData, data.chatData, gd.gameState)

func _on_server_update(_game_data, _chat_data, _game_state):
	print("Not been told what to do with this: ", _game_data)

#this will tell the game scene to get the data ready and send it
func on_user_send():
	GameManager.send_data("Raw game data: ", game_data)
