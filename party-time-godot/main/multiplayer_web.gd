extends Node

signal player_connected(peer_id)
signal player_disconnected(peer_id)

var multiplayer_peer : WebRTCMultiplayerPeer
var peers = {}
var my_peer_id : int = 0

func setup_network(id: int):
	my_peer_id = id
	multiplayer_peer = WebRTCMultiplayerPeer.new()
	
	multiplayer_peer.create_mesh(my_peer_id)
	multiplayer.multiplayer_peer = multiplayer_peer
	
	multiplayer.peer_connected.connect(func(i): player_connected.emit(i))
	multiplayer.peer_disconnected.connect(func(i): player_disconnected.emit(i))

func update_active_players(active_ids: Array):
	if my_peer_id == 0 : return
	print(active_ids)
	
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
	
	print("pearsss")
	
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
	
	print(data)
	
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
