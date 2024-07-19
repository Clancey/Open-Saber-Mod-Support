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
	# not officially part of the spec, but used by mods a lot
	var custom_name: String
	
	func load_v2(diff_dict: Dictionary) -> void:
		difficulty = Utils.get_str(diff_dict, "_difficulty", "")
		difficulty_rank = int(Utils.get_float(diff_dict, "_difficultyRank", 0))
		beatmap_filename = Utils.get_str(diff_dict, "_beatmapFilename", "")
		note_jump_movement_speed = Utils.get_float(diff_dict, "_noteJumpMovementSpeed", 1.0)
		note_jump_start_beat_offset = Utils.get_float(diff_dict, "_noteJumpStartBeatOffset", 0.0)
		custom_data = Utils.get_dict(diff_dict, "_customData", {})
		
		# not officially part of the spec, but used by mods a lot
		if not custom_data.is_empty():
			custom_name = Utils.get_str(custom_data, "_difficultyLabel", "")
		if custom_name.is_empty():
			custom_name = difficulty

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
	
	func load_v2(info_dict: Dictionary, load_path: String) -> void:
		filepath = load_path
		version = Utils.get_str(info_dict, "_version", "2.0.0")
		song_name = Utils.get_str(info_dict, "_songName", "")
		song_sub_name = Utils.get_str(info_dict, "_songSubName", "")
		song_author_name = Utils.get_str(info_dict, "_songAuthorName", "")
		level_author_name = Utils.get_str(info_dict, "_levelAuthorName", "")
		beats_per_minute = Utils.get_float(info_dict, "_beatsPerMinute", 60.0)
		# shuffle and shuffle period maybe in the future?
		preview_start_time = Utils.get_float(info_dict, "_previewStartTime", 0.0)
		preview_duration = Utils.get_float(info_dict, "_previewDuration", 0.0)
		song_filename = Utils.get_str(info_dict, "_songFilename", "")
		cover_image_filename = Utils.get_str(info_dict, "_coverImageFilename", "")
		environment_name = Utils.get_str(info_dict, "_environmentName", "")
		song_time_offset = Utils.get_float(info_dict, "_songTimeOffset", 0.0)
		custom_data = Utils.get_dict(info_dict, "_customData", {})
		
		# mix all the difficulty sets into a single one
		difficulty_beatmaps.clear()
		var difficulty_beatmap_sets := Utils.get_array(info_dict, "_difficultyBeatmapSets", [])
		if (difficulty_beatmap_sets.is_empty()):
			vr.log_warning("No _difficultyBeatmapSets in info.dat")
		
		for difficulty_set: Variant in difficulty_beatmap_sets:
			if difficulty_set is Dictionary:
				var beatmaps := Utils.get_array(difficulty_set as Dictionary, "_difficultyBeatmaps", [])
				for i: Variant in beatmaps:
					if i is Dictionary:
						var diff := Difficulty.new()
						diff.load_v2(i as Dictionary)
						difficulty_beatmaps.append(diff)
	
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
	var angle_offset: int
	
	func load_v2(note_dict: Dictionary) -> void:
		beat = Utils.get_float(note_dict, "_time", 0.0)
		line_index = int(Utils.get_float(note_dict, "_lineIndex", 0))
		line_layer = int(Utils.get_float(note_dict, "_lineLayer", 0))
		color = int(Utils.get_float(note_dict, "_type", -1.0))
		cut_direction = int(Utils.get_float(note_dict, "_cutDirection", 0))
	
	func load_v3(note_dict: Dictionary) -> void:
		beat = Utils.get_float(note_dict, "b", 0.0)
		line_index = int(Utils.get_float(note_dict, "x", 0))
		line_layer = int(Utils.get_float(note_dict, "y", 0))
		color = int(Utils.get_float(note_dict, "c", -1.0))
		cut_direction = int(Utils.get_float(note_dict, "d", 0))
		angle_offset = int(Utils.get_float(note_dict, "a", 0))

class BombInfo extends RefCounted:
	var beat: float
	var line_index: int
	var line_layer: int
	
	func load_v2(bomb_dict: Dictionary) -> void:
		beat = Utils.get_float(bomb_dict, "_time", 0.0)
		line_index = int(Utils.get_float(bomb_dict, "_lineIndex", 0))
		line_layer = int(Utils.get_float(bomb_dict, "_lineLayer", 0))
	
	func load_v3(bomb_dict: Dictionary) -> void:
		beat = Utils.get_float(bomb_dict, "b", 0.0)
		line_index = int(Utils.get_float(bomb_dict, "x", 0))
		line_layer = int(Utils.get_float(bomb_dict, "y", 0))

