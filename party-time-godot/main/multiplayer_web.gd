extends Node

signal player_connected(peer_id)
signal player_disconnected(peer_id)

signal server_setup(peer_id)

signal mesh_entered
signal mesh_exited

var multiplayer_peer : WebRTCMultiplayerPeer
var peer_to_uid = {}
var peers = {}

var in_mesh : bool = false

var my_peer_id : int = 0
var cloud_master_id : int = -1

func setup_network(id: int):
	my_peer_id = id
	peer_to_uid[id] = GameManager.my_uid
	
	multiplayer_peer = WebRTCMultiplayerPeer.new()
	multiplayer_peer.create_mesh(my_peer_id)
	multiplayer.multiplayer_peer = multiplayer_peer
	
	multiplayer.peer_connected.connect(
		func(i):
			rpc("add_uid", GameManager.my_uid)
			
			if cloud_master_id == multiplayer.get_unique_id():
				#tell the new peer that I am the master.
				rpc_id(i, "set_cloud_master", cloud_master_id)
			
			player_connected.emit(i)
			
			if not in_mesh:
				in_mesh = true
				mesh_entered.emit()
	)
	
	multiplayer.peer_disconnected.connect(
		func(i):
			
			#if the master disconnects
			if cloud_master_id == i:
				elect_new_master()
			player_disconnected.emit(i)
			
			print("peers available ", peers)
	)
	
	server_setup.emit(id)

@rpc("any_peer", "call_local", "reliable")
func add_uid(incoming_uid):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = multiplayer.get_unique_id()
	peer_to_uid[sender_id] = incoming_uid

@rpc("any_peer", "call_remote", "reliable")
func set_cloud_master(new_master_id):
	if cloud_master_id == multiplayer.get_unique_id():
		if new_master_id > my_peer_id: return
	
	cloud_master_id = new_master_id
	print("Acknowledged Master: ", cloud_master_id)

func elect_new_master():
	# Deterministic Election: Lowest Peer ID wins
	var _peers = multiplayer.get_peers()
	_peers.append(multiplayer.get_unique_id()) # Include self
	_peers.sort() # Sorts lowest to highest.
	
	if _peers.size() > 0:
		cloud_master_id = _peers[0]
		if cloud_master_id == multiplayer.get_unique_id():
			print("Look at me. I am the Captain now.")

func update_active_players(active_ids: Array):
	if my_peer_id == 0 : return
	
	if active_ids.size() == 1:
		cloud_master_id = my_peer_id
	
	if multiplayer.has_multiplayer_peer():
		peer_to_uid[multiplayer.get_unique_id()] = GameManager.my_uid
	
	var current_active_ids = []
	for id in active_ids:
		current_active_ids.append(int(id))
	
	for player_id in current_active_ids:
		if player_id != my_peer_id and not peers.has(player_id):
			_create_peer_connection(player_id)
	
	var peers_to_remove = []
	for known_peer_id in peers.keys():
		if not current_active_ids.has(known_peer_id):
			peers_to_remove.append(known_peer_id)
	
	# Safely disconnect and delete them
	for peer_id in peers_to_remove:
		print("Player ", peer_id, " left the session. Cleaning up.")
		
		if peers[peer_id]:
			peers[peer_id].close()
		
		if multiplayer_peer.has_peer(peer_id):
			multiplayer_peer.remove_peer(peer_id)
		
		peers.erase(peer_id)
	
	if in_mesh and peers.is_empty():
		in_mesh = false
		mesh_exited.emit()
	
	print(peers, " the current peers after active player update.")

func _create_peer_connection(target_peer_id):
	print(target_peer_id)
	
	var peer : WebRTCPeerConnection = WebRTCPeerConnection.new()
	
	peer.initialize({ 
		"iceServers": [{ "urls" : ["stun:stun.l.google.com:19302"] }] 
	})
	
	peer.session_description_created.connect(_on_session_description_created.bind(target_peer_id))
	peer.ice_candidate_created.connect(_on_ice_candidate_created.bind(target_peer_id))
	
	multiplayer_peer.add_peer(peer, target_peer_id)
	peers[target_peer_id] = peer
	
	if my_peer_id > target_peer_id:
		peer.create_offer()

func _on_session_description_created(type: String, sdp: String, target_id: int):
	var peer = peers[target_id]
	peer.set_local_description(type, sdp)
	_send_to_js(target_id, {"type": type, "sdp": sdp})

func _on_ice_candidate_created(media: String, index: int, _name: String, target_id: int):
	_send_to_js(target_id, {"media": media, "index": index, "name": _name})

func _send_to_js(target_id, data):
	var msg : Dictionary = { "target": target_id, "payload": data }
	GameManager.send_webrtc_signal(msg)

func close_game():
	for peer_id in peers:
		if peers[peer_id]:
			peers[peer_id].close()
	
	peers.clear()
	multiplayer.multiplayer_peer = null
	
	my_peer_id = 0
	print(peers, " peers after I have left the game.")

func handle_webrtc_signal(data: Dictionary):
	var source_id = int(data.source_id)
	var payload = data.payload
	
	if not peers.has(source_id):
		_create_peer_connection(source_id)
	
	var peer : WebRTCPeerConnection = peers[source_id]
	
	if payload.has("type"):
		# It's an Offer or Answer
		if payload.type == "offer":
			peer.set_remote_description(payload.type, payload.sdp)
		elif payload.type == "answer":
			peer.set_remote_description(payload.type, payload.sdp)
	elif payload.has("media"):
		# It's an ICE Candidate
		peer.add_ice_candidate(payload.media, payload.index, payload.name)
