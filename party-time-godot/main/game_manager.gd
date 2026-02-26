extends Node
class_name GameManager

const color_game_scene = preload("res://main/games/color_game/color_game.tscn")
const world_game_scene = preload("res://main/games/world/world_game.tscn")

static var my_uid = ''

#this only works in Web Builds
var web_callback_ref
func _ready():
	web_callback_ref = JavaScriptBridge.create_callback(godot_callback)
	var window = JavaScriptBridge.get_interface("window")
	window.sendToGodot = web_callback_ref

func godot_callback(args):
	var function_name = args[0]
	var data = args[1]
	
	var parsed_data
	
	if data is String:
		parsed_data = JSON.parse_string(data)
	else:
		parsed_data = data
	
	match function_name:
		"setup_network":
			MultiplayerManager.setup_network(parsed_data.id)
			return
		"handle_webrtc_signal":
			MultiplayerManager.handle_webrtc_signal(parsed_data)
			return
		"update_active_players":
			MultiplayerManager.update_active_players(parsed_data)
			return
	
	if parsed_data is Dictionary:
		call(function_name, parsed_data )
		send_data(function_name, parsed_data )

func start_game(game : Dictionary):
	my_uid = game.chatData.myID
	
	if not game.has("gameData"):
		print(" No game data. ")
		return
	
	var game_data = game.gameData
	if game_data.key == "" : return
	
	var game_scene : GameScene
	
	match game_data.key:
		"ColorGame" : game_scene = color_game_scene.instantiate()
		"WorldGame" : game_scene = world_game_scene.instantiate()
	
	add_child(game_scene)
	game_scene.add_to_group("GameScene")
	game_scene.on_server_update(game)

func update_game(data):
	get_tree().call_group("GameScene", "on_server_update", data)

#when the user presses the send button.
func send_game(_data):
	get_tree().call_group("GameScene", "on_user_send")

func on_game_close(_b):
	#chill for half a second before deleting.
	create_tween().tween_callback( get_tree().call_group.bind( 
		"GameScene", "queue_free" ) ).set_delay( 0.16 )
	create_tween().tween_callback( MultiplayerManager.close_game ).set_delay( 0.16 )

static func send_data(message_name: String, payload : Dictionary):
	var message_data = {"message": message_name, "data": payload }
	var json_string = JSON.stringify(message_data)
	var js_code = "window.parent.postMessage(%s, '*');" % json_string
	JavaScriptBridge.eval(js_code)

static func send_webrtc_signal(payload: Dictionary):
	var json_string = JSON.stringify(payload)
	JavaScriptBridge.eval("window.parent.postMessage({type: 'GODOT_SIGNAL', data: %s}, '*');" % json_string)
