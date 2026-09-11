extends Node3D
class_name TrackLaneRings

# Beat Saber's TrackLaneRingsManager + TrackLaneRingsRotationEffect +
# TrackLaneRingsRotationEffectSpawner + TrackLaneRingsPositionStepEffectSpawner,
# for the two ring sets of "The First" environment. Each set is one MultiMesh.

class RingSet:
	var multimesh_instance: MultiMeshInstance3D
	var count: int
	var origin: Vector3
	var position_step: float
	var startup_angle: float
	var startup_step: float
	var startup_flexy_speed: float
	var spin_rotation: float
	var spin_step: float
	var spin_flexy_speed: float
	var zoom_min_step: float
	var zoom_max_step: float
	var zoom_move_speed: float
	var has_zoom: bool
	var mesh_basis: Basis
	var rotations: PackedFloat32Array
	var dest_rotations: PackedFloat32Array
	var rotation_speeds: PackedFloat32Array
	var positions: PackedFloat32Array
	var dest_positions: PackedFloat32Array
	var move_speed: float
	var zoom_index: int = 0
	# active propagating rotation effects: [angle, step, flexy, progress]
	var effects: Array = []

@export var ring_color: Color = Color.BLACK

var _sets: Array[RingSet] = []
var _materials: Array[ShaderMaterial] = []

func _ready() -> void:
	_sets.clear()
	# Small rings: 30 rings, 3.5 m apart, from 14 m ahead, 1.4 m up
	_sets.append(_make_set($SmallRings as MultiMeshInstance3D, 30, Vector3(0.0, 1.4, -14.0), 3.5,
		45.0, 5.0, 10.0, 90.0, 10.0, 4.0, 1.0, 3.5, 5.0, true))
	# Big rings: 15 rings, 8 m apart, from 7 m ahead, 5 m up
	_sets.append(_make_set($BigRings as MultiMeshInstance3D, 15, Vector3(0.0, 5.0, -7.0), 8.0,
		45.0, 0.0, 10.0, 90.0, 5.0, 2.0, 8.0, 8.0, 5.0, false))
	for ring_set: RingSet in _sets:
		var material := ring_set.multimesh_instance.material_override as ShaderMaterial
		if material != null:
			_materials.append(material)
		_add_effect(ring_set, ring_set.startup_angle, ring_set.startup_step, ring_set.startup_flexy_speed)
		_write_transforms(ring_set)

func _make_set(
	instance: MultiMeshInstance3D, count: int, origin: Vector3, step: float,
	startup_angle: float, startup_step: float, startup_flexy: float,
	spin_rotation: float, spin_step: float, spin_flexy: float,
	zoom_min: float, zoom_max: float, zoom_speed: float, has_zoom: bool
) -> RingSet:
	var ring_set := RingSet.new()
	ring_set.multimesh_instance = instance
	ring_set.count = count
	ring_set.origin = origin
	ring_set.position_step = step
	ring_set.startup_angle = startup_angle
	ring_set.startup_step = startup_step
	ring_set.startup_flexy_speed = startup_flexy
	ring_set.spin_rotation = spin_rotation
	ring_set.spin_step = spin_step
	ring_set.spin_flexy_speed = spin_flexy
	ring_set.zoom_min_step = zoom_min
	ring_set.zoom_max_step = zoom_max
	ring_set.zoom_move_speed = zoom_speed
	ring_set.has_zoom = has_zoom
	# the exported ring meshes lie in the Y-Z plane; turn them to face the player
	ring_set.mesh_basis = Basis(Vector3.UP, -PI * 0.5)
	ring_set.rotations.resize(count)
	ring_set.dest_rotations.resize(count)
	ring_set.rotation_speeds.resize(count)
	ring_set.positions.resize(count)
	ring_set.dest_positions.resize(count)
	for i in range(count):
		ring_set.positions[i] = i * step
		ring_set.dest_positions[i] = i * step
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = instance.multimesh.mesh if instance.multimesh != null else null
	multimesh.instance_count = count
	instance.multimesh = multimesh
	instance.custom_aabb = AABB(Vector3(-60.0, -60.0, -400.0), Vector3(120.0, 120.0, 400.0))
	return ring_set

func set_ring_color(color: Color) -> void:
	ring_color = color
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter(&"ring_color", color)

## Event 8: every ring turns by 90 degrees (random direction) with a random
## per-ring offset, propagating from the nearest ring outward.
func spin() -> void:
	for ring_set: RingSet in _sets:
		var step := randf_range(-ring_set.spin_step, ring_set.spin_step)
		var direction := -1.0 if randf() < 0.5 else 1.0
		var angle := ring_set.dest_rotations[0] + ring_set.spin_rotation * direction
		_add_effect(ring_set, angle, step, ring_set.spin_flexy_speed)

## Event 9: the small rings alternate between spread out and pulled together.
func zoom() -> void:
	for ring_set: RingSet in _sets:
		if not ring_set.has_zoom:
			continue
		var step := ring_set.zoom_max_step if ring_set.zoom_index % 2 == 0 else ring_set.zoom_min_step
		ring_set.zoom_index += 1
		for i in range(ring_set.count):
			ring_set.dest_positions[i] = i * step
		ring_set.move_speed = ring_set.zoom_move_speed

func _add_effect(ring_set: RingSet, angle: float, step: float, flexy_speed: float) -> void:
	ring_set.effects.append([angle, step, flexy_speed, 0])

func _physics_process(delta: float) -> void:
	for ring_set: RingSet in _sets:
		# propagate rotation effects one ring per physics tick
		for index in range(ring_set.effects.size() - 1, -1, -1):
			var effect: Array = ring_set.effects[index]
			var progress: int = effect[3]
			if progress < ring_set.count:
				ring_set.dest_rotations[progress] = effect[0] + progress * effect[1]
				ring_set.rotation_speeds[progress] = effect[2]
			effect[3] = progress + 1
			if effect[3] >= ring_set.count:
				ring_set.effects.remove_at(index)
		for i in range(ring_set.count):
			ring_set.rotations[i] = lerpf(ring_set.rotations[i], ring_set.dest_rotations[i], clampf(delta * ring_set.rotation_speeds[i], 0.0, 1.0))
			ring_set.positions[i] = lerpf(ring_set.positions[i], ring_set.dest_positions[i], clampf(delta * ring_set.move_speed, 0.0, 1.0))
		_write_transforms(ring_set)

func _write_transforms(ring_set: RingSet) -> void:
	var multimesh := ring_set.multimesh_instance.multimesh
	if multimesh == null:
		return
	for i in range(ring_set.count):
		var roll := Basis(Vector3.BACK, deg_to_rad(ring_set.rotations[i]))
		var origin := ring_set.origin + Vector3(0.0, 0.0, -ring_set.positions[i])
		multimesh.set_instance_transform(i, Transform3D(roll * ring_set.mesh_basis, origin))
