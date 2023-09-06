extends Node3D
class_name BeepCubeSliceParticles

@onready var c1 := $CPUParticles3D

func _ready():
	c1.one_shot = true
	if not RenderingServer.get_rendering_device():
		c1.queue_free()
	reset()

func reset():
	if not c1: return
	visible = false
	c1.emitting = false
	c1.restart()

func fire():
	if not c1: return
	visible = true
	c1.emitting = true
