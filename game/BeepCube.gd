# BeepCube is the standard cube that will get cut by the sabers
extends Note
class_name BeepCube

# emitted when the cube is 'destroyed'. this signal is required by ScenePool to
# manage when an instanced scene is free again.
signal scene_released()

# the animation player contains the span animation that is applied to the CubeMeshAnimation node
@onready var _anim := $CubeMeshAnimation/AnimationPlayer as AnimationPlayer
@onready var _big_coll_area := $BeepCube_Big as Area3D
@onready var _small_coll_area := $BeepCube_Small as Area3D
@onready var collision_big := $BeepCube_Big/CollisionBig as CollisionShape3D
@onready var collision_small := $BeepCube_Small/CollisionSmall as CollisionShape3D

# structure of nodes that represent a cut piece of a cube (ie. one half)
class CutPieceNodes:
	extends RefCounted
	
	var rigid_body := RigidBody3D.new()
	var mesh := MeshInstance3D.new()
	var coll := CollisionShape3D.new()
	
	func _init():
		rigid_body.add_to_group(&"cutted_cube")
		rigid_body.collision_layer = 0
		rigid_body.collision_mask = CollisionLayerConstants.Floor_mask
		rigid_body.gravity_scale = 1
		# set a phyiscs material for some more bouncy behaviour
		rigid_body.physics_material_override = preload("res://game/BeepCube_Cut.phymat")
		
		coll.shape = BoxShape3D.new()
		
		rigid_body.add_child(coll)
		rigid_body.add_child(mesh)
		
		rigid_body.set_script(preload("res://game/BeepCube_CutFadeout.gd"))

# structure of nodes that are used to produce effects when cutting a cube
class CutCubeResources:
	extends RefCounted
	
	var particles : BeepCubeSliceParticles = null
	var piece1 := CutPieceNodes.new()
	var piece2 := CutPieceNodes.new()
	
	func _init():
		particles = preload("res://game/BeepCube_SliceParticles.tscn").instantiate() as BeepCubeSliceParticles


static var LinkedList := preload("res://game/scripts/LinkedList.gd")
const MAX_CUT_CUBE_RESOURCES := 32
static var _cut_cube_resources := LinkedList.new()

# we store the mesh here as part of the BeepCube for easier access because we will
# reuse it when we create the cut cube pieces
var _mesh: Mesh
var _mat: ShaderMaterial
@export var min_speed := 0.5

func _ready() -> void:
	var mi := $CubeMeshAnimation/BeepCube_Mesh as MeshInstance3D
	_mat = mi.material_override.duplicate(true) as ShaderMaterial
	mi.mesh = mi.mesh.duplicate() as Mesh
	mi.material_override = _mat
	_mesh = mi.mesh
	
	# initialize list of cut cube resources
	if _cut_cube_resources._len == 0:
		for _i in range(MAX_CUT_CUBE_RESOURCES):
			var new_res := CutCubeResources.new()
			get_tree().get_root().add_child(new_res.particles)
			get_tree().get_root().add_child(new_res.piece1.rigid_body)
			get_tree().get_root().add_child(new_res.piece2.rigid_body)
			_cut_cube_resources.push_back(new_res)

func update_color_only(color : Color) -> void:
	_mat.set_shader_parameter(&"color",color);

# note_type: 0 -> left, 1 -> right
func spawn(note_type: int, color: Color, is_dot: bool) -> void:
	_mat.set_shader_parameter(&"color",color)
	_mat.set_shader_parameter(&"is_dot", is_dot)
	
	# separate cube collision layers to allow a diferent collider on right/wrong cuts.
	# opposing collision layers (ie. right note & left saber) will be placed on the
	# smalling collision shape, while similar collision layers (ie right note &
	# right saber) are placed on the larger collision shape.
	var is_left_note := note_type == 0
	_big_coll_area.collision_layer = 0x0
	_big_coll_area.set_collision_layer_value(CollisionLayerConstants.LeftNote_bit, is_left_note)
	_big_coll_area.set_collision_layer_value(CollisionLayerConstants.RightNote_bit, not is_left_note)
	_small_coll_area.collision_layer = 0x0
	_small_coll_area.set_collision_layer_value(CollisionLayerConstants.LeftNote_bit, not is_left_note)
	_small_coll_area.set_collision_layer_value(CollisionLayerConstants.RightNote_bit, is_left_note)
	
	visible = true
	
	# play the spawn animation when this cube enters the scene
	_anim.speed_scale = maxf(min_speed,speed)
	_anim.play(&"Spawn")

func release() -> void:
	visible = false
	set_collision_disabled(true)
	@warning_ignore("return_value_discarded")
	emit_signal(&"scene_released")

func set_collision_disabled(value: bool) -> void:
	collision_disabled = value
	collision_big.disabled = value
	collision_small.disabled = value

