extends RefCounted
class_name DifficultyInfo

var difficulty: String
var difficulty_rank: int
var beatmap_filename: String
var note_jump_movement_speed: float
var note_jump_start_beat_offset: float
var custom_data: Dictionary
# not officially part of the spec, but used by mods a lot
var custom_name: String
var characteristic: String = ""
var lightshow_filename: String = ""
var beatmap_authors: Array[String] = []
var lightshow_authors: Array[String] = []
var environment_name_index: int = 0
var color_scheme_index: int = 0

func _init(
	difficulty: String, difficulty_rank: int, beatmap_filename: String,
	note_jump_movement_speed: float, note_jump_start_beat_offset: float,
	custom_data: Dictionary, custom_name: String
) -> void:
	self.difficulty = difficulty
	self.difficulty_rank = difficulty_rank
	self.beatmap_filename = beatmap_filename
	self.note_jump_movement_speed = note_jump_movement_speed
	self.note_jump_start_beat_offset = note_jump_start_beat_offset
	self.custom_data = custom_data
	# not officially part of the spec, but used by mods a lot
	self.custom_name = custom_name

static func load_v2(diff_dict: Dictionary) -> DifficultyInfo:
	var diff := Utils.get_str(diff_dict, "_difficulty", "")
	var data := Utils.get_dict(diff_dict, "_customData", {})
	
	var name := ""
	# not officially part of the spec, but used by mods a lot
	if not data.is_empty():
		name = Utils.get_str(data, "_difficultyLabel", "")
	if name.is_empty():
		name = diff
	
	return DifficultyInfo.new(
		diff,
		int(Utils.get_float(diff_dict, "_difficultyRank", 0)),
		Utils.get_str(diff_dict, "_beatmapFilename", ""),
		Utils.get_float(diff_dict, "_noteJumpMovementSpeed", 1.0),
		Utils.get_float(diff_dict, "_noteJumpStartBeatOffset", 0.0),
		data,
		name
	)

static func load_v4(diff_dict: Dictionary) -> DifficultyInfo:
	var difficulty: String = Utils.get_str(diff_dict, "difficulty", "")
	var data: Dictionary = Utils.get_dict(diff_dict, "customData", {})
	var custom_name: String = Utils.get_str(data, "difficultyLabel", difficulty)
	var result: DifficultyInfo = DifficultyInfo.new(
		difficulty,
		_difficulty_rank(difficulty),
		Utils.get_str(diff_dict, "beatmapDataFilename", ""),
		Utils.get_float(diff_dict, "noteJumpMovementSpeed", 1.0),
		Utils.get_float(diff_dict, "noteJumpStartBeatOffset", 0.0),
		data,
		custom_name
	)
	result.characteristic = Utils.get_str(diff_dict, "characteristic", "")
	result.lightshow_filename = Utils.get_str(diff_dict, "lightshowDataFilename", "")
	result.environment_name_index = int(Utils.get_float(diff_dict, "environmentNameIdx", 0.0))
	result.color_scheme_index = int(Utils.get_float(diff_dict, "beatmapColorSchemeIdx", 0.0))

	var authors: Dictionary = Utils.get_dict(diff_dict, "beatmapAuthors", {})
	result.beatmap_authors = _string_array(Utils.get_array(authors, "mappers", []))
	result.lightshow_authors = _string_array(Utils.get_array(authors, "lighters", []))
	return result

static func _difficulty_rank(difficulty: String) -> int:
	match difficulty.to_lower():
		"easy":
			return 1
		"normal":
			return 3
		"hard":
			return 5
		"expert":
			return 7
		"expertplus", "expert+":
			return 9
		_:
			return 0

static func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		if value is String:
			result.append(value as String)
	return result
