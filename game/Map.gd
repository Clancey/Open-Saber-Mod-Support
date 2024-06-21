extends Node

# this would have basically been impossible to figure out without constantly
# referencing the beat saber modding group wiki.
# https://bsmg.wiki/mapping/map-format.html

class Difficulty extends RefCounted:
	var difficulty: String
	var difficulty_rank: int
	var beatmap_filename: String
	var note_jump_movement_speed: float
	var note_jump_start_beat_offset: float
	var custom_data: Dictionary

class Info extends RefCounted:
	var version: String
	var song_name: String
	var song_sub_name: String
	var song_author_name: String
	var level_author_name: String
	var beats_per_minute: float
	#var shuffle: float
	#var shuffle_period: float
	var preview_start_time: float
	var preview_duration: float
	var song_filename: String
	var cover_image_filename: String
	var environment_name: String
	var song_time_offset: float
	var custom_data: Dictionary
	
	var filepath: String
	var difficulty_beatmaps: Array[Difficulty]
	
	func is_empty() -> bool:
		return (
			song_name.is_empty()
			and song_author_name.is_empty()
			and song_sub_name.is_empty()
			and level_author_name.is_empty()
		)
	
	func get_key() -> String:
		return "[%s,%s,%s,%s]" % [
			song_author_name,
			song_name,
			song_sub_name,
			level_author_name
		]

class ColorNoteInfo extends RefCounted:
	var beat: float
	var line_index: int
	var line_layer: int
	var color: int # 0=left, 1=right
	var cut_direction: int

class BombInfo extends RefCounted:
	var beat: float
	var line_index: int
	var line_layer: int

class ObstacleInfo extends RefCounted:
	var beat: float
	var duration: float
	var line_index: int
	var line_layer: int
	var width: int
	var height: int

class EventInfo extends RefCounted:
	var beat: float
	var type: int
	var value: int
	var float_value: float

var current_info: Info
var current_difficulty: Difficulty
var current_difficulty_index: int

var note_stack: Array[ColorNoteInfo]
var bomb_stack: Array[BombInfo]
var obstacle_stack: Array[ObstacleInfo]
var event_stack: Array[EventInfo]

var color_left: Color
var color_right: Color

# type safety, just in case a wrongly-made beatmap comes through
func get_str(dict: Dictionary, key: String, default: String) -> String:
		if dict.has(key) and dict[key] is String:
			return dict[key] as String
		return default

func get_float(dict: Dictionary, key: String, default: float) -> float:
	if dict.has(key) and dict[key] is float:
		return dict[key] as float
	return default

func get_array(dict: Dictionary, key: String, default: Array) -> Array:
	if dict.has(key) and dict[key] is Array:
		return dict[key] as Array
	return default

func get_dict(dict: Dictionary, key: String, default: Dictionary) -> Dictionary:
	if dict.has(key) and dict[key] is Dictionary:
		return dict[key] as Dictionary
	return default

# no get_int because godot dictionaries made from json only have floats

func set_colors_from_custom_data(info_data: Dictionary, diff_data: Dictionary, default_left: Color, default_right: Color) -> void:
	var set_colors := func(data: Dictionary, color_name: String) -> void:
		var left_name := color_name % "Left"
		var right_name := color_name % "Right"
		if (
			data.has(left_name) and data.has(right_name)
			and data[left_name] is Dictionary and data[right_name] is Dictionary
		):
			var left := data[left_name] as Dictionary
			var right := data[right_name] as Dictionary
			color_left = Color(
				get_float(left, "r", default_left.r),
				get_float(left, "g", default_left.g),
				get_float(left, "b", default_left.b)
			)
			color_right = Color(
				get_float(right, "r", default_right.r),
				get_float(right, "g", default_right.g),
				get_float(right, "b", default_right.b)
			)
	set_colors.call(info_data, "_envColor%sBoost")
	set_colors.call(diff_data, "_envColor%sBoost")
	set_colors.call(info_data, "_envColor%s")
	set_colors.call(diff_data, "_envColor%s")
	set_colors.call(info_data, "_color%s")
	set_colors.call(diff_data, "_color%s")

# mix all the difficulty sets into a single one
func mix_difficulty_sets_v2(difficulty_beatmap_sets: Array) -> Array[Difficulty]:
	var newset: Array[Difficulty] = []
	for difficulty_set in difficulty_beatmap_sets:
		if not difficulty_set is Dictionary: continue
		var beatmaps := get_array(difficulty_set as Dictionary, "_difficultyBeatmaps", [])
		for i in beatmaps:
			if not i is Dictionary: continue
			var diff_dict := i as Dictionary
			var diff := Difficulty.new()
			diff.difficulty = get_str(diff_dict, "_difficulty", "")
			diff.difficulty_rank = int(get_float(diff_dict, "_difficultyRank", 0))
			diff.beatmap_filename = get_str(diff_dict, "_beatmapFilename", "")
			diff.note_jump_movement_speed = get_float(diff_dict, "_noteJumpMovementSpeed", 1.0)
			diff.note_jump_start_beat_offset = get_float(diff_dict, "_noteJumpStartBeatOffset", 0.0)
			diff.custom_data = get_dict(diff_dict, "_customData", {})
			newset.append(diff)
	return newset

