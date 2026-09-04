extends RefCounted
class_name ColorNoteInfo

class NoodleData:
	const NOODLE_X_OFFSET := 2.0

	static func has_coordinates(custom_data: Dictionary, is_v2: bool, tail: bool = false) -> bool:
		if not Constants.usingNoodleExtension:
			return false
		var key: String
		if tail:
			key = "_tailPosition" if is_v2 else "tailCoordinates"
		else:
			key = "_position" if is_v2 else "coordinates"
		return _has_numeric_array_component(custom_data, key, 2)

	static func get_coordinates(
		custom_data: Dictionary, is_v2: bool, vanilla: Vector2, tail: bool = false
	) -> Vector2:
		if not has_coordinates(custom_data, is_v2, tail):
			return vanilla
		var key: String
		if tail:
			key = "_tailPosition" if is_v2 else "tailCoordinates"
		else:
			key = "_position" if is_v2 else "coordinates"
		var values: Array = custom_data[key] as Array
		var result := vanilla
		var x_value: Variant = values[0]
		var y_value: Variant = values[1]
		if _is_number(x_value):
			# Noodle coordinates are centered around the middle of the four lanes:
			# x=-2 is vanilla lane 0. Store game-lane coordinates so all spawners
			# can keep using LANE_DISTANCE + LANE_ZERO_X.
			result.x = float(x_value) + NOODLE_X_OFFSET
		if _is_number(y_value):
			result.y = float(y_value)
		return result

	static func has_world_rotation(custom_data: Dictionary, is_v2: bool) -> bool:
		if not Constants.usingNoodleExtension:
			return false
		var key := "_rotation" if is_v2 else "worldRotation"
		if not custom_data.has(key):
			return false
		var value: Variant = custom_data[key]
		if _is_number(value):
			return true
		if value is Array:
			var values: Array = value as Array
			return values.size() >= 3 and _is_number(values[1])
		return false

	static func get_world_rotation(custom_data: Dictionary, is_v2: bool) -> Vector3:
		if not has_world_rotation(custom_data, is_v2):
			return Vector3.ZERO
		var key := "_rotation" if is_v2 else "worldRotation"
		var value: Variant = custom_data[key]
		if _is_number(value):
			return Vector3(0.0, float(value), 0.0)
		var values: Array = value as Array
		return Vector3(
			_number_or_default(values[0], 0.0),
			_number_or_default(values[1], 0.0),
			_number_or_default(values[2], 0.0)
		)

	static func has_local_rotation(custom_data: Dictionary, is_v2: bool) -> bool:
		if not Constants.usingNoodleExtension:
			return false
		var key := "_localRotation" if is_v2 else "localRotation"
		return _has_numeric_array_component(custom_data, key, 3)

	static func get_local_rotation(custom_data: Dictionary, is_v2: bool) -> Vector3:
		if not has_local_rotation(custom_data, is_v2):
			return Vector3.ZERO
		var key := "_localRotation" if is_v2 else "localRotation"
		var values: Array = custom_data[key] as Array
		return Vector3(
			_number_or_default(values[0], 0.0),
			_number_or_default(values[1], 0.0),
			_number_or_default(values[2], 0.0)
		)

	static func has_note_jump_movement_speed(custom_data: Dictionary, is_v2: bool) -> bool:
		var key := "_noteJumpMovementSpeed" if is_v2 else "noteJumpMovementSpeed"
		return Constants.usingNoodleExtension and _has_number(custom_data, key)

	static func get_note_jump_movement_speed(
		custom_data: Dictionary, is_v2: bool, default_value: float
	) -> float:
		var key := "_noteJumpMovementSpeed" if is_v2 else "noteJumpMovementSpeed"
		return _get_number(custom_data, key, default_value)

	static func has_note_jump_start_beat_offset(custom_data: Dictionary, is_v2: bool) -> bool:
		var key := "_noteJumpStartBeatOffset" if is_v2 else "noteJumpStartBeatOffset"
		return Constants.usingNoodleExtension and _has_number(custom_data, key)

	static func get_note_jump_start_beat_offset(
		custom_data: Dictionary, is_v2: bool, default_value: float
	) -> float:
		var key := "_noteJumpStartBeatOffset" if is_v2 else "noteJumpStartBeatOffset"
		return _get_number(custom_data, key, default_value)

	static func is_uninteractable(custom_data: Dictionary, is_v2: bool) -> bool:
		if not Constants.usingNoodleExtension:
			return false
		if is_v2:
			return (
				custom_data.has("_interactable")
				and custom_data["_interactable"] is bool
				and not bool(custom_data["_interactable"])
			)
		return (
			custom_data.has("uninteractable")
			and custom_data["uninteractable"] is bool
			and bool(custom_data["uninteractable"])
		)

	static func is_fake(
		custom_data: Dictionary, is_v2: bool, from_fake_collection: bool = false
	) -> bool:
		if not Constants.usingNoodleExtension:
			return false
		if from_fake_collection:
			return true
		var key := "_fake" if is_v2 else "fake"
		return custom_data.has(key) and custom_data[key] is bool and bool(custom_data[key])

	static func has_color(custom_data: Dictionary) -> bool:
		if not Constants.usingChroma:
			return false
		var keys: Array[String] = ["color", "_color"]
		for key: String in keys:
			if not custom_data.has(key) or not custom_data[key] is Array:
				continue
			var values: Array = custom_data[key] as Array
			if values.size() < 3:
				continue
			var valid := true
			for index: int in range(mini(values.size(), 4)):
				if not _is_number(values[index]):
					valid = false
					break
			if valid:
				return true
		return false

	static func get_color(custom_data: Dictionary, default_value: Color) -> Color:
		if not has_color(custom_data):
			return default_value
		return Utils.get_color(custom_data, default_value)

	static func has_obstacle_size(custom_data: Dictionary, is_v2: bool) -> bool:
		if not Constants.usingNoodleExtension:
			return false
		var key := "_scale" if is_v2 else "size"
		return _has_numeric_array_component(custom_data, key, 3)

	static func has_obstacle_size_component(
		custom_data: Dictionary, is_v2: bool, component: int
	) -> bool:
		if not Constants.usingNoodleExtension:
			return false
		var key := "_scale" if is_v2 else "size"
		if not custom_data.has(key) or not custom_data[key] is Array:
			return false
		var values: Array = custom_data[key] as Array
		return component >= 0 and component < values.size() and _is_number(values[component])

	static func get_obstacle_size(
		custom_data: Dictionary, is_v2: bool, vanilla: Vector3
	) -> Vector3:
		if not has_obstacle_size(custom_data, is_v2):
			return vanilla
		var key := "_scale" if is_v2 else "size"
		var values: Array = custom_data[key] as Array
		var result := vanilla
		if _is_number(values[0]):
			result.x = float(values[0])
		if _is_number(values[1]):
			result.y = float(values[1])
		if _is_number(values[2]):
			result.z = float(values[2])
		return result

	static func apply_rotations(
		node: Node3D,
		base_z_rotation: float,
		local_rotation_degrees: Vector3,
		has_local: bool,
		world_rotation_degrees: Vector3,
		has_world: bool
	) -> void:
		var local_rotation := Vector3.ZERO
		if has_local:
			local_rotation = Vector3(
				deg_to_rad(local_rotation_degrees.x),
				deg_to_rad(local_rotation_degrees.y),
				deg_to_rad(local_rotation_degrees.z)
			)
		local_rotation.z += base_z_rotation
		node.rotation = local_rotation

		if has_world:
			# Noodle worldRotation supports XYZ, but this Y-up game currently
			# applies only the Y component. X/Z are intentionally ignored.
			var world_y := deg_to_rad(world_rotation_degrees.y)
			node.transform.origin = node.transform.origin.rotated(Vector3.UP, world_y)
			node.transform.basis = Basis(Vector3.UP, world_y) * node.transform.basis

	static func get_movement_direction(
		world_rotation_degrees: Vector3, has_world: bool
	) -> Vector3:
		if not has_world:
			return Vector3.BACK
		return Vector3.BACK.rotated(
			Vector3.UP, deg_to_rad(world_rotation_degrees.y)
		)

	static func _has_numeric_array_component(
		custom_data: Dictionary, key: String, required_size: int
	) -> bool:
		if not custom_data.has(key) or not custom_data[key] is Array:
			return false
		var values: Array = custom_data[key] as Array
		if values.size() < required_size:
			return false
		var has_number := false
		for index: int in range(required_size):
			if _is_number(values[index]):
				has_number = true
			elif values[index] != null:
				return false
		return has_number

	static func _has_number(custom_data: Dictionary, key: String) -> bool:
		return custom_data.has(key) and _is_number(custom_data[key])

	static func _get_number(custom_data: Dictionary, key: String, default_value: float) -> float:
		if not Constants.usingNoodleExtension or not _has_number(custom_data, key):
			return default_value
		return float(custom_data[key])

	static func _number_or_default(value: Variant, default_value: float) -> float:
		return float(value) if _is_number(value) else default_value

	static func _is_number(value: Variant) -> bool:
		return value is int or value is float