func cut(saber_type: int, cut_speed: Vector3, cut_plane: Plane, controller: BeepSaberController) -> void:
# compute the angle between the cube orientation and the cut direction
	var cut_direction_xy := -Vector3(cut_speed.x, cut_speed.y, 0.0).normalized()
	var base_cut_angle_accuracy := global_transform.basis.y.dot(cut_direction_xy)
	var cut_angle_accuracy := clampf((base_cut_angle_accuracy-0.7)/0.3, 0.0, 1.0)
	if _note._cutDirection==8: #ignore angle if is a dot
		cut_angle_accuracy = 1.0
	var cut_distance := cut_plane.distance_to(global_transform.origin)
	var cut_distance_accuracy = clampf((0.1 - absf(cut_distance))/0.1, 0.0, 1.0)
	var travel_distance_factor := (controller.movement_aabb as AABB).get_longest_axis_size()
	travel_distance_factor = clamp((travel_distance_factor-0.5)/0.5, 0.0, 1.0)
	
	# acquire oldest CutCubeResources to use for this event. we reused these
	# resource for performance reasons. it gets placed onto the back of the
	# list so that it won't get used again for a couple more cycles.
	var cut_res : CutCubeResources = _cut_cube_resources.pop_front()
	_cut_cube_resources.push_back(cut_res)
	_create_cut_rigid_body(-1, cut_plane, cut_distance, cut_speed, cut_res)
	_create_cut_rigid_body( 1, cut_plane, cut_distance, cut_speed, cut_res)
	
	# allows a bit of save margin where the beat is considered 100% correct
	var beat_accuracy := clampf((1.0 - absf(global_transform.origin.z)) / 0.5, 0.0, 1.0)
	
	BeepSaber_Game.game._update_points_from_cut(saber_type, self, beat_accuracy, cut_angle_accuracy, cut_distance_accuracy, travel_distance_factor)
	
	# reset the movement tracking volume for the next cut
	controller.reset_movement_aabb()
	
	release()

# cut the cube by creating two rigid bodies and using a CSGBox to create
# the cut plane
func _create_cut_rigid_body(_sign: int, cutplane: Plane, cut_distance: float, controller_speed: Vector3, cut_res: CutCubeResources) -> void:
	# this function gets run twice, one for each piece of the cube
	var piece: CutPieceNodes = cut_res.piece1
	if _sign == 1:
		piece = cut_res.piece2
	
	# make piece invisible and stop it's processing while we're updating it
	piece.rigid_body.reset()
	
	# the original cube mesh
	piece.mesh.mesh = _mesh
	piece.mesh.material_override = _mat.duplicate()
	
	# calculate angle and position of the cut
	piece.mesh.material_override.set_shader_parameter(&"cutted", true)
	piece.mesh.material_override.set_shader_parameter(&"inverted_cut", true)
	# TODO: cutplane is unused and replaced by this? what
	#var saber_end_mov = saber_ends[0]-saber_ends[1]
	#var saber_end_angle = rad_to_deg(Vector2(saber_end_mov.x,saber_end_mov.y).angle())
	#var saber_end_angle_rel = (int(((saber_end_angle+90)+(360-piece.mesh.rotation_degrees.z))+180)%360)-180
	
	#var rot_dir = saber_end_angle_rel > 90 or saber_end_angle_rel < -90
	#var rot_dir_flt = (float(rot_dir)*2)-1
	var angle := rad_to_deg(Vector2(cutplane.normal.y, -cutplane.normal.x).angle())
	var angle_rel := (int(((angle+90)+(360-piece.mesh.rotation_degrees.z))+180)%360)-180
	
	var rot_dir := float(angle_rel > 90 or angle_rel < -90)
	#piece.mesh.material_override.set_shader_parameter(&"cut_pos",cut_distance*rot_dir_flt)
	piece.mesh.material_override.set_shader_parameter(&"cut_pos", cut_distance * rot_dir)
	piece.mesh.material_override.set_shader_parameter(&"cut_angle", deg_to_rad(angle_rel))
	#piece.mesh.material_override.set_shader_parameter(&"cut_pos", 0)
	#piece.mesh.material_override.set_shader_parameter(&"cut_angle", 0)

	# transform the normal into the orientation of the actual cube mesh
	var normal = piece.mesh.transform.basis.inverse() * cutplane.normal
	
	# Next we are adding a simple collision cube to the rigid body. Note that
	# his is really just a very crude approximation of the actual cut geometry
	# but for now it's enough to give them some physics behaviour
	piece.coll.shape.size = Vector3(0.25, 0.25, 0.125)
	piece.coll.look_at_from_position(-cutplane.normal*_sign*0.125, cutplane.normal, Vector3(0,1,0))

	piece.rigid_body.global_transform = global_transform
	piece.rigid_body.linear_velocity = Vector3.ZERO
	piece.rigid_body.angular_velocity = Vector3.ZERO
	# make piece visible and start its simulation
	piece.rigid_body.fire()
	
	# some impulse so the cube half moves
	var cutplane_2d = Vector3(cutplane.x,cutplane.y,0.0) * 2.0
	var splitplane_2d = cutplane_2d.cross(piece.mesh.transform.basis.z)
	piece.rigid_body.apply_central_impulse((_sign * splitplane_2d) + (cutplane_2d))
	
	# This function gets run twice so we don't want two particle effects
	if is_equal_approx(_sign,1):
		cut_res.particles.transform.origin = global_transform.origin
		cut_res.particles.rotation_degrees.z = angle+90
		cut_res.particles.fire()
