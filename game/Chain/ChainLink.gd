extends Cuttable
class_name ChainLink

var which_saber: int
var _mesh: Mesh
var _mat: ShaderMaterial
@export var min_speed := 0.5

@onready var mi := $Mesh as MeshInstance3D

var piece_left : CutPiece = null
var piece_right : CutPiece = null
var link_info: ChainInfo = null
var movement_direction: Vector3 = Vector3.BACK
var distance_moved: float = 0.0
var collision_enable_distance: float = 0.0
var miss_distance: float = 0.0
var _default_collision_size_z: float
var _default_collision_origin_z: float

func _ready() -> void:
	_mat = mi.material_override as ShaderMaterial
	_mesh = mi.mesh
	var collision := $Area3D/CollisionShape3D as CollisionShape3D
	_default_collision_size_z = (collision.shape as BoxShape3D).size.z
	_default_collision_origin_z = collision.transform.origin.z
	
	# init our cut pieces with unique copies of our own material for reference,
	# and disable "bouncy" physics behavior
	piece_left = CutPiece.new(self, _mesh, _mat.duplicate(true) as ShaderMaterial, false)
	piece_right = CutPiece.new(self, _mesh, _mat.duplicate(true) as ShaderMaterial, false)
	piece_left.set_chain_head(false)
	piece_right.set_chain_head(false)

static func construct_chain(chain_info: ChainInfo, current_beat: float, note_info_refs: Array[ColorNoteInfo], cube_refs: Array[BeepCube]) -> void:
	# instead of just making a new note head for a new chain, beat saber
	# modifies an already-existing note to be the head, which is why we have to
	# do all this garbage with keeping references to other notes that were
	# spawned this frame.
	var i := 0
	while i < note_info_refs.size():
		var info_ref := note_info_refs[i]
		if (
			info_ref.beat == chain_info.head_beat
			and info_ref.line_index == chain_info.head_line_index
			and info_ref.line_layer == chain_info.head_line_layer
		):
			cube_refs[i].make_chain_head()
		i += 1
	
	# the curve of the chain is gotten from a 3-point bezier curve.  the first
	# point is the head position, the last point is the tail position, and the
	# mid point is based on the head and tail points.
	#
	# to get the mid point, draw a straight line from the head note, in the
	# direction the head note is pointing, with length equal to half the length
	# of a straight line from the head to the tail.  the end point of the line
	# you just drew is the mid point of the curve.

	# Get precise positions using the same logic as BeepCube (handles Mapping Extensions)
	var head_note_pos := chain_info.get_head_position()
	var tail_note_pos := chain_info.get_tail_position()

	var head_pos := Vector2(
		head_note_pos.x * Constants.LANE_DISTANCE + Constants.LANE_ZERO_X,
		head_note_pos.y * Constants.LANE_DISTANCE + Constants.LAYER_ZERO_Y
	)
	var tail_pos := Vector2(
		tail_note_pos.x * Constants.LANE_DISTANCE + Constants.LANE_ZERO_X,
		tail_note_pos.y * Constants.LANE_DISTANCE + Constants.LAYER_ZERO_Y
	)
	var cut_direction := chain_info.head_cut_direction
	var head_direction: Vector2 = Constants.ROTATION_UNIT_VECTORS[cut_direction] if cut_direction >= 0 and cut_direction <= 8 else Vector2.ZERO
	var mid_pos := head_pos + (head_direction * head_pos.distance_to(tail_pos) * 0.5)
	i = 1
	while i < chain_info.slice_count:
		var chain_link := GlobalReferences.link_pool.acquire() as ChainLink
		chain_link.spawn(chain_info, current_beat, head_pos, tail_pos, mid_pos, i)
		i += 1

