extends Node
class_name BeepCubePool

# emitted when the pool intances a scene for the first time
signal scene_instanced(scene: BeepCube)

@export var scene: PackedScene
var _free_list: Array[BeepCube] = []
@export var track: Node3D

var pre_pool := 100

func _ready() -> void:
	#if default_parent:
	#	default_parent = get_node(default_parent)
	#else:
	#	default_parent = self
	if scene == null:
		push_error("Scene is null ('%s' ScenePool)" % name)
		return
	
	
	print("creating initial cube pool")
	await get_tree().process_frame
	track.visible = true
	var init_cubes: Array[BeepCube] = []
	for pp in range(pre_pool):
		var cube = acquire(true)
		cube.visible = true
		cube.position.z = -2
		init_cubes.append(cube)
		if pp%4 == 0:
			await get_tree().process_frame
	#this forces the game to render all of the cubes in a couple of frames to prevent slow downs in the first pool cycle
	for cube in init_cubes:
		cube.release()
	print("cubes in pool: ",_free_list.size())

func acquire(force = false) -> BeepCube:
	var cube := _free_list.pop_front() as BeepCube if not force else null
	if not cube:
		var new_scene := scene.instantiate() as BeepCube
		new_scene.scene_released.connect(_on_scene_released.bind(new_scene))
		#if new_scene.connect("scene_released", _on_scene_released.bind(new_scene)) != OK:
		#	push_error("failed to connect 'scene_released' signal. Scene's must emit this signal for the ScenePool to function properly.")
		#	return
		scene_instanced.emit(new_scene)
		cube = new_scene
	if not cube.is_inside_tree():
		track.add_child(cube)
	#print("cubes in pool: ",_free_list.size())
	return cube

func _on_scene_released(scene) -> void:
	#_free_list.push_front(scene)
	_free_list.push_back(scene)
	#print("cubes in pool: ",_free_list.size())
