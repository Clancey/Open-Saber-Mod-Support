# BeepCube is the standard note that gets cut by the sabers.
# Movement, rotation and timing follow the model in NoteMovementData.
extends Cuttable
class_name BeepCube

# emitted when the cube gets cut, correct_saber is true if the right saber was used
signal cutted(correct_saber: bool)
signal released

const COLLISION_ENABLE_DISTANCE := 3.0

@onready var mi := $NoteCube as MeshInstance3D
@onready var arrow := $NoteArrow as MeshInstance3D
@onready var arrow_glow := $NoteArrowGlow as MeshInstance3D
@onready var circle_glow := $NoteCircleGlow as MeshInstance3D
@onready var collision_big := $BeepCube_Big/CollisionBig as CollisionShape3D
@onready var collision_small := $BeepCube_Small/CollisionSmall as CollisionShape3D
@onready var slice_particles := $SliceParticles as BeepCubeSliceParticles

var which_saber: int
var is_dot: bool

# we store the mesh here as part of the BeepCube for easier access because we will
# reuse it when we create the cut cube pieces
var _mesh: Mesh
var _mat: ShaderMaterial
var _arrow_glow_mat: ShaderMaterial
var _circle_glow_mat: ShaderMaterial

var piece_left : CutPiece = null
var piece_right : CutPiece = null

var note_info: ColorNoteInfo = null  # Store for later use (debris, etc.)
var jump := NoteMovementData.Jump.new()
var _end_rotation := Quaternion.IDENTITY
var _middle_rotation := Quaternion.IDENTITY
var _yaw_basis := Basis.IDENTITY
var _local_basis := Basis.IDENTITY
var _has_yaw := false
var _last_rotation := Basis.IDENTITY
var _missed := false
var _symbols_visible := true

func _ready() -> void:
	_mat = mi.material_override as ShaderMaterial
	_mesh = mi.mesh
	_arrow_glow_mat = arrow_glow.material_override as ShaderMaterial
	_circle_glow_mat = circle_glow.material_override as ShaderMaterial

	# init our cut pieces with unique copies of our own material for reference,
	# and enable "bouncy" physics behavior
	piece_left = CutPiece.new(self, _mesh, _mat.duplicate(true) as ShaderMaterial, true)
	piece_right = CutPiece.new(self, _mesh, _mat.duplicate(true) as ShaderMaterial, true)

	# slice_particles are within cube's tree, but want then to move in global space
	slice_particles.top_level = true

