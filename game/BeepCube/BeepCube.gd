# BeepCube is the standard cube that will get cut by the sabers
extends Cuttable
class_name BeepCube

# emitted when the cube gets cutted, correct_saber is true if the right saber was used
signal cutted(correct_saber: bool)
signal released

@onready var mi := $BeepCubeMesh as MeshInstance3D
@onready var collision_big := $BeepCube_Big/CollisionBig as CollisionShape3D
@onready var collision_small := $BeepCube_Small/CollisionSmall as CollisionShape3D
@onready var slice_particles := $SliceParticles as BeepCubeSliceParticles

var which_saber: int
var is_dot: bool

# we store the mesh here as part of the BeepCube for easier access because we will
# reuse it when we create the cut cube pieces
var _mesh: Mesh
var _mat: ShaderMaterial
@export var min_speed := 0.5

var piece_left : CutPiece = null
var piece_right : CutPiece = null

func _ready() -> void:
	_mat = mi.material_override as ShaderMaterial
	_mesh = mi.mesh

	# init our cut pieces with unique copies of our own material for reference,
	# and enable "bouncy" physics behavior
	piece_left = CutPiece.new(self, _mesh, _mat.duplicate(true) as ShaderMaterial, true)
	piece_right = CutPiece.new(self, _mesh, _mat.duplicate(true) as ShaderMaterial, true)

	# slice_particles are within cube's tree, but want then to move in global space
	slice_particles.top_level = true

var note_info: ColorNoteInfo = null  # Store for later use (debris, etc.)
var movement_direction: Vector3 = Vector3.BACK
var distance_moved: float = 0.0
var collision_enable_distance: float = 0.0
var hit_distance: float = 0.0
var miss_distance: float = 0.0

func spawn(note_info_param: ColorNoteInfo, current_beat: float, color : Color) -> void:
	# re-enable our process_mode first otherwise it seems like Godot-internals
	# can behave weirdly (ex. AnimationPlayer won't always play correctly)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Store note info for later use
	note_info = note_info_param

	transform = Transform3D.IDENTITY
	var default_njs: float = Map.current_difficulty.note_jump_movement_speed
	var effective_njs: float = note_info.get_note_jump_movement_speed(default_njs)
	var movement_scale := effective_njs / default_njs if default_njs > 0.0 and effective_njs > 0.0 else 1.0
	speed = (
		Constants.BEAT_DISTANCE
		* Map.current_info.beats_per_minute
		* 0.01666666666666666
		* movement_scale
	)
	beat = note_info.beat
	which_saber = note_info.color
	is_dot = note_info.cut_direction == 8

	# Get position using ME precision positioning if applicable
	var note_position := note_info.get_position()

	# Convert to world space
	transform.origin.x = note_position.x * Constants.LANE_DISTANCE + Constants.LANE_ZERO_X
	transform.origin.y = note_position.y * Constants.LANE_DISTANCE + Constants.LAYER_ZERO_Y
	transform.origin.z = -(note_info.beat - current_beat) * Constants.BEAT_DISTANCE * movement_scale
	var initial_z := transform.origin.z
	distance_moved = 0.0
	collision_enable_distance = maxf(0.0, -3.0 - initial_z)
	hit_distance = -initial_z
	miss_distance = Constants.MISS_Z - initial_z
	var cut_rotation: float
	if note_info.cut_direction < 9:
		cut_rotation = Constants.CUBE_ROTATIONS[note_info.cut_direction] + deg_to_rad(note_info.angle_offset)
	else:
		cut_rotation = deg_to_rad((note_info.cut_direction - 1000) * -1)
	ColorNoteInfo.NoodleData.apply_rotations(
		self,
		cut_rotation,
		note_info.local_rotation_degrees,
		note_info.has_local_rotation,
		note_info.world_rotation_degrees,
		note_info.has_world_rotation
	)
	movement_direction = ColorNoteInfo.NoodleData.get_movement_direction(
		note_info.world_rotation_degrees, note_info.has_world_rotation
	)

	if is_dot:
		(collision_big.shape as BoxShape3D).size.y = 0.8
	else:
		(collision_big.shape as BoxShape3D).size.y = 0.5

	piece_left.set_color(color)
	piece_right.set_color(color)
	_mat.set_shader_parameter(&"color", color)
	_mat.set_shader_parameter(&"is_dot", is_dot)
	# since cube instances get recycled, we gotta reset cubes that were chain
	# heads in a past life
	_mat.set_shader_parameter(&"is_chain_head", false)
	piece_left.set_chain_head(false)
	piece_right.set_chain_head(false)

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

	# play the spawn animation when this cube enters the scene
	var anim := $AnimationPlayer as AnimationPlayer
	var anim_speed := effective_njs / 9.0
	anim.speed_scale = maxf(min_speed,anim_speed)
	anim.play(&"Spawn")

	slice_particles.reset()
	mi.visible = true
	if note_info.uninteractable:
		set_collision_disabled(true)

func _physics_process(delta: float) -> void:
	if Scoreboard.paused or not is_visible_in_tree() or not Map.current_info:
		return
	var frame_distance := speed * delta
	transform.origin += movement_direction * frame_distance
	distance_moved += frame_distance
	if distance_moved >= collision_enable_distance and collision_big.disabled:
		set_collision_disabled(false)
	if distance_moved > miss_distance:
		on_miss()

# call this when clearing the track
# soon I'll add my optimization that really helps.
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
	set_collision_disabled(true)
	# disable processing on this node and all children to help with performance
	process_mode = Node.PROCESS_MODE_DISABLED

func make_chain_head() -> void:
	_mat.set_shader_parameter(&"is_chain_head", true)
	piece_left.set_chain_head(true)
	piece_right.set_chain_head(true)

func on_miss() -> void:
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
		var beat_distance := absf(hit_distance - distance_moved)
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
		_start_cut_pieces(cut_plane)
		# release() will be called by Cuttable class when it sees both pieces die
	else:
		release() # release now instead of waiting for cut pieces to die off

# cut the cube by creating two rigid bodies and using a CSGBox to create
# the cut plane
func _start_cut_pieces(cutplane: Plane) -> void:
	piece_left.global_transform = global_transform
	piece_right.global_transform = global_transform

	# calculate angle and position of the cut
	var cut_angle_abs := Vector2(cutplane.normal.x, cutplane.normal.y).angle()
	var cut_dist_from_center := cutplane.distance_to(global_transform.origin)
	var cut_angle_rel := cut_angle_abs - global_rotation.z

	_piece_death_count = 0
	piece_left.start_cut(-cut_dist_from_center, cut_angle_rel + PI)
	piece_right.start_cut(cut_dist_from_center, cut_angle_rel)

	# some impulse so the cube half moves
	var split_vector := cutplane.normal * 2.0
	piece_left.apply_central_impulse(-split_vector)
	piece_right.apply_central_impulse(split_vector)

	slice_particles.global_transform.origin = global_transform.origin
	slice_particles.rotation.z = cut_angle_abs+TAU*0.25
	slice_particles.fire()
