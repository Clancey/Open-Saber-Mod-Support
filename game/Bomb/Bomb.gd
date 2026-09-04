extends Cuttable
class_name Bomb

@export var min_speed := 0.5
@onready var collision_shape: CollisionShape3D = $Area3D/CollisionShape3D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var color_mesh: MeshInstance3D = $BombAnimation/Mesh/Icosphere2

var bomb_info: BombInfo = null
var color_material: StandardMaterial3D = null
var default_albedo_color: Color = Color.WHITE
var default_emission_color: Color = Color.BLACK
var movement_direction: Vector3 = Vector3.BACK
var distance_moved: float = 0.0
var collision_enable_distance: float = 0.0
var miss_distance: float = 0.0

func _ready() -> void:
	var source_material := color_mesh.material_override as StandardMaterial3D
	if source_material != null:
		color_material = source_material.duplicate(true) as StandardMaterial3D
		default_albedo_color = color_material.albedo_color
		default_emission_color = color_material.emission
		color_mesh.material_override = color_material

func set_collision_disabled(value: bool) -> void:
	if bomb_info != null and bomb_info.uninteractable and not value:
		value = true
	collision_shape.disabled = value

@warning_ignore("unused_parameter")
func cut(saber_type: int, cut_speed: Vector3, cut_plane: Plane, controller: BeepSaberController) -> void:
	if bomb_info == null or bomb_info.uninteractable:
		return
	Scoreboard.bad_cut(transform.origin)
	hide_bomb()
	release()

func on_miss() -> void:
	hide_bomb()
	release()

func spawn(info: BombInfo, current_beat: float) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	transform = Transform3D.IDENTITY
	bomb_info = info
	set_collision_disabled(true)

	var default_njs: float = Map.current_difficulty.note_jump_movement_speed
	var effective_njs: float = info.get_note_jump_movement_speed(default_njs)
	var movement_scale := effective_njs / default_njs if default_njs > 0.0 and effective_njs > 0.0 else 1.0
	speed = Constants.BEAT_DISTANCE * Map.current_info.beats_per_minute / 60.0 * movement_scale
	beat = info.beat

	var p := info.get_position()
	transform.origin.x = p.x * Constants.LANE_DISTANCE + Constants.LANE_ZERO_X
	transform.origin.y = p.y * Constants.LANE_DISTANCE + Constants.LAYER_ZERO_Y
	transform.origin.z = -(info.beat - current_beat) * Constants.BEAT_DISTANCE * movement_scale
	var initial_z := transform.origin.z
	distance_moved = 0.0
	collision_enable_distance = maxf(0.0, -3.0 - initial_z)
	miss_distance = Constants.MISS_Z - initial_z
	ColorNoteInfo.NoodleData.apply_rotations(
		self,
		0.0,
		info.local_rotation_degrees,
		info.has_local_rotation,
		info.world_rotation_degrees,
		info.has_world_rotation
	)
	movement_direction = ColorNoteInfo.NoodleData.get_movement_direction(
		info.world_rotation_degrees, info.has_world_rotation
	)
	if color_material != null:
		var bomb_color := info.get_color(default_albedo_color)
		color_material.albedo_color = bomb_color
		color_material.emission = bomb_color if info.has_custom_color else default_emission_color
	
	var anim_speed := effective_njs / 9.0
	animation_player.stop()
	animation_player.speed_scale = maxf(min_speed, anim_speed)
	animation_player.play(&"Spawn")
	animation_player.seek(0.0, true)
	if info.uninteractable:
		set_collision_disabled(true)

func _physics_process(delta: float) -> void:
	if Scoreboard.paused or not is_visible_in_tree() or not Map.current_info:
		return
	var frame_distance := speed * delta
	transform.origin += movement_direction * frame_distance
	distance_moved += frame_distance
	if distance_moved >= collision_enable_distance and collision_shape.disabled:
		set_collision_disabled(false)
	if distance_moved > miss_distance:
		on_miss()

func clear_from_track() -> void:
	hide_bomb()
	if not is_released():
		release()

func hide_bomb() -> void:
	visible = false
	set_collision_disabled(true)
	animation_player.stop()
	process_mode = Node.PROCESS_MODE_DISABLED
