extends Node3D
class_name MenuDecor

# Beat Saber's menu environment dressing: the neon logo high up in front of
# the player (with the flickering letter and its sparks), note cubes scattered
# on the floor around the menu and two levitating notes. Positions are the
# original's (Unity z flipped).

const NOTE_MESH: Mesh = preload("res://game/assets/beatsaber/meshes/note_cube.obj")
const NOTE_SHADER: Shader = preload("res://game/BeepCube/NoteHD.gdshader")

const LEFT_COLOR := Color(0.784, 0.078, 0.078)
const RIGHT_COLOR := Color(0.157, 0.557, 0.824)
const LOGO_RED := Color(1.0, 0.031, 0.031)
const LOGO_BLUE := Color(0.0, 0.66, 1.0)
const LOGO_ENERGY := 2.6

## note piles from the original DefaultMenuEnvironment (x, y, z in Godot space, yaw degrees, colour index)
const NOTES := [
	[9.77, 0.226, -5.03, -4.0, 0], [-5.38, 0.226, -5.67, 72.0, 1], [-4.95, 0.3, -6.14, 40.0, 0],
	[-5.55, 0.29, -6.26, -60.0, 1], [-6.06, 0.226, -6.58, 106.0, 0], [8.79, 0.226, -1.11, 102.0, 1],
	[9.07, 0.27, -1.6, 30.0, 0], [9.8, 0.226, -4.46, 52.0, 0], [-7.61, 0.226, -3.9, 52.0, 1],
	[-10.1, 0.226, -8.22, 34.0, 0], [-9.86, 0.31, -7.63, 10.0, 1], [-10.11, 0.226, -8.73, -38.0, 1],
	[7.02, 0.226, -5.7, 86.0, 0], [7.5, 0.226, -5.44, 24.0, 1], [6.93, 0.36, -5.13, -30.0, 0],
	[7.61, 0.226, -4.77, -4.0, 1], [6.5, 0.226, -4.78, 28.0, 0],
	# pile just in front of the platform
	[-0.28, 0.226, 2.28, 86.0, 0], [0.2, 0.226, 2.54, 24.0, 1], [-0.37, 0.36, 2.84, -30.0, 0],
	[0.3, 0.226, 3.2, -4.0, 1], [-0.8, 0.226, 3.18, 28.0, 0],
]
## levitating notes: origin, yaw
const LEVITATING := [[4.07, 0.0, -5.42, 86.0, 1], [-7.1, 0.0, -0.59, 65.0, 0]]

@onready var _logo := $Logo as Node3D
@onready var _open := $Logo/Open as Sprite3D
@onready var _open_e := $Logo/OpenE as Sprite3D
@onready var _saber := $Logo/Saber as Sprite3D
@onready var _sparks := $Logo/Sparks as GPUParticles3D

var _levitating: Array[Node3D] = []
var _flicker_time := 0.0
var _flicker_on := true
var _time := 0.0

func _ready() -> void:
	_open.modulate = LOGO_RED * LOGO_ENERGY
	_open_e.modulate = LOGO_RED * LOGO_ENERGY
	_saber.modulate = LOGO_BLUE * LOGO_ENERGY
	_open.modulate.a = 1.0
	_open_e.modulate.a = 1.0
	_saber.modulate.a = 1.0
	var notes := Node3D.new()
	notes.name = "Notes"
	add_child(notes)
	for entry: Array in NOTES:
		var note := _make_note(LEFT_COLOR if int(entry[4]) == 0 else RIGHT_COLOR)
		note.position = Vector3(entry[0], entry[1], entry[2])
		note.rotation_degrees = Vector3(0.0, float(entry[3]), 0.0)
		notes.add_child(note)
	for entry: Array in LEVITATING:
		var pivot := Node3D.new()
		pivot.position = Vector3(entry[0], entry[1], entry[2])
		pivot.rotation_degrees = Vector3(0.0, float(entry[3]), 0.0)
		notes.add_child(pivot)
		var note := _make_note(LEFT_COLOR if int(entry[4]) == 0 else RIGHT_COLOR)
		note.position = Vector3(0.0, 0.6, 0.0)
		pivot.add_child(note)
		_levitating.append(note)
	_schedule_flicker()

func _make_note(color: Color) -> MeshInstance3D:
	var note := MeshInstance3D.new()
	note.mesh = NOTE_MESH
	note.layers = 3
	var material := ShaderMaterial.new()
	material.shader = NOTE_SHADER
	material.set_shader_parameter(&"color", color)
	material.set_shader_parameter(&"albedo_multiplier", 0.9)
	material.set_shader_parameter(&"emission_energy", 0.16)
	material.set_shader_parameter(&"rim_dim", 0.55)
	material.set_shader_parameter(&"rim_dim_power", 2.2)
	material.set_shader_parameter(&"roughness_value", 0.3)
	material.set_shader_parameter(&"metallic_value", 0.0)
	note.material_override = material
	return note

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	# LevitatingCube: 8 s loop, 0.6 -> 0.75 m with a slight drift and slow turn
	var phase := (_time / 8.0) * TAU
	for i in range(_levitating.size()):
		var note := _levitating[i]
		var offset := phase + i * 1.7
		note.position = Vector3(-0.03 * sin(offset), 0.675 + 0.075 * -cos(offset), 0.04 * sin(offset))
		note.rotation_degrees = Vector3(2.0 * sin(offset * 0.5), 6.0 * sin(offset * 0.25), 0.0)
	# FlickeringNeonSign on the E
	_flicker_time -= delta
	if _flicker_time <= 0.0:
		_flicker_on = not _flicker_on
		_schedule_flicker()
		_open_e.visible = _flicker_on
		if not _flicker_on:
			_sparks.restart()
			_sparks.emitting = true

func _schedule_flicker() -> void:
	if _flicker_on:
		# mostly on, with the occasional stutter
		_flicker_time = randf_range(0.05, 0.8) if randf() < 0.35 else randf_range(1.5, 6.0)
	else:
		_flicker_time = randf_range(0.05, 0.3)
