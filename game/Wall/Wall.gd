extends PooledNode3D
class_name Wall

var speed: float
var movement_direction: Vector3 = Vector3.BACK
var distance_moved: float = 0.0
var despawn_distance: float = 0.0
var _mat: ShaderMaterial
var testforLayer = 0
@export var wallType : int
@export var wallWidth : float
const wallYOffset = 3.0

@onready var mesh_instance: MeshInstance3D = $WallMeshOrientation/WallMesh
@onready var collision_shape: CollisionShape3D = $WallMeshOrientation/WallArea/CollisionShape3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	_mat = mesh_instance.material_override.duplicate(true) as ShaderMaterial
	mesh_instance.material_override = _mat

func _physics_process(delta: float) -> void :
	if Scoreboard.paused or not is_visible_in_tree() or not Map.current_info:
		return
	var frame_distance := speed * delta
	transform.origin += movement_direction * frame_distance
	distance_moved += frame_distance

	if distance_moved > despawn_distance:
		hide_wall()
		release()

func spawn(wall_info: ObstacleInfo, current_beat: float, color: Color) -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	transform = Transform3D.IDENTITY
	collision_shape.disabled = wall_info.uninteractable

	# Set color
	_mat.set_shader_parameter(&"albedo_color", color)

	var mesh := mesh_instance.mesh as BoxMesh
	var shape := collision_shape.shape as BoxShape3D

	# Get properly decoded position and size from ObstacleInfo
	var data: Dictionary = wall_info.get_position_and_size()
	var position_2d: Vector2 = data["position"] as Vector2
	var size_2d: Vector2 = data["size"] as Vector2
	var custom_depth: float = float(data["depth"])
	var has_custom_depth: bool = bool(data["has_custom_depth"])

	# Convert to world space dimensions
	var world_width := size_2d.x * Constants.LANE_DISTANCE
	var world_height := size_2d.y * Constants.LANE_DISTANCE
	var world_depth := (
		custom_depth * Constants.LANE_DISTANCE
		if has_custom_depth
		else wall_info.duration * Constants.BEAT_DISTANCE
	)

	# Set mesh and collision sizes
	mesh.size.x = world_width
	shape.size.x = world_width
	mesh.size.y = world_height
	shape.size.y = world_height
	mesh.size.z = world_depth
	shape.size.z = world_depth

	# Set shader size parameter
	_mat.set_shader_parameter(&"size", Vector3(world_width, world_height, world_depth))

	# Position the wall in world space
	# X position: Convert from lane coordinates, centered at origin
	transform.origin.x = position_2d.x * Constants.LANE_DISTANCE + (size_2d.x * 0.5 * Constants.LANE_DISTANCE)

	# Y position: Convert from layer coordinates, offset from bottom, centered on height
	transform.origin.y = position_2d.y * Constants.LANE_DISTANCE + (size_2d.y * 0.5 * Constants.LANE_DISTANCE)

	# Z position: Place based on beat timing
	var depth_offset := world_depth * 0.5
	var default_njs: float = Map.current_difficulty.note_jump_movement_speed
	var effective_njs: float = wall_info.get_note_jump_movement_speed(default_njs)
	var movement_scale := effective_njs / default_njs if default_njs > 0.0 and effective_njs > 0.0 else 1.0
	transform.origin.z = (
		-(wall_info.beat - current_beat) * Constants.BEAT_DISTANCE * movement_scale
		- depth_offset
	)
	var initial_z := transform.origin.z
	distance_moved = 0.0
	despawn_distance = Constants.MISS_Z + depth_offset - initial_z
	ColorNoteInfo.NoodleData.apply_rotations(
		self,
		0.0,
		wall_info.local_rotation_degrees,
		wall_info.has_local_rotation,
		wall_info.world_rotation_degrees,
		wall_info.has_world_rotation
	)
	movement_direction = ColorNoteInfo.NoodleData.get_movement_direction(
		wall_info.world_rotation_degrees, wall_info.has_world_rotation
	)

	# Set movement speed
	speed = Constants.BEAT_DISTANCE * Map.current_info.beats_per_minute / 60.0 * movement_scale

	# Play spawn animation
	animation_player.stop()
	animation_player.play(&"Spawn")
	animation_player.seek(0.0, true)

func clear_from_track() -> void:
	hide_wall()
	if not is_released():
		release()

func hide_wall() -> void:
	visible = false
	collision_shape.disabled = true
	animation_player.stop()
	process_mode = Node.PROCESS_MODE_DISABLED
