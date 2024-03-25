extends Node3D

var text_mesh: TextMesh

func _ready():
	# gotta make a new text mesh for each one, otherwise they will all ref
	# the same one.  the result of that is if you change the text of one, you
	# change the text of all.
	var new_mesh := TextMesh.new()
	new_mesh.font_size = 4
	new_mesh.depth = 0
	var new_material := StandardMaterial3D.new()
	new_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	new_material.disable_receive_shadows = true
	new_mesh.material = new_material
	($mesh_instance as MeshInstance3D).mesh = new_mesh
	text_mesh = new_mesh

func show_points(_position: Vector3, value: String, color: Color):
	global_position = _position
	text_mesh.text = value
	(text_mesh.material as StandardMaterial3D).albedo_color = color
	$AnimationPlayer.stop()
	$AnimationPlayer.play("hit")