func spawn(note_info_param: ColorNoteInfo, _current_beat: float, color : Color) -> void:
	# re-enable our process_mode first otherwise it seems like Godot-internals
	# can behave weirdly
	process_mode = Node.PROCESS_MODE_ALWAYS

	note_info = note_info_param
	beat = note_info.beat
	which_saber = note_info.color
	is_dot = note_info.cut_direction == 8
	_missed = false

	var njs: float = note_info.get_note_jump_movement_speed(NoteMovementData.default_njs)
	var start_beat_offset: float = note_info.get_note_jump_start_beat_offset(NoteMovementData.default_start_beat_offset)
	speed = njs

	# lane coordinates (Mapping Extensions precision positions are fractional)
	var lane := note_info.get_position()
	var x := NoteMovementData.line_x(lane.x)
	var line_y := NoteMovementData.line_y(lane.y)
	var highest_y := _highest_jump_y(lane.y)
	var note_time := Map.beat_to_seconds(note_info.beat)
	jump.setup(note_time, njs, start_beat_offset, Vector2(x, line_y), Vector2(x, line_y), highest_y, line_y)

	# rotation: notes start upright, wobble through a random offset and settle
	# on the cut direction during the first half of the jump
	var cut_rotation: float
	if note_info.cut_direction < 9:
		cut_rotation = Constants.CUBE_ROTATIONS[note_info.cut_direction] + deg_to_rad(note_info.angle_offset)
	else:
		cut_rotation = deg_to_rad((note_info.cut_direction - 1000) * -1)
	_end_rotation = Quaternion(Vector3.BACK, cut_rotation)
	var wobble := NoteMovementData.random_rotation_offset(note_time, x, line_y)
	_middle_rotation = Quaternion.from_euler(Vector3(
		deg_to_rad(wobble.x), deg_to_rad(wobble.y), cut_rotation + deg_to_rad(wobble.z)
	))
	_has_yaw = note_info.has_world_rotation
	_yaw_basis = Basis(Vector3.UP, deg_to_rad(note_info.world_rotation_degrees.y)) if _has_yaw else Basis.IDENTITY
	_local_basis = Basis.IDENTITY
	if note_info.has_local_rotation:
		_local_basis = Basis.from_euler(Vector3(
			deg_to_rad(note_info.local_rotation_degrees.x),
			deg_to_rad(note_info.local_rotation_degrees.y),
			deg_to_rad(note_info.local_rotation_degrees.z)
		))
	_last_rotation = Basis(_end_rotation)

	# Dot notes use a wider hit box (NoteBigCuttableColliderSize)
	if is_dot:
		(collision_big.shape as BoxShape3D).size.y = 0.8
	else:
		(collision_big.shape as BoxShape3D).size.y = 0.5

	piece_left.set_color(color)
	piece_right.set_color(color)
	_mat.set_shader_parameter(&"color", color)
	_arrow_glow_mat.set_shader_parameter(&"color", color)
	_circle_glow_mat.set_shader_parameter(&"color", color.lerp(Color.WHITE, 0.6))
	# since cube instances get recycled, we gotta reset cubes that were chain
	# heads in a past life
	_mat.set_shader_parameter(&"is_chain_head", false)
	piece_left.set_chain_head(false)
	piece_right.set_chain_head(false)
	_set_symbols_visible(true)

	# separate cube collision layers to allow a diferent collider on right/wrong cuts.
	# opposing collision layers (ie. right note & left saber) will be placed on the
	# smalling collision shape, while similar collision layers (ie right note &
	# right saber) are placed on the larger collision shape.
	var is_left_note := note_info.color == 0
	var big_coll_area := $BeepCube_Big as Area3D
	big_coll_area.collision_layer = 0x0
	big_coll_area.set_collision_layer_value(CollisionLayerConstants.LeftNote_bit, is_left_note)
	big_coll_area.set_collision_layer_value(CollisionLayerConstants.RightNote_bit, not is_left_note)
	var small_coll_area := $BeepCube_Small as Area3D
	small_coll_area.collision_layer = 0x0
	small_coll_area.set_collision_layer_value(CollisionLayerConstants.LeftNote_bit, not is_left_note)
	small_coll_area.set_collision_layer_value(CollisionLayerConstants.RightNote_bit, is_left_note)

	slice_particles.reset()
	set_collision_disabled(true)
	_apply_movement()
	mi.visible = true
	visible = true

static func _highest_jump_y(layer: float) -> float:
	# Beat Saber tabulates the peak height per line layer; interpolate so that
	# Mapping Extensions' fractional layers still get sensible arcs.
	if layer <= 0.0:
		return NoteMovementData.HIGHEST_JUMP_Y[0] + layer * 0.55
	if layer >= 2.0:
		return NoteMovementData.HIGHEST_JUMP_Y[2] + (layer - 2.0) * 0.5
	if layer < 1.0:
		return lerpf(NoteMovementData.HIGHEST_JUMP_Y[0], NoteMovementData.HIGHEST_JUMP_Y[1], layer)
	return lerpf(NoteMovementData.HIGHEST_JUMP_Y[1], NoteMovementData.HIGHEST_JUMP_Y[2], layer - 1.0)

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
	if jump.phase == NoteMovementData.Phase.JUMPING:
		if collision_big.disabled and jump.local_position.z >= jump.beat_z() - COLLISION_ENABLE_DISTANCE:
			set_collision_disabled(false)
		if _symbols_visible and jump.progress >= 0.75:
			_set_symbols_visible(false)

func _apply_movement() -> void:
	jump.update(NoteMovementData.song_time)
	var local_position := jump.local_position
	if jump.phase == NoteMovementData.Phase.WAITING:
		mi.visible = false
		transform.origin = local_position
		return
	mi.visible = true
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

# Jump rotation: slerp identity -> middle (random wobble) -> cut rotation during the
# first half of the jump, blended toward "look at the player's head".
func _jump_rotation(progress: float, local_position: Vector3) -> Basis:
	var q: Quaternion
	if progress < 0.125:
		q = Quaternion.IDENTITY.slerp(_middle_rotation, sin(progress * PI * 4.0))
	else:
		q = _middle_rotation.slerp(_end_rotation, sin((progress - 0.125) * PI * 2.0))
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

# used by the visual preview harness: show a static note of a given color
func _preview_setup(color: Color) -> void:
	_mat.set_shader_parameter(&"color", color)
	_arrow_glow_mat.set_shader_parameter(&"color", color)
	_circle_glow_mat.set_shader_parameter(&"color", color.lerp(Color.WHITE, 0.6))
	_set_symbols_visible(true)
	mi.visible = true
	visible = true

func _set_symbols_visible(value: bool) -> void:
	_symbols_visible = value
	arrow.visible = value and not is_dot
	arrow_glow.visible = value and not is_dot
	circle_glow.visible = value and is_dot

