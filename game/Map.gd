extends RefCounted
class_name Map

# this would have basically been impossible to figure out without constantly
# referencing the beat saber modding group wiki.
# https://bsmg.wiki/mapping/map-format.html

static var current_info: MapInfo
static var current_difficulty: DifficultyInfo

static var note_stack: Array[ColorNoteInfo]
static var bomb_stack: Array[BombInfo]
static var obstacle_stack: Array[ObstacleInfo]
static var arc_stack: Array[ArcInfo]
static var chain_stack: Array[ChainInfo]
static var event_stack: Array[EventInfo]
static var bpm_changes: Array[BpmChangeInfo] = []
static var selected_mods: Array[String] = []
static var _warned_invalid_base_bpm := false

static var color_left: Color
static var color_right: Color
static var color_left_boost: Color
static var color_right_boost: Color
static var load_error: String = ""
static var load_warnings: Array[String] = []
static var load_info_messages: Array[String] = []
static var _load_bombs_enabled: bool = true

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
static var note_thread_0 := Thread.new()
static var note_thread_1 := Thread.new()
static var bomb_thread_0 := Thread.new()
static var bomb_thread_1 := Thread.new()
static var obstacle_thread_0 := Thread.new()
static var obstacle_thread_1 := Thread.new()
static var arc_thread_0 := Thread.new()
static var arc_thread_1 := Thread.new()
static var chain_thread_0 := Thread.new()
static var chain_thread_1 := Thread.new()
static var event_thread_0 := Thread.new()
static var event_thread_1 := Thread.new()

static func find_file_case_insensitive(dir_path: String, wanted: String) -> String:
	var directory: DirAccess = DirAccess.open(dir_path)
	if directory == null:
		return ""
	var wanted_lower: String = wanted.to_lower()
	for filename: String in directory.get_files():
		if filename.to_lower() == wanted_lower:
			return filename
	return ""

