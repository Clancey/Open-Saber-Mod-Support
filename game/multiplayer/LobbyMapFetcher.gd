extends Node
class_name LobbyMapFetcher

# Makes sure the lobby's selected song is installed locally. Given a lobby
# song key (see LobbySongKey) it looks in the loaded song list (or scans the
# Songs folder), and if the map is missing asks BeatSaver for it by level hash
# (falling back to the BeatSaver id), downloads the version whose hash matches,
# unpacks it with MapDownloader and refreshes the main menu's playlist.
#
# Set `main_menu` to the BeepSaberMainMenu node (get_all_songs() and
# _on_LoadPlaylists_Button_pressed() are used when present); without it the
# fetcher scans `songs_dir` itself, which also makes it usable headless.

signal state_changed(state: int, detail: String)
signal progress(fraction: float)
signal song_ready(song_key: String, map: MapInfo)
signal song_unavailable(song_key: String, reason: String)

enum State { IDLE, CHECKING, LOOKING_UP, DOWNLOADING, EXTRACTING, READY, UNAVAILABLE }

const API_BASE := "https://api.beatsaver.com"

var main_menu: Node
var songs_dir: String = Constants.APPDATA_PATH + "Songs/"
var state := State.IDLE
var song_key := ""
var last_reason := ""
var last_fraction := 0.0
## Whether the current READY result came from a download (for tests/logging).
var downloaded := false

var _info: Dictionary = {}
var _lookup_by_id := false
var _http: HTTPRequest
var _downloader: MapDownloader
var _generation := 0


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "HTTPLookup"
	_http.request_completed.connect(_on_lookup_completed)
	add_child(_http)
	_downloader = MapDownloader.new()
	_downloader.name = "Downloader"
	_downloader.songs_dir = songs_dir
	_downloader.progress.connect(_on_download_progress)
	_downloader.finished.connect(_on_download_finished)
	add_child(_downloader)


func is_ready() -> bool:
	return state == State.READY


## Checks (and if needed downloads) the song for `key`. Any previous fetch is
## abandoned. Emits song_ready or song_unavailable, state_changed on the way.
func resolve(key: String) -> void:
	_generation += 1
	_http.cancel_request()
	_downloader.cancel()
	song_key = key
	_info = LobbySongKey.parse(key)
	downloaded = false
	last_reason = ""
	last_fraction = 0.0
	_set_state(State.CHECKING)

	var local_map := LobbySongKey.find_map(key, _local_songs())
	if local_map != null:
		_finish_ready(local_map)
		return

	var level_hash := str(_info["hash"])
	var beatsaver_id := str(_info["beatsaver_id"])
	if level_hash.is_empty() and beatsaver_id.is_empty():
		_finish_unavailable("not_found", "the host's song has no BeatSaver hash")
		return
	_lookup_by_id = level_hash.is_empty()
	_request_lookup()


func _local_songs() -> Array[MapInfo]:
	if main_menu != null and main_menu.has_method("get_all_songs"):
		var songs: Variant = main_menu.call("get_all_songs")
		if songs is Array:
			var typed: Array[MapInfo] = []
			for entry: Variant in songs as Array:
				if entry is MapInfo:
					typed.append(entry as MapInfo)
			return typed
	var found: Array[MapInfo] = []
	var dir := DirAccess.open(songs_dir)
	if dir == null:
		return found
	for folder: String in dir.get_directories():
		var map := Map.load_map_info(songs_dir + folder + "/")
		if map != null:
			found.append(map)
	return found


func _request_lookup() -> void:
	_set_state(State.LOOKING_UP)
	var url: String
	if _lookup_by_id:
		url = "%s/maps/id/%s" % [API_BASE, str(_info["beatsaver_id"])]
	else:
		url = "%s/maps/hash/%s" % [API_BASE, str(_info["hash"]).to_lower()]
	var error := _http.request(url)
	if error != OK:
		_finish_unavailable("network", "lookup request failed: %s" % error_string(error))