func load_map_info_v2(load_path: String) -> Info:
	var info_dict := {}
	if FileAccess.file_exists(load_path + "Info.dat"):
		info_dict = vr.load_json_file(load_path + "Info.dat")
	elif FileAccess.file_exists(load_path + "info.dat"):
		info_dict = vr.load_json_file(load_path + "info.dat")
	if (info_dict.is_empty()):
		vr.log_error("Invalid info.dat found in " + load_path)
		return null
	
	var beatmap_sets := get_array(info_dict, "_difficultyBeatmapSets", [])
	if (beatmap_sets.is_empty()):
		vr.log_error("No _difficultyBeatmapSets in info.dat")
		return null
	
	var map := Info.new()
	map.filepath = load_path
	map.version = get_str(info_dict, "_version", "2.0.0")
	map.song_name = get_str(info_dict, "_songName", "")
	map.song_sub_name = get_str(info_dict, "_songSubName", "")
	map.song_author_name = get_str(info_dict, "_songAuthorName", "")
	map.level_author_name = get_str(info_dict, "_levelAuthorName", "")
	map.beats_per_minute = get_float(info_dict, "_beatsPerMinute", 60.0)
	# shuffle and shuffle period maybe in the future?
	map.preview_start_time = get_float(info_dict, "_previewStartTime", 0.0)
	map.preview_duration = get_float(info_dict, "_previewDuration", 0.0)
	map.song_filename = get_str(info_dict, "_songFilename", "")
	map.cover_image_filename = get_str(info_dict, "_coverImageFilename", "")
	map.environment_name = get_str(info_dict, "_environmentName", "")
	map.song_time_offset = get_float(info_dict, "_songTimeOffset", 0.0)
	map.custom_data = get_dict(info_dict, "_customData", {})
	map.difficulty_beatmaps = mix_difficulty_sets_v2(beatmap_sets)
	
	return map

func load_note_info_v2(note_data: Array) -> void:
	note_stack.clear()
	bomb_stack.clear()
	while not note_data.is_empty():
		var i: Variant = note_data.pop_back()
		if not i is Dictionary: continue
		var note := i as Dictionary
		
		var note_type := int(get_float(note, "_type", -1.0))
		if note_type == 3: # bombs are stored as note type 3 in v2
			var new_bomb := BombInfo.new()
			new_bomb.beat = get_float(note, "_time", 0.0)
			new_bomb.line_index = int(get_float(note, "_lineIndex", 0))
			new_bomb.line_layer = int(get_float(note, "_lineLayer", 0))
			bomb_stack.append(new_bomb)
		elif note_type == 0 or note_type == 1:
			var new_note := ColorNoteInfo.new()
			new_note.beat = get_float(note, "_time", 0.0)
			new_note.line_index = int(get_float(note, "_lineIndex", 0))
			new_note.line_layer = int(get_float(note, "_lineLayer", 0))
			new_note.color = note_type
			new_note.cut_direction = int(get_float(note, "_cutDirection", 0))
			note_stack.append(new_note)

func load_obstacle_info_v2(obstacle_data: Array) -> void:
	obstacle_stack.clear()
	while not obstacle_data.is_empty():
		var i: Variant = obstacle_data.pop_back()
		if not i is Dictionary: continue
		var obstacle := i as Dictionary
		
		var new_obstacle := ObstacleInfo.new()
		new_obstacle.beat = get_float(obstacle, "_time", 0.0)
		new_obstacle.duration = get_float(obstacle, "_duration", 0.0)
		new_obstacle.line_index = int(get_float(obstacle, "_lineIndex", 0))
		new_obstacle.width = int(get_float(obstacle, "_width", 0))
		var type := int(get_float(obstacle, "_type", 0))
		match type:
			0: # full height
				new_obstacle.line_layer = 0
				new_obstacle.height = 5
			1: # crouch
				new_obstacle.line_layer = 2
				new_obstacle.height = 3
			2: # free
				new_obstacle.line_layer = int(get_float(obstacle, "_lineLayer", 0))
				new_obstacle.height = int(get_float(obstacle, "_height", 0))
		obstacle_stack.append(new_obstacle)

func load_event_info_v2(event_data: Array) -> void:
	event_stack.clear()
	while not event_data.is_empty():
		var i: Variant = event_data.pop_back()
		if not i is Dictionary: continue
		var event := i as Dictionary
		
		var new_event := EventInfo.new()
		new_event.beat = get_float(event, "_time", 0.0)
		new_event.type = int(get_float(event, "_type", 0))
		new_event.value = int(get_float(event, "_value", 0))
		new_event.float_value = get_float(event, "_floatValue", -1.0)
		event_stack.append(new_event)

func load_beatmap_v2(map_data: Dictionary) -> void:
	load_note_info_v2(get_array(map_data, "_notes", []))
	load_obstacle_info_v2(get_array(map_data, "_obstacles", []))
	load_event_info_v2(get_array(map_data, "_events", []))
