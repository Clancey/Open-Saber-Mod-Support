extends Node

# Autoload "MultiplayerSession": lobby membership, roster, clock sync and the
# score/start RPCs for online multiplayer over WebRTC (mesh). The signaling
# server is the Cloudflare Worker from the VR Cooking Game, namespaced with
# gameId "open-saber". The host is always peer 1; there is no host migration
# (the server closes every socket when the host leaves).
#
# See game/multiplayer/README.md for the API and how to wire it into the game.

const SIGNALING_URL := "wss://vr-cooking-game-server-prod.james-clancey.workers.dev"
const GAME_ID := "open-saber"
const MAX_PLAYERS := 8
const CONNECT_TIMEOUT_SEC := 12.0
const HOST_CODE_RETRIES := 3
const SCORE_INTERVAL_MSEC := 200  # ~5 Hz
const START_LEAD_MSEC := 3000
const PING_BURST := 8
const PING_BURST_INTERVAL_SEC := 0.15
const PING_REFRESH_INTERVAL_SEC := 5.0

enum State { OFFLINE, CONNECTING, IN_LOBBY }

signal lobby_joined(code: String)
signal lobby_left(reason: String)
signal roster_changed(players: Array[Dictionary])
signal song_start_requested(song_key: String, difficulty: String, local_start_time_ms: int)
signal clock_synced(offset_ms: int, rtt_ms: int)
signal player_finished(id: int, score: int, percent: float, rank: String)
## The host picked a song (also sent to late joiners). Every peer then checks
## whether it has the map and reports set_has_song().
signal song_selected(song_key: String, difficulty: String)

## Shown to the other players; set it before hosting or joining.
var player_name := "Player"
var state := State.OFFLINE
var lobby_code := ""
var current_song_key := ""
var current_difficulty := ""

var _client: WebRtcClient
var _players: Dictionary = {}  # peer id -> player Dictionary
var _my_id := 0
var _intent_host := false
var _host_retries := 0
var _clock := ClockSync.new()
var _connect_timer: Timer
var _ping_timer: Timer
var _pings_left := 0
var _ping_seq := 0
var _score_dirty := false
var _last_score_send_ms := 0


func _ready() -> void:
	_connect_timer = Timer.new()
	_connect_timer.one_shot = true
	_connect_timer.timeout.connect(_on_connect_timeout)
	add_child(_connect_timer)
	_ping_timer = Timer.new()
	_ping_timer.timeout.connect(_on_ping_timer)
	add_child(_ping_timer)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _process(_delta: float) -> void:
	if _score_dirty and state == State.IN_LOBBY:
		var now := Time.get_ticks_msec()
		if now - _last_score_send_ms >= SCORE_INTERVAL_MSEC:
			_flush_score(now)


# --- Lobby membership -------------------------------------------------------

## Creates a lobby with a random 4-character code. lobby_joined(code) fires
## once the server confirms, lobby_left(reason) if it fails.
func host_lobby() -> bool:
	if state != State.OFFLINE:
		return false
	_intent_host = true
	_host_retries = 0
	_begin_connection(WebRtcSignaling.generate_code())
	return true


## Joins an existing lobby. Unknown codes silently create a new lobby on the
## server, which we detect (we would be assigned host id 1) and report as
## lobby_left("lobby_not_found").
func join_lobby(code: String) -> bool:
	if state != State.OFFLINE:
		return false
	var clean := code.strip_edges().to_upper()
	if not WebRtcSignaling.is_valid_code(clean):
		lobby_left.emit("invalid_code")
		return false
	_intent_host = false
	_begin_connection(clean)
	return true


func leave(reason: String = "left") -> void:
	if state == State.OFFLINE:
		return
	_teardown(reason)


func is_online() -> bool:
	return state == State.IN_LOBBY


func is_host() -> bool:
	return state == State.IN_LOBBY and _my_id == 1


func get_local_id() -> int:
	return _my_id


## Sorted by peer id, host (1) first. Each entry:
## {id, name, ready, has_song, score, combo, percent, finished, rank}
func get_players() -> Array[Dictionary]:
	var ids: Array = _players.keys()
	ids.sort()
	var players: Array[Dictionary] = []
	for id: int in ids:
		players.append((_players[id] as Dictionary).duplicate())
	return players


