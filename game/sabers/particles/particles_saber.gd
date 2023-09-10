extends "res://game/sabers/default/default_saber.gd"

@onready var Particles = $CPUParticles3D

func _sub_ready():
	saber_holder.saber_hit.connect(hit_particles)
	if OS.get_name() in ["Android","Web"]:
		Particles.free()

var last_tip_pos = Vector3()
func _process(delta):
	var current_tip_pos = $tip.global_transform.origin
	var speed = (current_tip_pos-last_tip_pos).length()
	if is_instance_valid(Particles):
		Particles.speed_scale = 2.5+(30*speed)
		#Particles.lifetime = max(0.1, 2-(20*speed))
	last_tip_pos = current_tip_pos

func hit_particles(cube,time_offset):
	$hitsound.pitch_scale = randf_range(0.9,1.1)

func set_thickness(value): #ignore set thinkness on this saber
	pass
