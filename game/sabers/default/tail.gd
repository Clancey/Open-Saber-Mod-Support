extends Node3D
class_name SaberTail

# Beat Saber's SaberTrail / SaberTrailRenderer: the blade's bottom and top
# positions are snapshotted every physics frame, a Catmull-Rom spline through
# the snapshots is resampled into a fixed number of segments spaced evenly by
# distance, and a two-quad-wide strip is built in world space. The newest
# 0.03 s of the strip is white, the rest is the saber color; the age fade lives
# in the trail texture.

const TRAIL_DURATION: float = 0.4
const GRANULARITY: int = 45
const WHITE_SECTION_MAX_DURATION: float = 0.03
const MIN_MOTION_BLUR_SPEED: float = 2.5
const MOTION_BLUR_STRENGTH: float = 0.8
const MAX_SNAPSHOTS: int = 64

@export var size: float = 1.0

@onready var _mesh_instance: MeshInstance3D = $Mesh as MeshInstance3D
@onready var _material: ShaderMaterial = _mesh_instance.material_override as ShaderMaterial

var _immediate_mesh := ImmediateMesh.new()
# newest snapshot first
var _bottoms: Array[Vector3] = []
var _tops: Array[Vector3] = []
var _times: Array[float] = []
var _enabled: bool = true
var _active: bool = false
var _clock: float = 0.0
# scratch buffers for one rebuild
var _segment_top: Array[Vector3] = []
var _segment_mid: Array[Vector3] = []
var _segment_bottom: Array[Vector3] = []
var _segment_v: Array[float] = []
var _segment_white: Array[float] = []

func _ready() -> void:
	_mesh_instance.mesh = _immediate_mesh
	_mesh_instance.top_level = true
	_mesh_instance.global_transform = Transform3D.IDENTITY
	_mesh_instance.custom_aabb = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
	_segment_top.resize(GRANULARITY)
	_segment_mid.resize(GRANULARITY)
	_segment_bottom.resize(GRANULARITY)
	_segment_v.resize(GRANULARITY)
	_segment_white.resize(GRANULARITY)

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
		if not _bottoms.is_empty():
			_clear()
		return
	_clock += delta
	_bottoms.push_front(global_position)
	_tops.push_front(to_global(Vector3(0.0, size, 0.0)))
	_times.push_front(_clock)
	while _bottoms.size() > MAX_SNAPSHOTS or (_bottoms.size() > 2 and _clock - _times[_bottoms.size() - 1] > TRAIL_DURATION):
		_bottoms.pop_back()
		_tops.pop_back()
		_times.pop_back()
	_rebuild_mesh()

static func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

func _rebuild_mesh() -> void:
	_immediate_mesh.clear_surfaces()
	var count := _bottoms.size()
	if count < 2:
		return
	# cumulative distance along the blade midpoints so segments are spaced by
	# distance instead of time (fast swings stay smooth)
	var distances: PackedFloat32Array = PackedFloat32Array()
	distances.resize(count)
	var total := 0.0
	distances[0] = 0.0
	for i in range(1, count):
		var a := (_bottoms[i - 1] + _tops[i - 1]) * 0.5
		var b := (_bottoms[i] + _tops[i]) * 0.5
		total += a.distance_to(b)
		distances[i] = total
	if total < 0.0005:
		return

	var segment := 0
	var prev_mid := (_bottoms[0] + _tops[0]) * 0.5
	var inverse_segment_duration := float(GRANULARITY) / TRAIL_DURATION
	for i in range(GRANULARITY):
		var target := float(i) / float(GRANULARITY - 1) * total
		while segment < count - 2 and distances[segment + 1] < target:
			segment += 1
		var seg_len := distances[segment + 1] - distances[segment]
		var lerp_t := 0.0 if seg_len <= 0.00001 else clampf((target - distances[segment]) / seg_len, 0.0, 1.0)
		var i0 := maxi(segment - 1, 0)
		var i2 := mini(segment + 1, count - 1)
		var i3 := mini(segment + 2, count - 1)
		var bottom := _catmull_rom(_bottoms[i0], _bottoms[segment], _bottoms[i2], _bottoms[i3], lerp_t)
		var top := _catmull_rom(_tops[i0], _tops[segment], _tops[i2], _tops[i3], lerp_t)
		var sample_time := lerpf(_times[segment], _times[i2], lerp_t)
		var age: float = clampf(_clock - sample_time, 0.0, TRAIL_DURATION)
		var mid := (bottom + top) * 0.5
		# white section right behind the blade, weaker when the blade is slow
		var white := 0.0
		if age < WHITE_SECTION_MAX_DURATION:
			var section := 1.0 - age / WHITE_SECTION_MAX_DURATION
			var speed := maxf(mid.distance_to(prev_mid) * inverse_segment_duration, MIN_MOTION_BLUR_SPEED)
			var blur := MIN_MOTION_BLUR_SPEED / speed
			blur = blur * MOTION_BLUR_STRENGTH + 1.0 - MOTION_BLUR_STRENGTH
			white = clampf(section * blur, 0.0, 1.0)
		prev_mid = mid
		_segment_top[i] = top
		_segment_mid[i] = mid
		_segment_bottom[i] = bottom
		_segment_v[i] = age / TRAIL_DURATION
		_segment_white[i] = white

	# two quads (four triangles) per segment; COLOR.r carries "how much saber
	# color" (1 = color, 0 = white)
	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(GRANULARITY - 1):
		var ca := Color(1.0 - _segment_white[i], 0.0, 0.0, 1.0)
		var cb := Color(1.0 - _segment_white[i + 1], 0.0, 0.0, 1.0)
		var va := _segment_v[i]
		var vb := _segment_v[i + 1]
		# upper quad: top -> mid
		_add_vertex(_segment_top[i + 1], Vector2(0.0, vb), cb)
		_add_vertex(_segment_mid[i + 1], Vector2(0.5, vb), cb)
		_add_vertex(_segment_top[i], Vector2(0.0, va), ca)
		_add_vertex(_segment_mid[i + 1], Vector2(0.5, vb), cb)
		_add_vertex(_segment_mid[i], Vector2(0.5, va), ca)
		_add_vertex(_segment_top[i], Vector2(0.0, va), ca)
		# lower quad: mid -> bottom
		_add_vertex(_segment_mid[i + 1], Vector2(0.5, vb), cb)
		_add_vertex(_segment_bottom[i + 1], Vector2(1.0, vb), cb)
		_add_vertex(_segment_mid[i], Vector2(0.5, va), ca)
		_add_vertex(_segment_bottom[i + 1], Vector2(1.0, vb), cb)
		_add_vertex(_segment_bottom[i], Vector2(1.0, va), ca)
		_add_vertex(_segment_mid[i], Vector2(0.5, va), ca)
	_immediate_mesh.surface_end()

func _add_vertex(vertex: Vector3, uv: Vector2, color: Color) -> void:
	_immediate_mesh.surface_set_color(color)
	_immediate_mesh.surface_set_uv(uv)
	_immediate_mesh.surface_add_vertex(vertex)

func _clear() -> void:
	_bottoms.clear()
	_tops.clear()
	_times.clear()
	_immediate_mesh.clear_surfaces()
