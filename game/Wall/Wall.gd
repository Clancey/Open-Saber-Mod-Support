@tool
extends Node3D
class_name Wall

# copy of 'obstacle' struct from map data
var _obstacle;

# width of wall in meters
@export var width = 1: set = _set_width
# height of wall in meters
@export var height = 1: set = _set_height
# depth of wall in meters (can be negative)
@export var depth = 1: set = _set_depth

@onready var _anim = $WallMeshOrientation/AnimationPlayer
@onready var _mesh_orientation = $WallMeshOrientation
@onready var _mesh = $WallMeshOrientation/WallMesh
@onready var _coll = $WallMeshOrientation/WallArea/CollisionShape3D

func _ready():
	# play the spawn animation when wall enters the scene
	_anim.play("Spawn")

func _set_width(value):
	width = value
	
	if not _mesh:
		await self.ready
		
	_mesh.mesh.size.x = width
	_coll.shape.size.x = width #/ 2.0
	_mesh_orientation.position.x = width / 2.0
	update_material()
	
func _set_height(value):
	height = value
	
	if not _mesh:
		await self.ready
		
	_mesh.mesh.size.y = height
	_coll.shape.size.y = height #/ 2.0
	_mesh_orientation.position.y = height / 2.0
	update_material()
	
func _set_depth(value):
	depth = value
	
	if not _mesh:
		await self.ready
		
	_mesh.mesh.size.z = depth
	_coll.shape.size.z = depth #/ 2.0
	_mesh_orientation.position.z = -1 * depth / 2.0
	update_material()

func update_material():
	_mesh.material_override.set_shader_parameter("size", Vector3(width, height, depth))
	
func duplicate_create():
	if not _mesh:
		await self.ready
	
	_mesh.mesh = _mesh.mesh.duplicate();
	_mesh.material_override = _mesh.material_override.duplicate()
	_coll.shape = _coll.shape.duplicate()
