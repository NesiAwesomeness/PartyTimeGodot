extends GameScene

const PLAYER_SCENE = preload("res://main/games/world/player.tscn")
@onready var players_node = $Players

func _ready():
	multiplayer.peer_connected.connect(spawn_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	MultiplayerManager.server_setup.connect(on_server_setup)

func on_server_setup(id):
	spawn_player(id)
	
	for peer_id in multiplayer.get_peers():
		print("Attempt to spawn player ", peer_id)
		spawn_player(peer_id)

func spawn_player(id):
	if players_node.has_node(str(id)): return
	
	var player = PLAYER_SCENE.instantiate()
	player.name = str(id)
	players_node.add_child(player)
	
	if MultiplayerManager.peer_to_uid.has(id):
		var uid = MultiplayerManager.peer_to_uid[id]
		if not game_state.has("positions"): return
		
		var initial_positions : Dictionary = game_state.positions
		if not initial_positions.has(uid): return
		
		var saved_pos = initial_positions[uid]
		player.global_position = Vector2(saved_pos.x, saved_pos.y)
	
	print("Just spawned a player")

func remove_player(id):
	if players_node.has_node(str(id)):
		players_node.get_node(str(id)).queue_free()

var save_timer = 0.0

func _process(delta):
	# Only the Cloud Master runs this logic
	if not multiplayer.multiplayer_peer: return
	if MultiplayerManager.cloud_master_id != multiplayer.get_unique_id():
		return
	
	save_timer += delta
	if save_timer > 1.8:
		save_timer = 0.0
		print("Attempting to save positions as the master.")
		save_all_positions()

func save_all_positions():
	var positions = {}
	
	for peer_id in MultiplayerManager.peer_to_uid:
		var uid = MultiplayerManager.peer_to_uid[peer_id]
		var player_node_name = str(peer_id)
		
		if players_node.has_node(player_node_name):
			var player = players_node.get_node(player_node_name)
			positions[uid] = {
				"x": player.global_position.x, 
				"y": player.global_position.y 
			}
	
	if not positions.is_empty():
		var payload = {
			"positions" : positions
		}
		
		print("sending game state : ", payload)
		GameManager.send_data("batch_update", payload)
