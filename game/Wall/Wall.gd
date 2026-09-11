extends PooledNode3D
class_name Wall

# Obstacle movement and sizing follow the shared model in NoteMovementData.

var speed: float
var _core_mat: ShaderMaterial
var _frame_mat: ShaderMaterial
@export var wallType : int
@export var wallWidth : float

var movement := NoteMovementData.ObstacleMovement.new()
var _yaw_basis := Basis.IDENTITY
var _has_yaw := false
var _local_basis := Basis.IDENTITY
var _wall_info: ObstacleInfo = null

@onready var orientation: Node3D = $WallMeshOrientation
@onready var mesh_instance: MeshInstance3D = $WallMeshOrientation/WallMesh
@onready var collision_shape: CollisionShape3D = $WallMeshOrientation/WallArea/CollisionShape3D

func _ready() -> void:
	_core_mat = mesh_instance.material_override as ShaderMaterial
	_frame_mat = _core_mat.next_pass as ShaderMaterial

func _physics_process(_delta: float) -> void :
	if Scoreboard.paused or not is_visible_in_tree() or not Map.current_info:
		return
	_apply_movement()
	if movement.phase == NoteMovementData.Phase.FINISHED:
		hide_wall()
		release()
		return
	if movement.phase == NoteMovementData.Phase.JUMPING and collision_shape.disabled \
			and _wall_info != null and not _wall_info.uninteractable:
		collision_shape.disabled = false

func spawn(wall_info: ObstacleInfo, _current_beat: float, color: Color) -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	_wall_info = wall_info
	collision_shape.disabled = true

	var njs: float = wall_info.get_note_jump_movement_speed(NoteMovementData.default_njs)
	var start_beat_offset: float = wall_info.get_note_jump_start_beat_offset(NoteMovementData.default_start_beat_offset)
	speed = njs

	# Get properly decoded position and size from ObstacleInfo
	var data: Dictionary = wall_info.get_position_and_size()
	var position_2d: Vector2 = data["position"] as Vector2 # x is centered lane index (-2 .. 1)
	var size_2d: Vector2 = data["size"] as Vector2
	var custom_depth: float = float(data["depth"])
	var has_custom_depth: bool = bool(data["has_custom_depth"])

	# spawn placement: lane offset, then shifted to the center of the span
	var world_width := size_2d.x * NoteMovementData.NOTE_LINES_DISTANCE
	var offset_x := NoteMovementData.line_x(position_2d.x + 2.0) + (world_width - NoteMovementData.NOTE_LINES_DISTANCE) * 0.5
	var offset_y := NoteMovementData.line_y(position_2d.y) + NoteMovementData.OBSTACLE_VERTICAL_OFFSET + NoteMovementData.jump_offset_y
	offset_y = maxf(offset_y, NoteMovementData.OBSTACLE_MIN_Y)
	var world_height := minf(
		size_2d.y * NoteMovementData.NOTE_LINES_DISTANCE,
		NoteMovementData.OBSTACLE_TOP_Y - offset_y
	)
	world_height = maxf(world_height, 0.05)

	var obstacle_time := Map.beat_to_seconds(wall_info.beat)
	var duration_seconds := Map.beat_to_seconds(wall_info.beat + wall_info.duration) - obstacle_time
	if has_custom_depth:
		duration_seconds = custom_depth * NoteMovementData.NOTE_LINES_DISTANCE / maxf(njs, 0.01)
	movement.setup(obstacle_time, duration_seconds, njs, start_beat_offset, Vector2(offset_x, offset_y))
	var world_depth := maxf(movement.length, 0.05)

	# visual width is 98% of the lane width so neighbouring walls stay separate
	var visual_width := world_width * 0.98
	var mesh := mesh_instance.mesh as BoxMesh
	var shape := collision_shape.shape as BoxShape3D
	mesh.size = Vector3(visual_width, world_height, world_depth)
	shape.size = Vector3(world_width, world_height, world_depth)
	# the obstacle origin is at its front-bottom-center; the body trails behind it
	var center := Vector3(0.0, world_height * 0.5, -world_depth * 0.5)
	mesh_instance.position = center
	collision_shape.position = center

	_core_mat.set_shader_parameter(&"color", color)
	_frame_mat.set_shader_parameter(&"color", color)
	_frame_mat.set_shader_parameter(&"size", mesh.size)

	_has_yaw = wall_info.has_world_rotation
	_yaw_basis = Basis(Vector3.UP, deg_to_rad(wall_info.world_rotation_degrees.y)) if _has_yaw else Basis.IDENTITY
	_local_basis = Basis.IDENTITY
	if wall_info.has_local_rotation:
		_local_basis = Basis.from_euler(Vector3(
			deg_to_rad(wall_info.local_rotation_degrees.x),
			deg_to_rad(wall_info.local_rotation_degrees.y),
			deg_to_rad(wall_info.local_rotation_degrees.z)
		))
	orientation.transform = Transform3D(_local_basis, Vector3.ZERO)
	_apply_movement()

# used by the visual preview harness: a static wall of a given size
func _preview_setup(size: Vector3, color: Color) -> void:
	var mesh := mesh_instance.mesh as BoxMesh
	var shape := collision_shape.shape as BoxShape3D
	mesh.size = size
	shape.size = size
	var center := Vector3(0.0, size.y * 0.5, -size.z * 0.5)
	mesh_instance.position = center
	collision_shape.position = center
	_core_mat.set_shader_parameter(&"color", color)
	_frame_mat.set_shader_parameter(&"color", color)
	_frame_mat.set_shader_parameter(&"size", size)
	mesh_instance.visible = true
	visible = true

func _apply_movement() -> void:
	movement.update(NoteMovementData.song_time)
	var local_position := movement.local_position
	mesh_instance.visible = movement.phase != NoteMovementData.Phase.WAITING
	var world_position := local_position
	if _has_yaw:
		world_position = _yaw_basis * local_position
	transform = Transform3D(_yaw_basis, world_position)

func clear_from_track() -> void:
	hide_wall()
	if not is_released():
		release()

func hide_wall() -> void:
	visible = false
	collision_shape.disabled = true
	process_mode = Node.PROCESS_MODE_DISABLED
