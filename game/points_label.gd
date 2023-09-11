extends Node3D

func _ready():
	$points/mesh.material_override.albedo_texture = $SubViewport.get_texture()

func show_points(_position=Vector3(),value="x",color = Color(1,1,1)):
	global_position = _position
	$SubViewport/Label.text = str(value)
	$SubViewport/Label.modulate = color
	$AnimationPlayer.stop()
	$AnimationPlayer.play("hit")
	$update_once.update_once($SubViewport)
