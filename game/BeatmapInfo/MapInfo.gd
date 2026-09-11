extends RefCounted
class_name MapInfo

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
var song_duration: float = 0.0
var audio_data_filename: String = ""
var environment_names: Array[String] = []
var color_schemes: Array[Dictionary] = []
var difficulty_beatmap_sets: Dictionary = {}

var filepath: String
var difficulty_beatmaps: Array[DifficultyInfo]

@warning_ignore("shadowed_variable")
func _init(
	version: String, song_name: String, song_sub_name: String,
	song_author_name: String, level_author_name: String, beats_per_minute: float,
	preview_start_time: float, preview_duration: float, song_filename: String,
	cover_image_filename: String, environment_name: String,
	song_time_offset: float, custom_data: Dictionary, filepath: String,
	difficulty_beatmaps: Array[DifficultyInfo]
) -> void:
	self.version = version
	self.song_name = song_name
	self.song_sub_name = song_sub_name
	self.song_author_name = song_author_name
	self.level_author_name = level_author_name
	self.beats_per_minute = beats_per_minute
	# shuffle and shuffle period maybe in the future?
	self.preview_start_time = preview_start_time
	self.preview_duration = preview_duration
	self.song_filename = song_filename
	self.cover_image_filename = cover_image_filename
	self.environment_name = environment_name
	self.song_time_offset = song_time_offset
	self.custom_data = custom_data
	self.filepath = filepath
	self.difficulty_beatmaps = difficulty_beatmaps

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

var _level_hash := ""

## Beat Saber level hash (SHA1 hex, uppercase), the id BeatSaver indexes maps by.
## Computed once per MapInfo from the files in `filepath`.
func level_hash() -> String:
	if _level_hash.is_empty():
		_level_hash = compute_level_hash(filepath)
	return _level_hash

## SHA1 (uppercase hex) of the raw bytes of Info.dat followed by the raw bytes
## of every difficulty beatmap file in the order Info.dat lists them (v2/v3).
## v4 maps list a beatmap and a lightshow file per difficulty; both are hashed,
## each file once, in listed order. Returns "" if a file is missing.
static func compute_level_hash(folder: String) -> String:
	var dir: String = folder if folder.ends_with("/") else folder + "/"
	var info_name: String = Map.find_file_case_insensitive(dir, "info.dat")
	if info_name.is_empty():
		return ""
	var info_bytes: PackedByteArray = FileAccess.get_file_as_bytes(dir + info_name)
	if info_bytes.is_empty():
		return ""
	var parsed: Variant = JSON.parse_string(info_bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA1) != OK:
		return ""
	@warning_ignore("return_value_discarded")
	context.update(info_bytes)
	for filename: String in hashed_beatmap_files(parsed as Dictionary):
		var actual: String = filename
		if not FileAccess.file_exists(dir + actual):
			actual = Map.find_file_case_insensitive(dir, filename)
			if actual.is_empty():
				return ""
		@warning_ignore("return_value_discarded")
		context.update(FileAccess.get_file_as_bytes(dir + actual))
	return context.finish().hex_encode().to_upper()

## The beatmap files that take part in the level hash, in Info.dat order.
static func hashed_beatmap_files(info_dict: Dictionary) -> Array[String]:
	var files: Array[String] = []
	if info_dict.has("_difficultyBeatmapSets"):
		for set_value: Variant in Utils.get_array(info_dict, "_difficultyBeatmapSets", []):
			if not set_value is Dictionary:
				continue
			for diff_value: Variant in Utils.get_array(set_value as Dictionary, "_difficultyBeatmaps", []):
				if diff_value is Dictionary:
					var filename: String = Utils.get_str(diff_value as Dictionary, "_beatmapFilename", "")
					if not filename.is_empty():
						files.append(filename)
	else:
		for diff_value: Variant in Utils.get_array(info_dict, "difficultyBeatmaps", []):
			if not diff_value is Dictionary:
				continue
			for key: String in ["beatmapDataFilename", "lightshowDataFilename"]:
				var filename: String = Utils.get_str(diff_value as Dictionary, key, "")
				if not filename.is_empty() and not files.has(filename):
					files.append(filename)
	return files

