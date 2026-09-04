extends RefCounted
class_name BombInfo

var beat: float
var line_index: int
var line_layer: int
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
	custom_data: Dictionary = {},
	is_v2: bool = false,
	from_fake_collection: bool = false
) -> void:
	self.beat = beat
	self.line_index = line_index
	self.line_layer = line_layer
	self.custom_data = custom_data

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

func get_position() -> Vector2:
	return custom_position if has_custom_position else ColorNoteInfo.lane_to_position(line_index, line_layer)

func get_color(default_value: Color) -> Color:
	return custom_color if has_custom_color else default_value

func get_note_jump_movement_speed(default_value: float) -> float:
	return note_jump_movement_speed if has_note_jump_movement_speed else default_value

func get_note_jump_start_beat_offset(default_value: float) -> float:
	return note_jump_start_beat_offset if has_note_jump_start_beat_offset else default_value

func get_spawn_ahead_beats(default_value: float, default_offset: float) -> float:
	return maxf(0.0, default_value + get_note_jump_start_beat_offset(default_offset) - default_offset)

static func new_v2(bomb_dict: Dictionary) -> BombInfo:
	return BombInfo.new(
		Utils.get_float(bomb_dict, "_time", 0.0),
		int(Utils.get_float(bomb_dict, "_lineIndex", 0)),
		int(Utils.get_float(bomb_dict, "_lineLayer", 0)),
		Utils.get_dict(bomb_dict, "_customData", {}),
		true
	)

static func new_v3(bomb_dict: Dictionary, from_fake_collection: bool = false) -> BombInfo:
	return BombInfo.new(
		Utils.get_float(bomb_dict, "b", 0.0),
		int(Utils.get_float(bomb_dict, "x", 0)),
		int(Utils.get_float(bomb_dict, "y", 0)),
		Utils.get_dict(bomb_dict, "customData", {}),
		false,
		from_fake_collection
	)
