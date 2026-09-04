extends "res://tests/test_case.gd"


func test_v4_info_parsing() -> void:
	var info_data: Dictionary = _load_dictionary("res://tests/fixtures/v4/Info.dat")
	var info: MapInfo = MapInfo.new_v4(info_data, "res://tests/fixtures/v4/")

	assert_eq(info.song_name, "V4 Test Song", "V4 song title")
	assert_eq(info.beats_per_minute, 128.0, "V4 BPM")
	assert_eq(info.song_duration, 120.0, "V4 song duration")
	assert_eq(info.environment_names, ["DefaultEnvironment"], "V4 environments")
	assert_eq(info.color_schemes.size(), 1, "V4 color scheme count")
	assert_eq(info.difficulty_beatmaps.size(), 1, "V4 difficulty count")
	if info.difficulty_beatmaps.is_empty():
		return
	var difficulty: DifficultyInfo = info.difficulty_beatmaps[0]
	assert_eq(difficulty.difficulty, "Expert", "V4 difficulty name")
	assert_eq(difficulty.custom_name, "Fixture Expert", "V4 custom difficulty name")
	assert_eq(difficulty.note_jump_movement_speed, 16.0, "V4 NJS")
	assert_eq(difficulty.characteristic, "Standard", "V4 characteristic")
	assert_eq(difficulty.lightshow_filename, "Lightshow.dat", "V4 lightshow filename")
	assert_eq(difficulty.beatmap_authors, ["Test Mapper"], "V4 beatmap authors")
	assert_eq(difficulty.lightshow_authors, ["Test Lighter"], "V4 lightshow authors")
	assert_eq(
		Map.get_mods_for_difficulty(difficulty),
		["Chroma", "Noodle Extensions"],
		"V4 unprefixed requirements and suggestions"
	)


func test_v4_converter_flattens_gameplay_and_events() -> void:
	var beatmap: Dictionary = _load_dictionary(
		"res://tests/fixtures/v4/ExpertStandard.beatmap.dat"
	)
	var lightshow: Dictionary = _load_dictionary("res://tests/fixtures/v4/Lightshow.dat")
	var converted: Dictionary = V4Converter.to_v3(beatmap, lightshow)

	var notes: Array = Utils.get_array(converted, "colorNotes", [])
	assert_eq(notes.size(), 2, "V4 color note count")
	if notes.size() >= 2:
		var first_note: Dictionary = notes[0] as Dictionary
		var second_note: Dictionary = notes[1] as Dictionary
		assert_eq(
			first_note,
			{"b": 1.0, "x": 0, "y": 1, "c": 0, "d": 1, "a": 15},
			"First V4 note should resolve to the v3 shape"
		)
		assert_eq(second_note["c"], 1, "Second note color")

	var obstacles: Array = Utils.get_array(converted, "obstacles", [])
	assert_eq(obstacles.size(), 1, "V4 obstacle count")
	if not obstacles.is_empty():
		var obstacle: Dictionary = obstacles[0] as Dictionary
		assert_eq(obstacle["w"], 2, "V4 obstacle width")
		assert_eq(obstacle["h"], 3, "V4 obstacle height")

	assert_eq(
		Utils.get_array(converted, "bombNotes", []).size(),
		1,
		"V4 bomb count"
	)

	var arcs: Array = Utils.get_array(converted, "sliders", [])
	assert_eq(arcs.size(), 1, "V4 arc count")
	if not arcs.is_empty():
		var arc: Dictionary = arcs[0] as Dictionary
		assert_eq(arc["b"], 1.0, "V4 arc head beat")
		assert_eq(arc["x"], 0, "V4 arc head lane")
		assert_eq(arc["tb"], 2.0, "V4 arc tail beat")
		assert_eq(arc["tx"], 3, "V4 arc tail lane")

	var chains: Array = Utils.get_array(converted, "burstSliders", [])
	assert_eq(chains.size(), 1, "V4 chain count")
	if not chains.is_empty():
		var chain: Dictionary = chains[0] as Dictionary
		assert_eq(chain["tx"], 2, "V4 chain tail lane")
		assert_eq(chain["sc"], 4, "V4 chain slice count")

	var events: Array = Utils.get_array(converted, "basicBeatmapEvents", [])
	assert_eq(events.size(), 2, "V4 basic event count")
	if events.size() >= 2:
		var first_event: Dictionary = events[0] as Dictionary
		var second_event: Dictionary = events[1] as Dictionary
		assert_eq(first_event["et"], 1, "First event type")
		assert_eq(first_event["i"], 5, "First event value")
		assert_eq(first_event["f"], 0.75, "First event float value")
		assert_eq(second_event["et"], 4, "Second event type")
		assert_eq(second_event["i"], 2, "Second event value")
		assert_eq(second_event["f"], 1.25, "Second event float value")

	var rotation_groups: Array = Utils.get_array(
		converted, "lightRotationEventBoxGroups", []
	)
	assert_eq(rotation_groups.size(), 1, "V4 rotation group count")
	if not rotation_groups.is_empty():
		var rotation_group: Dictionary = rotation_groups[0] as Dictionary
		assert_eq(rotation_group["g"], 1, "V4 rotation group ID")
		assert_eq(rotation_group["b"], 3.0, "V4 rotation group beat")
		var rotation_boxes: Array = Utils.get_array(rotation_group, "e", [])
		assert_eq(rotation_boxes.size(), 1, "V4 rotation box count")
		if not rotation_boxes.is_empty():
			var rotation_box: Dictionary = rotation_boxes[0] as Dictionary
			var rotation_events: Array = Utils.get_array(rotation_box, "l", [])
			assert_eq(rotation_events.size(), 1, "V4 rotation event count")
			if not rotation_events.is_empty():
				var rotation_event: Dictionary = rotation_events[0] as Dictionary
				assert_eq(rotation_event["b"], 0.5, "V4 rotation event beat offset")
				assert_eq(rotation_event["r"], 45.0, "V4 rotation amount")
				assert_eq(rotation_event["o"], 1, "V4 rotation direction")


func test_v4_map_loader_uses_separate_lightshow() -> void:
	var fixture_path: String = "res://tests/fixtures/v4/"
	var info: MapInfo = MapInfo.new_v4(
		_load_dictionary(fixture_path + "Info.dat"),
		fixture_path
	)
	var difficulty: DifficultyInfo = info.difficulty_beatmaps[0]
	var beatmap: Dictionary = _load_dictionary(
		fixture_path + difficulty.beatmap_filename
	)

	assert_true(Map.load_beatmap(info, difficulty, beatmap), "V4 map should load")
	assert_eq(Map.note_stack.size(), 2, "V4 map note stack")
	assert_eq(Map.obstacle_stack.size(), 1, "V4 map obstacle stack")
	assert_eq(Map.arc_stack.size(), 1, "V4 map arc stack")
	assert_eq(Map.chain_stack.size(), 1, "V4 map chain stack")
	assert_eq(Map.event_stack.size(), 5, "V4 basic and light group events")
	var ring_spin_count: int = 0
	for event: EventInfo in Map.event_stack:
		if event.type == EventInfo.TYPE_RING_SPIN:
			ring_spin_count += 1
	assert_true(ring_spin_count >= 1, "V4 rotation group should produce a ring spin event")


func _load_dictionary(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_true(file != null, "Fixture should be readable: %s" % path)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert_true(parsed is Dictionary, "Fixture should contain a dictionary: %s" % path)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}
