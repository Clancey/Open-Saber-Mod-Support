extends Node
class_name LightManager

const TYPE_DIAGONAL_LASERS: int = 0
const TYPE_SQUARE_LASERS: int = 1
const TYPE_LEFT_WAVING_LASERS: int = 2
const TYPE_RIGHT_WAVING_LASERS: int = 3
const TYPE_FLOOR_LIGHTS: int = 4
const LIGHT_BAR_SHADER: Shader = preload("res://game/data/light_bar.gdshader")

# Light instances organized by type and ID.
# Structure: { type: { id: LightInstance } }
var lights_by_type_and_id: Dictionary = {}
var light_updates: int = 0
var _lights_by_type: Dictionary = {}
var _animated_lights: Array[LightInstance] = []
var _empty_lights: Array[LightInstance] = []
static var _instance_ids_by_type: Dictionary = {}


class LightInstance:
	var manager: LightManager
	var mesh_instance: MeshInstance3D
	var material: StandardMaterial3D
	var current_color: Color = Color.BLACK
	var visible: bool = false
	var active_tween: Tween = null
	var has_unique_material: bool = false
	var batch: MultiMeshInstance3D
	var batch_index: int = -1
	var source_transform_adjustment: Transform3D = Transform3D.IDENTITY
	var cached_transform: Transform3D = Transform3D.IDENTITY

	func _init(
		owner: LightManager,
		mesh: MeshInstance3D,
		source_material: StandardMaterial3D,
		multimesh_instance: MultiMeshInstance3D = null,
		instance_index: int = -1,
		transform_adjustment: Transform3D = Transform3D.IDENTITY
	) -> void:
		manager = owner
		mesh_instance = mesh
		material = source_material
		batch = multimesh_instance
		batch_index = instance_index
		source_transform_adjustment = transform_adjustment
		if is_instance_valid(material):
			current_color = material.albedo_color
		else:
			current_color = Color.WHITE
		visible = mesh.visible

	func ensure_unique_material() -> bool:
		if is_batched():
			return true
		if has_unique_material:
			return true
		if not is_instance_valid(material) or not is_instance_valid(mesh_instance):
			return false
		var duplicated_material: StandardMaterial3D = material.duplicate() as StandardMaterial3D
		if not is_instance_valid(duplicated_material):
			return false
		material = duplicated_material
		mesh_instance.material_override = material
		has_unique_material = true
		return true

	func is_batched() -> bool:
		return is_instance_valid(batch) and batch.multimesh != null and batch_index >= 0

	func set_color(color: Color) -> void:
		if current_color == color:
			return
		current_color = color
		_write_state()

	func set_visible(is_visible: bool) -> void:
		if visible == is_visible:
			return
		visible = is_visible
		_write_state()

	func write_initial_state() -> void:
		if is_batched():
			batch.multimesh.set_instance_custom_data(batch_index, _get_custom_data())
			_write_transform()

	func sync_transform() -> void:
		if not is_batched() or not is_instance_valid(mesh_instance):
			return
		var relative_transform: Transform3D = (
			batch.global_transform.affine_inverse()
			* mesh_instance.global_transform
			* source_transform_adjustment
		)
		cached_transform = relative_transform
		_write_transform()

	func _write_state() -> void:
		if is_batched():
			batch.multimesh.set_instance_custom_data(batch_index, _get_custom_data())
			_write_transform()
			manager.light_updates += 1
			return
		if is_instance_valid(material) and material.albedo_color != current_color:
			material.albedo_color = current_color
			manager.light_updates += 1
		if is_instance_valid(mesh_instance) and mesh_instance.visible != visible:
			mesh_instance.visible = visible
			manager.light_updates += 1

	func _get_custom_data() -> Color:
		return Color(
			current_color.r,
			current_color.g,
			current_color.b,
			current_color.a if visible else 0.0
		)

	func _write_transform() -> void:
		if not is_batched():
			return
		var target_transform: Transform3D = cached_transform
		if not visible or current_color.a <= 0.0:
			target_transform = Transform3D(
				Basis.from_scale(Vector3.ZERO),
				cached_transform.origin
			)
		if batch.multimesh.get_instance_transform(batch_index) != target_transform:
			batch.multimesh.set_instance_transform(batch_index, target_transform)

	func stop_tween() -> void:
		if active_tween and is_instance_valid(active_tween):
			active_tween.kill()
			active_tween = null

	func flash(target_color: Color, parent_node: Node) -> void:
		stop_tween()
		set_visible(true)
		set_color(target_color * 3.0)
		active_tween = parent_node.create_tween()
		active_tween.set_trans(Tween.TRANS_LINEAR)
		active_tween.set_ease(Tween.EASE_OUT)
		active_tween.tween_method(set_color, target_color * 3.0, target_color, 1.0)

	func flash_fade_off(target_color: Color, parent_node: Node) -> void:
		stop_tween()
		set_visible(true)
		set_color(target_color * 3.0)
		active_tween = parent_node.create_tween()
		active_tween.set_trans(Tween.TRANS_QUAD)
		active_tween.set_ease(Tween.EASE_IN)
		active_tween.tween_method(set_color, target_color * 3.0, Color.BLACK, 1.0)
		active_tween.finished.connect(_on_fade_off_finished, CONNECT_ONE_SHOT)

	func fade_to(target_color: Color, parent_node: Node, duration: float = 1.0) -> void:
		stop_tween()
		set_visible(true)
		var from_color: Color = current_color
		active_tween = parent_node.create_tween()
		active_tween.set_trans(Tween.TRANS_LINEAR)
		active_tween.set_ease(Tween.EASE_IN)
		active_tween.tween_method(set_color, from_color, target_color, duration)

	func _on_fade_off_finished() -> void:
		set_visible(false)


