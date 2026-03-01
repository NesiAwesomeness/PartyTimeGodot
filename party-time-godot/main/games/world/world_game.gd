extends GameScene

const PLAYER_SCENE = preload("res://main/games/world/player.tscn")
@onready var players_node = $Players

func on_server_setup(id):
	player_joined(id)
	for peer_id in multiplayer.get_peers():
		player_joined(peer_id)

func player_joined(id):
	if players_node.has_node(str(id)): return
	
	var player = PLAYER_SCENE.instantiate()
	player.name = str(id)
	players_node.add_child(player)
	
	if NetworkManager.peer_to_uid.has(id):
		var uid = NetworkManager.peer_to_uid[id]
		if not game_state.has("positions"): return
		
		var initial_positions : Dictionary = game_state.positions
		if not initial_positions.has(uid): return
		
		var saved_pos = initial_positions[uid]
		player.global_position = Vector2(saved_pos.x, saved_pos.y)

func player_exited(id):
	if players_node.has_node(str(id)):
		players_node.get_node(str(id)).queue_free()

var save_timer = 0.0
func _process(delta):
	# only the Cloud Master runs this logic
	if not multiplayer.multiplayer_peer: return
	if NetworkManager.cloud_master_id != multiplayer.get_unique_id():
		return
	
	save_timer += delta
	if save_timer > 1.8:
		save_timer = 0.0
		save_players()

func save_players():
	var positions = {}
	
	print("I'm the master noww")
	
	for peer_id in NetworkManager.peer_to_uid:
		var uid = NetworkManager.peer_to_uid[peer_id]
		var player_node_name = str(peer_id)
		
		if players_node.has_node(player_node_name):
			var player = players_node.get_node(player_node_name)
			positions[uid] = {
				"x": player.global_position.x, 
				"y": player.global_position.y 
			}
	
	if not positions.is_empty():
		#game state
		var payload = {
			"positions" : positions
		}
		
		GameManager.send_data("batch_update", payload)