static func load_json_file_threaded(filename: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(filename, FileAccess.READ)
	if file == null:
		return {}
	var parsed_result: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed_result is Dictionary:
		return parsed_result as Dictionary
	return {}

static func prepare_beatmap_load(info: MapInfo, difficulty: DifficultyInfo) -> void:
	load_error = ""
	load_warnings.clear()
	load_info_messages.clear()
	_load_bombs_enabled = Settings.bombs_enabled
	current_info = info
	current_difficulty = difficulty
	update_mod_flags(difficulty)
	set_colors_from_custom_data()

# not officially part of the spec, but used by mods a lot
static func set_colors_from_custom_data() -> void:
	if Settings.disable_map_color:
		Map.color_left = Settings.color_left
		Map.color_right = Settings.color_right
		Map.color_left_boost = Map.color_left
		Map.color_right_boost = Map.color_right
		return
	
	var set_colors := func(data: Dictionary, color_name: String) -> bool:
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
			Map.color_left = Color(
				Utils.get_float(left, "r", Settings.color_left.r),
				Utils.get_float(left, "g", Settings.color_left.g),
				Utils.get_float(left, "b", Settings.color_left.b)
			)
			Map.color_right = Color(
				Utils.get_float(right, "r", Settings.color_right.r),
				Utils.get_float(right, "g", Settings.color_right.g),
				Utils.get_float(right, "b", Settings.color_right.b)
			)
			return true
		return false
	var info_data := current_info.custom_data
	var diff_data := current_difficulty.custom_data
	var custom_colors_found := false
	if set_colors.call(info_data, "envColor%sBoost"): custom_colors_found = true
	if set_colors.call(diff_data, "envColor%sBoost"): custom_colors_found = true
	if set_colors.call(info_data, "envColor%s"): custom_colors_found = true
	if set_colors.call(diff_data, "envColor%s"): custom_colors_found = true
	if set_colors.call(info_data, "color%s"): custom_colors_found = true
	if set_colors.call(diff_data, "color%s"): custom_colors_found = true
	if set_colors.call(info_data, "_envColor%sBoost"): custom_colors_found = true
	if set_colors.call(diff_data, "_envColor%sBoost"): custom_colors_found = true
	if set_colors.call(info_data, "_envColor%s"): custom_colors_found = true
	if set_colors.call(diff_data, "_envColor%s"): custom_colors_found = true
	if set_colors.call(info_data, "_color%s"): custom_colors_found = true
	if set_colors.call(diff_data, "_color%s"): custom_colors_found = true
	if not custom_colors_found:
		Map.color_left = Settings.color_left
		Map.color_right = Settings.color_right
	Map.color_left_boost = Map.color_left
	Map.color_right_boost = Map.color_right

	var set_boost_colors := func(data: Dictionary, color_name: String) -> void:
		var left_name: String = color_name % "LeftBoost"
		var right_name: String = color_name % "RightBoost"
		if (
			data.has(left_name) and data.has(right_name)
			and data[left_name] is Dictionary and data[right_name] is Dictionary
		):
			var left: Dictionary = data[left_name] as Dictionary
			var right: Dictionary = data[right_name] as Dictionary
			Map.color_left_boost = Color(
				Utils.get_float(left, "r", Map.color_left.r),
				Utils.get_float(left, "g", Map.color_left.g),
				Utils.get_float(left, "b", Map.color_left.b)
			)
			Map.color_right_boost = Color(
				Utils.get_float(right, "r", Map.color_right.r),
				Utils.get_float(right, "g", Map.color_right.g),
				Utils.get_float(right, "b", Map.color_right.b)
			)

	if current_info.version.begins_with("4"):
		var scheme_index: int = current_difficulty.color_scheme_index
		if scheme_index >= 0 and scheme_index < current_info.color_schemes.size():
			var scheme: Dictionary = current_info.color_schemes[scheme_index]
			Map.color_left_boost = Color.from_string(
				Utils.get_str(scheme, "environmentColor0Boost", Map.color_left.to_html()),
				Map.color_left
			)
			Map.color_right_boost = Color.from_string(
				Utils.get_str(scheme, "environmentColor1Boost", Map.color_right.to_html()),
				Map.color_right
			)

	set_boost_colors.call(info_data, "envColor%s")
	set_boost_colors.call(diff_data, "envColor%s")
	set_boost_colors.call(info_data, "_envColor%s")
	set_boost_colors.call(diff_data, "_envColor%s")

static func load_map_info(load_path: String) -> MapInfo:
	var info_dict := {}
	var info_filename: String = find_file_case_insensitive(load_path, "info.dat")
	if not info_filename.is_empty():
		info_dict = vr.load_json_file(load_path + info_filename)
	if (info_dict.is_empty()):
		vr.log_error("Invalid info.dat found in " + load_path)
		return null
	
	if info_dict.has("_version"):
		return MapInfo.new_v2(info_dict, load_path)
	elif info_dict.has("version"):
		var version: String = Utils.get_str(info_dict, "version", "")
		if version.begins_with("4"):
			return MapInfo.new_v4(info_dict, load_path)
		vr.log_warning("%s is an unsupported beatmap version: %s" % [load_path, version])
		return null
	else:
		vr.log_warning("%s is an unknown beatmap version" % load_path)
		return null

# speed for the speed gods.  please forgive me for this.
# - steve hocktail
static func load_note_stack_v2(note_data: Array) -> void:
	var load_range := func(start: int, end: int) -> Array[Array]:
		var note_array: Array[ColorNoteInfo] = []
		var bomb_array: Array[BombInfo] = []
		var i := start
		while i < end:
			if note_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				var note_dict := note_data[i] as Dictionary
				var note_type := int(Utils.get_float(note_dict, "_type", -1.0))
				if note_type == 3 and _load_bombs_enabled:
					bomb_array.append(BombInfo.new_v2(note_dict))
				elif note_type == 0 or note_type == 1:
					note_array.append(ColorNoteInfo.new_v2(note_dict))
			i += 1
		return [note_array, bomb_array]
	var midpoint := note_data.size() >> 1
	Utils.custom_thread_call(note_thread_1, load_range, [0, midpoint])
	var total_second_half : Array[Array] = load_range.bind(midpoint, note_data.size()).call()
	var total_first_half : Array[Array] = Utils.custom_thread_wait_to_finish(note_thread_1)
	note_stack = total_first_half[0] + total_second_half[0]
	bomb_stack = total_first_half[1] + total_second_half[1]
	note_stack.reverse()
	bomb_stack.reverse()

static func load_obstacle_stack_v2(obstacle_data: Array) -> void:
	var last_index := obstacle_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if obstacle_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				obstacle_stack[last_index - i] = ObstacleInfo.new_v2(obstacle_data[i] as Dictionary)
			i += 1
	var midpoint := obstacle_data.size() >> 1
	obstacle_stack.resize(obstacle_data.size())
	Utils.custom_thread_call(obstacle_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, obstacle_data.size()).call()
	Utils.custom_thread_wait_to_finish(obstacle_thread_1)

static func load_arc_stack_v2(arc_data: Array) -> void:
	var last_index := arc_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if arc_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				arc_stack[last_index - i] = ArcInfo.new_v2(arc_data[i] as Dictionary)
			i += 1
	var midpoint := arc_data.size() >> 1
	arc_stack.resize(arc_data.size())
	Utils.custom_thread_call(arc_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, arc_data.size()).call()
	Utils.custom_thread_wait_to_finish(arc_thread_1)
	

static func load_event_stack_v2(event_data: Array) -> void:
	var last_index := event_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if event_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				event_stack[last_index - i] = EventInfo.new_v2(event_data[i] as Dictionary)
			i += 1
	var midpoint := event_data.size() >> 1
	event_stack.resize(event_data.size())
	Utils.custom_thread_call(event_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, event_data.size()).call()
	Utils.custom_thread_wait_to_finish(event_thread_1)

static func load_bpm_changes_v2(map_data: Dictionary) -> void:
	bpm_changes.clear()
	if not map_data.has("_customData"):
		return
	@warning_ignore("unsafe_cast")
	var custom: Dictionary = map_data["_customData"] as Dictionary
	if not custom.has("_BPMChanges"):
		return

	var changes := Utils.get_array(custom, "_BPMChanges", [])
	for change_data in changes:
		if change_data is Dictionary:
			@warning_ignore("unsafe_cast")
			var change := BpmChangeInfo.new_v2(change_data as Dictionary)
			if change.bpm <= 0.0:
				load_warnings.append(
					"Skipping v2 BPM change with non-positive BPM at beat %s" % change.beat
				)
				continue
			bpm_changes.append(change)

	bpm_changes.sort_custom(func(a: BpmChangeInfo, b: BpmChangeInfo): return a.beat < b.beat)

static func load_note_stack_v3(note_data: Array) -> void:
	var last_index := note_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if note_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				note_stack[last_index - i] = ColorNoteInfo.new_v3(note_data[i] as Dictionary)
			i += 1
	var midpoint := note_data.size() >> 1
	note_stack.resize(note_data.size())
	Utils.custom_thread_call(note_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, note_data.size()).call()
	Utils.custom_thread_wait_to_finish(note_thread_1)

static func load_bomb_stack_v3(bomb_data: Array) -> void:
	if not _load_bombs_enabled:
		bomb_stack.clear()
		return
	var last_index := bomb_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if bomb_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				bomb_stack[last_index - i] = BombInfo.new_v3(bomb_data[i] as Dictionary)
			i += 1
	var midpoint := bomb_data.size() >> 1
	bomb_stack.resize(bomb_data.size())
	Utils.custom_thread_call(bomb_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, bomb_data.size()).call()
	Utils.custom_thread_wait_to_finish(bomb_thread_1)

static func load_obstacle_stack_v3(obstacle_data: Array) -> void:
	var last_index := obstacle_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if obstacle_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				obstacle_stack[last_index - i] = ObstacleInfo.new_v3(obstacle_data[i] as Dictionary)
			i += 1
	var midpoint := obstacle_data.size() >> 1
	obstacle_stack.resize(obstacle_data.size())
	Utils.custom_thread_call(obstacle_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, obstacle_data.size()).call()
	Utils.custom_thread_wait_to_finish(obstacle_thread_1)

static func load_arc_stack_v3(arc_data: Array) -> void:
	var last_index := arc_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if arc_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				arc_stack[last_index - i] = ArcInfo.new_v3(arc_data[i] as Dictionary)
			i += 1
	var midpoint := arc_data.size() >> 1
	arc_stack.resize(arc_data.size())
	Utils.custom_thread_call(arc_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, arc_data.size()).call()
	Utils.custom_thread_wait_to_finish(arc_thread_1)

static func load_chain_stack_v3(chain_data: Array) -> void:
	var last_index := chain_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if chain_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				chain_stack[last_index - i] = ChainInfo.new_v3(chain_data[i] as Dictionary)
			i += 1
	var midpoint := chain_data.size() >> 1
	chain_stack.resize(chain_data.size())
	Utils.custom_thread_call(chain_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, chain_data.size()).call()
	Utils.custom_thread_wait_to_finish(chain_thread_1)

static func load_event_stack_v3(event_data: Array) -> void:
	var last_index := event_data.size() - 1
	var load_range := func(start: int, end: int) -> void:
		var i := start
		while i < end:
			if event_data[i] is Dictionary:
				@warning_ignore("unsafe_cast")
				event_stack[last_index - i] = EventInfo.new_v3(event_data[i] as Dictionary)
			i += 1
	var midpoint := event_data.size() >> 1
	event_stack.resize(event_data.size())
	Utils.custom_thread_call(event_thread_1, load_range, [0, midpoint])
	load_range.bind(midpoint, event_data.size()).call()
	Utils.custom_thread_wait_to_finish(event_thread_1)

static func load_bpm_changes_v3(map_data: Dictionary) -> void:
	bpm_changes.clear()
	var changes := Utils.get_array(map_data, "bpmEvents", [])
	for change_data in changes:
		if change_data is Dictionary:
			@warning_ignore("unsafe_cast")
			var change := BpmChangeInfo.new_v3(change_data as Dictionary)
			if change.bpm <= 0.0:
				load_warnings.append(
					"Skipping v3 BPM event with non-positive BPM at beat %s" % change.beat
				)
				continue
			bpm_changes.append(change)

	bpm_changes.sort_custom(func(a: BpmChangeInfo, b: BpmChangeInfo): return a.beat < b.beat)

static func load_v3_lighting_groups(map_data: Dictionary, environment_name: String = "") -> void:
	var light_groups: Array = Utils.get_array(map_data, "lightColorEventBoxGroups", [])
	var color_group_ids: Array[int] = V3LightingInfo.collect_color_group_ids(map_data)
	V3LightingInfo.configure_group_mapping(
		environment_name,
		color_group_ids,
		load_info_messages,
		load_warnings
	)

	var left_color: Color = Map.color_left
	var right_color: Color = Map.color_right

	var v3_events: Array[EventInfo] = []
	for group_data: Variant in light_groups:
		if group_data is Dictionary:
			var group: V3LightingInfo.LightColorEventBoxGroup = (
				V3LightingInfo.LightColorEventBoxGroup.from_dict(group_data as Dictionary)
			)
			var converted_events: Array[EventInfo] = group.to_event_infos(left_color, right_color)
			v3_events.append_array(converted_events)
	v3_events.append_array(V3LightingInfo.convert_rotation_groups(map_data))
	v3_events.append_array(V3LightingInfo.convert_boost_events(map_data))

	var basic_event_count: int = event_stack.size()
	event_stack.append_array(v3_events)
	var indexed_events: Array[Dictionary] = []
	for stack_index: int in range(event_stack.size()):
		var original_index: int = stack_index
		if stack_index < basic_event_count:
			original_index = basic_event_count - 1 - stack_index
		indexed_events.append({
			"event": event_stack[stack_index],
			"index": original_index,
		})
	indexed_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_event: EventInfo = a["event"] as EventInfo
		var b_event: EventInfo = b["event"] as EventInfo
		if a_event.beat != b_event.beat:
			return a_event.beat > b_event.beat
		return int(a["index"]) > int(b["index"])
	)
	event_stack.clear()
	for indexed_event: Dictionary in indexed_events:
		event_stack.append(indexed_event["event"] as EventInfo)