func initialize_lights(event_driver: EventDriver) -> void:
	if not is_instance_valid(event_driver):
		push_warning("LightManager: EventDriver is not valid, skipping initialization")
		return

	lights_by_type_and_id.clear()
	_lights_by_type.clear()
	_animated_lights.clear()
	_instance_ids_by_type.clear()

	_build_batch(
		TYPE_DIAGONAL_LASERS,
		event_driver.diagonal_lasers_batch,
		_collect_mesh_instances(event_driver.diagonal_lasers_holder),
		true
	)
	_build_batch(
		TYPE_SQUARE_LASERS,
		event_driver.square_lasers_batch,
		_collect_mesh_instances(event_driver.square_lasers_holder),
		false
	)
	_build_batch(
		TYPE_LEFT_WAVING_LASERS,
		event_driver.left_waving_lasers_batch,
		_collect_mesh_instances(event_driver.left_waving_lasers_holder),
		true,
		true
	)
	_build_batch(
		TYPE_RIGHT_WAVING_LASERS,
		event_driver.right_waving_lasers_batch,
		_collect_mesh_instances(event_driver.right_waving_lasers_holder),
		true,
		true
	)

	var floor_sources: Array[MeshInstance3D] = _collect_mesh_instances(
		event_driver.track_lights_holder
	)
	floor_sources.append_array(_collect_mesh_instances(event_driver.floor_holder))
	_build_batch(TYPE_FLOOR_LIGHTS, event_driver.floor_lights_batch, floor_sources, false)


func _build_batch(
	light_type: int,
	batch: MultiMeshInstance3D,
	sources: Array[MeshInstance3D],
	use_node_name_ids: bool,
	sync_runtime_transform: bool = false
) -> void:
	lights_by_type_and_id[light_type] = {}
	_instance_ids_by_type[light_type] = []
	var type_lights: Array[LightInstance] = []
	_lights_by_type[light_type] = type_lights
	if not is_instance_valid(batch) or sources.is_empty():
		return

	var canonical_mesh: Mesh = null
	for source: MeshInstance3D in sources:
		if source.mesh != null and not source.mesh is PlaneMesh:
			canonical_mesh = source.mesh
			break
	if canonical_mesh == null:
		for source: MeshInstance3D in sources:
			if source.mesh != null:
				canonical_mesh = source.mesh
				break
	if canonical_mesh == null:
		push_warning("LightManager: No mesh available for light type %d" % light_type)
		return

	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = canonical_mesh
	multimesh.instance_count = sources.size()
	batch.multimesh = multimesh
	batch.material_override = _create_batch_material()
	batch.visible = true

	var lights_for_ids: Dictionary = {}
	for source_index: int in range(sources.size()):
		var source: MeshInstance3D = sources[source_index]
		var source_material: StandardMaterial3D = _get_source_material(source)
		var adjustment: Transform3D = _get_mesh_adjustment(source.mesh, canonical_mesh)
		var light: LightInstance = LightInstance.new(
			self, source, source_material, batch, source_index, adjustment
		)
		var light_id: int = source_index + 1
		if use_node_name_ids:
			light_id = _get_named_light_id(source, source_index + 1)
		lights_for_ids[light_id] = light
		type_lights.append(light)
		if sync_runtime_transform:
			_animated_lights.append(light)
		light.sync_transform()
		light.write_initial_state()
		source.visible = false

	lights_by_type_and_id[light_type] = lights_for_ids
	_lights_by_type[light_type] = type_lights
	var instance_ids: Array[int] = []
	for light_id_value: Variant in lights_for_ids.keys():
		if light_id_value is int:
			instance_ids.append(light_id_value as int)
	instance_ids.sort()
	_instance_ids_by_type[light_type] = instance_ids


