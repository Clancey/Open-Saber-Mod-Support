extends Node3D
class_name BeepCubeSliceParticles

# Beat Saber's NoteCutParticlesEffect: a burst of directional sparkles along the
# cut plus a short spherical explosion, both in the note's color.

@onready var sparkles := $Particles3D as GPUParticles3D
@onready var explosion := $Explosion3D as GPUParticles3D

var _enabled := true

func _ready() -> void:
	#disable gpu particles since they don't work correctly on android
	if OS.get_name() in ["Android", "Web"]:
		_enabled = false
		sparkles.free()
		explosion.free()
		return
	sparkles.one_shot = true
	explosion.one_shot = true
	reset()

func reset() -> void:
	if not _enabled: return
	visible = false
	sparkles.emitting = false
	explosion.emitting = false
	sparkles.restart()
	explosion.restart()

func set_color(color: Color) -> void:
	if not _enabled: return
	var bright := color.lerp(Color.WHITE, 0.35)
	(sparkles.process_material as ParticleProcessMaterial).color = bright
	(explosion.process_material as ParticleProcessMaterial).color = bright

func fire() -> void:
	if not _enabled: return
	visible = true
	sparkles.emitting = true
	explosion.emitting = true
