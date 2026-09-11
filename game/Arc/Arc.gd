extends PooledNode3D
class_name Arc

static var left_material := load("res://game/Arc/Arc.material").duplicate() as ShaderMaterial
static var right_material := left_material.duplicate() as ShaderMaterial
static var left_color: Color = left_material.get_shader_parameter(&"color") as Color
static var right_color: Color = right_material.get_shader_parameter(&"color") as Color

@onready var visual: CSGPolygon3D = $Path3D/Visual

@export var arc_angle_force := 2.0
@export var mid_points := 3

var arc_info: ArcInfo = null
var activator_cube: BeepCube = null

var speed: float
var tail_jump := NoteMovementData.Jump.new()
var _yaw_basis := Basis.IDENTITY
var _has_yaw := false
var _tail_xy := Vector2.ZERO
var _instance_material: ShaderMaterial

func _ready() -> void:
	_instance_material = left_material.duplicate() as ShaderMaterial
	visual.material_override = _instance_material

func spawn(info: ArcInfo, current_beat: float, _activator_cube: BeepCube = null, custom_color: Color = Color.TRANSPARENT) -> void:
	_disconnect_activator_cube()
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	transform = Transform3D.IDENTITY

	arc_info = info
	var njs: float = info.get_note_jump_movement_speed(NoteMovementData.default_njs)
	var start_beat_offset: float = info.get_note_jump_start_beat_offset(NoteMovementData.default_start_beat_offset)
	speed = njs

	var arc_color: Color = custom_color
	if arc_color == Color.TRANSPARENT:
		arc_color = right_color if arc_info.color == 1 else left_color
	_instance_material.set_shader_parameter(&"color", arc_color)
	_instance_material.set_shader_parameter(&"saber_magnet", 0)
	visual.material_override = _instance_material

	activator_cube = _activator_cube
	if activator_cube:
		activator_cube.cutted.connect(_on_activator_cube_cutted)
		activator_cube.released.connect(_on_activator_cube_released)
	else:
		start_magnet()
	
	# arcs connect the notes at their cut positions (the peak of the jump arc)
	var head_position_2d := info.get_head_position()
	var tail_position_2d := info.get_tail_position()
	var head_time := Map.beat_to_seconds(info.head_beat)
	var tail_time := Map.beat_to_seconds(info.tail_beat)
	var head_pos := Vector3(
		NoteMovementData.line_x(head_position_2d.x),
		BeepCube._highest_jump_y(head_position_2d.y) + NoteMovementData.jump_offset_y,
		-(tail_time - head_time) * njs
	)
	var tail_pos := Vector3(
		NoteMovementData.line_x(tail_position_2d.x),
		BeepCube._highest_jump_y(tail_position_2d.y) + NoteMovementData.jump_offset_y,
		0.0
	)
	_tail_xy = Vector2(tail_pos.x, tail_pos.y)
	tail_jump.setup(tail_time, njs, start_beat_offset, _tail_xy, _tail_xy, tail_pos.y, tail_pos.y)
	_has_yaw = info.has_world_rotation
	_yaw_basis = Basis(Vector3.UP, deg_to_rad(info.world_rotation_degrees.y)) if _has_yaw else Basis.IDENTITY
	_apply_movement()

	var head_rotation: Vector2 = Constants.ROTATION_UNIT_VECTORS[info.head_cut_direction] if info.head_cut_direction >= 0 and info.head_cut_direction <= 8 else Vector2.ZERO
	head_rotation *= info.head_control_point_length_multiplier
	var tail_rotation: Vector2 = -Constants.ROTATION_UNIT_VECTORS[info.tail_cut_direction] if info.tail_cut_direction >= 0 and info.tail_cut_direction <= 8 else Vector2.ZERO
	tail_rotation *= info.tail_control_point_length_multiplier
	
	var curve := ($Path3D as Path3D).curve
	curve.clear_points()
	
	# sets the origin of the tail at the tail point to use in the shader for a fade out effect
	$Path3D.position = Vector3.ZERO
	
	curve.add_point(head_pos - tail_pos, Vector3.ZERO, Vector3(head_rotation.x, head_rotation.y, 0.0) * arc_angle_force)
	
	if info.mid_anchor_mode > 0:
		for midpoint_id in range(mid_points):
			var range : float = (float(midpoint_id+1) / (mid_points+1))
			
			var point_pos :=  head_pos.lerp(tail_pos, range)
			point_pos += Vector3(head_rotation.x, head_rotation.y, 0.0).rotated(Vector3(0,0,1), 
					(
						(PI if info.head_cut_direction == info.tail_cut_direction else TAU)
						*(-range if info.mid_anchor_mode == 1 else range)
					)
				) * arc_angle_force
			
			curve.add_point(point_pos - tail_pos, Vector3.ZERO, Vector3.ZERO)
		# calculate smooth in out directions after all points have been set
		for smoothpoint_id in range(mid_points):
			var prev_point_pos := curve.get_point_position(smoothpoint_id)
			var current_point_pos := curve.get_point_position(smoothpoint_id + 1)
			var next_point_pos := curve.get_point_position(smoothpoint_id + 2)
			# Calculate vectors to previous and next points and the average direction
			var to_prev := (prev_point_pos - current_point_pos).normalized()
			var to_next := (next_point_pos - current_point_pos).normalized()
			var smooth_dir := (to_next - to_prev).normalized()
			var distance := (prev_point_pos.distance_to(current_point_pos) + 
							current_point_pos.distance_to(next_point_pos)) * 0.25
			curve.set_point_in(smoothpoint_id + 1, smooth_dir * -distance)
			curve.set_point_out(smoothpoint_id + 1, smooth_dir * distance)
	
	curve.add_point(tail_pos - tail_pos, Vector3(tail_rotation.x, tail_rotation.y, 0.0) * arc_angle_force, Vector3.ZERO)

func _apply_movement() -> void:
	tail_jump.update(NoteMovementData.song_time)
	var local_position := Vector3(_tail_xy.x, _tail_xy.y, tail_jump.local_position.z)
	visual.visible = tail_jump.phase != NoteMovementData.Phase.WAITING
	var world_position := local_position
	if _has_yaw:
		world_position = _yaw_basis * local_position
	transform = Transform3D(_yaw_basis, world_position)

func _on_activator_cube_cutted(correct_saber: bool) -> void:
	var cube := activator_cube
	_disconnect_activator_cube()
	if correct_saber and cube and not cube.is_released() and cube.beat == arc_info.head_beat:
		start_magnet()

func _on_activator_cube_released() -> void:
	_disconnect_activator_cube()

func _disconnect_activator_cube() -> void:
	if activator_cube and activator_cube.cutted.is_connected(_on_activator_cube_cutted):
		activator_cube.cutted.disconnect(_on_activator_cube_cutted)
	if activator_cube and activator_cube.released.is_connected(_on_activator_cube_released):
		activator_cube.released.disconnect(_on_activator_cube_released)
	activator_cube = null

func start_magnet() -> void:
	_instance_material.set_shader_parameter(&"saber_magnet", arc_info.color + 1)

func _process(_delta: float) -> void:
	if activator_cube and activator_cube.is_released():
		_disconnect_activator_cube()
	if Scoreboard.paused or not is_visible_in_tree() or not Map.current_info: return
	_apply_movement()
	if tail_jump.phase == NoteMovementData.Phase.FINISHED:
		hide_arc()
		release()

func clear_from_track() -> void:
	hide_arc()
	if not is_released():
		release()

func hide_arc() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

func release() -> void:
	_disconnect_activator_cube()
	arc_info = null
	visual.material_override = null
	super.release()
