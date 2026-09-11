extends Node
class_name WebRtcSignaling

# WebSocket signaling client for the Cloudflare Worker lobby server
# (D:\Projects\VRCookingGame\MultiplayerServer\worker.js). Adapted from the
# VR Cooking Game ws_webrtc_client.gd.
#
# Protocol: JSON text frames {"type": int, "id": int, "data": string}.
# The worker keys each lobby (Durable Object) by "<gameId>:<URL path>", so the
# lobby code MUST be part of the URL path: wss://host/<CODE>?gameId=<game>.
# A bare path makes the worker create a fresh lobby every time, and the JOIN
# reply only echoes the code the client sent, so the code we connect with is
# the code the lobby has. The server drops sockets that do not JOIN within 1 s
# of connecting, hence the automatic JOIN on open.

enum Message {
	JOIN,
	ID,
	PEER_CONNECT,
	PEER_DISCONNECT,
	OFFER,
	ANSWER,
	CANDIDATE,
	SEAL,
	GAME_STATE,
}

const CODE_ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ23456789"
const CODE_LENGTH := 4

@export var autojoin := true
@export var lobby := ""
@export var mesh := true
@export var game_id := "open-saber"

var ws := WebSocketPeer.new()
var close_code := 1000
var close_reason := "Unknown"
var _old_state := WebSocketPeer.STATE_CLOSED

signal lobby_joined(lobby: String)
signal connected(id: int, use_mesh: bool)
signal disconnected()
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal offer_received(id: int, offer: String)
signal answer_received(id: int, answer: String)
signal candidate_received(id: int, mid: String, index: int, sdp: String)
signal lobby_sealed()
signal game_state_received(state: String)


static func generate_code() -> String:
	var code := ""
	for _i: int in range(CODE_LENGTH):
		code += CODE_ALPHABET[randi() % CODE_ALPHABET.length()]
	return code


static func is_valid_code(code: String) -> bool:
	if code.length() != CODE_LENGTH:
		return false
	for character: String in code:
		if CODE_ALPHABET.find(character) == -1:
			return false
	return true


func connect_to_url(url: String, custom_game_id: String = "") -> Error:
	close()
	close_code = 1000
	close_reason = "Unknown"
	if custom_game_id != "":
		game_id = custom_game_id

	var final_url := url.trim_suffix("/")
	if lobby != "":
		final_url += "/" + lobby
	final_url += ("&" if final_url.find("?") != -1 else "?") + "gameId=" + game_id

	print("[Signaling] Connecting to ", final_url)
	var error := ws.connect_to_url(final_url)
	if error != OK:
		push_warning("[Signaling] Failed to connect: %s" % error_string(error))
	return error


func close() -> void:
	ws.close()


func is_open() -> bool:
	return ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func _process(_delta: float) -> void:
	ws.poll()
	var state := ws.get_ready_state()
	if state != _old_state:
		if state == WebSocketPeer.STATE_OPEN:
			print("[Signaling] Connected")
			if autojoin:
				@warning_ignore("return_value_discarded")
				join_lobby(lobby)
		elif state == WebSocketPeer.STATE_CLOSED:
			close_code = ws.get_close_code()
			close_reason = ws.get_close_reason()
			print("[Signaling] Disconnected. Code: %d Reason: %s" % [close_code, close_reason])
			disconnected.emit()
	while state == WebSocketPeer.STATE_OPEN and ws.get_available_packet_count():
		if not _parse_msg():
			push_warning("[Signaling] Could not parse a message from the server")
	_old_state = state


func _parse_msg() -> bool:
	var packet_str := ws.get_packet().get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(packet_str)
	if not parsed is Dictionary:
		return false
	var msg := parsed as Dictionary
	if not msg.has("type") or not msg.has("id"):
		return false
	var data: String = str(msg.get("data", ""))
	var type := _to_int(msg["type"])
	var src_id := _to_int(msg["id"])
	if type < 0 or src_id < 0:
		return false

	match type:
		Message.ID:
			connected.emit(src_id, data == "true")
		Message.JOIN:
			# The worker prefixes the code with "<gameId>:".
			var code := data
			var separator := code.find(":")
			if separator != -1:
				code = code.substr(separator + 1)
			lobby = code
			print("[Signaling] Joined lobby ", code)
			lobby_joined.emit(code)
		Message.SEAL:
			lobby_sealed.emit()
		Message.GAME_STATE:
			game_state_received.emit(data)
		Message.PEER_CONNECT:
			peer_connected.emit(src_id)
		Message.PEER_DISCONNECT:
			peer_disconnected.emit(src_id)
		Message.OFFER:
			offer_received.emit(src_id, data)
		Message.ANSWER:
			answer_received.emit(src_id, data)
		Message.CANDIDATE:
			var candidate: PackedStringArray = data.split("\n", false)
			if candidate.size() != 3 or not candidate[1].is_valid_int():
				return false
			candidate_received.emit(src_id, candidate[0], candidate[1].to_int(), candidate[2])
		_:
			return false
	return true


static func _to_int(value: Variant) -> int:
	match typeof(value):
		TYPE_INT:
			return value as int
		TYPE_FLOAT:
			return int(value as float)
		TYPE_STRING:
			var text := value as String
			return text.to_int() if text.is_valid_int() else -1
	return -1


func join_lobby(code: String) -> Error:
	var lobby_code := code
	if code != "" and not code.contains(":"):
		lobby_code = game_id + ":" + code
	# id 0 asks for mesh mode, id 1 for host-relayed star topology.
	return _send_msg(Message.JOIN, 0 if mesh else 1, lobby_code)


## Host only: marks the game ended; the server closes every socket ~5 s later.
func seal_lobby() -> Error:
	return _send_msg(Message.SEAL, 0)


## Host only: opaque string the server stores and replays to late joiners.
func send_game_state(state: String) -> Error:
	return _send_msg(Message.GAME_STATE, 0, state)


func send_candidate(id: int, mid: String, index: int, sdp: String) -> Error:
	return _send_msg(Message.CANDIDATE, id, "\n%s\n%d\n%s" % [mid, index, sdp])


func send_offer(id: int, offer: String) -> Error:
	return _send_msg(Message.OFFER, id, offer)


func send_answer(id: int, answer: String) -> Error:
	return _send_msg(Message.ANSWER, id, answer)


func _send_msg(type: int, id: int, data: String = "") -> Error:
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_UNAVAILABLE
	return ws.send_text(JSON.stringify({"type": type, "id": id, "data": data}))