# call this when clearing the track
func clear_from_track() -> void:
	hide_cube()
	piece_left.hide_piece()
	piece_right.hide_piece()
	if ! is_released():
		release()

func release() -> void:
	if not is_released():
		released.emit()
	super.release()

func hide_cube() -> void:
	mi.visible = false
	visible = false
	set_collision_disabled(true)
	# disable processing on this node and all children to help with performance
	process_mode = Node.PROCESS_MODE_DISABLED

func make_chain_head() -> void:
	_mat.set_shader_parameter(&"is_chain_head", true)
	piece_left.set_chain_head(true)
	piece_right.set_chain_head(true)

func on_miss() -> void:
	_missed = true
	if note_info != null and not note_info.uninteractable:
		Scoreboard.reset_combo()
	hide_cube()
	release()

func set_collision_disabled(value: bool) -> void:
	if note_info != null and note_info.uninteractable and not value:
		value = true
	collision_big.disabled = value
	collision_small.disabled = value

func cut(saber_type: int, cut_speed: Vector3, cut_plane: Plane, controller: BeepSaberController) -> void:
	if note_info == null or note_info.uninteractable:
		return
	# compute the angle between the cube orientation and the cut direction
	var cut_direction_xy := -Vector3(cut_speed.x, cut_speed.y, 0.0).normalized()
	var base_cut_angle_accuracy := global_transform.basis.y.dot(cut_direction_xy)
	var cut_distance := cut_plane.distance_to(global_transform.origin)

	if saber_type == which_saber:
		var cut_angle_accuracy := clampf((base_cut_angle_accuracy-0.7)/0.3, 0.0, 1.0)
		if is_dot: #ignore angle if is a dot
			cut_angle_accuracy = 1.0
		var cut_distance_accuracy := clampf((0.1 - absf(cut_distance))/0.1, 0.0, 1.0)
		var travel_distance_factor := controller.movement_aabb.get_longest_axis_size()
		travel_distance_factor = clampf((travel_distance_factor-0.5)/0.5, 0.0, 1.0)
		# allows a bit of save margin where the beat is considered 100% correct
		var beat_distance := absf(jump.distance_to_beat(NoteMovementData.song_time))
		var beat_accuracy := clampf((1.0 - beat_distance) / 0.5, 0.0, 1.0)
		Scoreboard.note_cut(transform.origin, beat_accuracy, cut_angle_accuracy, cut_distance_accuracy, travel_distance_factor)
		cutted.emit(true)
	else:
		Scoreboard.bad_cut(transform.origin)
		cutted.emit(false)

	# reset the movement tracking volume for the next cut
	controller.reset_movement_aabb()

	hide_cube()
	if Settings.cube_cuts_falloff:
		_start_cut_pieces(cut_plane, cut_speed)
		# release() will be called by Cuttable class when it sees both pieces die
	else:
		release() # release now instead of waiting for cut pieces to die off

# cut the cube by creating two rigid bodies and a shader plane cut
func _start_cut_pieces(cutplane: Plane, cut_speed: Vector3) -> void:
	piece_left.global_transform = global_transform
	piece_right.global_transform = global_transform

	# calculate angle and position of the cut
	var cut_angle_abs := Vector2(cutplane.normal.x, cutplane.normal.y).angle()
	var cut_dist_from_center := cutplane.distance_to(global_transform.origin)
	var cut_angle_rel := cut_angle_abs - global_rotation.z

	_piece_death_count = 0
	piece_left.start_cut(-cut_dist_from_center, cut_angle_rel + PI)
	piece_right.start_cut(cut_dist_from_center, cut_angle_rel)

	# NoteDebrisSpawner: pieces separate along the cut normal, keep a bit of the
	# saber's direction and the note's own travel direction
	var move_vec := Vector3(0.0, 0.0, speed)
	var saber_dir := cut_speed
	saber_dir.z = 0.0
	var side_vector := saber_dir * 0.1 + move_vec * 0.2
	if global_transform.origin.y < 1.3:
		side_vector.y = minf(side_vector.y, 0.0)
	else:
		side_vector.y = maxf(side_vector.y, 0.0)
	var split_vector := cutplane.normal * 2.0
	piece_left.start_flying(-split_vector + side_vector, -cutplane.normal.cross(saber_dir.normalized()) * 2.0)
	piece_right.start_flying(split_vector + side_vector, cutplane.normal.cross(saber_dir.normalized()) * 2.0)

	slice_particles.global_transform.origin = global_transform.origin
	slice_particles.rotation.z = cut_angle_abs+TAU*0.25
	slice_particles.fire()
