extends Node3D
class_name BeepCubeSliceParticles

@onready var c1 := $CPUParticles3D

func _ready():
	c1.one_shot = true
	reset()

func reset():
	visible = false
	c1.emitting = false
	c1.restart()

func fire():
	visible = true
	c1.emitting = true
