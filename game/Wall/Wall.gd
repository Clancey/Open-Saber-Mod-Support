extends Node3D
class_name Wall

var despawn_z: float
var speed: float
var _mat: ShaderMaterial
var testforLayer = 0

const wallYOffset = 3.0

func _ready():
	var mi: = $WallMeshOrientation / WallMesh as MeshInstance3D
	_mat = mi.material_override as ShaderMaterial

func _physics_process(delta: float) -> void :
	if Scoreboard.paused: return
	transform.origin.z += speed * delta


	if transform.origin.z > despawn_z:
		queue_free()

func spawn(wall_info: ObstacleInfo, current_beat: float, color: Color) -> void :

	$WallMeshOrientation / WallMesh.material_override.set_shader_parameter(&"albedo_color", color)
	var mesh: = $WallMeshOrientation / WallMesh as MeshInstance3D
	var m: = mesh.mesh as BoxMesh
	var shape: = ($WallMeshOrientation / WallArea / CollisionShape3D as CollisionShape3D).shape as BoxShape3D
	if wall_info.line_layer == 0:
		testforLayer += 1
		print(testforLayer)



	var wallWidth = wall_info.width
	var wallHeight = wall_info.height
	var wallType = wall_info.type
	if wallWidth >= 1000 and wallWidth <= 4000:
		wallWidth = (wallWidth - 1000) / 1000.0
	elif wallWidth >= 40001 and wallWidth >= 4005000:
		pass

	if wallType >= 1000 and wallType <= 4000:
		wallHeight = (wallType - 1000) / 1000.0
	elif wallType >= 40001 and wallType <= 4005000:
		wallHeight = ((wallType - 4001) / 200000)


	var x = wallWidth * Constants.LANE_DISTANCE
	var y = wallHeight * Constants.LANE_DISTANCE
	var z = wall_info.duration * Constants.BEAT_DISTANCE

	var depth = z * 0.5
	m.size.x = x
	shape.size.x = x
	m.size.y = y
	shape.size.y = y
	m.size.z = z
	shape.size.z = z
	despawn_z = Constants.MISS_Z + depth
	(mesh.material_override as ShaderMaterial).set_shader_parameter(&"size", Vector3(x, y, z))
	if wall_info.line_index > 3 or wall_info.line_index < 0 or wall_info.line_layer > 2 or wall_info.line_layer < 0:
		var wallLineIndex = wall_info.line_index
		var wallLayerIndex = wall_info.line_layer
		var leftSide = false
		var flipLineIndex = wallLineIndex * -1
		var newLaneCount = 1000
		if wallLineIndex >= 1000 or wallLineIndex <= -1000:
			if sign(wall_info.line_index) == 1:
				transform.origin.x = ((wall_info.line_index - ((4 - wallWidth) * 0.5) - 1000) / 1000.0) - 1.5
			else:
				transform.origin.x = ((wall_info.line_index - ((4 - wallWidth) * 0.5) + 1000) / 1000.0) - 1.5
			transform.origin.y = (wall_info.line_layer + (wallHeight * 0.5) - 1000.0) / 1000.0 + 0.8
		else:
			transform.origin.x = (wall_info.line_index - ((4 - wallWidth) * 0.5)) * Constants.LANE_DISTANCE
			transform.origin.y = (wall_info.line_layer + (wallHeight * 0.5)) * Constants.LANE_DISTANCE

		transform.origin.z = - (wall_info.beat - current_beat) * Constants.BEAT_DISTANCE
	else:
		transform.origin.x = (wall_info.line_index - ((4 - wallWidth) * 0.5)) * Constants.LANE_DISTANCE
		transform.origin.y = (wall_info.line_layer + (wallHeight * 0.5)) * Constants.LANE_DISTANCE
		transform.origin.z = (current_beat - wall_info.beat) * Constants.BEAT_DISTANCE - depth

	speed = Constants.BEAT_DISTANCE * Map.current_info.beats_per_minute / 60.0
	($AnimationPlayer as AnimationPlayer).play(&"Spawn")
