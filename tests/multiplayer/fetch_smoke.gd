extends SceneTree

# Live check of LobbyMapFetcher against the real BeatSaver API: looks up a
# known small map by id, builds a lobby song key from the answer, lets the
# fetcher download it into a throwaway Songs folder (never the user's), and
# verifies the installed folder's level hash equals the hash BeatSaver
# reported. Run with:
#   godot --headless --xr-mode off --path . -s tests/multiplayer/fetch_smoke.gd

const MAP_ID := "1"  # "succducc - me & u", ~330 notes, one difficulty
const TEMP_ROOT := "user://OpenSaber/temp/fetch_smoke/"
const TIMEOUT_SEC := 90.0

var _failures: Array[String] = []


func _initialize() -> void:
	await process_frame
	@warning_ignore("return_value_discarded")
	DirAccess.make_dir_recursive_absolute(TEMP_ROOT + "Songs/")

	var http := HTTPRequest.new()
	root.add_child(http)
	var error := http.request("https://api.beatsaver.com/maps/id/%s" % MAP_ID)
	_check(error == OK, "lookup request sent")
	var answer: Array = await http.request_completed
	_check(int(answer[1]) == 200, "BeatSaver answered 200 for map %s" % MAP_ID)
	var doc: Variant = JSON.parse_string((answer[3] as PackedByteArray).get_string_from_utf8())
	if not doc is Dictionary:
		_check(false, "BeatSaver answer parses")
		return _finish()
	# (Autoloads such as Utils are not available at this script's compile time.)
	var versions: Array = (doc as Dictionary).get("versions", []) as Array
	var expected_hash := str((versions[0] as Dictionary).get("hash", "")).to_upper() if versions.size() > 0 else ""
	_check(expected_hash.length() == 40, "map has a version hash: %s" % expected_hash)

	var key := JSON.stringify({
		"hash": expected_hash,
		"folder": "not-installed-anywhere",
		"name": str((doc as Dictionary).get("name", "")),
		"author": "",
		"beatsaver_id": MAP_ID,
	})
	print("FETCH: song key ", key)

	var fetcher: Node = load("res://game/multiplayer/LobbyMapFetcher.gd").new()
	fetcher.songs_dir = TEMP_ROOT + "Songs/"
	root.add_child(fetcher)
	var states: Array = []
	fetcher.state_changed.connect(func(state: int, detail: String) -> void:
		states.append(state)
		print("FETCH: state %d %s" % [state, detail]))
	var progress_seen: Array = [0.0]
	fetcher.progress.connect(func(fraction: float) -> void: progress_seen[0] = maxf(progress_seen[0], fraction))
	var outcome: Array = []
	fetcher.song_ready.connect(func(_k: String, map: RefCounted) -> void: outcome.append(map))
	fetcher.song_unavailable.connect(func(_k: String, reason: String) -> void: outcome.append(reason))

	fetcher.resolve(key)
	var deadline := Time.get_ticks_msec() + int(TIMEOUT_SEC * 1000)
	while outcome.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not outcome.is_empty(), "fetcher finished within %d s" % int(TIMEOUT_SEC))
	if outcome.is_empty():
		return _finish()
	_check(not outcome[0] is String, "song_ready fired (got %s)" % str(outcome[0]))
	_check(bool(fetcher.downloaded), "the map was downloaded, not found locally")
	_check(states.has(3) and states.has(4), "went through DOWNLOADING and EXTRACTING (%s)" % str(states))
	_check(progress_seen[0] > 0.0, "progress was reported (max %.2f)" % progress_seen[0])
	if not outcome[0] is String:
		# MapInfo is referenced dynamically: naming the class here would compile
		# it before the autoloads it depends on exist.
		var map: RefCounted = outcome[0]
		var map_info_script: GDScript = load("res://game/BeatmapInfo/MapInfo.gd")
		print("FETCH: installed at ", map.filepath, " song ", map.song_name)
		_check(str(map.filepath).begins_with(TEMP_ROOT), "installed inside the temp Songs folder")
		var actual: String = map_info_script.call("compute_level_hash", map.filepath)
		_check(actual == expected_hash, "level hash of the download (%s) equals BeatSaver's %s" % [actual, expected_hash])
		_check(map.level_hash() == actual, "MapInfo.level_hash() agrees and caches")
		# Second resolve must now find it locally without downloading.
		fetcher.resolve(key)
		var deadline2 := Time.get_ticks_msec() + 5000
		while outcome.size() < 2 and Time.get_ticks_msec() < deadline2:
			await process_frame
		_check(outcome.size() == 2 and not outcome[1] is String and not bool(fetcher.downloaded), "second resolve found the map locally")
	_finish()


func _finish() -> void:
	_remove_dir(TEMP_ROOT)
	_check(not DirAccess.dir_exists_absolute(TEMP_ROOT), "temp folder removed")
	for failure: String in _failures:
		print("FETCH FAIL: " + failure)
	print("FETCH %s: %d checks failed" % ["FAILED" if _failures.size() > 0 else "OK", _failures.size()])
	quit(1 if _failures.size() > 0 else 0)


func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_remove_dir(path.path_join(sub))
	for file: String in dir.get_files():
		@warning_ignore("return_value_discarded")
		dir.remove(file)
	@warning_ignore("return_value_discarded")
	DirAccess.remove_absolute(path)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("FETCH PASS " + label)
	else:
		_failures.append(label)