func get_player(id: int) -> Dictionary:
	return (_players.get(id, {}) as Dictionary).duplicate()


func get_player_count() -> int:
	return _players.size()


func all_ready() -> bool:
	if _players.is_empty():
		return false
	for player: Dictionary in _players.values():
		if not bool(player["ready"]):
			return false
	return true


func all_have_song() -> bool:
	if _players.is_empty():
		return false
	for player: Dictionary in _players.values():
		if not bool(player.get("has_song", false)):
			return false
	return true


# --- Ready / scores ---------------------------------------------------------

func set_ready(ready: bool) -> void:
	if state != State.IN_LOBBY:
		return
	_players[_my_id]["ready"] = ready
	_rpc_set_ready.rpc(ready)
	_emit_roster()


## Whether this peer has the selected song installed (the lobby's map fetcher
## reports it once the map is found locally or downloaded).
func set_has_song(has_song: bool) -> void:
	if state != State.IN_LOBBY:
		return
	if bool(_players[_my_id].get("has_song", false)) == has_song:
		return
	_players[_my_id]["has_song"] = has_song
	_rpc_set_has_song.rpc(has_song)
	_emit_roster()


## Throttled to ~5 Hz on the wire; the local roster updates immediately.
func report_score(score: int, combo: int, percent: float) -> void:
	if state != State.IN_LOBBY:
		return
	var me: Dictionary = _players[_my_id]
	me["score"] = score
	me["combo"] = combo
	me["percent"] = percent
	_score_dirty = true
	_emit_roster()


func report_finished(score: int, percent: float, rank: String) -> void:
	if state != State.IN_LOBBY:
		return
	var me: Dictionary = _players[_my_id]
	me["score"] = score
	me["percent"] = percent
	me["finished"] = true
	me["rank"] = rank
	me["ready"] = false
	_score_dirty = false
	_rpc_finished.rpc(score, percent, rank)
	_emit_roster()
	player_finished.emit(_my_id, score, percent, rank)


# --- Song start / clock -----------------------------------------------------

## Host only: announce the chosen song right away so every peer can fetch it.
## Everyone (host included) gets song_selected; readiness and has_song reset.
func select_song(song_key: String, difficulty: String) -> bool:
	if not is_host():
		return false
	_rpc_song_selected.rpc(song_key, difficulty)
	return true


## Host only. Everyone (host included) gets song_start_requested with the
## start time converted to their own Time.get_ticks_msec() clock, about
## START_LEAD_MSEC ahead so the map can be loaded first.
func start_song(song_key: String, difficulty: String) -> bool:
	if not is_host():
		return false
	var start_at_host_ms := Time.get_ticks_msec() + START_LEAD_MSEC
	_rpc_start_song.rpc(song_key, difficulty, start_at_host_ms)
	return true


## Current time on the host's Time.get_ticks_msec() clock.
func get_host_time_ms() -> int:
	if _my_id == 1:
		return Time.get_ticks_msec()
	return _clock.host_from_local(Time.get_ticks_msec())


func host_time_to_local_ms(host_ms: int) -> int:
	if _my_id == 1:
		return host_ms
	return _clock.local_from_host(host_ms)


func is_clock_synced() -> bool:
	return _my_id == 1 or _clock.is_synced()


func get_clock_rtt_ms() -> int:
	return 0 if _my_id == 1 else _clock.rtt_ms()


# --- Connection plumbing ----------------------------------------------------

func _begin_connection(code: String) -> void:
	_players.clear()
	_my_id = 0
	lobby_code = ""
	_clock.clear()
	_client = WebRtcClient.new()
	_client.name = "WebRtcClient"
	_client.connected.connect(_on_client_connected)
	_client.disconnected.connect(_on_client_disconnected)
	_client.lobby_joined.connect(_on_client_lobby_joined)
	_client.lobby_sealed.connect(_on_client_sealed)
	_client.multiplayer_peer_ready.connect(_on_multiplayer_peer_ready)
	add_child(_client)
	state = State.CONNECTING
	_connect_timer.start(CONNECT_TIMEOUT_SEC)
	if _client.start(SIGNALING_URL, code, true, GAME_ID) != OK:
		_teardown("connect_failed")


