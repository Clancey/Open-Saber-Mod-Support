extends WebRtcSignaling
class_name WebRtcClient

# Owns the WebRTCMultiplayerPeer and turns signaling messages into peer
# connections (mesh: every peer connects to every other peer; the peer with the
# lower id creates the offer so the host never does). Adapted from the VR
# Cooking Game multiplayer_client.gd. The owner (MultiplayerSession) decides
# when to install rtc_mp as the scene's multiplayer peer.

signal multiplayer_peer_ready(peer: WebRTCMultiplayerPeer)

const ICE_SERVERS: Array[Dictionary] = [
	{"urls": ["stun:stun.l.google.com:19302"]},
	# TURN is required for strict NATs (most mobile networks); add credentials here:
	# {"urls": ["turn:relay.example.com:3478"], "username": "user", "credential": "pass"},
]

var rtc_mp := WebRTCMultiplayerPeer.new()
var sealed := false
var unique_id := 0


func _init() -> void:
	connected.connect(_connected)
	disconnected.connect(_disconnected)
	offer_received.connect(_offer_received)
	answer_received.connect(_answer_received)
	candidate_received.connect(_candidate_received)
	lobby_sealed.connect(_lobby_sealed)
	peer_connected.connect(_peer_connected)
	peer_disconnected.connect(_peer_disconnected)


func start(url: String, lobby_code: String, use_mesh: bool = true, custom_game_id: String = "") -> Error:
	stop()
	sealed = false
	mesh = use_mesh
	lobby = lobby_code
	if custom_game_id != "":
		game_id = custom_game_id
	return connect_to_url(url, custom_game_id)


func stop() -> void:
	unique_id = 0
	rtc_mp.close()
	rtc_mp = WebRTCMultiplayerPeer.new()
	close()


func _create_peer(id: int) -> WebRTCPeerConnection:
	var peer := WebRTCPeerConnection.new()
	var error := peer.initialize({"iceServers": ICE_SERVERS})
	if error != OK:
		push_warning("[WebRTC] Could not initialize peer connection: %s" % error_string(error))
	peer.session_description_created.connect(_offer_created.bind(id))
	peer.ice_candidate_created.connect(_new_ice_candidate.bind(id))
	error = rtc_mp.add_peer(peer, id)
	if error != OK:
		push_warning("[WebRTC] Could not add peer %d: %s" % [id, error_string(error)])
	if id < rtc_mp.get_unique_id():
		# The peer with the lower id makes the offer, so the host (1) never does.
		@warning_ignore("return_value_discarded")
		peer.create_offer()
	return peer


func _new_ice_candidate(mid_name: String, index_name: int, sdp_name: String, id: int) -> void:
	@warning_ignore("return_value_discarded")
	send_candidate(id, mid_name, index_name, sdp_name)


func _offer_created(type: String, data: String, id: int) -> void:
	if not rtc_mp.has_peer(id):
		return
	var connection: WebRTCPeerConnection = rtc_mp.get_peer(id)["connection"]
	@warning_ignore("return_value_discarded")
	connection.set_local_description(type, data)
	if type == "offer":
		@warning_ignore("return_value_discarded")
		send_offer(id, data)
	else:
		@warning_ignore("return_value_discarded")
		send_answer(id, data)


func _connected(id: int, use_mesh: bool) -> void:
	print("[WebRTC] Assigned peer id %d, mesh: %s" % [id, use_mesh])
	unique_id = id
	var error: Error
	if use_mesh:
		error = rtc_mp.create_mesh(id)
	elif id == 1:
		error = rtc_mp.create_server()
	else:
		error = rtc_mp.create_client(id)
	if error != OK:
		push_warning("[WebRTC] Could not create multiplayer peer: %s" % error_string(error))
		return
	multiplayer_peer_ready.emit(rtc_mp)


func _lobby_sealed() -> void:
	sealed = true


func _disconnected() -> void:
	if not sealed:
		# Unexpected disconnect: drop every data channel too.
		rtc_mp.close()


func _peer_connected(id: int) -> void:
	print("[WebRTC] Signaling peer connected: %d" % id)
	@warning_ignore("return_value_discarded")
	_create_peer(id)


func _peer_disconnected(id: int) -> void:
	if rtc_mp.has_peer(id):
		rtc_mp.remove_peer(id)


func _offer_received(id: int, offer: String) -> void:
	if rtc_mp.has_peer(id):
		var connection: WebRTCPeerConnection = rtc_mp.get_peer(id)["connection"]
		@warning_ignore("return_value_discarded")
		connection.set_remote_description("offer", offer)


func _answer_received(id: int, answer: String) -> void:
	if rtc_mp.has_peer(id):
		var connection: WebRTCPeerConnection = rtc_mp.get_peer(id)["connection"]
		@warning_ignore("return_value_discarded")
		connection.set_remote_description("answer", answer)


func _candidate_received(id: int, mid: String, index: int, sdp: String) -> void:
	if rtc_mp.has_peer(id):
		var connection: WebRTCPeerConnection = rtc_mp.get_peer(id)["connection"]
		@warning_ignore("return_value_discarded")
		connection.add_ice_candidate(mid, index, sdp)
