extends Node
class_name GameManager

@export var game_scenes : Dictionary[String, PackedScene]
@export var modal : Control

signal close_game
static var my_uid = ''
static var chat_data = {}

#this only works in Web Builds
var svelte_bridge
var webrtc_bridge
var mesh_bridge

var set_up_bridge
var game_close_bridge
var new_move_bridge

func _ready():
	svelte_bridge = JavaScriptBridge.create_callback(godot_callback)
	webrtc_bridge = JavaScriptBridge.create_callback(on_webrtc_message)
	mesh_bridge = JavaScriptBridge.create_callback(network_update)
	
	set_up_bridge = JavaScriptBridge.create_callback(set_up_game)
	game_close_bridge = JavaScriptBridge.create_callback(on_close_game)
	new_move_bridge = JavaScriptBridge.create_callback(on_new_move)
	
	var window = JavaScriptBridge.get_interface("window")
	
	window.sendToGodot = svelte_bridge
	window.GodotReceiveData = webrtc_bridge
	window.networkUpdate = mesh_bridge
	
	window.startGame = set_up_bridge
	window.closeGame = game_close_bridge
	window.newMove = new_move_bridge

func set_up_game(args):
	var data = args[0]
	
	var game_data = data
	
	if data is String:
		game_data = JSON.parse_string( data )
	
	if not game_scenes.has(game_data.key):
		print("Game Unavailable")
		return
	
	var game_scene : GameScene = get_node_or_null(game_data.key)
	if game_scene: return
	
	game_scene = game_scenes[game_data.key].instantiate()
	add_child(game_scene)
	
	game_scene.name = game_data.key
	game_scene.add_to_group("GameScene")
	
	#serve game...
	game_scene.start_game( game_data )
	
	close_game.connect( game_scene.queue_free )
	
	game_scene.tree_exiting.connect(
		remove_game.bind(game_scene) 
	)
	
	game_scene.tree_exited.connect( clean_up )

#deconstruct game.
func remove_game(_scene : GameScene):
	print('Game Closing')

func on_close_game(_b):
	create_tween().tween_callback( close_game.emit ).set_delay( 0.2 )

func clean_up():
	print('Game Closed')
	var window = JavaScriptBridge.get_interface("window")
	window.gameClose()
	#print(_x)

#new move has been done.
func on_new_move( args ):
	get_tree().call_group("GameScene", "on_new_move", args[0] )

func godot_callback(args):
	var function_name = args[0]
	var data = args[1]
	
	var parsed_data = data
	if data is String: parsed_data = JSON.parse_string(data)
	
	call( function_name , parsed_data )
	#send read back.
	if parsed_data is Dictionary: send_data( function_name + " from Godot", parsed_data )

func update_chat(new_chat_data : Dictionary):
	chat_data = new_chat_data
	my_uid = chat_data.myID

func initialize_game(game_key):
	var game_scene : GameScene = game_scenes[game_key].instantiate()
	send_data("send_game", game_scene.initialize_game())
	game_scene.free()

func on_game_close(_b):
	pass
	#chill for half a second before deleting.

#game state.
func update_game(data):
	get_tree().call_group("GameScene", "on_game_state_update", data)

#player state.
func update_players(data):
	get_tree().call_group("GameScene", "on_player_state_update", data)

#when the user presses the send button.
func send_game(_data):
	get_tree().call_group("GameScene", "on_user_send")

static func send_data(message_name: String, payload : Dictionary):
	var message_data = {"message": message_name, "data": payload }
	var json_string = JSON.stringify(message_data)
	var js_code = "window.parent.postMessage(%s, '*');" % json_string
	JavaScriptBridge.eval(js_code)

func network_update( args ):
	var message = args[0]
	var data = args[1]
	
	call(message, data)

func peer_connected(_id):
	pass
	#print("someone joined ", id)

func peer_disconnected(_id):
	pass
	#print("someone left ", id)

func on_webrtc_message( args ):
	var sender_peer_id = args[0]
	var raw_data = args[1]
	
	if typeof(raw_data) == TYPE_STRING:
		var parsed_data = JSON.parse_string(raw_data)
		
		if typeof(parsed_data) == TYPE_DICTIONARY:
			var data = parsed_data.get("data")
			print("I got this ", data, " from ", sender_peer_id)
			return
		return

#this gets the browsers timestamp.
static func get_time():
	var window = JavaScriptBridge.get_interface("window")
	var timestamp = window.getTime()
	return timestamp

static func broadcast_webrtc(payload):
	print("trying to send rtc")
	
	var data = payload
	if payload is Dictionary or payload is String:
		data = JSON.stringify({ "data": payload })
	
	var window = JavaScriptBridge.get_interface("window")
	window.GodotBroadcastData(data)