class ObstacleInfo extends RefCounted:
	var beat: float
	var duration: float
	var line_index: int
	var line_layer: int
	var width: int
	var height: int
	
	func load_v2(obstacle_dict: Dictionary) -> void:
		beat = Utils.get_float(obstacle_dict, "_time", 0.0)
		duration = Utils.get_float(obstacle_dict, "_duration", 0.0)
		line_index = int(Utils.get_float(obstacle_dict, "_lineIndex", 0))
		width = int(Utils.get_float(obstacle_dict, "_width", 0))
		var type := int(Utils.get_float(obstacle_dict, "_type", 0))
		match type:
			0: # full height
				line_layer = 0
				height = 5
			1: # crouch
				line_layer = 2
				height = 3
			2: # free
				line_layer = int(Utils.get_float(obstacle_dict, "_lineLayer", 0))
				height = int(Utils.get_float(obstacle_dict, "_height", 0))
	
	func load_v3(obstacle_dict: Dictionary) -> void:
		beat = Utils.get_float(obstacle_dict, "b", 0.0)
		duration = Utils.get_float(obstacle_dict, "d", 0.0)
		line_index = int(Utils.get_float(obstacle_dict, "x", 0))
		line_layer = int(Utils.get_float(obstacle_dict, "y", 0))
		width = int(Utils.get_float(obstacle_dict, "w", 0))
		height = int(Utils.get_float(obstacle_dict, "h", 0))

class ChainInfo extends RefCounted:
	var color: int
	var head_beat: float
	var head_line_index: int
	var head_line_layer: int
	var head_cut_direction: int
	var tail_beat: float
	var tail_line_index: int
	var tail_line_layer: int
	var slice_count: int
	var squish_factor: float
	
	func load_v3(chain_dict: Dictionary) -> void:
			color = int(Utils.get_float(chain_dict, "c", 0))
			head_beat = Utils.get_float(chain_dict, "b", 0.0)
			head_line_index = int(Utils.get_float(chain_dict, "x", 0))
			head_line_layer = int(Utils.get_float(chain_dict, "y", 0))
			head_cut_direction = int(Utils.get_float(chain_dict, "d", 0))
			tail_beat = Utils.get_float(chain_dict, "tb", 0.0)
			tail_line_index = int(Utils.get_float(chain_dict, "tx", 0))
			tail_line_layer = int(Utils.get_float(chain_dict, "ty", 0))
			slice_count = int(Utils.get_float(chain_dict, "sc", 0))
			squish_factor = int(Utils.get_float(chain_dict, "s", 1.0))

class EventInfo extends RefCounted:
	var beat: float
	var type: int
	var value: int
	var float_value: float
	
	func load_v2(event_dict: Dictionary) -> void:
		beat = Utils.get_float(event_dict, "_time", 0.0)
		type = int(Utils.get_float(event_dict, "_type", 0))
		value = int(Utils.get_float(event_dict, "_value", 0))
		float_value = Utils.get_float(event_dict, "_floatValue", -1.0)
	
	func load_v3(event_dict: Dictionary) -> void:
		beat = Utils.get_float(event_dict, "b", 0.0)
		type = int(Utils.get_float(event_dict, "et", 0))
		value = int(Utils.get_float(event_dict, "i", 0))
		float_value = Utils.get_float(event_dict, "f", -1.0)

var current_info: Info
var current_difficulty: Difficulty
var current_difficulty_index: int

var note_stack: Array[ColorNoteInfo]
var bomb_stack: Array[BombInfo]
var obstacle_stack: Array[ObstacleInfo]
var chain_stack: Array[ChainInfo]
var event_stack: Array[EventInfo]

var color_left: Color
var color_right: Color

# some simple multithreading, since larger maps can take a very long time to
# load.  one particulary notable outlier is the beatmap of shrek, which took
# around 48 milliseconds to load before even on a 7800x3d, and now takes around
# 29 milliseconds.  takes just over half as long as before, very worth the
# nightmare code i've written.
#
# long story short, each beatmap-element loading func splits into two threads:
# one for parsing the top half of the array of dicts, and one for parsing the
# bottom half.  these run concurrently, not quite halfing the time, but
# getting pretty close to halfing it.
var note_thread_0 := Thread.new()
var note_thread_1 := Thread.new()
var bomb_thread_0 := Thread.new()
var bomb_thread_1 := Thread.new()
var obstacle_thread_0 := Thread.new()
var obstacle_thread_1 := Thread.new()
var chain_thread_0 := Thread.new()
var chain_thread_1 := Thread.new()
var event_thread_0 := Thread.new()
var event_thread_1 := Thread.new()