func spawn(chain_info: ChainInfo, current_beat: float, head_pos: Vector2, tail_pos: Vector2, mid_pos: Vector2, link_index: int) -> void:
	# re-enable our process_mode first otherwise it seems like Godot-internals
	# can behave weirdly (ex. AnimationPlayer won't always play correctly)
	process_mode = Node.PROCESS_MODE_ALWAYS
	transform = Transform3D.IDENTITY
	link_info = chain_info
	var collision := $Area3D/CollisionShape3D as CollisionShape3D
	(collision.shape as BoxShape3D).size.z = _default_collision_size_z
	collision.transform.origin.z = _default_collision_origin_z
	
	var default_color := Map.color_left if chain_info.color == 0 else Map.color_right
	var color := chain_info.get_color(default_color)
	var default_njs: float = Map.current_difficulty.note_jump_movement_speed
	var effective_njs: float = chain_info.get_note_jump_movement_speed(default_njs)
	var movement_scale := effective_njs / default_njs if default_njs > 0.0 and effective_njs > 0.0 else 1.0
	speed = (
		Constants.BEAT_DISTANCE
		* Map.current_info.beats_per_minute
		* 0.016666666666666667
		* movement_scale
	)
	which_saber = chain_info.color
	
	var lerp_factor := float(link_index) / float(chain_info.slice_count - 1) * chain_info.squish_factor
	beat = lerpf(chain_info.head_beat, chain_info.tail_beat, lerp_factor)
	
	var q0 := head_pos.lerp(mid_pos, lerp_factor)
	var q1 := mid_pos.lerp(tail_pos, lerp_factor)
	var bezier_pos := q0.lerp(q1, lerp_factor)
	
	transform.origin.x = bezier_pos.x
	transform.origin.y = bezier_pos.y
	transform.origin.z = -(beat - current_beat) * Constants.BEAT_DISTANCE * movement_scale
	var initial_z := transform.origin.z
	distance_moved = 0.0
	collision_enable_distance = maxf(0.0, -3.0 - initial_z)
	miss_distance = Constants.MISS_Z - initial_z
	
	var chain_rotation := q0.angle_to_point(q1) - TAU*0.25
	ColorNoteInfo.NoodleData.apply_rotations(
		self,
		chain_rotation,
		chain_info.local_rotation_degrees,
		chain_info.has_local_rotation,
		chain_info.world_rotation_degrees,
		chain_info.has_world_rotation
	)
	movement_direction = ColorNoteInfo.NoodleData.get_movement_direction(
		chain_info.world_rotation_degrees, chain_info.has_world_rotation
	)
	
	# little bit of forgiveness.  if the chain link is more than a meter away
	# from the chain head, its hitbox is extended to halfway between the link
	# and the head.
	var z_distance_from_head := (beat - chain_info.head_beat) * Constants.BEAT_DISTANCE
	if z_distance_from_head > 1.0:
		var new_size := z_distance_from_head * 0.5
		(collision.shape as BoxShape3D).size.z = new_size
		collision.transform.origin.z = new_size * 0.5 - 0.25
	
	piece_left.set_color(color)
	piece_right.set_color(color)
	_mat.set_shader_parameter(&"color", color)
	
	var anim := $AnimationPlayer as AnimationPlayer
	var anim_speed := effective_njs / 9.0
	anim.speed_scale = maxf(min_speed,anim_speed)
	anim.play(&"Spawn")
	
	mi.visible = true
	if chain_info.uninteractable:
		set_collision_disabled(true)

func _physics_process(delta: float) -> void:
	if Scoreboard.paused or not is_visible_in_tree() or not Map.current_info:
		return
	var frame_distance := speed * delta
	transform.origin += movement_direction * frame_distance
	distance_moved += frame_distance
	var collision := $Area3D/CollisionShape3D as CollisionShape3D
	if distance_moved >= collision_enable_distance and collision.disabled:
		set_collision_disabled(false)
	if distance_moved > miss_distance:
		on_miss()

# call this when clearing the track
func clear_from_track() -> void:
	hide_cube()
	piece_left.hide_piece()
	piece_right.hide_piece()
	if ! is_released():
		release()

func hide_cube() -> void:
	mi.visible = false
	set_collision_disabled(true)
	# disable processing on this node and all children to help with performance
	process_mode = Node.PROCESS_MODE_DISABLED # disable to help with performance

func cut(saber_type: int, _cut_speed: Vector3, cut_plane: Plane, _controller: BeepSaberController) -> void:
	if link_info == null or link_info.uninteractable:
		return
	if saber_type == which_saber:
		Scoreboard.chain_link_cut(transform.origin)
	else:
		Scoreboard.bad_cut(transform.origin)
	
	hide_cube()
	if Settings.cube_cuts_falloff:
		_start_cut_pieces(cut_plane)
		# release() will be called by Cuttable class when it sees both pieces die
	else:
		release()# release now instead of waiting for cut pieces to die off

func on_miss() -> void:
	if link_info != null and not link_info.uninteractable:
		Scoreboard.reset_combo()
	hide_cube()
	release()

func set_collision_disabled(value: bool) -> void:
	if link_info != null and link_info.uninteractable and not value:
		value = true
	($Area3D/CollisionShape3D as CollisionShape3D).disabled = value

func _start_cut_pieces(cutplane: Plane) -> void:
	piece_left.global_transform = global_transform
	piece_right.global_transform = global_transform
	
	# calculate angle and position of the cut
	var cut_angle_abs := Vector2(cutplane.normal.x, cutplane.normal.y).angle()
	var cut_dist_from_center := cutplane.distance_to(transform.origin)
	var cut_angle_rel := cut_angle_abs - global_rotation.z
	
	_piece_death_count = 0
	piece_left.start_cut(-cut_dist_from_center, cut_angle_rel + PI)
	piece_right.start_cut(cut_dist_from_center, cut_angle_rel)
	
	# some impulse so the cube half moves
	var split_vector := cutplane.normal * 2.0
	piece_left.apply_central_impulse(-split_vector)
	piece_right.apply_central_impulse(split_vector)
