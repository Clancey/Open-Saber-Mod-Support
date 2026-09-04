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
