extends "res://tests/test_case.gd"


func test_beat_second_conversion_with_bpm_changes() -> void:
	var difficulties: Array[DifficultyInfo] = []
	Map.current_info = MapInfo.new(
		"2.0.0", "", "", "", "", 120.0, 0.0, 0.0, "", "", "", 0.0, {}, "", difficulties
	)
	Map.bpm_changes.clear()

	assert_eq(Map.beat_to_seconds(8.0), 4.0, "Eight beats at 120 BPM")
	assert_eq(Map.seconds_to_beat(4.0), 8.0, "Four seconds at 120 BPM")

	Map.bpm_changes.append(BpmChangeInfo.new(4.0, 240.0))
	assert_eq(Map.beat_to_seconds(8.0), 3.0, "BPM change beat-to-seconds conversion")
	assert_eq(Map.seconds_to_beat(3.0), 8.0, "BPM change seconds-to-beat conversion")
	Map.bpm_changes.clear()


func test_load_note_stack_v2_skips_non_dictionaries() -> void:
	var fixture_file: FileAccess = FileAccess.open(
		"res://tests/fixtures/mixed_notes_v2.json", FileAccess.READ
	)
	assert_true(fixture_file != null, "Mixed-note fixture should be readable")
	if fixture_file == null:
		return

	var note_data: Variant = JSON.parse_string(fixture_file.get_as_text())
	assert_true(note_data is Array, "Mixed-note fixture should contain an array")
	if not note_data is Array:
		return

	Map.load_note_stack_v2(note_data)
	assert_eq(Map.note_stack.size(), 2, "Only dictionary color notes should be loaded")


func test_map_info_v2_parses_color_scheme() -> void:
	var info_data: Dictionary = {
		"_version": "2.1.0",
		"_colorSchemes": [{
			"useOverride": true,
			"colorScheme": {
				"saberAColor": {"r": 0.8, "g": 0.2, "b": 0.1, "a": 1.0},
				"saberBColor": {"r": 0.1, "g": 0.2, "b": 0.8, "a": 1.0},
			},
		}],
		"_difficultyBeatmapSets": [{
			"_difficultyBeatmaps": [{
				"_difficulty": "Expert",
				"_difficultyRank": 7.0,
				"_beatmapFilename": "Expert.dat",
				"_beatmapColorSchemeIdx": 0.0,
				"_environmentNameIdx": 1.0,
			}],
		}],
	}
	var info: MapInfo = MapInfo.new_v2(info_data, "")
	var scheme_entry: Dictionary = info.color_schemes[0]
	var scheme: Dictionary = scheme_entry["colorScheme"] as Dictionary
	var saber_a: Dictionary = scheme["saberAColor"] as Dictionary

	assert_eq(saber_a["r"], 0.8, "V2 saber A color")
	assert_eq(info.difficulty_beatmaps[0].color_scheme_index, 0, "V2 color scheme index")
	assert_eq(info.difficulty_beatmaps[0].environment_name_index, 1, "V2 environment index")


func test_map_uses_enabled_v2_color_scheme() -> void:
	var original_disable_map_color: bool = Settings.disable_map_color
	var original_left: Color = Settings.color_left
	var original_right: Color = Settings.color_right
	Settings.disable_map_color = false
	Settings.color_left = Color("ff1a1a")
	Settings.color_right = Color("1a1aff")
	var difficulty: DifficultyInfo = DifficultyInfo.new(
		"Expert", 7, "", 10.0, 0.0, {}, "Expert"
	)
	difficulty.color_scheme_index = 0
	var difficulties: Array[DifficultyInfo] = [difficulty]
	Map.current_info = MapInfo.new(
		"2.1.0", "", "", "", "", 120.0, 0.0, 0.0, "", "", "", 0.0, {}, "", difficulties
	)
	Map.current_info.color_schemes = [{
		"useOverride": true,
		"colorScheme": {
			"saberAColor": {"r": 0.8, "g": 0.2, "b": 0.1, "a": 1.0},
			"saberBColor": {"r": 0.1, "g": 0.2, "b": 0.8, "a": 1.0},
		},
	}]
	Map.current_difficulty = difficulty

	Map.set_colors_from_custom_data()

	assert_eq(Map.color_left, Color(0.8, 0.2, 0.1, 1.0), "Scheme left saber color")
	assert_eq(Map.color_right, Color(0.1, 0.2, 0.8, 1.0), "Scheme right saber color")
	Settings.disable_map_color = original_disable_map_color
	Settings.color_left = original_left
	Settings.color_right = original_right


func test_map_ignores_disabled_v2_color_scheme() -> void:
	var original_disable_map_color: bool = Settings.disable_map_color
	var original_left: Color = Settings.color_left
	var original_right: Color = Settings.color_right
	var settings_left: Color = Color(0.9, 0.1, 0.2, 1.0)
	var settings_right: Color = Color(0.2, 0.1, 0.9, 1.0)
	Settings.disable_map_color = false
	Settings.color_left = settings_left
	Settings.color_right = settings_right
	var difficulty: DifficultyInfo = DifficultyInfo.new(
		"Expert", 7, "", 10.0, 0.0, {}, "Expert"
	)
	difficulty.color_scheme_index = 0
	var difficulties: Array[DifficultyInfo] = [difficulty]
	Map.current_info = MapInfo.new(
		"2.1.0", "", "", "", "", 120.0, 0.0, 0.0, "", "", "", 0.0, {}, "", difficulties
	)
	Map.current_info.color_schemes = [{
		"useOverride": false,
		"colorScheme": {
			"saberAColor": {"r": 0.8, "g": 0.2, "b": 0.1, "a": 1.0},
			"saberBColor": {"r": 0.1, "g": 0.2, "b": 0.8, "a": 1.0},
		},
	}]
	Map.current_difficulty = difficulty

	Map.set_colors_from_custom_data()

	assert_eq(Map.color_left, settings_left, "Disabled scheme uses settings left color")
	assert_eq(Map.color_right, settings_right, "Disabled scheme uses settings right color")
	Settings.disable_map_color = original_disable_map_color
	Settings.color_left = original_left
	Settings.color_right = original_right


func test_settings_replaces_black_saber_color_with_default() -> void:
	var validated: Color = Settings._validate_loaded_saber_color(
		Color.BLACK, Settings.DEFAULT_COLOR_LEFT, &"color_left"
	)
	assert_eq(validated, Settings.DEFAULT_COLOR_LEFT, "Black saber color uses documented default")
