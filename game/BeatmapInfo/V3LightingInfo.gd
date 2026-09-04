extends RefCounted
class_name V3LightingInfo

# V3 Lighting Event Box Group System
# Represents the complex lighting system introduced in Beat Saber v3

const GROUP_TABLE_PATH := "res://game/data/lighting/v3_light_groups.json"
const FALLBACK_LIGHT_TYPES: Array[int] = [
	EventInfo.TYPE_SQUARE_LASERS,
	EventInfo.TYPE_LEFT_WAVING_LASERS,
	EventInfo.TYPE_RIGHT_WAVING_LASERS,
	EventInfo.TYPE_DIAGONAL_LASERS,
	EventInfo.TYPE_FLOOR_LIGHTS,
]

static var _group_tables_loaded: bool = false
static var _group_tables: Dictionary = {}
static var _active_environment_table: Dictionary = {}
static var _fallback_group_types: Dictionary = {}
static var _active_environment_known: bool = false


static func configure_group_mapping(
	environment_name: String,
	color_group_ids: Array[int],
	info_messages: Array[String] = [],
	warning_messages: Array[String] = []
) -> void:
	_load_group_tables(warning_messages)
	_active_environment_table = {}
	_fallback_group_types.clear()

	var environment_value: Variant = _group_tables.get(environment_name, {})
	if environment_value is Dictionary:
		_active_environment_table = environment_value as Dictionary
	_active_environment_known = not _active_environment_table.is_empty()

	var sorted_ids: Array[int] = []
	for group_id: int in color_group_ids:
		if not sorted_ids.has(group_id):
			sorted_ids.append(group_id)
	sorted_ids.sort()
	for index: int in range(sorted_ids.size()):
		_fallback_group_types[sorted_ids[index]] = FALLBACK_LIGHT_TYPES[index % FALLBACK_LIGHT_TYPES.size()]

	if not _active_environment_known and not sorted_ids.is_empty():
		info_messages.append(
			"v3 lighting: environment %s unknown, mapping %d groups by fallback"
			% [environment_name, sorted_ids.size()]
		)


static func _map_group_to_light_type(group_id: int) -> int:
	var group_key: String = str(group_id)
	var entry_value: Variant = _active_environment_table.get(group_key, null)
	if entry_value is Dictionary:
		var entry: Dictionary = entry_value as Dictionary
		return int(Utils.get_float(entry, "type", EventInfo.TYPE_SQUARE_LASERS))
	if _fallback_group_types.has(group_id):
		return int(_fallback_group_types[group_id])

	var fallback_index: int = posmod(group_id, FALLBACK_LIGHT_TYPES.size())
	return FALLBACK_LIGHT_TYPES[fallback_index]


static func active_environment_is_known() -> bool:
	return _active_environment_known


static func group_is_rotation_capable(group_id: int) -> bool:
	var group_key: String = str(group_id)
	var entry_value: Variant = _active_environment_table.get(group_key, null)
	if entry_value is Dictionary:
		var entry: Dictionary = entry_value as Dictionary
		if entry.has("rotation"):
			return bool(entry["rotation"])
	return _map_group_to_light_type(group_id) == EventInfo.TYPE_SQUARE_LASERS


static func group_is_color_capable(group_id: int) -> bool:
	var group_key: String = str(group_id)
	var entry_value: Variant = _active_environment_table.get(group_key, null)
	if entry_value is Dictionary:
		var entry: Dictionary = entry_value as Dictionary
		if entry.has("color"):
			return bool(entry["color"])
	return true


static func _group_light_count(group_id: int) -> int:
	var group_key: String = str(group_id)
	var entry_value: Variant = _active_environment_table.get(group_key, null)
	if entry_value is Dictionary:
		var entry: Dictionary = entry_value as Dictionary
		return maxi(int(Utils.get_float(entry, "count", 0.0)), 0)
	return 0


