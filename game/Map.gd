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

var current_info: Info

var notes: Array
var obstacles: Array
var events: Array

var current_note: int
var current_obstacle: int
var current_event: int

# mix all the difficulty sets into a single one
func mix_difficulty_sets(difficulty_beatmap_sets: Array) -> Array[Difficulty]:
	var newset: Array[Difficulty]
	for difficulty_set in difficulty_beatmap_sets:
		for difficulty in difficulty_set._difficultyBeatmaps:
			var custom_data: Dictionary
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
