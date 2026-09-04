extends "res://tests/test_case.gd"


func test_fallback_mapping_distributes_unknown_groups() -> void:
	var group_ids: Array[int] = []
	for group_id: int in range(100, 110):
		group_ids.append(group_id)
	V3LightingInfo.configure_group_mapping("UnknownTestEnvironment", group_ids)

	var mapped_types: Array[int] = []
	for group_id: int in group_ids:
		var light_type: int = V3LightingInfo._map_group_to_light_type(group_id)
		assert_true(light_type >= 0, "Fallback mapping should never return -1")
		if not mapped_types.has(light_type):
			mapped_types.append(light_type)
	assert_eq(mapped_types.size(), 5, "Fallback should use all five light types")


func test_environment_lookup_is_exact_and_unknown_name_uses_fallback() -> void:
	V3LightingInfo.configure_group_mapping("TheRollingStonesEnvironment ", [0])
	assert_false(
		V3LightingInfo.active_environment_is_known(),
		"A non-exact environment name should not select the table"
	)
	assert_eq(
		V3LightingInfo._map_group_to_light_type(0),
		EventInfo.TYPE_SQUARE_LASERS,
		"An unknown environment should map its first group through fallback"
	)


func test_rolling_stones_group_table_types() -> void:
	V3LightingInfo.configure_group_mapping("TheRollingStonesEnvironment", [0, 1])
	assert_eq(
		V3LightingInfo._map_group_to_light_type(0),
		EventInfo.TYPE_LEFT_WAVING_LASERS,
		"Rolling Stones group 0 should use its table type"
	)
	assert_eq(
		V3LightingInfo._map_group_to_light_type(1),
		EventInfo.TYPE_RIGHT_WAVING_LASERS,
		"Rolling Stones group 1 should use its table type"
	)


func test_non_color_group_produces_no_color_events() -> void:
	var group_data: Dictionary = {
		"b": 1.0,
		"g": 26.0,
		"e": [{"e": [{"b": 0.0, "c": 0.0, "s": 1.0, "i": 0.0}]}],
	}
	V3LightingInfo.configure_group_mapping("TheRollingStonesEnvironment", [26])
	var group: V3LightingInfo.LightColorEventBoxGroup = (
		V3LightingInfo.LightColorEventBoxGroup.from_dict(group_data)
	)
	var events: Array[EventInfo] = group.to_event_infos(Color.RED, Color.BLUE)
	assert_eq(events.size(), 0, "A color:false group should not produce color events")


func test_color_groups_convert_to_events() -> void:
	var map_data: Dictionary = {
		"lightColorEventBoxGroups": [
			{"b": 1.0, "g": 100.0, "e": [{"e": [{"b": 0.0, "c": 0.0, "s": 1.0, "i": 0.0}]}]},
			{"b": 2.0, "g": 101.0, "e": [{"e": [{"b": 0.0, "c": 1.0, "s": 0.5, "i": 1.0}]}]},
		]
	}
	var group_ids: Array[int] = V3LightingInfo.collect_color_group_ids(map_data)
	V3LightingInfo.configure_group_mapping("UnknownFixtureEnvironment", group_ids)

	var events: Array[EventInfo] = []
	for group_value: Variant in Utils.get_array(map_data, "lightColorEventBoxGroups", []):
		var group: V3LightingInfo.LightColorEventBoxGroup = (
			V3LightingInfo.LightColorEventBoxGroup.from_dict(group_value as Dictionary)
		)
		events.append_array(group.to_event_infos(Color.RED, Color.BLUE))

	assert_true(events.size() >= 2, "Two color groups should produce at least two events")
	if events.size() >= 2:
		assert_eq(events[0].type, EventInfo.TYPE_SQUARE_LASERS, "First fallback type")
		assert_eq(events[1].type, EventInfo.TYPE_LEFT_WAVING_LASERS, "Second fallback type")


func test_index_filter_division_selects_first_half() -> void:
	var index_filter: V3LightingInfo.IndexFilter = V3LightingInfo.IndexFilter.from_dict({
		"f": 1, "p": 2, "t": 0,
	})
	assert_eq(
		V3LightingInfo.resolve_index_filter_for_count(index_filter, 8),
		[0, 1, 2, 3],
		"Division filter should select section zero"
	)


