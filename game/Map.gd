extends Node

class Difficulty:
	var difficulty: String
	var difficulty_rank: int
	var beatmap_filename: String
	var note_jump_movement_speed: float
	var note_jump_start_beat_offset: float
	var custom_data: Dictionary

class Info:
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

class ColorNoteInfo:
	var beat: float
	var line_index: int
	var line_layer: int
	var color: int # 0=left, 1=right
	var cut_direction: int

class BombInfo:
	var beat: float
	var line_index: int
	var line_layer: int

class ObstacleInfo:
	var beat: float
	var duration: float
	var line_index: int
	var line_layer: int
	var width: int
	var height: int

class EventInfo:
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

# mix all the difficulty sets into a single one
func mix_difficulty_sets(difficulty_beatmap_sets: Array) -> Array[Difficulty]:
	var newset: Array[Difficulty] = []
	for difficulty_set in difficulty_beatmap_sets:
		for difficulty: Dictionary in difficulty_set._difficultyBeatmaps:
			var custom_data: Dictionary = {}
			var diff := Difficulty.new()
			if difficulty.has("_difficulty"):
				diff.difficulty = difficulty._difficulty
			if difficulty.has("_difficultyRank"):
				diff.difficulty_rank = difficulty._difficultyRank
			if difficulty.has("_beatmapFilename"):
				diff.beatmap_filename = difficulty._beatmapFilename
			if difficulty.has("_noteJumpMovementSpeed"):
				diff.note_jump_movement_speed = difficulty._noteJumpMovementSpeed
			if difficulty.has("_noteJumpStartBeatOffset"):
				diff.note_jump_start_beat_offset = difficulty._noteJumpStartBeatOffset
			if difficulty.has("_customData"):
				diff.custom_data = difficulty._customData
			if difficulty_set._beatmapCharacteristicName != "Standard":
				if difficulty.has("_customData") and difficulty._customData.has("_difficultyLabel"):
					difficulty._customData._difficultyLabel = (
						str(difficulty_set._beatmapCharacteristicName)+" "+difficulty._customData._difficultyLabel)
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
	if info_dict.has("_version"):
		map.version = info_dict._version
	if info_dict.has("_songName"):
		map.song_name = info_dict._songName
	if info_dict.has("_songSubName"):
		map.song_sub_name = info_dict._songSubName
	if info_dict.has("_songAuthorName"):
		map.song_author_name = info_dict._songAuthorName
	if info_dict.has("_levelAuthorName"):
		map.level_author_name = info_dict._levelAuthorName
	if info_dict.has("_beatsPerMinute"):
		map.beats_per_minute = info_dict._beatsPerMinute
	# shuffle and shuffle period maybe in the future?
	if info_dict.has("_previewStartTime"):
		map.preview_start_time = info_dict._previewStartTime
	if info_dict.has("_previewDuration"):
		map.preview_duration = info_dict._previewDuration
	if info_dict.has("_songFilename"):
		map.song_filename = info_dict._songFilename
	if info_dict.has("_coverImageFilename"):
		map.cover_image_filename = info_dict._coverImageFilename
	if info_dict.has("_environmentName"):
		map.environment_name = info_dict._environmentName
	if info_dict.has("_songTimeOffset"):
		map.song_time_offset = info_dict._songTimeOffset
	if info_dict.has("_customData"):
		map.custom_data = info_dict._customData
	map.difficulty_beatmaps = mix_difficulty_sets(info_dict._difficultyBeatmapSets)
	
	return map

func load_note_info_v2(note_data: Array) -> void:
	note_stack.clear()
	bomb_stack.clear()
	while not note_data.is_empty():
		var note: Dictionary = note_data.pop_back()
		if not note.has("_type"):
			continue
		elif note._type == 3: # bombs are stored as note type 3 in v2
			var new_bomb := BombInfo.new()
			if note.has("_time"):
				new_bomb.beat = note._time
			if note.has("_lineIndex"):
				new_bomb.line_index = note._lineIndex
			if note.has("_lineLayer"):
				new_bomb.line_layer = note._lineLayer
			bomb_stack.append(new_bomb)
		else:
			var new_note := ColorNoteInfo.new()
			if note.has("_time"):
				new_note.beat = note._time
			if note.has("_lineIndex"):
				new_note.line_index = note._lineIndex
			if note.has("_lineLayer"):
				new_note.line_layer = note._lineLayer
			new_note.color = note._type
			if note.has("_cutDirection"):
				new_note.cut_direction = note._cutDirection
			note_stack.append(new_note)

func load_obstacle_info_v2(obstacle_data: Array) -> void:
	obstacle_stack.clear()
	while not obstacle_data.is_empty():
		var obstacle: Dictionary = obstacle_data.pop_back()
		var new_obstacle := ObstacleInfo.new()
		if obstacle.has("_time"):
			new_obstacle.beat = obstacle._time
		if obstacle.has("_duration"):
			new_obstacle.duration = obstacle._duration
		if obstacle.has("_lineIndex"):
			new_obstacle.line_index = obstacle._lineIndex
		if obstacle.has("_width"):
			new_obstacle.width = obstacle._width
		if obstacle.has("_type"):
			match obstacle._type as int:
				0: # full height
					new_obstacle.line_layer = 0
					new_obstacle.height = 5
				1: # crouch
					new_obstacle.line_layer = 2
					new_obstacle.height = 3
				2: # free
					if obstacle_data.has("_lineLayer"):
						new_obstacle.line_layer = obstacle._lineLayer
					if obstacle_data.has("_height"):
						new_obstacle.height = obstacle._height
		obstacle_stack.append(new_obstacle)

func load_event_info_v2(event_data: Array) -> void:
	event_stack.clear()
	while not event_data.is_empty():
		var event: Dictionary = event_data.pop_back()
		var new_event := EventInfo.new()
		if event.has("_time"):
			new_event.beat = event._time
		if event.has("_type"):
			new_event.type = event._type
		if event.has("_value"):
			new_event.value = event._value
		if event.has("_floatValue"):
			new_event.float_value = event._floatValue
		else:
			new_event.float_value = -1
		event_stack.append(new_event)
