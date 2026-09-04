extends RefCounted
class_name ChainInfo

var color: int
var head_beat: float
var head_line_index: int
var head_line_layer: int
var head_cut_direction: int
var tail_beat: float
var tail_line_index: int
var tail_line_layer: int
var slice_count: int
var squish_factor: float
var custom_data: Dictionary = {}
var head_position: Vector2
var has_head_position: bool = false
var tail_position: Vector2
var has_tail_position: bool = false
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
	color: int, head_beat: float, head_line_index: int, head_line_layer: int,
	head_cut_direction: int, tail_beat: float, tail_line_index: int,
	tail_line_layer: int, slice_count: int, squish_factor: float,
	custom_data_dict: Dictionary = {}, from_fake_collection: bool = false
) -> void:
	self.color = color
	self.head_beat = head_beat
	self.head_line_index = head_line_index
	self.head_line_layer = head_line_layer
	self.head_cut_direction = head_cut_direction
	self.tail_beat = tail_beat
	self.tail_line_index = tail_line_index
	self.tail_line_layer = tail_line_layer
	self.slice_count = slice_count
	self.squish_factor = squish_factor
	self.custom_data = custom_data_dict

	var vanilla_head := ColorNoteInfo.lane_to_position(head_line_index, head_line_layer)
	var vanilla_tail := ColorNoteInfo.lane_to_position(tail_line_index, tail_line_layer)
	has_head_position = ColorNoteInfo.NoodleData.has_coordinates(custom_data_dict, false)
	head_position = ColorNoteInfo.NoodleData.get_coordinates(
		custom_data_dict, false, vanilla_head
	)
	has_tail_position = ColorNoteInfo.NoodleData.has_coordinates(custom_data_dict, false, true)
	tail_position = ColorNoteInfo.NoodleData.get_coordinates(
		custom_data_dict, false, vanilla_tail, true
	)
	has_world_rotation = ColorNoteInfo.NoodleData.has_world_rotation(custom_data_dict, false)
	world_rotation_degrees = ColorNoteInfo.NoodleData.get_world_rotation(custom_data_dict, false)
	has_local_rotation = ColorNoteInfo.NoodleData.has_local_rotation(custom_data_dict, false)
	local_rotation_degrees = ColorNoteInfo.NoodleData.get_local_rotation(custom_data_dict, false)
	has_note_jump_movement_speed = ColorNoteInfo.NoodleData.has_note_jump_movement_speed(
		custom_data_dict, false
	)
	note_jump_movement_speed = ColorNoteInfo.NoodleData.get_note_jump_movement_speed(
		custom_data_dict, false, 0.0
	)
	has_note_jump_start_beat_offset = ColorNoteInfo.NoodleData.has_note_jump_start_beat_offset(
		custom_data_dict, false
	)
	note_jump_start_beat_offset = ColorNoteInfo.NoodleData.get_note_jump_start_beat_offset(
		custom_data_dict, false, 0.0
	)
	fake = ColorNoteInfo.NoodleData.is_fake(custom_data_dict, false, from_fake_collection)
	uninteractable = ColorNoteInfo.NoodleData.is_uninteractable(custom_data_dict, false) or fake
	has_custom_color = ColorNoteInfo.NoodleData.has_color(custom_data_dict)
	custom_color = ColorNoteInfo.NoodleData.get_color(custom_data_dict, Color.TRANSPARENT)

func get_head_position() -> Vector2:
	return head_position if has_head_position else ColorNoteInfo.lane_to_position(
		head_line_index, head_line_layer
	)

func get_tail_position() -> Vector2:
	return tail_position if has_tail_position else ColorNoteInfo.lane_to_position(
		tail_line_index, tail_line_layer
	)

func get_color(default_value: Color) -> Color:
	return custom_color if has_custom_color else default_value

func get_note_jump_movement_speed(default_value: float) -> float:
	return note_jump_movement_speed if has_note_jump_movement_speed else default_value

func get_note_jump_start_beat_offset(default_value: float) -> float:
	return note_jump_start_beat_offset if has_note_jump_start_beat_offset else default_value

func get_spawn_ahead_beats(default_value: float, default_offset: float) -> float:
	return maxf(0.0, default_value + get_note_jump_start_beat_offset(default_offset) - default_offset)

static func new_v3(chain_dict: Dictionary, from_fake_collection: bool = false) -> ChainInfo:
	return ChainInfo.new(
		int(Utils.get_float(chain_dict, "c", 0)),
		Utils.get_float(chain_dict, "b", 0.0),
		int(Utils.get_float(chain_dict, "x", 0)),
		int(Utils.get_float(chain_dict, "y", 0)),
		int(Utils.get_float(chain_dict, "d", 0)),
		Utils.get_float(chain_dict, "tb", 0.0),
		int(Utils.get_float(chain_dict, "tx", 0)),
		int(Utils.get_float(chain_dict, "ty", 0)),
		int(Utils.get_float(chain_dict, "sc", 0)),
		Utils.get_float(chain_dict, "s", 1.0),
		Utils.get_dict(chain_dict, "customData", {}),
		from_fake_collection
	)
