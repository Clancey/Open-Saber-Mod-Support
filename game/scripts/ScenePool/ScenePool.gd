extends Node

# emitted when the pool intances a scene for the first time
signal scene_instanced(scene)

@export var Scene : PackedScene
@export var pool_size = 10

@onready var LinkedList := preload("res://game/scripts/LinkedList.gd")
@onready var _free_list := LinkedList.new()

func _ready():
	if Scene == null:
		push_error("Scene is null ('%s' ScenePool)" % name)
		return
	
	var prepool = []
	for _i in range(pool_size):
		var c = acquire(self, true)
		c.spawn(0, Color.BLACK)
		prepool.append(c)
	for c in prepool:
		c.release()

func acquire(parent: Node = self, push_to_pool = false):
	var cube = _free_list.pop_front()
	if not cube:
		var new_scene = Scene.instantiate()
		parent.add_child(new_scene)
		if new_scene.connect("scene_released", _on_scene_released.bind(new_scene)) != OK:
			push_error("failed to connect 'scene_released' signal. Scene's must emit this signal for the ScenePool to function properly.")
			return
		emit_signal("scene_instanced",new_scene)
		_free_list.push_back(new_scene)
		cube = new_scene
	else:
		if cube.is_inside_tree():
			if cube.get_parent() != parent:
				cube.get_parent().remove_child(cube)
				parent.add_child(cube)
		else:
			parent.add_child(cube)
	return cube

func _on_scene_released(scene):
	_free_list.push_back(scene)
	#print("pool size: ",_free_list._len)