# not officially part of the spec, but used by mods a lot
func set_colors_from_custom_data(info_data: Dictionary, diff_data: Dictionary, default_left: Color, default_right: Color) -> void:
	var set_colors := func(data: Dictionary, color_name: String) -> void:
		var left_name := color_name % "Left"
		var right_name := color_name % "Right"
		if (
			data.has(left_name) and data.has(right_name)
			and data[left_name] is Dictionary and data[right_name] is Dictionary
		):
			@warning_ignore("unsafe_cast")
			var left := data[left_name] as Dictionary
			@warning_ignore("unsafe_cast")
			var right := data[right_name] as Dictionary
			color_left = Color(
				Utils.get_float(left, "r", default_left.r),
				Utils.get_float(left, "g", default_left.g),
				Utils.get_float(left, "b", default_left.b)
			)
			color_right = Color(
				Utils.get_float(right, "r", default_right.r),
				Utils.get_float(right, "g", default_right.g),
				Utils.get_float(right, "b", default_right.b)
			)
	set_colors.call(info_data, "_envColor%sBoost")
	set_colors.call(diff_data, "_envColor%sBoost")
	set_colors.call(info_data, "_envColor%s")
	set_colors.call(diff_data, "_envColor%s")
	set_colors.call(info_data, "_color%s")
	set_colors.call(diff_data, "_color%s")

func load_map_info(load_path: String) -> Info:
	var info_dict := {}
	if FileAccess.file_exists(load_path + "Info.dat"):
		info_dict = vr.load_json_file(load_path + "Info.dat")
	elif FileAccess.file_exists(load_path + "info.dat"):
		info_dict = vr.load_json_file(load_path + "info.dat")
	if (info_dict.is_empty()):
		vr.log_error("Invalid info.dat found in " + load_path)
		return null
	
	if info_dict.has("_version"):
		var info := Info.new()
		info.load_v2(info_dict, load_path)
		return info
	elif info_dict.has("version"):
		vr.log_warning("%s is an unsupported beatmap version: %s" % [load_path, info_dict["version"]])
		return null
	else:
		vr.log_warning("%s is an unknown beatmap version" % load_path)
		return null

# speed for the speed gods.  please forgive me for this.
# - steve hocktail
func load_note_stack_v2(note_data: Array) -> void:
	var load_range := func(start: int, end: int) -> Array[Array]:
		var note_array: Array[ColorNoteInfo] = []
		var bomb_array: Array[BombInfo] = []
		var i := start
		while i < end:
			if not note_data[i] is Dictionary: continue
			@warning_ignore("unsafe_cast")
			var note_dict := note_data[i] as Dictionary
			var note_type := int(Utils.get_float(note_dict, "_type", -1.0))
			if note_type == 3 and Settings.bombs_enabled:
				var new_bomb := BombInfo.new()
				new_bomb.load_v2(note_dict)
				bomb_array.append(new_bomb)
			elif note_type == 0 or note_type == 1:
				var new_note := ColorNoteInfo.new()
				new_note.load_v2(note_dict)
				note_array.append(new_note)
			i += 1
		return [note_array, bomb_array]
	var midpoint := note_data.size() >> 1
	note_thread_1.start(load_range.bind(0, midpoint))
	var total_second_half := load_range.bind(midpoint, note_data.size()).call() as Array[Array]
	var total_first_half := note_thread_1.wait_to_finish() as Array[Array]
	note_stack = total_first_half[0] + total_second_half[0]
	bomb_stack = total_first_half[1] + total_second_half[1]
	note_stack.reverse()
	bomb_stack.reverse()

func load_obstacle_stack_v2(obstacle_data: Array) -> void:
	var last_index := obstacle_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if obstacle_data[i] is Dictionary:
				var new_obstacle := ObstacleInfo.new()
				@warning_ignore("unsafe_cast")
				new_obstacle.load_v2(obstacle_data[i] as Dictionary)
				obstacle_stack[last_index - i] = new_obstacle
			i += 1
	var midpoint := obstacle_data.size() >> 1
	obstacle_stack.resize(obstacle_data.size())
	obstacle_thread_1.start(load_range.bind(0, midpoint))
	load_range.bind(midpoint, obstacle_data.size()).call()
	obstacle_thread_1.wait_to_finish()

func load_event_stack_v2(event_data: Array) -> void:
	var last_index := event_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if event_data[i] is Dictionary:
				var new_event := EventInfo.new()
				@warning_ignore("unsafe_cast")
				new_event.load_v2(event_data[i] as Dictionary)
				event_stack[last_index - i] = new_event
			i += 1
	var midpoint := event_data.size() >> 1
	event_stack.resize(event_data.size())
	event_thread_1.start(load_range.bind(0, midpoint))
	load_range.bind(midpoint, event_data.size()).call()
	event_thread_1.wait_to_finish()

