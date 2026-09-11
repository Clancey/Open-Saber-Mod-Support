extends "res://tests/test_case.gd"

const TIMELAPSE_PATH: String = "res://game/data/maps/Songs/TheFatRat_Timelapse/"
const GOLDEN_PATH: String = \
	"res://game/data/maps/Songs/48088 (Golden - sammy & Tonkie)/"


func test_timelapse_shipped_map_loads() -> void:
	_assert_shipped_map(TIMELAPSE_PATH, false)


const BUILT_IN_PATH: String = 	"res://game/data/maps/Songs/Jaroslav Beck - Beat Saber (Built in)/"


# Maps that are not part of the repository (the Songs folder is ignored by git)
# are only checked when they are present locally.
func test_golden_shipped_map_loads() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(GOLDEN_PATH)):
		print("  (skipped: %s is not present)" % GOLDEN_PATH)
		return
	_assert_shipped_map(GOLDEN_PATH, true)


func test_built_in_beat_saber_map_loads() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(BUILT_IN_PATH)):
		print("  (skipped: %s is not present)" % BUILT_IN_PATH)
		return
	_assert_shipped_map(BUILT_IN_PATH, true)


func _assert_shipped_map(map_path: String, expect_lighting: bool) -> void:
	_reset_map_state()
	var info: MapInfo = Map.load_map_info(map_path)
	assert_true(info != null, "Map info should load: %s" % map_path)
	if info == null:
		return

	assert_true(not info.song_name.is_empty(), "Song name should not be empty: %s" % map_path)
	assert_true(
		not info.difficulty_beatmaps.is_empty(),
		"Map should have at least one difficulty: %s" % map_path
	)

	for difficulty: DifficultyInfo in info.difficulty_beatmaps:
		_reset_map_stacks()
		var beatmap_filename: String = Map.find_file_case_insensitive(
			map_path, difficulty.beatmap_filename
		)
		assert_true(
			not beatmap_filename.is_empty(),
			"Difficulty file should exist: %s" % difficulty.beatmap_filename
		)
		if beatmap_filename.is_empty():
			continue

		var map_data: Dictionary = _load_dictionary(map_path + beatmap_filename)
		if map_data.is_empty():
			continue
		assert_true(
			Map.load_beatmap(info, difficulty, map_data),
			"Difficulty should load: %s" % difficulty.beatmap_filename
		)
		_assert_color_notes(difficulty.beatmap_filename)
		if expect_lighting:
			assert_true(
				not Map.obstacle_stack.is_empty(),
				"Golden obstacles should load: %s" % difficulty.beatmap_filename
			)
			assert_true(
				not Map.event_stack.is_empty(),
				"Golden lighting events should load: %s" % difficulty.beatmap_filename
			)

	_reset_map_state()


func _assert_color_notes(difficulty_name: String) -> void:
	assert_true(
		not Map.note_stack.is_empty(),
		"Color notes should load: %s" % difficulty_name
	)
	var previous_beat: float = -INF
	for index: int in range(Map.note_stack.size() - 1, -1, -1):
		var note: ColorNoteInfo = Map.note_stack[index]
		assert_true(note != null, "Color note should not be null: %s" % difficulty_name)
		if note == null:
			continue
		assert_true(
			note.beat >= previous_beat,
			"Color note beats should be non-decreasing: %s" % difficulty_name
		)
		assert_true(
			note.line_index >= -1000 and note.line_index <= 4000,
			"Color note line index should be sane: %s" % difficulty_name
		)
		previous_beat = note.beat


func _load_dictionary(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_true(file != null, "Beatmap should be readable: %s" % path)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert_true(parsed is Dictionary, "Beatmap should contain a dictionary: %s" % path)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _reset_map_stacks() -> void:
	Map.note_stack.clear()
	Map.bomb_stack.clear()
	Map.obstacle_stack.clear()
	Map.arc_stack.clear()
	Map.chain_stack.clear()
	Map.event_stack.clear()
	Map.bpm_changes.clear()


func _reset_map_state() -> void:
	_reset_map_stacks()
	Map.selected_mods.clear()
	Map.current_info = null
	Map.current_difficulty = null
