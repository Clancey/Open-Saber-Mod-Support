extends Node

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

# type safety, just in case a wrongly-made beatmap comes through
func get_str(dict: Dictionary, key: String, default: String) -> String:
		if dict.has(key) and dict[key] is String:
			return dict.get(key, default) as String
		return default

func get_float(dict: Dictionary, key: String, default: float) -> float:
	if dict.has(key) and dict[key] is float:
		return dict.get(key, default) as float
	return default

# no get_int because godot dictionaries made from json only have floats

# mix all the difficulty sets into a single one
func mix_difficulty_sets(difficulty_beatmap_sets: Array) -> Array[Difficulty]:
	var newset: Array[Difficulty] = []
	for difficulty_set in difficulty_beatmap_sets:
		for diff_dict: Dictionary in difficulty_set._difficultyBeatmaps:
			var custom_data: Dictionary = {}
			var diff := Difficulty.new()
			diff.difficulty = get_str(diff_dict, "_difficulty", "")
			diff.difficulty_rank = int(get_float(diff_dict, "_difficultyRank", 0))
			diff.beatmap_filename = get_str(diff_dict, "_beatmapFilename", "")
			diff.note_jump_movement_speed = get_float(diff_dict, "_noteJumpMovementSpeed", 1.0)
			diff.note_jump_start_beat_offset = get_float(diff_dict, "_noteJumpStartBeatOffset", 0.0)
			diff.custom_data = diff_dict.get("_customData", {})
			newset.append(diff)
	return newset

func load_info_from_folder(load_path: String) -> Info:
	var info_dict := vr.load_json_file(load_path + "Info.dat")
	if (info_dict == {}):
		info_dict = vr.load_json_file(load_path + "info.dat")
		#because android is case sensitive and some maps have it lowercase, some not
		if (info_dict == {}):
			vr.log_error("Invalid info.dat found in " + load_path)
			return null
		
	if (info_dict._difficultyBeatmapSets.size() == 0):
		vr.log_error("No _difficultyBeatmapSets in info.dat")
		return null
	
	var map := Info.new()
	map.filepath = load_path
	map.version = get_str(info_dict, "_version", "v2.0.0")
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
	map.custom_data = info_dict.get("_customData", {})
	map.difficulty_beatmaps = mix_difficulty_sets(info_dict._difficultyBeatmapSets)
	
	return map

func load_note_info_v2(note_data: Array) -> void:
	note_stack.clear()
	bomb_stack.clear()
	while not note_data.is_empty():
		var note: Dictionary = note_data.pop_back()
		var note_type := int(get_float(note, "_type", -1.0))
		if note_type == -1:
			continue
		elif note_type == 3: # bombs are stored as note type 3 in v2
			var new_bomb := BombInfo.new()
			new_bomb.beat = get_float(note, "_time", 0.0)
			new_bomb.line_index = int(get_float(note, "_lineIndex", 0))
			new_bomb.line_layer = int(get_float(note, "_lineLayer", 0))
			bomb_stack.append(new_bomb)
		else:
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
		var obstacle: Dictionary = obstacle_data.pop_back()
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
		var event: Dictionary = event_data.pop_back()
		var new_event := EventInfo.new()
		new_event.beat = get_float(event, "_time", 0.0)
		new_event.type = int(get_float(event, "_type", 0))
		new_event.value = int(get_float(event, "_value", 0))
		new_event.float_value = get_float(event, "_floatValue", -1.0)
		event_stack.append(new_event)
