extends RefCounted
class_name ObstacleInfo

var beat: float
var duration: float
var line_index: int
var line_layer: int
var width: int
var height: int
var custom_data: Dictionary
var type: int
var is_v2: bool = false
var custom_position: Vector2
var has_custom_position: bool = false
var world_rotation_degrees: Vector3 = Vector3.ZERO
var has_world_rotation: bool = false
var local_rotation_degrees: Vector3 = Vector3.ZERO
var has_local_rotation: bool = false
var note_jump_movement_speed: float = 0.0
var has_note_jump_movement_speed: bool = false
var note_jump_start_beat_offset: float = 0.0
var has_note_jump_start_beat_offset: bool = false
var uninteractable: bool = false
var fake: bool = false
var custom_color: Color = Color.TRANSPARENT
var has_custom_color: bool = false
var custom_size: Vector3
var has_custom_size: bool = false
var has_custom_width: bool = false
var has_custom_height: bool = false
var has_custom_depth: bool = false

@warning_ignore("shadowed_variable")
func _init(
	beat: float,
	duration: float,
	line_index: int,
	line_layer: int,
	width: int,
	height: int,
	custom_data: Dictionary,
	type: int,
	is_v2_format: bool = false,
	from_fake_collection: bool = false
) -> void:
	self.beat = beat
	self.duration = duration
	self.line_index = line_index
	self.line_layer = line_layer
	self.width = width
	self.height = height
	self.custom_data = custom_data
	self.type = type
	self.is_v2 = is_v2_format

	var vanilla_position := ColorNoteInfo.lane_to_position(line_index, line_layer)
	has_custom_position = ColorNoteInfo.NoodleData.has_coordinates(custom_data, is_v2)
	custom_position = ColorNoteInfo.NoodleData.get_coordinates(custom_data, is_v2, vanilla_position)
	has_world_rotation = ColorNoteInfo.NoodleData.has_world_rotation(custom_data, is_v2)
	world_rotation_degrees = ColorNoteInfo.NoodleData.get_world_rotation(custom_data, is_v2)
	has_local_rotation = ColorNoteInfo.NoodleData.has_local_rotation(custom_data, is_v2)
	local_rotation_degrees = ColorNoteInfo.NoodleData.get_local_rotation(custom_data, is_v2)
	has_note_jump_movement_speed = ColorNoteInfo.NoodleData.has_note_jump_movement_speed(custom_data, is_v2)
	note_jump_movement_speed = ColorNoteInfo.NoodleData.get_note_jump_movement_speed(custom_data, is_v2, 0.0)
	has_note_jump_start_beat_offset = ColorNoteInfo.NoodleData.has_note_jump_start_beat_offset(custom_data, is_v2)
	note_jump_start_beat_offset = ColorNoteInfo.NoodleData.get_note_jump_start_beat_offset(custom_data, is_v2, 0.0)
	fake = ColorNoteInfo.NoodleData.is_fake(custom_data, is_v2, from_fake_collection)
	uninteractable = ColorNoteInfo.NoodleData.is_uninteractable(custom_data, is_v2) or fake
	has_custom_color = ColorNoteInfo.NoodleData.has_color(custom_data)
	custom_color = ColorNoteInfo.NoodleData.get_color(custom_data, Color.TRANSPARENT)
	has_custom_size = ColorNoteInfo.NoodleData.has_obstacle_size(custom_data, is_v2)
	has_custom_width = ColorNoteInfo.NoodleData.has_obstacle_size_component(custom_data, is_v2, 0)
	has_custom_height = ColorNoteInfo.NoodleData.has_obstacle_size_component(custom_data, is_v2, 1)
	has_custom_depth = ColorNoteInfo.NoodleData.has_obstacle_size_component(custom_data, is_v2, 2)
	custom_size = ColorNoteInfo.NoodleData.get_obstacle_size(
		custom_data, is_v2, Vector3(float(width), float(height), duration)
	)