var beat: float
var line_index: int
var line_layer: int
var color: int
var cut_direction: int
var angle_offset: int
var custom_data: Dictionary
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

@warning_ignore("shadowed_variable")
func _init(
	beat: float,
	line_index: int,
	line_layer: int,
	color: int,
	cut_direction: int,
	angle_offset: int,
	custom_data: Dictionary,
	is_v2: bool = false,
	from_fake_collection: bool = false
) -> void:
	self.beat = beat
	self.line_index = line_index
	self.line_layer = line_layer
	self.color = color
	self.cut_direction = cut_direction
	self.angle_offset = angle_offset
	self.custom_data = custom_data

	var vanilla_position := lane_to_position(line_index, line_layer)
	has_custom_position = NoodleData.has_coordinates(custom_data, is_v2)
	custom_position = NoodleData.get_coordinates(custom_data, is_v2, vanilla_position)
	has_world_rotation = NoodleData.has_world_rotation(custom_data, is_v2)
	world_rotation_degrees = NoodleData.get_world_rotation(custom_data, is_v2)
	has_local_rotation = NoodleData.has_local_rotation(custom_data, is_v2)
	local_rotation_degrees = NoodleData.get_local_rotation(custom_data, is_v2)
	has_note_jump_movement_speed = NoodleData.has_note_jump_movement_speed(custom_data, is_v2)
	note_jump_movement_speed = NoodleData.get_note_jump_movement_speed(custom_data, is_v2, 0.0)
	has_note_jump_start_beat_offset = NoodleData.has_note_jump_start_beat_offset(custom_data, is_v2)
	note_jump_start_beat_offset = NoodleData.get_note_jump_start_beat_offset(custom_data, is_v2, 0.0)
	fake = NoodleData.is_fake(custom_data, is_v2, from_fake_collection)
	uninteractable = NoodleData.is_uninteractable(custom_data, is_v2) or fake
	has_custom_color = NoodleData.has_color(custom_data)
	custom_color = NoodleData.get_color(custom_data, Color.TRANSPARENT)