static func _instance_ids_for_group(group_id: int, light_type: int) -> Array[int]:
	var runtime_ids: Array[int] = LightManager.get_instance_ids_for_type(light_type)
	if not runtime_ids.is_empty():
		return runtime_ids

	var light_count: int = _group_light_count(group_id)
	if light_count <= 0:
		light_count = 4
	var result: Array[int] = []
	for light_index: int in range(light_count):
		result.append(light_index)
	return result


static func resolve_index_filter_for_count(
	index_filter: IndexFilter,
	light_count: int
) -> Array[int]:
	var result: Array[int] = []
	if light_count <= 0:
		return result
	if index_filter == null:
		for light_index: int in range(light_count):
			result.append(light_index)
		return result

	match index_filter.filter_type:
		1:
			var section_count: int = index_filter.param_0
			var section_index: int = index_filter.param_1
			if section_count > 0 and section_index >= 0 and section_index < section_count:
				var section_size: int = ceili(float(light_count) / float(section_count))
				var start_index: int = section_size * section_index
				var end_index: int = mini(start_index + section_size, light_count)
				for light_index: int in range(start_index, end_index):
					result.append(light_index)
		2:
			var start_index: int = maxi(index_filter.param_0, 0)
			var step: int = maxi(index_filter.param_1, 1)
			for light_index: int in range(start_index, light_count, step):
				result.append(light_index)
		_:
			for light_index: int in range(light_count):
				result.append(light_index)

	# Chunks and seeded randomization need environment-specific ordering unavailable here.
	if index_filter.reverse:
		result.reverse()
	if index_filter.limit > 0.0 and not result.is_empty():
		var limit_fraction: float = clampf(index_filter.limit, 0.0, 1.0)
		var limit_count: int = ceili(float(result.size()) * limit_fraction)
		result.resize(limit_count)
	return result


