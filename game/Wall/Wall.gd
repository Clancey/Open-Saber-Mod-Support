extends Node3D
class_name Wall

var info: Map.ObstacleInfo
var depth: float

@onready var _anim := $AnimationPlayer as AnimationPlayer

#func _ready() -> void:
	# play the spawn animation when wall enters the scene
	#_anim.play(&"Spawn")

func _physics_process(delta: float) -> void:
	if Scoreboard.paused or not Map.current_info: return
	var speed := Vector3(0.0, 0.0, BeepSaber_Game.beat_distance * Map.current_info.beats_per_minute / 60.0) * delta
	translate(speed)
	
	# remove children that go to far
	if global_transform.origin.z - (depth * 0.5) > 3.0:
		queue_free()

func spawn(wall_info: Map.ObstacleInfo, current_beat: float) -> void:
	info = wall_info
	
	var mesh := get_node(^"WallMeshOrientation/WallMesh") as MeshInstance3D
	var coll := get_node(^"WallMeshOrientation/WallArea/CollisionShape3D") as CollisionShape3D
	_anim.play(&"Spawn")
	
	const CUBE_DISTANCE := 0.5
	var x := wall_info.width * CUBE_DISTANCE
	var y := wall_info.height * CUBE_DISTANCE
	var z := wall_info.duration * BeepSaber_Game.beat_distance
	mesh.mesh.size.x = x
	coll.shape.size.x = x
	mesh.mesh.size.y = y
	coll.shape.size.y = y
	mesh.mesh.size.z = z
	coll.shape.size.z = z
	depth = z * 0.5
	mesh.material_override.set_shader_parameter(&"size", Vector3(x, y, z))
	
	transform.origin = Vector3(
		(wall_info.line_index - ((4 - wall_info.width) * 0.5)) * CUBE_DISTANCE,
		(wall_info.line_layer + (wall_info.height * 0.5)) *  CUBE_DISTANCE,
		(current_beat - wall_info.beat) * BeepSaber_Game.beat_distance - depth
	)
