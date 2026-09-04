extends "res://tests/test_case.gd"


func test_v3_coordinates_match_vanilla_lane_zero() -> void:
	_set_flags(true, false, false)
	var vanilla := ColorNoteInfo.new_v3({
		"b": 1.0, "x": 0.0, "y": 0.0, "c": 0.0, "d": 1.0,
	})
	var noodle := ColorNoteInfo.new_v3({
		"b": 1.0,
		"x": 3.0,
		"y": 2.0,
		"c": 0.0,
		"d": 1.0,
		"customData": {"coordinates": [-2.0, 0.0]},
	})
	var vanilla_world_x := (
		vanilla.get_position().x * Constants.LANE_DISTANCE + Constants.LANE_ZERO_X
	)
	var noodle_world_x := (
		noodle.get_position().x * Constants.LANE_DISTANCE + Constants.LANE_ZERO_X
	)

	assert_true(noodle.has_custom_position, "V3 coordinates should be parsed")
	assert_eq(noodle_world_x, vanilla_world_x, "Noodle x=-2 should match vanilla lane 0")
	_reset_flags()


func test_v2_position_is_parsed() -> void:
	_set_flags(true, false, false)
	var note := ColorNoteInfo.new_v2({
		"_time": 1.0,
		"_lineIndex": 3.0,
		"_lineLayer": 2.0,
		"_type": 0.0,
		"_cutDirection": 1.0,
		"_customData": {"_position": [-1.0, 1.5]},
	})

	assert_true(note.has_custom_position, "V2 _position should be parsed")
	assert_eq(note.get_position(), Vector2(1.0, 1.5), "V2 position should use Noodle coordinates")
	_reset_flags()


func test_v3_uninteractable_is_parsed() -> void:
	_set_flags(true, false, false)
	var note := ColorNoteInfo.new_v3({
		"b": 1.0,
		"x": 0.0,
		"y": 0.0,
		"c": 0.0,
		"d": 1.0,
		"customData": {"uninteractable": true},
	})

	assert_true(note.uninteractable, "V3 uninteractable should disable interaction")
	_reset_flags()


func test_v3_obstacle_size_keeps_null_height() -> void:
	_set_flags(true, false, false)
	var obstacle := ObstacleInfo.new_v3({
		"b": 1.0,
		"x": 0.0,
		"y": 0.0,
		"d": 2.0,
		"w": 1.0,
		"h": 5.0,
		"customData": {"size": [2.0, null, 3.0]},
	})
	var geometry: Dictionary = obstacle.get_position_and_size()
	var size: Vector2 = geometry["size"] as Vector2

	assert_true(obstacle.has_custom_size, "V3 obstacle size should be parsed")
	assert_eq(size.x, 2.0, "Custom obstacle width")
	assert_eq(size.y, 5.0, "Null custom height should retain vanilla height")
	assert_eq(float(geometry["depth"]), 3.0, "Custom obstacle depth")
	_reset_flags()


func test_v3_local_rotation_is_parsed() -> void:
	_set_flags(true, false, false)
	var note := ColorNoteInfo.new_v3({
		"b": 1.0,
		"x": 0.0,
		"y": 0.0,
		"c": 0.0,
		"d": 1.0,
		"customData": {"localRotation": [0.0, 45.0, 0.0]},
	})

	assert_true(note.has_local_rotation, "V3 localRotation should be parsed")
	assert_eq(note.local_rotation_degrees, Vector3(0.0, 45.0, 0.0))
	_reset_flags()


func test_track_and_animation_are_ignored() -> void:
	_set_flags(true, true, false)
	var note := ColorNoteInfo.new_v3({
		"b": 1.0,
		"x": 0.0,
		"y": 0.0,
		"c": 0.0,
		"d": 1.0,
		"customData": {
			"track": "ignored-track",
			"animation": {"offsetPosition": [[0.0, 0.0, 0.0, 0.0]]},
		},
	})

	assert_true(
		not note.has_custom_position, "Ignored keys should not create a position override"
	)
	assert_true(
		not note.has_world_rotation, "Ignored keys should not create a world rotation override"
	)
	assert_true(
		not note.has_local_rotation, "Ignored keys should not create a local rotation override"
	)
	assert_true(
		not note.has_note_jump_movement_speed,
		"Ignored keys should not create an NJS override"
	)
	assert_true(not note.uninteractable, "Ignored keys should not disable interaction")
	_reset_flags()


func _set_flags(noodle: bool, chroma: bool, mapping: bool) -> void:
	Constants.usingNoodleExtension = noodle
	Constants.usingChroma = chroma
	Constants.usingMappingExtension = mapping


func _reset_flags() -> void:
	_set_flags(false, false, false)
