extends Node
class_name GameManager

@export var game_scenes : Dictionary[String, PackedScene]
@export var modal : Control

static var my_uid = ''
static var chat_data = {}

#this only works in Web Builds
var svelte_bridge
var webrtc_bridge
var mesh_bridge

func _ready():
	svelte_bridge = JavaScriptBridge.create_callback(godot_callback)
	webrtc_bridge = JavaScriptBridge.create_callback(on_webrtc_message)
	mesh_bridge = JavaScriptBridge.create_callback(network_update)
	
	var window = JavaScriptBridge.get_interface("window")
	
	window.sendToGodot = svelte_bridge
	window.GodotReceiveData = webrtc_bridge
	window.networkUpdate = mesh_bridge

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

func start_game(game_data : Dictionary):
	if game_data.key == "" : return
	
	if not game_scenes.has(game_data.key):
		print("Game Unavailable")
		return
	
	get_time()
	
	var game_scene : GameScene = get_node_or_null(game_data.key)
	if not game_scene:
		game_scene = game_scenes[game_data.key].instantiate()
		add_child(game_scene)
		
		game_scene.name = game_data.key
		game_scene.add_to_group("GameScene")
		#serve game...
		game_scene.start_game(game_data)
	
	game_scene.game_closing = false

#new move has been done.
func new_move(move):
	get_tree().call_group("GameScene", "on_new_move", move)

#game state.
func update_game(data):
	get_tree().call_group("GameScene", "on_game_state_update", data)

#player state.
func update_players(data):
	get_tree().call_group("GameScene", "on_player_state_update", data)

#when the user presses the send button.
func send_game(_data):
	get_tree().call_group("GameScene", "on_user_send")

func on_game_close(_b):
	#chill for half a second before deleting.
	
	create_tween().tween_callback( func(): 
		get_tree().call_group( "GameScene", "close_game" )
	).set_delay( 0.16 )

static func send_data(message_name: String, payload : Dictionary):
	var message_data = {"message": message_name, "data": payload }
	var json_string = JSON.stringify(message_data)
	var js_code = "window.parent.postMessage(%s, '*');" % json_string
	JavaScriptBridge.eval(js_code)

func network_update( args ):
	var message = args[0]
	var data = args[1]
	
	call(message, data)

func peer_connected(id):
	print("someone joined ", id)

func peer_disconnected(id):
	print("someone left ", id)

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
	
	print("Godot time is ", Time.get_unix_time_from_system())
	print("Browser time is ", timestamp)
	
	return timestamp

static func broadcast_webrtc(payload):
	print("trying to send rtc")
	
	var data = payload
	if payload is Dictionary or payload is String:
		data = JSON.stringify({ "data": payload })
	
	var window = JavaScriptBridge.get_interface("window")
	window.GodotBroadcastData(data)