static func get_instance_ids_for_type(light_type: int) -> Array[int]:
	var ids_value: Variant = _instance_ids_by_type.get(light_type, [])
	if not ids_value is Array:
		return []
	var result: Array[int] = []
	for id_value: Variant in (ids_value as Array):
		if id_value is int:
			result.append(id_value as int)
	return result


func _collect_mesh_instances(parent: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if not is_instance_valid(parent):
		return meshes
	for child: Node in parent.get_children():
		if child is MultiMeshInstance3D:
			continue
		if child is MeshInstance3D:
			meshes.append(child as MeshInstance3D)
		meshes.append_array(_collect_mesh_instances(child))
	return meshes


func _get_source_material(mesh_instance: MeshInstance3D) -> StandardMaterial3D:
	if mesh_instance.material_override is StandardMaterial3D:
		return mesh_instance.material_override as StandardMaterial3D
	if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		var surface_material: Material = mesh_instance.mesh.surface_get_material(0)
		if surface_material is StandardMaterial3D:
			return surface_material as StandardMaterial3D
	return null


func _create_batch_material() -> ShaderMaterial:
	var batch_material: ShaderMaterial = ShaderMaterial.new()
	batch_material.shader = LIGHT_BAR_SHADER
	return batch_material


func _get_named_light_id(source: MeshInstance3D, fallback: int) -> int:
	var parent_name: String = str(source.get_parent().name)
	if parent_name.begins_with("laser"):
		var suffix: String = parent_name.trim_prefix("laser")
		if suffix.is_valid_int():
			return suffix.to_int()
	return fallback


func _get_mesh_adjustment(source_mesh: Mesh, canonical_mesh: Mesh) -> Transform3D:
	if source_mesh == canonical_mesh or source_mesh == null:
		return Transform3D.IDENTITY
	if source_mesh is PlaneMesh:
		var canonical_size: Vector3 = canonical_mesh.get_aabb().size
		var plane_size: Vector2 = (source_mesh as PlaneMesh).size
		var scale_x: float = plane_size.x / maxf(canonical_size.x, 0.0001)
		var scale_y: float = 0.001 / maxf(canonical_size.y, 0.0001)
		var scale_z: float = plane_size.y / maxf(canonical_size.z, 0.0001)
		return Transform3D(Basis.from_scale(Vector3(scale_x, scale_y, scale_z)), Vector3.ZERO)
	push_warning("LightManager: Unsupported mixed light mesh; using the source transform")
	return Transform3D.IDENTITY


func sync_batched_transforms() -> void:
	for light: LightInstance in _animated_lights:
		light.sync_transform()


func process_light_event(
	event: EventInfo,
	left_color: Color,
	right_color: Color,
	white_color: Color = Color.WHITE
) -> void:
	var light_type: int = event.type
	var target_ids: Array[int] = []
	if event.lightID.is_empty():
		var all_lights: Dictionary = lights_by_type_and_id.get(light_type, {})
		for key: Variant in all_lights.keys():
			if key is int:
				target_ids.append(key as int)
	else:
		target_ids = event.lightID

	var target_color: Color = Color.BLACK
	var fade_duration: float = _event_fade_duration(event)
	match event.value:
		EventInfo.VALUE_LIGHTS_RIGHT_ON, EventInfo.VALUE_LIGHTS_RIGHT_FLASH, EventInfo.VALUE_LIGHTS_RIGHT_FADE, EventInfo.VALUE_LIGHTS_FADE_TO_RIGHT:
			target_color = right_color
		EventInfo.VALUE_LIGHTS_LEFT_ON, EventInfo.VALUE_LIGHTS_LEFT_FLASH, EventInfo.VALUE_LIGHTS_LEFT_FADE, EventInfo.VALUE_LIGHTS_FADE_TO_LEFT:
			target_color = left_color
		EventInfo.VALUE_LIGHTS_WHITE_ON, EventInfo.VALUE_LIGHTS_WHITE_FLASH, EventInfo.VALUE_LIGHTS_WHITE_FADE, EventInfo.VALUE_LIGHTS_FADE_TO_WHITE:
			target_color = white_color

	if event.color.size() >= 3:
		target_color = Color(event.color[0], event.color[1], event.color[2])

	var lights: Dictionary = lights_by_type_and_id.get(light_type, {})
	for light_id: int in target_ids:
		if not lights.has(light_id):
			continue
		var light: LightInstance = lights[light_id] as LightInstance
		if not light.ensure_unique_material():
			continue
		match event.value:
			EventInfo.VALUE_LIGHTS_OFF:
				light.stop_tween()
				light.set_color(Color.BLACK)
				light.set_visible(false)
			EventInfo.VALUE_LIGHTS_RIGHT_ON, EventInfo.VALUE_LIGHTS_LEFT_ON, EventInfo.VALUE_LIGHTS_WHITE_ON:
				light.stop_tween()
				light.set_color(target_color)
				light.set_visible(true)
			EventInfo.VALUE_LIGHTS_RIGHT_FLASH, EventInfo.VALUE_LIGHTS_LEFT_FLASH, EventInfo.VALUE_LIGHTS_WHITE_FLASH:
				light.flash(target_color, self)
			EventInfo.VALUE_LIGHTS_RIGHT_FADE, EventInfo.VALUE_LIGHTS_LEFT_FADE, EventInfo.VALUE_LIGHTS_WHITE_FADE:
				light.flash_fade_off(target_color, self)
			EventInfo.VALUE_LIGHTS_FADE_TO_RIGHT, EventInfo.VALUE_LIGHTS_FADE_TO_LEFT, EventInfo.VALUE_LIGHTS_FADE_TO_WHITE:
				light.fade_to(target_color, self, fade_duration)


func set_all_lights_of_type(light_type: int, color: Color, is_visible: bool) -> void:
	var type_lights: Array[LightInstance] = _get_type_lights(light_type)
	for light: LightInstance in type_lights:
		light.stop_tween()
		light.set_color(color)
		light.set_visible(is_visible)


func set_all_lights_color(color: Color, light_type: int) -> void:
	var type_lights: Array[LightInstance] = _get_type_lights(light_type)
	for light: LightInstance in type_lights:
		light.set_color(color)


func set_all_lights_visible(light_type: int, is_visible: bool) -> void:
	var type_lights: Array[LightInstance] = _get_type_lights(light_type)
	for light: LightInstance in type_lights:
		light.set_visible(is_visible)


func get_light_color(light_type: int) -> Color:
	var type_lights: Array[LightInstance] = _get_type_lights(light_type)
	if type_lights.is_empty():
		return Color.BLACK
	return type_lights[0].current_color


func prepare_unique_lights_for_fade(light_type: int) -> void:
	var type_lights: Array[LightInstance] = _get_type_lights(light_type)
	for light: LightInstance in type_lights:
		if light.has_unique_material:
			light.stop_tween()
			light.set_visible(true)


func set_unique_lights_color(color: Color, light_type: int) -> void:
	var type_lights: Array[LightInstance] = _get_type_lights(light_type)
	for light: LightInstance in type_lights:
		if light.has_unique_material:
			light.set_color(color)


func set_unique_lights_visible(light_type: int, is_visible: bool) -> void:
	var type_lights: Array[LightInstance] = _get_type_lights(light_type)
	for light: LightInstance in type_lights:
		if light.has_unique_material:
			light.set_visible(is_visible)

func has_visible_lights(light_type: int) -> bool:
	for light: LightInstance in _get_type_lights(light_type):
		if light.visible and light.current_color.a > 0.0:
			return true
	return false


func _get_type_lights(light_type: int) -> Array[LightInstance]:
	if not _lights_by_type.has(light_type):
		return _empty_lights
	return _lights_by_type[light_type] as Array[LightInstance]


func _event_fade_duration(event: EventInfo) -> float:
	var duration_beats: float = float(event.custom_data.get("_v3FadeDurationBeats", 0.0))
	if duration_beats <= 0.0:
		return 1.0
	var end_beat: float = event.beat + duration_beats
	return maxf(Map.beat_to_seconds(end_beat) - Map.beat_to_seconds(event.beat), 0.001)
