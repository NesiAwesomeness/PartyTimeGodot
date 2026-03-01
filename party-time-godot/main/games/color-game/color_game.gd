extends GameScene

@onready var button : Button = $Button
@onready var color : ColorRect = $ColorRect

func _ready():
	button.pressed.connect( on_button_pressed )
	NetworkManager.player_disconnected.connect(_on_player_exited)

func _on_player_exited(peer_id):
	print("this player has left ", peer_id)

func initialize_game() -> Dictionary:
	
	return {
		'name' : "Color Game",
		'key' : 'ColorGame',
		'gameState' : {
			'playerTurn' : 1,
			'stateColor' : '#ffffff'
		}
	}

func on_button_pressed():
	#print("it is not your turn: ", current_player_index != player_index)
	if NetworkManager.cloud_master_id != NetworkManager.my_peer_id : return
	color.color = Color( randf_range(0.5, 1.0), randf_range(0.5, 1.0), randf_range(0.5, 1.0) )
	# Tell everyone connected to run the 'sync_color' function immediately!
	rpc("sync_color", color.color.to_html(false))
	
	print("color sent by ", NetworkManager.my_peer_id)

@rpc("any_peer", "call_local", "reliable")
func sync_color(hex_color: String):
	color.color = Color(hex_color)
	print("color received from somewhere")

func _on_server_update(_game_data : Dictionary, _game_state: Dictionary):
	#just update the data i guess...
	color.color = Color( game_state["stateColor"] )

func on_user_send():
	print("user send landed in Godot")
	#change the playerTurn
	if game_state["playerTurn"] != GameManager.chat_data["playerIndex"] : return #not your turn yet.
	game_state["playerTurn"] = wrapi(GameManager.chat_data["playerIndex"] + 1, 0, int(GameManager.chat_data["memberCount"]))
	print("turn has been updated")
	
	game_state["stateColor"] = color.color.to_html(false)
	game_state['round'] += int(game_state["playerTurn"] < GameManager.chat_data["playerIndex"])
	
	GameManager.send_data("update", game_state)
