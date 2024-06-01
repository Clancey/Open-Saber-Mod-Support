extends RigidBody3D
class_name BeepCubeCut

var _meshinstance: MeshInstance3D

const timer_length := 0.3
const timer_rcp := 1.0/timer_length
var lifetime := 0.0

func _ready() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			_meshinstance = child as MeshInstance3D
			break
	if _meshinstance == null:
		print("WARN: could not find child MeshInstance3D")
	reset()

func reset() -> void:
	lifetime = 0.0
	visible = false
	# set both velocities to zero
	linear_velocity *= 0
	angular_velocity *= 0
	set_process(false)
	set_physics_process(false)

func fire() -> void:
	if _meshinstance != null:
		visible = true
		set_process(true)
		set_physics_process(true)

func _process(delta: float) -> void:
	lifetime += delta
	if lifetime > timer_length:
		reset()
		return
	var f := lifetime*timer_rcp
	(_meshinstance.material_override as ShaderMaterial).set_shader_parameter(&"cut_vanish",ease(f,2)*0.5)

#	f = ease(f,0.1)
#	_meshinstance.scale = Vector3(f, f, f)
