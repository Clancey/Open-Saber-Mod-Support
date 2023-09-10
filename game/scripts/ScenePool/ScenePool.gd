extends Node

# emitted when the pool intances a scene for the first time
signal scene_instanced(scene)
@export var Scene : PackedScene
var _free_list = []
@export_node_path var default_parent

var pre_pool = 100

func _ready():
	if default_parent:
		default_parent = get_node(default_parent)
	else:
		default_parent = self
	if Scene == null:
		push_error("Scene is null ('%s' ScenePool)" % name)
		return
	
	
	print("creating initial cube pool")
	await get_tree().process_frame
	default_parent.visible = true
	var init_cubes = []
	for pp in range(pre_pool):
		var cube = acquire(default_parent, true)
		cube.visible = true
		init_cubes.append(cube)
		if pp%10 == 0:
			await get_tree().process_frame
	#this forces the game to render all of the cubes in a couple of frames to prevent slow downs in the first pool cycle
	for cube in init_cubes:
		cube.release()
	print("cubes in pool: ",_free_list.size())

func acquire(parent: Node = default_parent, force = false):
	var cube = _free_list.pop_front() if not force else null
	if not cube:
		var new_scene = Scene.instantiate()
		if new_scene.connect("scene_released", _on_scene_released.bind(new_scene)) != OK:
			push_error("failed to connect 'scene_released' signal. Scene's must emit this signal for the ScenePool to function properly.")
			return
		emit_signal("scene_instanced",new_scene)
		cube = new_scene
	if not cube.is_inside_tree():
		parent.add_child(cube)
	#print("cubes in pool: ",_free_list.size())
	return cube

func _on_scene_released(scene):
	#_free_list.push_front(scene)
	_free_list.push_back(scene)
	#print("cubes in pool: ",_free_list.size())
