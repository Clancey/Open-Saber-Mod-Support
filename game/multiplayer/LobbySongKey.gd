extends RefCounted
class_name LobbySongKey

# The lobby song key is a JSON object string so peers can identify the song
# without sharing a folder layout:
#   {"hash": "<40 hex, uppercase>", "folder": "<song folder name>",
#    "name": "<song name>", "author": "<song author>", "beatsaver_id": "<id or ''>"}
# Matching order: level hash, then folder name, then name + author. A plain
# (non JSON) string is treated as a folder name for backwards compatibility
# (the OPENSABER_TEST_MP_START debug hook passes one).

const FIELDS: Array[String] = ["hash", "folder", "name", "author", "beatsaver_id"]


static func make(map: MapInfo) -> String:
	var folder := folder_name(map)
	return JSON.stringify({
		"hash": map.level_hash(),
		"folder": folder,
		"name": map.song_name,
		"author": map.song_author_name,
		"beatsaver_id": beatsaver_id_from_folder(folder),
	})


static func folder_name(map: MapInfo) -> String:
	return map.filepath.trim_suffix("/").get_file()


static func parse(key: String) -> Dictionary:
	var result: Dictionary = {}
	for field: String in FIELDS:
		result[field] = ""
	var parsed: Variant = JSON.parse_string(key) if key.begins_with("{") else null
	if parsed is Dictionary:
		for field: String in FIELDS:
			result[field] = str((parsed as Dictionary).get(field, ""))
	else:
		result["folder"] = key
	result["hash"] = str(result["hash"]).to_upper()
	return result


static func display_name(key: String) -> String:
	var info := parse(key)
	var song_name := str(info["name"])
	if song_name.is_empty():
		return str(info["folder"])
	var author := str(info["author"])
	return "%s - %s" % [song_name, author] if not author.is_empty() else song_name


static func find_map(key: String, maps: Array[MapInfo]) -> MapInfo:
	var info := parse(key)
	var wanted_hash := str(info["hash"])
	if not wanted_hash.is_empty():
		for map: MapInfo in maps:
			if map.level_hash() == wanted_hash:
				return map
	var folder := str(info["folder"])
	if not folder.is_empty():
		for map: MapInfo in maps:
			if folder_name(map) == folder:
				return map
	var song_name := str(info["name"])
	if not song_name.is_empty():
		var author := str(info["author"])
		for map: MapInfo in maps:
			if map.song_name == song_name and map.song_author_name == author:
				return map
	return null


## "1a2b (Song - Mapper)" style folders (the Beat Saber convention) carry the
## BeatSaver id as the first token; returns "" for any other layout.
static func beatsaver_id_from_folder(folder: String) -> String:
	var regex := RegEx.new()
	if regex.compile("^([0-9a-fA-F]{1,8}) \\(") != OK:
		return ""
	var found := regex.search(folder)
	return found.get_string(1).to_lower() if found != null else ""