# Get position accounting for Mapping Extensions precision placement
func get_position() -> Vector2:
	if has_custom_position:
		return custom_position
	return lane_to_position(line_index, line_layer)

func get_color(default_value: Color) -> Color:
	return custom_color if has_custom_color else default_value

func get_note_jump_movement_speed(default_value: float) -> float:
	return note_jump_movement_speed if has_note_jump_movement_speed else default_value

func get_note_jump_start_beat_offset(default_value: float) -> float:
	return note_jump_start_beat_offset if has_note_jump_start_beat_offset else default_value

func get_spawn_ahead_beats(default_value: float, default_offset: float) -> float:
	return maxf(0.0, default_value + get_note_jump_start_beat_offset(default_offset) - default_offset)

static func lane_to_position(line_index: int, line_layer: int) -> Vector2:
	var position_x := float(line_index)
	var position_y := float(line_layer)

	# Mapping Extensions precision position encoding
	if Constants.usingMappingExtension:
		if line_index >= 1000:
			position_x = (float(line_index) - 1000.0) / 1000.0
		elif line_index <= -1000:
			position_x = (float(line_index) + 1000.0) / 1000.0

		if line_layer >= 1000:
			position_y = (float(line_layer) - 1000.0) / 1000.0
		elif line_layer <= -1000:
			position_y = (float(line_layer) + 1000.0) / 1000.0

	return Vector2(position_x, position_y)

static func new_v2(note_dict: Dictionary) -> ColorNoteInfo:
	return ColorNoteInfo.new(
		Utils.get_float(note_dict, "_time", 0.0), 
		int(Utils.get_float(note_dict, "_lineIndex", 0)), 
		int(Utils.get_float(note_dict, "_lineLayer", 0)), 
		int(Utils.get_float(note_dict, "_type", -1.0)), 
		int(Utils.get_float(note_dict, "_cutDirection", 0)), 
		0, 
		Utils.get_dict(note_dict, "_customData", {}),
		true
	)

static func new_v3(note_dict: Dictionary, from_fake_collection: bool = false) -> ColorNoteInfo:
	return ColorNoteInfo.new(
		Utils.get_float(note_dict, "b", 0.0), 
		int(Utils.get_float(note_dict, "x", 0)), 
		int(Utils.get_float(note_dict, "y", 0)), 
		int(Utils.get_float(note_dict, "c", -1)), 
		int(Utils.get_float(note_dict, "d", 0)), 
		int(Utils.get_float(note_dict, "a", 0)), 
		Utils.get_dict(note_dict, "customData", {}),
		false,
		from_fake_collection
	)
