extends Node3D
class_name DefaultSaber

# Beat Saber's "BasicSaberModel": blade, glowing edges, handle, two fake glow
# sprites and the trail. The blade points along the local +Y axis.

var is_extended := false

@onready var _anim := $AnimationPlayer as AnimationPlayer
@onready var blade_root := $BladeRoot as Node3D
@onready var blade := $BladeRoot/Blade as MeshInstance3D
@onready var glowing_edges := $BladeRoot/GlowingEdges as MeshInstance3D
@onready var blade_glow := $BladeRoot/BladeGlow as MeshInstance3D
@onready var handle := $Handle as MeshInstance3D
@onready var pommel_glow := $PommelGlow as MeshInstance3D
@onready var tip := $tip as Marker3D
@onready var tail := $tail as SaberTail
@onready var hitsound := $hitsound as AudioStreamPlayer3D

var _materials: Array[ShaderMaterial] = []

func _ready() -> void:
	for mesh_instance: MeshInstance3D in [blade, glowing_edges, handle, blade_glow, pommel_glow]:
		_materials.append(mesh_instance.material_override as ShaderMaterial)
	quickhide()

func set_color(color: Color) -> void:
	for material: ShaderMaterial in _materials:
		var current := material.get_shader_parameter(&"color") as Color
		var tinted := Color(color.r, color.g, color.b, current.a)
		material.set_shader_parameter(&"color", tinted)
	tail.set_color(color)

func set_thickness(value: float) -> void:
	# the blade nodes are rotated 180 degrees about Z so the mesh (authored
	# along -Y) points along +Y; the scale setter keeps that rotation
	blade.scale = Vector3(value, 1.0, value)
	glowing_edges.scale = Vector3(value, 1.0, value)
	(blade_glow.material_override as ShaderMaterial).set_shader_parameter(&"width", 0.12 * value)

func set_trail(enabled: bool = true) -> void:
	tail.set_enabled(enabled)

func _show() -> void:
	_anim.play(&"Show")
	is_extended = true
	tail.set_active(true)

func _hide() -> void:
	_anim.play(&"Hide")
	is_extended = false
	tail.set_active(false)

func quickhide() -> void:
	_anim.play(&"QuickHide")
	is_extended = false
	tail.set_active(false)

func hit(time_offset: float) -> void:
	if time_offset>0.2 or time_offset<-0.05:
		hitsound.play()
	else:
		if time_offset <= 0:
			hitsound.play(-time_offset)
		else:
			await get_tree().create_timer(time_offset).timeout
			hitsound.play()
