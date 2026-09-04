extends Node3D
class_name SaberTail

class TrailSample:
	extends RefCounted

	var base_position: Vector3
	var tip_position: Vector3
	var age: float = 0.0

	func _init(base: Vector3, tip: Vector3) -> void:
		base_position = base
		tip_position = tip

const TRAIL_LIFETIME: float = 0.2
const MAX_SAMPLES: int = 18
const TRAIL_ALPHA: float = 0.46

@export var size: float = 1.0

@onready var _mesh_instance: MeshInstance3D = $Mesh as MeshInstance3D
@onready var _material: ShaderMaterial = _mesh_instance.material_override as ShaderMaterial
@onready var _immediate_mesh: ImmediateMesh = _mesh_instance.mesh as ImmediateMesh

var _samples: Array[TrailSample] = []
var _enabled: bool = true
var _active: bool = false

func set_color(color: Color) -> void:
	_material.set_shader_parameter(&"color", color)

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	visible = enabled
	if not enabled:
		_clear()

func set_active(active: bool) -> void:
	_active = active
	if not active:
		_clear()

func _physics_process(delta: float) -> void:
	if not _enabled or not _active or size <= 0.001:
		if not _samples.is_empty():
			_clear()
		return

	for sample: TrailSample in _samples:
		sample.age += delta

	while not _samples.is_empty() and _samples.back().age >= TRAIL_LIFETIME:
		_samples.pop_back()

	var current_sample := TrailSample.new(
		global_position,
		to_global(Vector3(0.0, size, 0.0))
	)
	_samples.push_front(current_sample)
	if _samples.size() > MAX_SAMPLES:
		_samples.resize(MAX_SAMPLES)

	_rebuild_mesh()

func _rebuild_mesh() -> void:
	_immediate_mesh.clear_surfaces()
	if _samples.size() < 2:
		return

	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(_samples.size() - 1):
		var newer: TrailSample = _samples[index]
		var older: TrailSample = _samples[index + 1]
		var newer_alpha: float = _sample_alpha(newer)
		var older_alpha: float = _sample_alpha(older)
		var newer_base: Vector3 = _mesh_instance.to_local(newer.base_position)
		var newer_tip: Vector3 = _mesh_instance.to_local(newer.tip_position)
		var older_base: Vector3 = _mesh_instance.to_local(older.base_position)
		var older_tip: Vector3 = _mesh_instance.to_local(older.tip_position)

		_add_vertex(newer_base, newer_alpha)
		_add_vertex(newer_tip, newer_alpha)
		_add_vertex(older_tip, older_alpha)
		_add_vertex(newer_base, newer_alpha)
		_add_vertex(older_tip, older_alpha)
		_add_vertex(older_base, older_alpha)
	_immediate_mesh.surface_end()

func _sample_alpha(sample: TrailSample) -> float:
	var fade: float = 1.0 - clampf(sample.age / TRAIL_LIFETIME, 0.0, 1.0)
	return fade * fade * TRAIL_ALPHA

func _add_vertex(vertex: Vector3, alpha: float) -> void:
	_immediate_mesh.surface_set_color(Color(1.0, 1.0, 1.0, alpha))
	_immediate_mesh.surface_add_vertex(vertex)

func _clear() -> void:
	_samples.clear()
	_immediate_mesh.clear_surfaces()
