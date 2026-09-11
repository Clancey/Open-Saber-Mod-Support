extends SceneTree

# Headless smoke test for the multiplayer foundation: builds every node without
# touching the network and reports. Run with:
#   godot --headless --xr-mode off --path . -s tests/multiplayer/smoke.gd
# Any "SCRIPT ERROR" in the output is a failure.

var _failures: Array[String] = []


func _initialize() -> void:
	# The root only enters the tree after _initialize returns, so wait a frame
	# for the autoloads' _ready (and every @onready) to have run.
	await process_frame
	# The autoload is present because the project is loaded with --path, but a
	# -s main script compiles before autoload globals exist, so look it up.
	_check(root.has_node("MultiplayerSession"), "MultiplayerSession autoload registered")
	var session: Node = root.get_node("MultiplayerSession")
	_check(not session.is_online(), "Session starts offline")
	_check(session.get_players().is_empty(), "Roster starts empty")
	_check(session.start_song("x", "y") == false, "start_song refused when offline")
	_check(session.join_lobby("bad code") == false, "Invalid code rejected")

	# A second, detached instance of the session script must construct cleanly.
	var extra_session: Node = load("res://game/multiplayer/MultiplayerSession.gd").new()
	extra_session.name = "DetachedSession"
	root.add_child(extra_session)
	_check(extra_session.get_host_time_ms() >= 0, "Detached session ticks")

	# Scripts that reference autoloads (Settings, MultiplayerSession) must not be
	# named statically here: this main script compiles before autoloads exist.
	var panel: Node = (load("res://game/multiplayer/LobbyPanel.tscn") as PackedScene).instantiate()
	root.add_child(panel)
	_check(panel.get_script() != null and panel.has_method("refresh"), "LobbyPanel script compiled")
	_check(panel.get_entered_code() == "AAAA", "Code entry defaults to AAAA")
	panel.set_entered_code("ZX42")
	_check(panel.get_entered_code() == "ZX42", "Code entry accepts a code")
	panel.set_selected_song("res://song", "Expert", "Song - Author")
	panel.refresh()

	var avatars: Node3D = load("res://game/multiplayer/MultiplayerAvatars.gd").new()
	avatars.name = "MultiplayerAvatars"
	root.add_child(avatars)
	var roster: Array[Dictionary] = [
		{"id": 1, "name": "Host"},
		{"id": 4242, "name": "Guest"},
		{"id": 99, "name": "Other"},
	]
	avatars.apply_roster(roster, 99)
	_check(avatars.get_avatar_count() == 3, "One avatar per player")
	var host_avatar: Node3D = avatars.get_avatar(1)
	var me: Node3D = avatars.get_avatar(99)
	var guest: Node3D = avatars.get_avatar(4242)
	_check(host_avatar != null and me != null and guest != null, "Avatars spawned")
	if host_avatar and me and guest:
		_check(host_avatar.get_multiplayer_authority() == 1, "Host avatar authority")
		_check(guest.get_multiplayer_authority() == 4242, "Guest avatar authority")
		_check(me.position.x == 0.0, "Local player sits at the origin")
		_check(is_equal_approx(host_avatar.position.x, -1.2), "Host (lower id) is one slot to the left")
		_check(is_equal_approx(guest.position.x, 1.2), "Guest (higher id) is one slot to the right")
		_check(not me.visible and host_avatar.visible, "Local avatar hidden, remote visible")
		me.set_pose(Transform3D(Basis(), Vector3(0, 1.6, 0.2)), Transform3D(), Transform3D())
		_check(me.head.position.is_equal_approx(Vector3(0, 1.6, 0.2)), "set_pose writes the head")
	var remaining: Array[Dictionary] = [roster[2]]
	avatars.apply_roster(remaining, 99)
	_check(avatars.get_avatar_count() == 1, "Avatars removed when players leave")

	var broadcaster: Node = load("res://game/multiplayer/LocalPlayerBroadcaster.gd").new()
	broadcaster.avatars_path = avatars.get_path()
	root.add_child(broadcaster)
	_check(broadcaster.has_method("bind_sources"), "LocalPlayerBroadcaster script compiled")

	var client: Node = load("res://game/multiplayer/WebRtcClient.gd").new()
	root.add_child(client)
	_check(client.rtc_mp != null, "WebRTC multiplayer peer constructed (extension loaded)")
	var connection := WebRTCPeerConnection.new()
	_check(connection.initialize({}) == OK, "WebRTCPeerConnection initializes (native extension present)")

	await create_timer(0.2).timeout
	for failure: String in _failures:
		print("SMOKE FAIL: " + failure)
	print("SMOKE %s: %d checks failed" % ["FAILED" if _failures.size() > 0 else "OK", _failures.size()])
	quit(1 if _failures.size() > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("SMOKE PASS " + label)
	else:
		_failures.append(label)
