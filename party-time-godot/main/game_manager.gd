extends Node
class_name GameManager

@export var game_scenes : Dictionary[String, PackedScene]
@export var modal : Control

static var my_uid = ''
static var chat_data = {}

#this only works in Web Builds
var web_callback_ref
func _ready():
	web_callback_ref = JavaScriptBridge.create_callback(godot_callback)
	var window = JavaScriptBridge.get_interface("window")
	window.sendToGodot = web_callback_ref
	
	NetworkManager.mesh_entered.connect(on_mesh_entered)
	NetworkManager.mesh_exited.connect(on_mesh_exited)

func on_mesh_entered():
	#modal.hide()
	print("In Mesh")

func on_mesh_exited():
	#modal.show()
	#modal.move_to_front()
	print("Not in Mesh")

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
			NetworkManager.setup_network(parsed_data.id)
			return
		"handle_webrtc_signal":
			NetworkManager.handle_webrtc_signal(parsed_data)
			return
		"update_active_players":
			NetworkManager.update_active_players(parsed_data)
			return
	
	call( function_name, parsed_data )
	if parsed_data is Dictionary:
		send_data( function_name, parsed_data )

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
	
	var game_scene : GameScene = get_node_or_null(game_data.key)
	if not game_scene:
		game_scene = game_scenes[game_data.key].instantiate()
		add_child(game_scene)
		game_scene.name = game_data.key
		game_scene.add_to_group("GameScene")
		#serve game...
		game_scene.set_up(game_data)
	
	game_scene.game_closing = false
	

func update_game(data):
	get_tree().call_group("GameScene", "on_game_state_update", data)

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

static func send_webrtc_signal(payload: Dictionary):
	var json_string = JSON.stringify(payload)
	JavaScriptBridge.eval("window.parent.postMessage({type: 'GODOT_SIGNAL', data: %s}, '*');" % json_string)