static func new_v2(info_dict: Dictionary, load_path: String) -> MapInfo:
	# mix all the difficulty sets into a single one
	var diffs: Array[DifficultyInfo] = []
	var difficulty_beatmap_sets := Utils.get_array(info_dict, "_difficultyBeatmapSets", [])
	if (difficulty_beatmap_sets.is_empty()):
		vr.log_warning("No _difficultyBeatmapSets in info.dat")
	
	for difficulty_set: Variant in difficulty_beatmap_sets:
		if difficulty_set is Dictionary:
			var beatmaps := Utils.get_array(difficulty_set as Dictionary, "_difficultyBeatmaps", [])
			for difficulty_value: Variant in beatmaps:
				if difficulty_value is Dictionary:
					var difficulty_dict: Dictionary = difficulty_value as Dictionary
					var difficulty: DifficultyInfo = DifficultyInfo.load_v2(difficulty_dict)
					difficulty.characteristic = Utils.get_str(
						difficulty_set as Dictionary, "_beatmapCharacteristicName", "Standard"
					)
					difficulty.color_scheme_index = int(
						Utils.get_float(difficulty_dict, "_beatmapColorSchemeIdx", -1.0)
					)
					difficulty.environment_name_index = int(
						Utils.get_float(difficulty_dict, "_environmentNameIdx", 0.0)
					)
					diffs.append(difficulty)
	var info: MapInfo = MapInfo.new(
		Utils.get_str(info_dict, "_version", "2.0.0"),
		Utils.get_str(info_dict, "_songName", ""),
		Utils.get_str(info_dict, "_songSubName", ""),
		Utils.get_str(info_dict, "_songAuthorName", ""),
		Utils.get_str(info_dict, "_levelAuthorName", ""),
		Utils.get_float(info_dict, "_beatsPerMinute", 60.0),
		Utils.get_float(info_dict, "_previewStartTime", 0.0),
		Utils.get_float(info_dict, "_previewDuration", 0.0),
		Utils.get_str(info_dict, "_songFilename", ""),
		Utils.get_str(info_dict, "_coverImageFilename", ""),
		Utils.get_str(info_dict, "_environmentName", ""),
		Utils.get_float(info_dict, "_songTimeOffset", 0.0),
		Utils.get_dict(info_dict, "_customData", {}),
		load_path,
		diffs
	)
	info.environment_names = _string_array(Utils.get_array(info_dict, "_environmentNames", []))
	info.color_schemes = _dictionary_array(Utils.get_array(info_dict, "_colorSchemes", []))
	return info

static func new_v4(info_dict: Dictionary, load_path: String) -> MapInfo:
	var song: Dictionary = Utils.get_dict(info_dict, "song", {})
	var audio: Dictionary = Utils.get_dict(info_dict, "audio", {})
	var grouped_difficulties: Dictionary = {}
	var characteristic_order: Array[String] = []
	var level_authors: Array[String] = []

	for difficulty_value: Variant in Utils.get_array(info_dict, "difficultyBeatmaps", []):
		if not difficulty_value is Dictionary:
			continue
		var difficulty_dict: Dictionary = difficulty_value as Dictionary
		var difficulty: DifficultyInfo = DifficultyInfo.load_v4(difficulty_dict)
		var characteristic: String = difficulty.characteristic
		if not grouped_difficulties.has(characteristic):
			grouped_difficulties[characteristic] = []
			characteristic_order.append(characteristic)
		var characteristic_difficulties: Array = grouped_difficulties[characteristic] as Array
		characteristic_difficulties.append(difficulty)
		grouped_difficulties[characteristic] = characteristic_difficulties
		for mapper: String in difficulty.beatmap_authors:
			if not level_authors.has(mapper):
				level_authors.append(mapper)

	var difficulties: Array[DifficultyInfo] = []
	for characteristic: String in characteristic_order:
		var characteristic_difficulties: Array = grouped_difficulties[characteristic] as Array
		for difficulty_value: Variant in characteristic_difficulties:
			if difficulty_value is DifficultyInfo:
				difficulties.append(difficulty_value as DifficultyInfo)

	var environments: Array[String] = _string_array(Utils.get_array(info_dict, "environmentNames", []))
	var schemes: Array[Dictionary] = _dictionary_array(Utils.get_array(info_dict, "colorSchemes", []))
	var info: MapInfo = MapInfo.new(
		Utils.get_str(info_dict, "version", "4.0.0"),
		Utils.get_str(song, "title", ""),
		Utils.get_str(song, "subTitle", ""),
		Utils.get_str(song, "author", ""),
		", ".join(level_authors),
		Utils.get_float(audio, "bpm", 60.0),
		Utils.get_float(audio, "previewStartTime", 0.0),
		Utils.get_float(audio, "previewDuration", 0.0),
		Utils.get_str(audio, "songFilename", ""),
		Utils.get_str(info_dict, "coverImageFilename", ""),
		environments[0] if not environments.is_empty() else "",
		0.0,
		Utils.get_dict(info_dict, "customData", {}),
		load_path,
		difficulties
	)
	info.song_duration = Utils.get_float(audio, "songDuration", 0.0)
	info.audio_data_filename = Utils.get_str(audio, "audioDataFilename", "")
	info.environment_names = environments
	info.color_schemes = schemes
	info.difficulty_beatmap_sets = grouped_difficulties
	return info

static func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		if value is String:
			result.append(value as String)
	return result

static func _dictionary_array(values: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in values:
		if value is Dictionary:
			result.append(value as Dictionary)
	return result
