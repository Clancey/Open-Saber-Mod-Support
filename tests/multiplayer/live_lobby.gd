extends SceneTree

# Live check against the real signaling worker (creates a throwaway lobby):
# session A hosts, session B (a second MultiplayerSession with its own
# MultiplayerAPI under /root/B) joins by code, both must see each other over
# WebRTC, B must clock-sync against A, and a start_song from A must reach B.
# Run with:
#   godot --headless --xr-mode off --path . -s tests/multiplayer/live_lobby.gd

const STEP_TIMEOUT_SEC := 15.0

var _a: Node
var _b: Node
var _failures: Array[String] = []


func _initialize() -> void:
	# The root only enters the tree after _initialize returns; wait for _ready.
	await process_frame
	_a = root.get_node("MultiplayerSession")
	_a.player_name = "HostBot"

	var holder := Node.new()
	holder.name = "B"
	root.add_child(holder)
	set_multiplayer(MultiplayerAPI.create_default_interface(), NodePath("/root/B"))
	_b = load("res://game/multiplayer/MultiplayerSession.gd").new()
	_b.name = "MultiplayerSession"  # same relative path as A so RPCs resolve
	_b.player_name = "GuestBot"
	holder.add_child(_b)

	_run()


func _run() -> void:
	print("LIVE: hosting...")
	var hosted: bool = _a.host_lobby()
	_check(hosted, "host_lobby accepted")
	var code: String = await _await_signal(_a.lobby_joined, _a.lobby_left)
	_check(code != "" and WebRtcSignaling.is_valid_code(code), "host got a 4-character code: %s" % code)
	_check(_a.is_host(), "A is host (peer id 1)")
	if code == "":
		_finish()
		return

	print("LIVE: joining ", code)
	_check(_b.join_lobby(code), "join_lobby accepted")
	var joined: String = await _await_signal(_b.lobby_joined, _b.lobby_left)
	_check(joined == code, "B joined the same lobby")
	_check(not _b.is_host(), "B is not host")
	if joined == "":
		_finish()
		return

	print("LIVE: waiting for the WebRTC data channels...")
	var ok := await _wait_until(func() -> bool: return _a.get_player_count() == 2 and _b.get_player_count() == 2)
	_check(ok, "both rosters show 2 players (WebRTC connected)")
	if ok:
		# The placeholder roster entry appears on peer_connected; the name
		# arrives a moment later with the player-state RPC.
		ok = await _wait_until(func() -> bool:
			return str(_a.get_player(_b.get_local_id()).get("name", "")) == "GuestBot" 				and str(_b.get_player(1).get("name", "")) == "HostBot")
		_check(ok, "names exchanged over RPC both ways")

	print("LIVE: waiting for clock sync...")
	ok = await _wait_until(func() -> bool: return _b.is_clock_synced())
	_check(ok, "B synced its clock (rtt %d ms, host time %d)" % [_b.get_clock_rtt_ms(), _b.get_host_time_ms()])

	_b.set_ready(true)
	_a.set_ready(true)
	ok = await _wait_until(func() -> bool: return _a.all_ready() and _b.all_ready())
	_check(ok, "ready state replicated both ways")

	_b.report_score(1234, 12, 0.95)
	ok = await _wait_until(func() -> bool: return int(_a.get_player(_b.get_local_id()).get("score", 0)) == 1234)
	_check(ok, "score replicated from B to A")

	var received: Array = []
	_b.song_start_requested.connect(func(song_key: String, difficulty: String, local_start: int) -> void:
		received.append([song_key, difficulty, local_start]))
	var started: bool = _a.start_song("res://song", "Expert")
	_check(started, "host start_song accepted")
	ok = await _wait_until(func() -> bool: return received.size() > 0)
	_check(ok, "B received song_start_requested")
	if ok:
		var lead: int = int(received[0][2]) - Time.get_ticks_msec()
		_check(lead > 1500 and lead <= 3000, "start lead time on B's clock: %d ms" % lead)

	_finish()


func _finish() -> void:
	_a.leave()
	_b.leave()
	await create_timer(0.5).timeout
	for failure: String in _failures:
		print("LIVE FAIL: " + failure)
	print("LIVE %s: %d checks failed" % ["FAILED" if _failures.size() > 0 else "OK", _failures.size()])
	quit(1 if _failures.size() > 0 else 0)


func _await_signal(success: Signal, failure: Signal) -> String:
	var result: Array = [""]
	var done: Array = [false]  # lambdas capture by value, so share an Array
	var on_success := func(code: String) -> void:
		result[0] = code
		done[0] = true
	var on_failure := func(reason: String) -> void:
		print("LIVE: failure signal: ", reason)
		done[0] = true
	success.connect(on_success)
	failure.connect(on_failure)
	var deadline := Time.get_ticks_msec() + int(STEP_TIMEOUT_SEC * 1000)
	while not done[0] and Time.get_ticks_msec() < deadline:
		await process_frame
	success.disconnect(on_success)
	failure.disconnect(on_failure)
	return result[0]


func _wait_until(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + int(STEP_TIMEOUT_SEC * 1000)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("LIVE PASS " + label)
	else:
		_failures.append(label)