func _on_multiplayer_peer_ready(peer: WebRTCMultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer


func _on_client_connected(id: int, _use_mesh: bool) -> void:
	if _intent_host and id != 1:
		# Somebody already owns that code: pick another one.
		_host_retries += 1
		if _host_retries > HOST_CODE_RETRIES:
			_teardown("code_taken")
			return
		var next_code := WebRtcSignaling.generate_code()
		_teardown_client()
		_begin_connection(next_code)
		return
	if not _intent_host and id == 1:
		_teardown("lobby_not_found")
		return
	_my_id = id
	_try_enter_lobby()


func _on_client_lobby_joined(code: String) -> void:
	lobby_code = code
	_try_enter_lobby()


func _try_enter_lobby() -> void:
	if state != State.CONNECTING or _my_id == 0 or lobby_code == "":
		return
	_connect_timer.stop()
	state = State.IN_LOBBY
	_players[_my_id] = _new_player(_my_id, player_name)
	lobby_joined.emit(lobby_code)
	_emit_roster()


func _on_client_disconnected() -> void:
	if state == State.OFFLINE:
		return
	var reason := "disconnected"
	if _client != null and _client.close_reason.to_lower().contains("host"):
		reason = "host_left"
	elif state == State.CONNECTING:
		reason = "connect_failed"
	_teardown(reason)


func _on_client_sealed() -> void:
	_teardown("sealed")


func _on_connect_timeout() -> void:
	if state == State.CONNECTING:
		_teardown("timeout")


func _on_peer_connected(id: int) -> void:
	if state != State.IN_LOBBY:
		return
	if not _players.has(id):
		_players[id] = _new_player(id, "Player %d" % (id % 100))
	if _my_id == 1 and current_song_key != "":
		# Late joiner: tell it what was picked before it reports its own state.
		_rpc_song_selected.rpc_id(id, current_song_key, current_difficulty)
	_announce_state(id)
	if id == 1 and _my_id != 1:
		_start_clock_sync()
	_emit_roster()


func _on_peer_disconnected(id: int) -> void:
	if state != State.IN_LOBBY:
		return
	if id == 1 and _my_id != 1:
		_teardown("host_left")
		return
	if _players.erase(id):
		_emit_roster()


func _teardown_client() -> void:
	if _client == null:
		return
	var client := _client
	_client = null
	client.connected.disconnect(_on_client_connected)
	client.disconnected.disconnect(_on_client_disconnected)
	client.lobby_joined.disconnect(_on_client_lobby_joined)
	client.lobby_sealed.disconnect(_on_client_sealed)
	client.multiplayer_peer_ready.disconnect(_on_multiplayer_peer_ready)
	client.stop()
	client.queue_free()
	if multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer = null


func _teardown(reason: String) -> void:
	_connect_timer.stop()
	_ping_timer.stop()
	_teardown_client()
	var was_in_lobby := state == State.IN_LOBBY
	state = State.OFFLINE
	_players.clear()
	_my_id = 0
	lobby_code = ""
	current_song_key = ""
	current_difficulty = ""
	_score_dirty = false
	_clock.clear()
	print("[Session] Left lobby: ", reason)
	if was_in_lobby:
		_emit_roster()
	lobby_left.emit(reason)


func _new_player(id: int, display_name: String) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"ready": false,
		"has_song": false,
		"score": 0,
		"combo": 0,
		"percent": 1.0,
		"finished": false,
		"rank": "",
	}


func _emit_roster() -> void:
	roster_changed.emit(get_players())


## Sends this peer's full state to one peer (or everyone with peer_id 0).
func _announce_state(peer_id: int = 0) -> void:
	var me: Dictionary = _players[_my_id]
	var args: Array = [str(me["name"]), bool(me["ready"]), bool(me.get("has_song", false)),
		int(me["score"]), int(me["combo"]), float(me["percent"]), bool(me["finished"]), str(me["rank"])]
	if peer_id == 0:
		_rpc_player_state.rpc.callv(args)
	else:
		_rpc_player_state.rpc_id.callv([peer_id] + args)