func _on_lookup_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if state != State.LOOKING_UP:
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		_finish_unavailable("network", "could not reach BeatSaver (result %d)" % result)
		return
	if response_code == 404:
		if not _lookup_by_id and not str(_info["beatsaver_id"]).is_empty():
			_lookup_by_id = true
			_request_lookup()
			return
		_finish_unavailable("not_found", "not on BeatSaver")
		return
	if response_code != 200:
		_finish_unavailable("network", "BeatSaver answered http %d" % response_code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_finish_unavailable("network", "unreadable BeatSaver answer")
		return
	var doc := parsed as Dictionary
	var version := _pick_version(doc)
	var download_url := Utils.get_str(version, "downloadURL", "")
	if download_url.is_empty():
		_finish_unavailable("not_found", "no downloadable version on BeatSaver")
		return
	# Keep the hash BeatSaver reports so the download can be verified.
	var version_hash := Utils.get_str(version, "hash", "").to_upper()
	if str(_info["hash"]).is_empty() and not version_hash.is_empty():
		_info["hash"] = version_hash
	if str(_info["name"]).is_empty():
		_info["name"] = Utils.get_str(doc, "name", "")
	var folder := _target_folder(doc)
	_set_state(State.DOWNLOADING, folder)
	var error := _downloader.download(download_url, folder)
	if error != OK:
		_finish_unavailable("network", "download request failed: %s" % error_string(error))


func _pick_version(doc: Dictionary) -> Dictionary:
	var versions: Array = Utils.get_array(doc, "versions", [])
	var wanted := str(_info["hash"]).to_upper()
	var first_published: Dictionary = {}
	for value: Variant in versions:
		if not value is Dictionary:
			continue
		var version := value as Dictionary
		if not wanted.is_empty() and Utils.get_str(version, "hash", "").to_upper() == wanted:
			return version
		if first_published.is_empty() and Utils.get_str(version, "state", "") == "Published":
			first_published = version
	if not first_published.is_empty():
		return first_published
	for value: Variant in versions:
		if value is Dictionary:
			return value as Dictionary
	return {}


## Same folder naming as the BeatSaver panel (the map name), with the BeatSaver
## id appended when that folder already holds a different map.
func _target_folder(doc: Dictionary) -> String:
	var base := MapDownloader.sanitize_dir_name(Utils.get_str(doc, "name", str(_info["name"])))
	if base.is_empty() or base == "map":
		base = MapDownloader.sanitize_dir_name(str(_info["folder"]))
	if DirAccess.dir_exists_absolute(songs_dir + base):
		base = "%s (%s)" % [base, Utils.get_str(doc, "id", "dl")]
	return base


func _on_download_progress(downloaded_bytes: int, total_bytes: int) -> void:
	if state != State.DOWNLOADING:
		return
	last_fraction = clampf(float(downloaded_bytes) / float(total_bytes), 0.0, 1.0) if total_bytes > 0 else 0.0
	progress.emit(last_fraction)


func _on_download_finished(ok: bool, out_dir: String, error: String) -> void:
	if state != State.DOWNLOADING:
		return
	if not ok:
		_finish_unavailable("network", error)
		return
	_set_state(State.EXTRACTING)
	var expected := str(_info["hash"])
	var actual := MapInfo.compute_level_hash(out_dir)
	if not expected.is_empty() and actual != expected:
		push_warning("[LobbyMapFetcher] hash of %s is %s, BeatSaver said %s" % [out_dir, actual, expected])
	downloaded = true
	var generation := _generation
	if main_menu != null and main_menu.has_method("_on_LoadPlaylists_Button_pressed"):
		main_menu.call("_on_LoadPlaylists_Button_pressed")
	if generation != _generation:
		return
	var map := LobbySongKey.find_map(song_key, _local_songs())
	if map == null:
		map = Map.load_map_info(out_dir)
	if map == null:
		_finish_unavailable("network", "downloaded map could not be loaded")
		return
	_finish_ready(map)


func _finish_ready(map: MapInfo) -> void:
	last_fraction = 1.0
	_set_state(State.READY)
	song_ready.emit(song_key, map)


func _finish_unavailable(reason: String, detail: String) -> void:
	last_reason = reason
	_set_state(State.UNAVAILABLE, detail)
	push_warning("[LobbyMapFetcher] %s: %s" % [reason, detail])
	song_unavailable.emit(song_key, reason)


func _set_state(new_state: State, detail: String = "") -> void:
	state = new_state
	state_changed.emit(new_state, detail)