static func collect_color_group_ids(map_data: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for group_value: Variant in Utils.get_array(map_data, "lightColorEventBoxGroups", []):
		if not group_value is Dictionary:
			continue
		var group_data: Dictionary = group_value as Dictionary
		var group_id: int = int(Utils.get_float(group_data, "g", 0.0))
		if not result.has(group_id):
			result.append(group_id)
	result.sort()
	return result


static func convert_rotation_groups(map_data: Dictionary) -> Array[EventInfo]:
	var result: Array[EventInfo] = []
	var spin_candidate_beats: Array[float] = []
	var zoom_beats: Dictionary = {}
	for group_value: Variant in Utils.get_array(map_data, "lightRotationEventBoxGroups", []):
		if not group_value is Dictionary:
			continue
		var group_data: Dictionary = group_value as Dictionary
		var group_id: int = int(Utils.get_float(group_data, "g", 0.0))
		if _active_environment_known and not group_is_rotation_capable(group_id):
			continue

		var beat: float = Utils.get_float(group_data, "b", 0.0)
		for box_value: Variant in Utils.get_array(group_data, "e", []):
			if not box_value is Dictionary:
				continue
			if not spin_candidate_beats.has(beat):
				spin_candidate_beats.append(beat)

			var box_data: Dictionary = box_value as Dictionary
			if _rotation_box_requests_zoom(box_data) and not zoom_beats.has(beat):
				result.append(EventInfo.new(
					beat,
					EventInfo.TYPE_RING_ZOOM,
					0,
					-1.0,
					{},
					true
				))
				zoom_beats[beat] = true

	spin_candidate_beats.sort()
	var last_spin_beat: float = -INF
	for spin_beat: float in spin_candidate_beats:
		if spin_beat - last_spin_beat < 0.5:
			continue
		result.append(EventInfo.new(
			spin_beat,
			EventInfo.TYPE_RING_SPIN,
			0,
			-1.0,
			{},
			true
		))
		last_spin_beat = spin_beat
	return result


static func convert_boost_events(map_data: Dictionary) -> Array[EventInfo]:
	var result: Array[EventInfo] = []
	for event_value: Variant in Utils.get_array(map_data, "colorBoostBeatmapEvents", []):
		if not event_value is Dictionary:
			continue
		var event_data: Dictionary = event_value as Dictionary
		result.append(EventInfo.new(
			Utils.get_float(event_data, "b", 0.0),
			EventInfo.TYPE_COLOR_BOOST,
			1 if Utils.get_bool(event_data, "o", false) else 0,
			-1.0,
			{},
			true
		))
	return result


static func _rotation_box_requests_zoom(box_data: Dictionary) -> bool:
	if Utils.get_float(box_data, "l", 0.0) > 0.0:
		return true
	for event_value: Variant in Utils.get_array(box_data, "e", []):
		if not event_value is Dictionary:
			continue
		var event_data: Dictionary = event_value as Dictionary
		if Utils.get_float(event_data, "l", 0.0) > 0.0:
			return true
		if absf(Utils.get_float(event_data, "p", 0.0)) >= 90.0:
			return true
	return false


static func _load_group_tables(warning_messages: Array[String]) -> void:
	if _group_tables_loaded:
		return
	_group_tables_loaded = true
	var file: FileAccess = FileAccess.open(GROUP_TABLE_PATH, FileAccess.READ)
	if file == null:
		warning_messages.append("Unable to load v3 lighting group table: %s" % GROUP_TABLE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		var parsed_tables: Dictionary = parsed as Dictionary
		for environment_key_value: Variant in parsed_tables:
			var environment_key: String = str(environment_key_value)
			if environment_key.begins_with("_"):
				continue
			var environment_value: Variant = parsed_tables[environment_key_value]
			if environment_value is Dictionary:
				_group_tables[environment_key] = environment_value
	else:
		warning_messages.append("Invalid v3 lighting group table: %s" % GROUP_TABLE_PATH)

# Index Filter - controls which lights in a group are affected
class IndexFilter:
	var chunks: int = 1              # c: Number of chunks to divide lights into
	var filter_type: int = 1         # f: 1=Division, 2=Step and Offset
	var param_0: int = 1             # p: Parameter depends on filter_type
	var param_1: int = 0             # t: Parameter depends on filter_type
	var reverse: bool = false        # r: 0 or 1
	var random: int = 0              # n: Randomization behavior
	var seed: int = 0                # s: Random seed
	var limit: float = 0.0           # l: Limit percentage (0.0-1.0)
	var limit_behavior: int = 0      # d: Limit behavior type

	static func from_dict(data: Dictionary) -> IndexFilter:
		var filter := IndexFilter.new()
		filter.chunks = int(_get_number(data, "c", 1.0))
		filter.filter_type = int(_get_number(data, "f", 1.0))
		filter.param_0 = int(_get_number(data, "p", 1.0))
		filter.param_1 = int(_get_number(data, "t", 0.0))
		filter.reverse = int(_get_number(data, "r", 0.0)) == 1
		filter.random = int(_get_number(data, "n", 0.0))
		filter.seed = int(_get_number(data, "s", 0.0))
		filter.limit = _get_number(data, "l", 0.0)
		filter.limit_behavior = int(_get_number(data, "d", 0.0))
		return filter

	static func _get_number(data: Dictionary, key: String, default: float) -> float:
		var value: Variant = data.get(key, default)
		if value is int or value is float:
			return float(value)
		return default

# Light Color Event - a single lighting event within an event box
class LightColorEvent:
	var beat: float = 0.0            # b: Beat offset from parent
	var transition_type: int = 0     # i: 0=Instant, 1=Interpolate
	var easing: int = 0              # e: Easing type for interpolation
	var color: int = 0               # c: 0=Primary, 1=Secondary, 2=White
	var brightness: float = 1.0      # s: Brightness multiplier
	var strobe_frequency: int = 0    # f: Strobe frequency (0=no strobe)
	var strobe_brightness: float = 0.0  # sb: Brightness of strobe "off" state
	var strobe_fade: bool = false    # sf: Whether strobe fades

	static func from_dict(data: Dictionary) -> LightColorEvent:
		var event := LightColorEvent.new()
		event.beat = Utils.get_float(data, "b", 0.0)
		event.transition_type = int(Utils.get_float(data, "i", Utils.get_float(data, "p", 0.0)))
		event.easing = int(Utils.get_float(data, "e", 0))
		event.color = int(Utils.get_float(data, "c", 0))
		event.brightness = Utils.get_float(data, "s", 1.0)
		event.strobe_frequency = int(Utils.get_float(data, "f", 0))
		event.strobe_brightness = Utils.get_float(data, "sb", 0.0)
		event.strobe_fade = int(Utils.get_float(data, "sf", 0)) == 1
		return event

# Event Box - contains a collection of light events and distribution info
class LightColorEventBox:
	var index_filter: IndexFilter = null
	var beat_distribution: float = 1.0      # w: Time distribution
	var beat_distribution_type: int = 1     # d: 1=Wave, 2=Step
	var brightness_distribution: float = 1.0  # s: Brightness distribution
	var brightness_distribution_type: int = 1  # t: 1=Wave, 2=Step
	var affects_first: bool = true          # b: Whether first event is affected
	var easing: int = 0                     # i: Easing for distribution
	var events: Array[LightColorEvent] = []  # e: Array of light events

	static func from_dict(data: Dictionary) -> LightColorEventBox:
		var box := LightColorEventBox.new()

		# Parse index filter
		if data.has("f") and data["f"] is Dictionary:
			box.index_filter = IndexFilter.from_dict(data["f"])

		box.beat_distribution = Utils.get_float(data, "w", 1.0)
		box.beat_distribution_type = int(Utils.get_float(data, "d", 1))
		box.brightness_distribution = Utils.get_float(data, "s", 1.0)
		box.brightness_distribution_type = int(Utils.get_float(data, "t", 1))
		box.affects_first = int(Utils.get_float(data, "b", 1)) == 1
		box.easing = int(Utils.get_float(data, "i", 0))

		# Parse events array
		var events_data: Array = Utils.get_array(data, "e", [])
		for event_dict in events_data:
			if event_dict is Dictionary:
				box.events.append(LightColorEvent.from_dict(event_dict))

		return box

# Light Color Event Box Group - top level container
class LightColorEventBoxGroup:
	var beat: float = 0.0          # b: Beat when this group fires
	var group_id: int = 0          # g: Environment group ID
	var event_boxes: Array[LightColorEventBox] = []  # e: Array of event boxes

	static func from_dict(data: Dictionary) -> LightColorEventBoxGroup:
		var group := LightColorEventBoxGroup.new()
		group.beat = Utils.get_float(data, "b", 0.0)
		group.group_id = int(Utils.get_float(data, "g", 0))

		# Parse event boxes array
		var boxes_data: Array = Utils.get_array(data, "e", [])
		for box_dict in boxes_data:
			if box_dict is Dictionary:
				group.event_boxes.append(LightColorEventBox.from_dict(box_dict))

		return group

	# Convert V3 event box group to V2-compatible EventInfo objects
	# This allows existing V2 lighting code to work with V3 data
	func to_event_infos(left_color: Color, right_color: Color) -> Array[EventInfo]:
		var events: Array[EventInfo] = []

		if not V3LightingInfo.group_is_color_capable(group_id):
			return events

		var light_type: int = V3LightingInfo._map_group_to_light_type(group_id)

		# Process each event box
		for box: LightColorEventBox in event_boxes:
			var instance_ids: Array[int] = V3LightingInfo._instance_ids_for_group(
				group_id, light_type
			)
			var selected_indexes: Array[int] = V3LightingInfo.resolve_index_filter_for_count(
				box.index_filter, instance_ids.size()
			)
			if selected_indexes.is_empty():
				continue
			var selected_ids: Array[int] = []
			for selected_index: int in selected_indexes:
				if selected_index < 0 or selected_index >= instance_ids.size():
					continue
				selected_ids.append(instance_ids[selected_index])
			if selected_ids.is_empty():
				continue
			var uses_subset: bool = selected_ids.size() < instance_ids.size()
			var previous_event_beats: Dictionary = {}

			# Process each event in the box
			for event: LightColorEvent in box.events:
				# Convert color enum to actual color
				var event_color: Color
				match event.color:
					0:  # Primary (left color for most types)
						event_color = left_color
					1:  # Secondary (right color)
						event_color = right_color
					2:  # White
						event_color = Color.WHITE
					_:
						event_color = Color.WHITE

				# Apply brightness
				event_color = event_color * event.brightness

				var event_value: int = _event_value(event)
				var uses_distribution: bool = (
					uses_subset
					and selected_ids.size() > 1
					and not is_zero_approx(box.beat_distribution)
				)
				var target_count: int = selected_ids.size() if uses_distribution else 1
				for target_index: int in range(target_count):
					var distribution_offset: float = 0.0
					var previous_key: int = -1
					if uses_distribution:
						distribution_offset = _beat_distribution_offset(
							box, target_index, selected_ids.size()
						)
						previous_key = selected_ids[target_index]
					var logical_event_beat: float = beat + event.beat + distribution_offset
					var event_beat: float = logical_event_beat

					# Create EventInfo with Chroma color and lightID.
					var custom_data: Dictionary = {}
					custom_data["color"] = [event_color.r, event_color.g, event_color.b]
					custom_data["_v3PaletteColor"] = event.color
					custom_data["_v3Brightness"] = event.brightness
					if event.transition_type == 1 and previous_event_beats.has(previous_key):
						var previous_event_beat: float = float(
							previous_event_beats[previous_key]
						)
						var fade_duration_beats: float = (
							logical_event_beat - previous_event_beat
						)
						if fade_duration_beats > 0.0:
							custom_data["_v3FadeDurationBeats"] = fade_duration_beats
							event_beat = previous_event_beat
					if uses_distribution:
						custom_data["lightID"] = [selected_ids[target_index]]
					elif uses_subset:
						custom_data["lightID"] = selected_ids

					var event_info: EventInfo = EventInfo.new(
						event_beat,
						light_type,
						event_value,
						-1.0,
						custom_data,
						true
					)

					events.append(event_info)
					previous_event_beats[previous_key] = logical_event_beat

		return events

	static func _beat_distribution_offset(
		box: LightColorEventBox,
		selected_index: int,
		selected_count: int
	) -> float:
		if selected_count <= 1:
			return 0.0
		if box.beat_distribution_type == 2:
			return box.beat_distribution * float(selected_index)
		return (
			box.beat_distribution
			* float(selected_index)
			/ float(selected_count - 1)
		)

	static func _event_value(event: LightColorEvent) -> int:
		if event.brightness <= 0.0:
			return EventInfo.VALUE_LIGHTS_OFF
		if event.strobe_frequency > 0:
			match event.color:
				0:
					return EventInfo.VALUE_LIGHTS_LEFT_FLASH
				1:
					return EventInfo.VALUE_LIGHTS_RIGHT_FLASH
				_:
					return EventInfo.VALUE_LIGHTS_WHITE_FLASH
		if event.transition_type == 0:
			match event.color:
				0:
					return EventInfo.VALUE_LIGHTS_LEFT_ON
				1:
					return EventInfo.VALUE_LIGHTS_RIGHT_ON
				_:
					return EventInfo.VALUE_LIGHTS_WHITE_ON
		match event.color:
			0:
				return EventInfo.VALUE_LIGHTS_FADE_TO_LEFT
			1:
				return EventInfo.VALUE_LIGHTS_FADE_TO_RIGHT
			_:
				return EventInfo.VALUE_LIGHTS_FADE_TO_WHITE