static func _environment_name_for(info: MapInfo, difficulty: DifficultyInfo) -> String:
	if info.version.begins_with("4") and not info.environment_names.is_empty():
		var environment_index: int = difficulty.environment_name_index
		if environment_index >= 0 and environment_index < info.environment_names.size():
			return info.environment_names[environment_index]
	return info.environment_name

static func _convert_v4_rotation_groups(lightshow_data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var index_filters: Array = Utils.get_array(lightshow_data, "indexFilters", [])
	var rotation_boxes: Array = Utils.get_array(lightshow_data, "lightRotationEventBoxes", [])
	var rotation_events: Array = Utils.get_array(lightshow_data, "lightRotationEvents", [])
	for group_value: Variant in Utils.get_array(lightshow_data, "eventBoxGroups", []):
		if not group_value is Dictionary:
			continue
		var group_data: Dictionary = group_value as Dictionary
		if int(Utils.get_float(group_data, "t", 0.0)) != 2:
			continue
		var converted_group: Dictionary = {
			"b": Utils.get_float(group_data, "b", 0.0),
			"g": int(Utils.get_float(group_data, "g", 0.0)),
			"e": [],
		}
		for box_value: Variant in Utils.get_array(group_data, "e", []):
			if not box_value is Dictionary:
				continue
			var box_reference: Dictionary = box_value as Dictionary
			var filter_data: Dictionary = _indexed_v4_dictionary(index_filters, box_reference, "f")
			var box_data: Dictionary = _indexed_v4_dictionary(rotation_boxes, box_reference, "e")
			if box_data.is_empty():
				continue
			var converted_box: Dictionary = {
				"f": filter_data.duplicate(true),
				"w": Utils.get_float(box_data, "w", 0.0),
				"d": int(Utils.get_float(box_data, "d", 0.0)),
				"l": Utils.get_float(box_data, "l", 0.0),
				"e": [],
			}
			for event_value: Variant in Utils.get_array(box_reference, "l", []):
				if not event_value is Dictionary:
					continue
				var event_reference: Dictionary = event_value as Dictionary
				var event_data: Dictionary = _indexed_v4_dictionary(
					rotation_events,
					event_reference,
					"i"
				)
				if event_data.is_empty():
					continue
				(converted_box["e"] as Array).append({
					"b": Utils.get_float(event_reference, "b", 0.0),
					"p": Utils.get_float(event_data, "p", 0.0),
					"e": int(Utils.get_float(event_data, "e", 0.0)),
					"l": Utils.get_float(event_data, "l", 0.0),
					"r": int(Utils.get_float(event_data, "r", 0.0)),
					"o": int(Utils.get_float(event_data, "o", 0.0)),
				})
			(converted_group["e"] as Array).append(converted_box)
		result.append(converted_group)
	return result

static func _indexed_v4_dictionary(
	values: Array,
	reference: Dictionary,
	index_key: String
) -> Dictionary:
	var index: int = int(Utils.get_float(reference, index_key, -1.0))
	if index < 0 or index >= values.size():
		return {}
	var value: Variant = values[index]
	if value is Dictionary:
		return value as Dictionary
	return {}

static func get_mods_for_difficulty(difficulty: DifficultyInfo) -> Array[String]:
	var mods: Array[String] = []
	var keys: Array[String] = [
		"_requirements", "_suggestions", "requirements", "suggestions"
	]
	for key in keys:
		var values := Utils.get_array(difficulty.custom_data, key, [])
		for value in values:
			if value is String:
				var mod_name := value as String
				if not mods.has(mod_name):
					mods.append(mod_name)
	return mods

static func update_mod_flags(difficulty: DifficultyInfo) -> void:
	Constants.usingMappingExtension = false
	Constants.usingNoodleExtension = false
	Constants.usingChroma = false
	Constants.usingVivify = false
	selected_mods = get_mods_for_difficulty(difficulty)
	for mod in selected_mods:
		match mod.to_lower():
			"mapping extensions":
				Constants.usingMappingExtension = true
			"noodle extensions":
				Constants.usingNoodleExtension = true
			"chroma":
				Constants.usingChroma = true
			"vivify":
				Constants.usingVivify = true

static func remove_null_stack_entries() -> void:
	for index in range(note_stack.size() - 1, -1, -1):
		if note_stack[index] == null:
			note_stack.remove_at(index)
	for index in range(bomb_stack.size() - 1, -1, -1):
		if bomb_stack[index] == null:
			bomb_stack.remove_at(index)
	for index in range(obstacle_stack.size() - 1, -1, -1):
		if obstacle_stack[index] == null:
			obstacle_stack.remove_at(index)
	for index in range(arc_stack.size() - 1, -1, -1):
		if arc_stack[index] == null:
			arc_stack.remove_at(index)
	for index in range(chain_stack.size() - 1, -1, -1):
		if chain_stack[index] == null:
			chain_stack.remove_at(index)
	for index in range(event_stack.size() - 1, -1, -1):
		if event_stack[index] == null:
			event_stack.remove_at(index)

static func load_beatmap(info: MapInfo, difficulty: DifficultyInfo, map_data: Dictionary) -> bool:
	# Ensures the map_data dict has a version (some maps include the version only on info but not in the data)
	if !map_data.has("_version") and !map_data.has("version"):
		if info.version.begins_with("2.") or info.version.begins_with("1."):
			map_data["_version"] = info.version
		else:
			map_data["version"] = info.version
	
	if map_data.has("_version"):
		Utils.custom_thread_call(note_thread_0, load_note_stack_v2, [Utils.get_array(map_data, "_notes", [])])
		Utils.custom_thread_call(obstacle_thread_0, load_obstacle_stack_v2, [Utils.get_array(map_data, "_obstacles", [])])
		Utils.custom_thread_call(event_thread_0, load_event_stack_v2, [Utils.get_array(map_data, "_events", [])])
		Utils.custom_thread_call(arc_thread_0, load_arc_stack_v2, [Utils.get_array(map_data, "_sliders", [])])
		chain_stack.clear()
		load_bpm_changes_v2(map_data)
		Utils.custom_thread_wait_to_finish(note_thread_0)
		Utils.custom_thread_wait_to_finish(obstacle_thread_0)
		Utils.custom_thread_wait_to_finish(event_thread_0)
		Utils.custom_thread_wait_to_finish(arc_thread_0)
		remove_null_stack_entries()
		return true
	elif map_data.has("version"):
		var version := Utils.get_str(map_data, "version", "")
		if version.begins_with("4."):
			var lightshow_data: Dictionary = {}
			if not difficulty.lightshow_filename.is_empty():
				var lightshow_filename: String = find_file_case_insensitive(
					info.filepath, difficulty.lightshow_filename
				)
				if not lightshow_filename.is_empty():
					lightshow_data = load_json_file_threaded(info.filepath + lightshow_filename)
			if lightshow_data.is_empty() and _has_v4_lightshow_data(map_data):
				lightshow_data = map_data
			if lightshow_data.is_empty():
				load_warnings.append(
					"No v4 lightshow data found for %s; loading without events"
					% difficulty.beatmap_filename
				)

			var audio_data: Dictionary = {}
			if not info.audio_data_filename.is_empty():
				var audio_data_filename: String = find_file_case_insensitive(
					info.filepath, info.audio_data_filename
				)
				if not audio_data_filename.is_empty():
					audio_data = load_json_file_threaded(info.filepath + audio_data_filename)
			var v4_rotation_groups: Array[Dictionary] = _convert_v4_rotation_groups(lightshow_data)
			map_data = V4Converter.to_v3(map_data, lightshow_data, audio_data)
			if not v4_rotation_groups.is_empty():
				map_data["lightRotationEventBoxGroups"] = v4_rotation_groups
			version = Utils.get_str(map_data, "version", "")
		if version.begins_with("3."):
			Utils.custom_thread_call(note_thread_0, load_note_stack_v3, [Utils.get_array(map_data, "colorNotes", [])])
			Utils.custom_thread_call(bomb_thread_0, load_bomb_stack_v3, [Utils.get_array(map_data, "bombNotes", [])])
			Utils.custom_thread_call(obstacle_thread_0, load_obstacle_stack_v3, [Utils.get_array(map_data, "obstacles", [])])
			Utils.custom_thread_call(arc_thread_0, load_arc_stack_v3, [Utils.get_array(map_data, "sliders", [])])
			Utils.custom_thread_call(chain_thread_0, load_chain_stack_v3, [Utils.get_array(map_data, "burstSliders", [])])
			Utils.custom_thread_call(event_thread_0, load_event_stack_v3, [Utils.get_array(map_data, "basicBeatmapEvents", [])])
			load_bpm_changes_v3(map_data)
			Utils.custom_thread_wait_to_finish(note_thread_0)
			Utils.custom_thread_wait_to_finish(bomb_thread_0)
			Utils.custom_thread_wait_to_finish(obstacle_thread_0)
			Utils.custom_thread_wait_to_finish(arc_thread_0)
			Utils.custom_thread_wait_to_finish(chain_thread_0)
			Utils.custom_thread_wait_to_finish(event_thread_0)
			remove_null_stack_entries()
			# Load V3 lighting event box groups AFTER event thread completes
			# This prevents race conditions when appending to event_stack
			load_v3_lighting_groups(map_data, _environment_name_for(info, difficulty))
			return true
	load_error = "selected map is an unsupported version"
	return false

static func _has_v4_lightshow_data(map_data: Dictionary) -> bool:
	var keys: Array[String] = [
		"basicEvents",
		"colorBoostEvents",
		"eventBoxGroups",
		"waypoints",
	]
	for key: String in keys:
		if map_data.has(key):
			return true
	return false

# Convert beat to seconds, accounting for BPM changes
static func beat_to_seconds(beat: float) -> float:
	if current_info.beats_per_minute <= 0.0:
		_warn_invalid_base_bpm_once()
		return 0.0
	if bpm_changes.is_empty():
		# Simple calculation - no BPM changes
		return beat * 60.0 / current_info.beats_per_minute

	var time: float = 0.0
	var last_beat: float = 0.0
	var current_bpm: float = current_info.beats_per_minute

	for change in bpm_changes:
		if beat <= change.beat:
			# Target beat is before this change
			var beat_diff: float = beat - last_beat
			time += beat_diff * 60.0 / current_bpm
			return time
		else:
			# Add time up to this change
			var beat_diff: float = change.beat - last_beat
			time += beat_diff * 60.0 / current_bpm
			last_beat = change.beat
			current_bpm = change.bpm

	# Beat is after all changes
	var beat_diff: float = beat - last_beat
	time += beat_diff * 60.0 / current_bpm
	return time

static func seconds_to_beat(seconds: float) -> float:
	if current_info.beats_per_minute <= 0.0:
		_warn_invalid_base_bpm_once()
		return 0.0
	if bpm_changes.is_empty():
		return seconds * current_info.beats_per_minute / 60.0

	var time: float = 0.0
	var last_beat: float = 0.0
	var current_bpm: float = current_info.beats_per_minute

	for change in bpm_changes:
		var beat_diff: float = change.beat - last_beat
		var segment_time: float = beat_diff * 60.0 / current_bpm
		if seconds <= time + segment_time:
			return last_beat + (seconds - time) * current_bpm / 60.0
		time += segment_time
		last_beat = change.beat
		current_bpm = change.bpm

	return last_beat + (seconds - time) * current_bpm / 60.0

static func _warn_invalid_base_bpm_once() -> void:
	if _warned_invalid_base_bpm:
		return
	_warned_invalid_base_bpm = true
	var warning: String = "Map BPM must be positive; beat/time conversion returns 0"
	if Thread.is_main_thread():
		vr.log_warning(warning)
	else:
		load_warnings.append(warning)
