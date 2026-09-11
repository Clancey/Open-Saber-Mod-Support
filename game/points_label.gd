extends Node3D

var label: Label3D
var player: AnimationPlayer

func _ready():
	player = $AnimationPlayer as AnimationPlayer
	label = $mesh_instance as Label3D

func show_points(_position: Vector3, value: String, color: Color):
	global_position = _position
	label.text = value
	label.modulate = color
	player.stop()
	player.play("hit")