func test_index_filter_step_selects_offset_instances() -> void:
	var index_filter: V3LightingInfo.IndexFilter = V3LightingInfo.IndexFilter.from_dict({
		"f": 2, "p": 1, "t": 2,
	})
	assert_eq(
		V3LightingInfo.resolve_index_filter_for_count(index_filter, 8),
		[1, 3, 5, 7],
		"Step filter should start at p and advance by t"
	)


func test_index_filter_reverse_reverses_selected_order() -> void:
	var index_filter: V3LightingInfo.IndexFilter = V3LightingInfo.IndexFilter.from_dict({
		"f": 2, "p": 1, "t": 2, "r": 1,
	})
	assert_eq(
		V3LightingInfo.resolve_index_filter_for_count(index_filter, 8),
		[7, 5, 3, 1],
		"Reverse should apply after filtering"
	)


func test_color_group_subset_sets_light_ids_and_distributes_beats() -> void:
	var group_data: Dictionary = {
		"b": 2.0,
		"g": 0,
		"e": [
			{
				"f": {"f": 1, "p": 2, "t": 0},
				"w": 0.75,
				"d": 1,
				"e": [{"b": 0.0, "c": 0, "s": 1.0, "i": 0}],
			}
		],
	}
	V3LightingInfo.configure_group_mapping("WeaveEnvironment", [0])
	var group: V3LightingInfo.LightColorEventBoxGroup = (
		V3LightingInfo.LightColorEventBoxGroup.from_dict(group_data)
	)
	var events: Array[EventInfo] = group.to_event_infos(Color.RED, Color.BLUE)
	assert_eq(events.size(), 4, "Four selected lights should produce four events")
	var selected_ids: Array[int] = []
	var event_beats: Array[float] = []
	for event: EventInfo in events:
		assert_eq(event.lightID.size(), 1, "Subset event should target one light")
		if not event.lightID.is_empty():
			selected_ids.append(event.lightID[0])
		event_beats.append(event.beat)
	assert_eq(selected_ids, [0, 1, 2, 3], "Subset events should carry selected light IDs")
	assert_eq(
		event_beats,
		[2.0, 2.25, 2.5, 2.75],
		"Wave distribution should stagger selected lights in order"
	)


func test_color_group_subset_carries_all_ids_without_distribution() -> void:
	var group_data: Dictionary = {
		"b": 1.0,
		"g": 0,
		"e": [
			{
				"f": {"f": 2, "p": 1, "t": 2},
				"w": 0.0,
				"d": 1,
				"e": [{"b": 0.0, "c": 1, "s": 1.0, "i": 0}],
			}
		],
	}
	V3LightingInfo.configure_group_mapping("WeaveEnvironment", [0])
	var group: V3LightingInfo.LightColorEventBoxGroup = (
		V3LightingInfo.LightColorEventBoxGroup.from_dict(group_data)
	)
	var events: Array[EventInfo] = group.to_event_infos(Color.RED, Color.BLUE)
	assert_eq(events.size(), 1, "A subset without distribution should stay one event")
	if not events.is_empty():
		assert_eq(
			events[0].lightID,
			[1, 3, 5, 7],
			"Converted event should carry every selected light ID"
		)


func test_rotation_box_produces_ring_spin() -> void:
	var map_data: Dictionary = {
		"lightRotationEventBoxGroups": [
			{"b": 3.0, "g": 26.0, "e": [{"f": {}, "e": [{"b": 0.0, "p": 30.0}]}]}
		]
	}
	V3LightingInfo.configure_group_mapping("TheRollingStonesEnvironment", [])
	var events: Array[EventInfo] = V3LightingInfo.convert_rotation_groups(map_data)
	assert_eq(events.size(), 1, "A rotation:true group should produce one event")
	if not events.is_empty():
		assert_eq(events[0].type, EventInfo.TYPE_RING_SPIN, "Rotation should use v2 ring spin")


func test_color_boost_events_convert_on_and_off() -> void:
	var map_data: Dictionary = {
		"colorBoostBeatmapEvents": [
			{"b": 1.0, "o": true},
			{"b": 2.0, "o": false},
		]
	}
	var events: Array[EventInfo] = V3LightingInfo.convert_boost_events(map_data)
	assert_eq(events.size(), 2, "Boost fixture should produce two events")
	if events.size() >= 2:
		assert_eq(events[0].type, EventInfo.TYPE_COLOR_BOOST, "Boost event type")
		assert_eq(events[0].value, 1, "Boost on value")
		assert_eq(events[1].value, 0, "Boost off value")
