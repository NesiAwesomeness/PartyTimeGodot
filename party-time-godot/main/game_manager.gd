extends Node
class_name GameManager

const color_game_scene = preload("res://main/games/color_game/color_game.tscn")

var web_callback_ref

#this only works in Web Builds
func _ready():
	web_callback_ref = JavaScriptBridge.create_callback(godot_callback)
	var window = JavaScriptBridge.get_interface("window")
	window.sendToGodot = web_callback_ref

func godot_callback(args):
	var function_name = args[0]
	var json_string = args[1]
	
	var data_dict : Dictionary = JSON.parse_string(json_string)
	
	call(function_name, data_dict)
	send_data(function_name, data_dict )

func start_game(game : Dictionary):
	if not game.has("gameData"):
		print("No game data.")
		return
	
	var game_data = game.gameData
	if game_data.key == "" : return
	print(game_data.key)
	
	match game_data.key:
		"ColorGame":
			var color_game : GameScene = color_game_scene.instantiate()
			add_child(color_game)
			color_game.on_server_update(game)

func update_game(data):
	get_tree().call_group("GameScene", "on_server_update", data)

#when the user presses the send button.
func send_game(_data):
	get_tree().call_group("GameScene", "on_user_send")

func on_game_close(_b):
	#chill for half a second before deleting.
	create_tween().tween_callback( get_tree().call_group.bind("GameScene", "queue_free") ).set_delay(0.5)

static func send_data(message_name: String, payload : Dictionary):
	var message_data = {"message": message_name, "data": payload }
	var json_string = JSON.stringify(message_data)
	var js_code = "window.parent.postMessage(%s, '*');" % json_string
	JavaScriptBridge.eval(js_code)
