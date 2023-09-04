extends Node

# emitted when the pool intances a scene for the first time
signal scene_instanced(scene)
@export var Scene : PackedScene
var _free_list = []

func _ready():
	if Scene == null:
		push_error("Scene is null ('%s' ScenePool)" % name)
		return

func acquire(parent: Node = self):
	var cube = _free_list.pop_front()
	if not cube or cube.is_inside_tree():
		var new_scene = Scene.instantiate()
		if new_scene.connect("scene_released", _on_scene_released.bind(new_scene)) != OK:
			push_error("failed to connect 'scene_released' signal. Scene's must emit this signal for the ScenePool to function properly.")
			return
		emit_signal("scene_instanced",new_scene)
		cube = new_scene
	parent.add_child(cube)
	return cube

func _on_scene_released(scene):
	_free_list.push_back(scene)
	#print("pool size: ",_free_list.size())