# Get proper position and size accounting for Mapping Extensions precision encoding
func get_position_and_size() -> Dictionary:
	var position_x := float(line_index)
	var position_y := float(line_layer)
	var width_f := float(width)
	var height_f := float(height)

	# Mapping Extensions precision width encoding
	if Constants.usingMappingExtension and width >= 1000:
		width_f = (float(width) - 1000.0) / 1000.0

	# Mapping Extensions precision position encoding
	if Constants.usingMappingExtension:
		if line_index >= 1000:
			position_x = ((float(line_index) - 1000.0) / 1000.0) - 2.0
		elif line_index <= -1000:
			position_x = (float(line_index) + 1000.0) / 1000.0 - 2.0
		else:
			position_x = float(line_index) - 2.0  # Center standard positions at 0
	else:
		position_x = float(line_index) - 2.0

	# V2 Type-based height encoding (Mapping Extensions)
	if is_v2 and Constants.usingMappingExtension and type >= 2:
		var units_to_full_height := 1000.0 / 3.5

		if type >= 2 and type < 1000:
			# Type 2-999: start height encoding
			position_y = float(type) / units_to_full_height
			height_f = 3.5
		elif type >= 1000 and type <= 4000:
			# Type 1000-4000: height control
			position_y = 0.0
			height_f = (float(type) - 1000.0) / units_to_full_height
		elif type >= 4001:
			# Type 4001+: combined height and start height
			var modified_type := float(type - 4001)
			position_y = fmod(modified_type, 1000.0) / units_to_full_height
			height_f = floor(modified_type / 1000.0) / units_to_full_height

	# V3 direct height and position (or standard V2 types 0 and 1)
	if not is_v2 or type < 2:
		# Standard positioning
		position_y = float(line_layer)
		height_f = float(height)

	if has_custom_position:
		position_x = custom_position.x - ColorNoteInfo.NoodleData.NOODLE_X_OFFSET
		position_y = custom_position.y
	if has_custom_width:
		width_f = custom_size.x
	if has_custom_height:
		height_f = custom_size.y

	return {
		"position": Vector2(position_x, position_y),
		"size": Vector2(width_f, height_f),
		"depth": custom_size.z if has_custom_depth else duration,
		"has_custom_depth": has_custom_depth,
	}

func get_color(default_value: Color) -> Color:
	return custom_color if has_custom_color else default_value

func get_note_jump_movement_speed(default_value: float) -> float:
	return note_jump_movement_speed if has_note_jump_movement_speed else default_value

func get_note_jump_start_beat_offset(default_value: float) -> float:
	return note_jump_start_beat_offset if has_note_jump_start_beat_offset else default_value

func get_spawn_ahead_beats(default_value: float, default_offset: float) -> float:
	return maxf(0.0, default_value + get_note_jump_start_beat_offset(default_offset) - default_offset)

static func new_v2(obstacle_dict: Dictionary) -> ObstacleInfo:
	var y: int = 0
	var h: int = 0
	var obstacle_type := int(Utils.get_float(obstacle_dict, "_type", 0))

	if obstacle_type == 0:
		y = 0
		h = 5
	elif obstacle_type == 1:
		y = 2
		h = 3
	elif obstacle_type >= 2:
		y = int(Utils.get_float(obstacle_dict, "_lineLayer", 0))
		h = int(Utils.get_float(obstacle_dict, "_height", 0))

	return ObstacleInfo.new(
		Utils.get_float(obstacle_dict, "_time", 0.0),
		Utils.get_float(obstacle_dict, "_duration", 0.0),
		int(Utils.get_float(obstacle_dict, "_lineIndex", 0)),
		y,
		int(Utils.get_float(obstacle_dict, "_width", 0)),
		h,
		Utils.get_dict(obstacle_dict, "_customData", {}),
		obstacle_type,
		true  # is_v2 = true
	)

static func new_v3(obstacle_dict: Dictionary, from_fake_collection: bool = false) -> ObstacleInfo:
	return ObstacleInfo.new(
		Utils.get_float(obstacle_dict, "b", 0.0),
		Utils.get_float(obstacle_dict, "d", 0.0),
		int(Utils.get_float(obstacle_dict, "x", 0)),
		int(Utils.get_float(obstacle_dict, "y", 0)),
		int(Utils.get_float(obstacle_dict, "w", 0)),
		int(Utils.get_float(obstacle_dict, "h", 0)),
		Utils.get_dict(obstacle_dict, "customData", {}),
		0,
		false,  # is_v2 = false
		from_fake_collection
	)
