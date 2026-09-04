extends "res://tests/test_case.gd"


func test_color_note_custom_data_parsing() -> void:
	var v3: ColorNoteInfo = ColorNoteInfo.new_v3({
		"b": 1.0,
		"x": 1.0,
		"y": 0.0,
		"c": 0.0,
		"d": 1.0,
		"customData": {"color": [1.0, 0.0, 0.0]},
	})
	var v2: ColorNoteInfo = ColorNoteInfo.new_v2({
		"_time": 1.0,
		"_lineIndex": 1.0,
		"_lineLayer": 0.0,
		"_type": 0.0,
		"_cutDirection": 1.0,
		"_customData": {"color": [1.0, 0.0, 0.0]},
	})

	assert_eq(v3.custom_data, {"color": [1.0, 0.0, 0.0]}, "V3 customData should be retained")
	assert_eq(v2.custom_data, {"color": [1.0, 0.0, 0.0]}, "V2 _customData should be retained")


func test_color_note_lane_to_position() -> void:
	Constants.usingMappingExtension = false
	var expected_world_x: Array[float] = [-0.9, -0.3, 0.3, 0.9]
	for lane: int in range(4):
		var position: Vector2 = ColorNoteInfo.lane_to_position(lane, 0)
		assert_eq(position.x, float(lane), "Lane %d should retain its standard x coordinate" % lane)
		assert_eq(
			position.x * Constants.LANE_DISTANCE + Constants.LANE_ZERO_X,
			expected_world_x[lane],
			"Lane %d should map to the expected world x coordinate" % lane
		)

	Constants.usingMappingExtension = true
	assert_eq(ColorNoteInfo.lane_to_position(1500, 0).x, 0.5, "Positive precision lane")
	assert_eq(ColorNoteInfo.lane_to_position(-1500, 0).x, -0.5, "Negative precision lane")
	Constants.usingMappingExtension = false


func test_obstacle_parsing_and_geometry() -> void:
	Constants.usingMappingExtension = false
	var v2: ObstacleInfo = ObstacleInfo.new_v2({
		"_time": 0.0,
		"_duration": 1.0,
		"_type": 1.0,
		"_lineIndex": 1.0,
		"_width": 2.0,
	})
	var geometry: Dictionary = v2.get_position_and_size()
	assert_eq(geometry["position"].x, -1.0, "V2 obstacle position x")
	assert_eq(geometry["size"].x, 2.0, "V2 obstacle width")

	var v3_custom_data: Dictionary = {"color": [0.25, 0.5, 0.75]}
	var v3: ObstacleInfo = ObstacleInfo.new_v3({
		"b": 0.0,
		"x": 0.0,
		"y": 0.0,
		"d": 1.0,
		"w": 1.0,
		"h": 5.0,
		"customData": v3_custom_data,
	})
	assert_eq(v3.height, 5, "V3 obstacle height")
	assert_eq(v3.custom_data, v3_custom_data, "V3 obstacle customData")