func load_note_stack_v3(note_data: Array) -> void:
	var last_index := note_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if note_data[i] is Dictionary:
				var new_note := ColorNoteInfo.new()
				@warning_ignore("unsafe_cast")
				new_note.load_v3(note_data[i] as Dictionary)
				note_stack[last_index - i] = new_note
			i += 1
	var midpoint := note_data.size() >> 1
	note_stack.resize(note_data.size())
	note_thread_1.start(load_range.bind(0, midpoint))
	load_range.bind(midpoint, note_data.size()).call()
	note_thread_1.wait_to_finish()

func load_bomb_stack_v3(bomb_data: Array) -> void:
	if not Settings.bombs_enabled:
		bomb_stack.clear()
		return
	var last_index := bomb_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if bomb_data[i] is Dictionary:
				var new_bomb := BombInfo.new()
				@warning_ignore("unsafe_cast")
				new_bomb.load_v3(bomb_data[i] as Dictionary)
				bomb_stack[last_index - i] = new_bomb
			i += 1
	var midpoint := bomb_data.size() >> 1
	bomb_stack.resize(bomb_data.size())
	bomb_thread_1.start(load_range.bind(0, midpoint))
	load_range.bind(midpoint, bomb_data.size()).call()
	bomb_thread_1.wait_to_finish()

func load_obstacle_stack_v3(obstacle_data: Array) -> void:
	var last_index := obstacle_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if obstacle_data[i] is Dictionary:
				var new_obstacle := ObstacleInfo.new()
				@warning_ignore("unsafe_cast")
				new_obstacle.load_v3(obstacle_data[i] as Dictionary)
				obstacle_stack[last_index - i] = new_obstacle
			i += 1
	var midpoint := obstacle_data.size() >> 1
	obstacle_stack.resize(obstacle_data.size())
	obstacle_thread_1.start(load_range.bind(0, midpoint))
	load_range.bind(midpoint, obstacle_data.size()).call()
	obstacle_thread_1.wait_to_finish()

func load_chain_stack_v3(chain_data: Array) -> void:
	var last_index := chain_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if chain_data[i] is Dictionary:
				var new_chain := ChainInfo.new()
				@warning_ignore("unsafe_cast")
				new_chain.load_v3(chain_data[i] as Dictionary)
				chain_stack[last_index - i] = new_chain
			i += 1
	var midpoint := chain_data.size() >> 1
	chain_stack.resize(chain_data.size())
	chain_thread_1.start(load_range.bind(0, midpoint))
	load_range.bind(midpoint, chain_data.size()).call()
	chain_thread_1.wait_to_finish()

func load_event_stack_v3(event_data: Array) -> void:
	var last_index := event_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if event_data[i] is Dictionary:
				var new_event := EventInfo.new()
				@warning_ignore("unsafe_cast")
				new_event.load_v3(event_data[i] as Dictionary)
				event_stack[last_index - i] = new_event
			i += 1
	var midpoint := event_data.size() >> 1
	event_stack.resize(event_data.size())
	event_thread_1.start(load_range.bind(0, midpoint))
	load_range.bind(midpoint, event_data.size()).call()
	event_thread_1.wait_to_finish()

func load_beatmap(map_data: Dictionary) -> bool:
	if map_data.has("_version"):
		note_thread_0.start(load_note_stack_v2.bind(Utils.get_array(map_data, "_notes", [])))
		obstacle_thread_0.start(load_obstacle_stack_v2.bind(Utils.get_array(map_data, "_obstacles", [])))
		event_thread_0.start(load_event_stack_v2.bind(Utils.get_array(map_data, "_events", [])))
		chain_stack.clear()
		note_thread_0.wait_to_finish()
		obstacle_thread_0.wait_to_finish()
		event_thread_0.wait_to_finish()
		return true
	elif map_data.has("version"):
		var version := Utils.get_str(map_data, "version", "")
		if version.begins_with("3."):
			note_thread_0.start(load_note_stack_v3.bind(Utils.get_array(map_data, "colorNotes", [])))
			bomb_thread_0.start(load_bomb_stack_v3.bind(Utils.get_array(map_data, "bombNotes", [])))
			obstacle_thread_0.start(load_obstacle_stack_v3.bind(Utils.get_array(map_data, "obstacles", [])))
			chain_thread_0.start(load_chain_stack_v3.bind(Utils.get_array(map_data, "burstSliders", [])))
			event_thread_0.start(load_event_stack_v3.bind(Utils.get_array(map_data, "basicBeatmapEvents", [])))
			note_thread_0.wait_to_finish()
			bomb_thread_0.wait_to_finish()
			obstacle_thread_0.wait_to_finish()
			chain_thread_0.wait_to_finish()
			event_thread_0.wait_to_finish()
			return true
	vr.log_warning("selected map is an unsupported version")
	return false