func _flush_score(now: int) -> void:
	_score_dirty = false
	_last_score_send_ms = now
	var me: Dictionary = _players[_my_id]
	_rpc_score.rpc(int(me["score"]), int(me["combo"]), float(me["percent"]))


# --- Clock sync (NTP style ping/pong against the host) ----------------------

func _start_clock_sync() -> void:
	_clock.clear()
	_pings_left = PING_BURST
	_ping_timer.wait_time = PING_BURST_INTERVAL_SEC
	_ping_timer.start()
	_send_ping()


func _on_ping_timer() -> void:
	if state != State.IN_LOBBY or _my_id == 1:
		_ping_timer.stop()
		return
	_send_ping()


func _send_ping() -> void:
	_ping_seq += 1
	_rpc_ping.rpc_id(1, _ping_seq, Time.get_ticks_msec())
	if _pings_left > 0:
		_pings_left -= 1
		if _pings_left == 0:
			_ping_timer.wait_time = PING_REFRESH_INTERVAL_SEC


# --- RPCs -------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _rpc_player_state(display_name: String, ready: bool, has_song: bool, score: int, combo: int,
		percent: float, finished: bool, rank: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if id == 0 or state != State.IN_LOBBY:
		return
	_players[id] = {
		"id": id,
		"name": display_name,
		"ready": ready,
		"has_song": has_song,
		"score": score,
		"combo": combo,
		"percent": percent,
		"finished": finished,
		"rank": rank,
	}
	_emit_roster()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_ready(ready: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not _players.has(id):
		return
	_players[id]["ready"] = ready
	_emit_roster()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_has_song(has_song: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not _players.has(id):
		return
	_players[id]["has_song"] = has_song
	_emit_roster()


@rpc("authority", "call_local", "reliable")
func _rpc_song_selected(song_key: String, difficulty: String) -> void:
	if state != State.IN_LOBBY:
		return
	var changed := song_key != current_song_key or difficulty != current_difficulty
	current_song_key = song_key
	current_difficulty = difficulty
	if changed:
		# A new pick invalidates everyone's readiness and song ownership; each
		# peer re-announces its own state after checking/downloading the map.
		for player: Dictionary in _players.values():
			player["ready"] = false
			player["has_song"] = false
		_announce_state()
	_emit_roster()
	song_selected.emit(song_key, difficulty)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_score(score: int, combo: int, percent: float) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not _players.has(id):
		return
	var player: Dictionary = _players[id]
	player["score"] = score
	player["combo"] = combo
	player["percent"] = percent
	_emit_roster()


@rpc("any_peer", "call_remote", "reliable")
func _rpc_finished(score: int, percent: float, rank: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not _players.has(id):
		return
	var player: Dictionary = _players[id]
	player["score"] = score
	player["percent"] = percent
	player["finished"] = true
	player["rank"] = rank
	player["ready"] = false
	_emit_roster()
	player_finished.emit(id, score, percent, rank)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_ping(seq: int, t_send: int) -> void:
	if _my_id != 1:
		return
	var sender := multiplayer.get_remote_sender_id()
	_rpc_pong.rpc_id(sender, seq, t_send, Time.get_ticks_msec())


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_pong(_seq: int, t_send: int, t_host: int) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	_clock.add_sample(t_send, t_host, Time.get_ticks_msec())
	clock_synced.emit(_clock.offset_ms(), _clock.rtt_ms())


@rpc("authority", "call_local", "reliable")
func _rpc_start_song(song_key: String, difficulty: String, start_at_host_ms: int) -> void:
	if state != State.IN_LOBBY:
		return
	current_song_key = song_key
	current_difficulty = difficulty
	for player: Dictionary in _players.values():
		player["score"] = 0
		player["combo"] = 0
		player["percent"] = 1.0
		player["finished"] = false
		player["rank"] = ""
	_emit_roster()
	song_start_requested.emit(song_key, difficulty, host_time_to_local_ms(start_at_host_ms))
