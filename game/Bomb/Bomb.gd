extends Cuttable
class_name Bomb

const COLLISION_ENABLE_DISTANCE := 3.0

@onready var collision_shape: CollisionShape3D = $Area3D/CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $Mesh

var bomb_info: BombInfo = null
var _mat: ShaderMaterial = null
var _default_color: Color = Color(0.283, 0.283, 0.283)
var jump := NoteMovementData.Jump.new()
var _middle_rotation := Quaternion.IDENTITY
var _yaw_basis := Basis.IDENTITY
var _local_basis := Basis.IDENTITY
var _has_yaw := false
var _last_rotation := Basis.IDENTITY
var _missed := false

func _ready() -> void:
	($Explosion as BeepCubeSliceParticles).top_level = true
	_mat = mesh_instance.material_override as ShaderMaterial
	if _mat != null:
		_default_color = _mat.get_shader_parameter(&"color")

func set_collision_disabled(value: bool) -> void:
	if bomb_info != null and bomb_info.uninteractable and not value:
		value = true
	collision_shape.disabled = value

@warning_ignore("unused_parameter")
func cut(saber_type: int, cut_speed: Vector3, cut_plane: Plane, controller: BeepSaberController) -> void:
	if bomb_info == null or bomb_info.uninteractable:
		return
	Scoreboard.bad_cut(transform.origin)
	var explosion := $Explosion as BeepCubeSliceParticles
	explosion.global_transform.origin = global_transform.origin
	explosion.set_color(Color(0.75, 0.75, 0.75))
	explosion.fire()
	hide_bomb()
	release()

func on_miss() -> void:
	_missed = true
	hide_bomb()
	release()

func spawn(info: BombInfo, _current_beat: float) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	($Explosion as BeepCubeSliceParticles).reset()
	bomb_info = info
	beat = info.beat
	_missed = false
	set_collision_disabled(true)

	var njs: float = info.get_note_jump_movement_speed(NoteMovementData.default_njs)
	var start_beat_offset: float = info.get_note_jump_start_beat_offset(NoteMovementData.default_start_beat_offset)
	speed = njs

	var lane := info.get_position()
	var x := NoteMovementData.line_x(lane.x)
	var line_y := NoteMovementData.line_y(lane.y)
	var highest_y := BeepCube._highest_jump_y(lane.y)
	var note_time := Map.beat_to_seconds(info.beat)
	jump.setup(note_time, njs, start_beat_offset, Vector2(x, line_y), Vector2(x, line_y), highest_y, line_y)

	var wobble := NoteMovementData.random_rotation_offset(note_time, x, line_y)
	_middle_rotation = Quaternion.from_euler(Vector3(
		deg_to_rad(wobble.x), deg_to_rad(wobble.y), deg_to_rad(wobble.z)
	))
	_has_yaw = info.has_world_rotation
	_yaw_basis = Basis(Vector3.UP, deg_to_rad(info.world_rotation_degrees.y)) if _has_yaw else Basis.IDENTITY
	_local_basis = Basis.IDENTITY
	if info.has_local_rotation:
		_local_basis = Basis.from_euler(Vector3(
			deg_to_rad(info.local_rotation_degrees.x),
			deg_to_rad(info.local_rotation_degrees.y),
			deg_to_rad(info.local_rotation_degrees.z)
		))
	_last_rotation = Basis.IDENTITY

	if _mat != null:
		var bomb_color := info.get_color(_default_color)
		_mat.set_shader_parameter(&"color", bomb_color)
		_mat.set_shader_parameter(&"custom_color", info.has_custom_color)
	_apply_movement()

func _physics_process(_delta: float) -> void:
	if Scoreboard.paused or not is_visible_in_tree() or not Map.current_info:
		return
	_apply_movement()
	if jump.phase == NoteMovementData.Phase.FINISHED:
		on_miss()
		return
	if not _missed and NoteMovementData.song_time >= jump.missed_time:
		on_miss()
		return
	if jump.phase == NoteMovementData.Phase.JUMPING and collision_shape.disabled \
			and jump.local_position.z >= jump.beat_z() - COLLISION_ENABLE_DISTANCE:
		set_collision_disabled(false)

func _apply_movement() -> void:
	jump.update(NoteMovementData.song_time)
	var local_position := jump.local_position
	if jump.phase == NoteMovementData.Phase.WAITING:
		mesh_instance.visible = false
		transform.origin = local_position
		return
	mesh_instance.visible = true
	var note_basis := _last_rotation
	if jump.phase == NoteMovementData.Phase.JUMPING and jump.progress < 0.5:
		note_basis = _jump_rotation(jump.progress, local_position)
		_last_rotation = note_basis
	elif jump.phase == NoteMovementData.Phase.MOVING:
		note_basis = Basis.IDENTITY
		_last_rotation = note_basis
	var world_position := local_position
	if _has_yaw:
		world_position = _yaw_basis * local_position
	transform = Transform3D(_yaw_basis * note_basis * _local_basis, world_position)

func _jump_rotation(progress: float, local_position: Vector3) -> Basis:
	var q: Quaternion
	if progress < 0.125:
		q = Quaternion.IDENTITY.slerp(_middle_rotation, sin(progress * PI * 4.0))
	else:
		q = _middle_rotation.slerp(Quaternion.IDENTITY, sin((progress - 0.125) * PI * 2.0))
	var head := NoteMovementData.head_position
	head.y = lerpf(head.y, local_position.y, 0.8)
	if _has_yaw:
		head = _yaw_basis.inverse() * head
	var away_from_head := local_position - head
	if away_from_head.length_squared() > 0.0001:
		var up := Basis(q).y
		if absf(up.dot(away_from_head.normalized())) < 0.999:
			var look := Basis.looking_at(away_from_head, up).get_rotation_quaternion()
			q = q.slerp(look, clampf(progress * 2.0, 0.0, 1.0))
	return Basis(q)

func clear_from_track() -> void:
	hide_bomb()
	if not is_released():
		release()

func hide_bomb() -> void:
	mesh_instance.visible = false
	set_collision_disabled(true)
	process_mode = Node.PROCESS_MODE_DISABLED
