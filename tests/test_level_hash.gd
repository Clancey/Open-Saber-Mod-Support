extends "res://tests/test_case.gd"

# Reference hashes computed independently in Python:
#   sha1(Info.dat bytes + each listed beatmap file's bytes, in Info.dat order)
const V2_FOLDER := "res://game/data/maps/Songs/Jaroslav Beck - Beat Saber (Built in)/"
const V2_HASH := "B68BF61AC6BE0E128BE32A85810D42E7C53F4756"
const V4_FOLDER := "res://tests/fixtures/v4/"
const V4_HASH := "090170338162871A46040FC7FB9DF4C4452DFC97"


func test_v2_level_hash_matches_reference() -> void:
	var info: Dictionary = vr.load_json_file(V2_FOLDER + "Info.dat")
	var files := MapInfo.hashed_beatmap_files(info)
	assert_eq(files.size(), 12, "Every difficulty of every characteristic takes part")
	assert_eq(files[0], "Easy.dat", "Info.dat order is kept")
	assert_eq(files[11], "90DegreeEasy.dat", "Info.dat order is kept")
	assert_eq(MapInfo.compute_level_hash(V2_FOLDER), V2_HASH, "v2 level hash")
	assert_eq(MapInfo.compute_level_hash(V2_FOLDER.trim_suffix("/")), V2_HASH, "Trailing slash is optional")


func test_v4_level_hash_uses_beatmap_and_lightshow_files() -> void:
	var info: Dictionary = vr.load_json_file(V4_FOLDER + "Info.dat")
	var files := MapInfo.hashed_beatmap_files(info)
	assert_eq(files, ["ExpertStandard.beatmap.dat", "Lightshow.dat"] as Array[String], "v4 file list")
	assert_eq(MapInfo.compute_level_hash(V4_FOLDER), V4_HASH, "v4 level hash")


func test_level_hash_is_cached_on_map_info_and_empty_when_missing() -> void:
	var map := Map.load_map_info(V2_FOLDER)
	assert_true(map != null, "Shipped map loads")
	assert_eq(map.level_hash(), V2_HASH, "MapInfo.level_hash()")
	map._level_hash = "CACHED"
	assert_eq(map.level_hash(), "CACHED", "Second call returns the cached value")
	assert_eq(MapInfo.compute_level_hash("res://tests/fixtures/does-not-exist/"), "", "Missing folder")


func test_song_key_format_and_matching() -> void:
	var map := Map.load_map_info(V2_FOLDER)
	var key := LobbySongKey.make(map)
	assert_true(key.begins_with("{"), "Key is a JSON object")
	var parsed := LobbySongKey.parse(key)
	assert_eq(parsed["hash"], V2_HASH, "hash field")
	assert_eq(parsed["folder"], "Jaroslav Beck - Beat Saber (Built in)", "folder field")
	assert_eq(parsed["name"], "Beat Saber", "name field")
	assert_eq(parsed["author"], "Jaroslav Beck", "author field")
	assert_eq(parsed["beatsaver_id"], "", "no BeatSaver id in a built-in folder name")
	assert_eq(LobbySongKey.display_name(key), "Beat Saber - Jaroslav Beck", "display name")

	var other := Map.load_map_info("res://game/data/maps/Songs/Jaroslav Beck - Magic (Built in)/")
	var maps: Array[String] = []
	var infos: Array[MapInfo] = [other, map]
	assert_true(LobbySongKey.find_map(key, infos) == map, "Found by hash")

	var by_folder := JSON.stringify({"hash": "0000", "folder": "Jaroslav Beck - Magic (Built in)", "name": "", "author": ""})
	assert_true(LobbySongKey.find_map(by_folder, infos) == other, "Unknown hash falls back to the folder name")
	var by_name := JSON.stringify({"hash": "", "folder": "elsewhere", "name": "Magic", "author": "Jaroslav Beck"})
	assert_true(LobbySongKey.find_map(by_name, infos) == other, "Falls back to name + author")
	assert_true(LobbySongKey.find_map("Jaroslav Beck - Beat Saber (Built in)", infos) == map, "Plain folder string still works")
	assert_true(LobbySongKey.find_map(JSON.stringify({"hash": "", "folder": "", "name": "Nope", "author": ""}), infos) == null, "No match")
	assert_eq(maps.size(), 0)


func test_beatsaver_id_from_folder() -> void:
	assert_eq(LobbySongKey.beatsaver_id_from_folder("1a2b3 (Song - Mapper)"), "1a2b3", "Beat Saber folder convention")
	assert_eq(LobbySongKey.beatsaver_id_from_folder("25F (Reality Check)"), "25f", "Lower-cased")
	assert_eq(LobbySongKey.beatsaver_id_from_folder("Jaroslav Beck - Magic (Built in)"), "", "Not an id")
	assert_eq(LobbySongKey.beatsaver_id_from_folder("Timelapse"), "", "Plain name")
