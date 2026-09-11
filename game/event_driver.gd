extends Node3D
class_name EventDriver

signal environment_palette_changed(left: Color, right: Color)

const IDLE_LIGHT_SCALE: float = 0.25
const ENVIRONMENT_BASE_BRIGHTNESS: float = 0.12
const INTENSITY_PARAMS: Array[StringName] = [
	&"bg_0_intensity",
	&"bg_1_intensity",
	&"bg_2_intensity",
	&"bg_3_intensity",
	&"bg_4_intensity",
]
const TINT_PARAMS: Array[StringName] = [
	&"bg_0_tint",
	&"bg_1_tint",
	&"bg_2_tint",
	&"bg_3_tint",
	&"bg_4_tint",
]

var ring_rot_speed: = 0.0
var ring_rot_inv_dir: = false
var rings_in: = false

var left_color: Color
var right_color: Color
var normal_left_color: Color
var normal_right_color: Color
var boost_enabled: bool = false
var floor_lights_active: bool = true
var ring_spin_tween: Tween = null

var events_processed: int = 0
var events_by_type: Dictionary = {}

# Light ID system (Chroma)
var light_manager: LightManager = null

@onready var ring_holder: = $Level / rings as TrackLaneRings
@onready var diagonal_lasers_holder: = $Level / DiagonalLasers as Node3D
@onready var square_lasers_holder: = $Level / SquareLasers as Node3D
@onready var left_waving_lasers_holder: = $Level / LeftWavingLasers as Node3D
@onready var right_waving_lasers_holder: = $Level / RightWavingLasers as Node3D
@onready var track_lights_holder: = $Level / TrackLights as Node3D
@onready var floor_holder: = $Level / floor as MeshInstance3D

@onready var diagonal_lasers_batch: = $Level / DiagonalLasers / LightBatch as MultiMeshInstance3D
@onready var square_lasers_batch: = $Level / SquareLasers / LightBatch as MultiMeshInstance3D
@onready var left_waving_lasers_batch: = $Level / LeftWavingLasers / LightBatch as MultiMeshInstance3D
@onready var right_waving_lasers_batch: = $Level / RightWavingLasers / LightBatch as MultiMeshInstance3D
@onready var floor_lights_batch: = (
	$Level / TrackLights / LightBatch as MultiMeshInstance3D
)

@onready var sphere_material: = ($Level / Sphere as MeshInstance3D).material_override as ShaderMaterial
@onready var diagonal_lasers_material: = ($Level / DiagonalLasers / laser1 / Bar7 as MeshInstance3D).material_override as StandardMaterial3D
@onready var square_lasers_material: = ($Level / SquareLasers / Bar7 as MeshInstance3D).material_override as StandardMaterial3D
@onready var left_waving_lasers_material: = ($Level / LeftWavingLasers / laser1 / Bar7 as MeshInstance3D).material_override as StandardMaterial3D
@onready var right_waving_lasers_material: = ($Level / RightWavingLasers / laser1 / Bar7 as MeshInstance3D).material_override as StandardMaterial3D
@onready var track_lights_material: = ($Level / TrackLights / Bar1 as MeshInstance3D).material_override as StandardMaterial3D
@onready var floor_material: = ($Level / floor as MeshInstance3D).material_override as ShaderMaterial

@onready var left_laser_anim_player: = $Level / LeftWavingLasers / AnimationPlayer as AnimationPlayer
@onready var right_laser_anim_player: = $Level / RightWavingLasers / AnimationPlayer as AnimationPlayer

@export var disabled: = false

func _ready() -> void :

	if not RenderingServer.get_rendering_device():
		sphere_material.set_shader_parameter("contrast", 1)
		for background_side in 5:
			var shader_param: = StringName("bg_%s_intensity_mult" % background_side)
			sphere_material.set_shader_parameter(
				shader_param,
				(sphere_material.get_shader_parameter(shader_param) as float) * 2.2
			)

	# Initialize after all @onready references have resolved.
	light_manager = LightManager.new()
	add_child(light_manager)
	light_manager.initialize_lights(self)
	_collect_scene_lights()
	_update_environment_base()

# Beat Saber's DirectionalLightWithIds: each scene light sums the current
# colors of several light types with fixed weights (light IDs 1..5 = types 0..4).
const SCENE_LIGHTS: Dictionary = {
	"LightFront": {"weights": {1: 0.5, 2: 0.5, 3: 0.5, 4: 0.7}, "intensity": 1.5},
	"LightTop": {"weights": {1: 1.0, 2: 1.0, 3: 1.0}, "intensity": 1.2},
	"LightLeft": {"weights": {2: 1.0, 3: 0.7}, "intensity": 1.5},
	"LightRight": {"weights": {2: 0.7, 3: 1.0}, "intensity": 1.5},
	"LightBack": {"weights": {0: 1.0, 1: 1.0}, "intensity": 1.5},
}
const SCENE_LIGHT_ENERGY_SCALE: float = 0.3
var _scene_lights: Dictionary = {}

var _scene_light_specs: Dictionary = {}

func _collect_scene_lights() -> void:
	_scene_lights.clear()
	_scene_light_specs.clear()
	var level: Node = get_node_or_null("Level")
	if level == null:
		return
	for child: Node in level.get_children():
		if not (child is DirectionalLight3D):
			continue
		var light_name := String(child.name)
		if child.has_meta(&"light_weights"):
			# generated environments carry their DirectionalLightWithIds weights
			var weights: Dictionary = child.get_meta(&"light_weights")
			_scene_light_specs[light_name] = {"weights": weights, "intensity": float(child.get_meta(&"light_intensity", 1.0))}
		elif SCENE_LIGHTS.has(light_name):
			_scene_light_specs[light_name] = SCENE_LIGHTS[light_name]
		else:
			continue
		_scene_lights[light_name] = child

func _update_scene_lights() -> void:
	if _scene_lights.is_empty():
		return
	var type_colors: Array[Color] = []
	for type: int in range(5):
		var holder: Node3D = _get_light_holder(type)
		var holder_visible: bool = holder != null and holder.visible
		var lit: bool = is_instance_valid(light_manager) and light_manager.has_visible_lights(type)
		if type == EventInfo.TYPE_SQUARE_LASERS:
			lit = holder_visible
		type_colors.append(_get_current_light_color(type) if (holder_visible and lit) else Color.BLACK)
	for light_name: String in _scene_lights.keys():
		var spec: Dictionary = _scene_light_specs[light_name]
		var weights: Dictionary = spec["weights"]
		var mixed := Color.BLACK
		for type_value: Variant in weights.keys():
			var weight: float = float(weights[type_value])
			var type_index: int = int(type_value)
			if type_index < 0 or type_index >= type_colors.size():
				continue  # light ids beyond the five basic event types (newer environments)
			var c: Color = type_colors[type_index]
			mixed.r += c.r * weight
			mixed.g += c.g * weight
			mixed.b += c.b * weight
		var luminance: float = mixed.get_luminance() * float(spec["intensity"])
		luminance = minf(luminance, 1.0)
		var light := _scene_lights[light_name] as DirectionalLight3D
		if luminance <= 0.001:
			light.light_energy = 0.0
			continue
		var peak: float = maxf(mixed.r, maxf(mixed.g, mixed.b))
		# the construction takes the light tint only lightly (mostly grey in the original)
		light.light_color = Color(mixed.r / peak, mixed.g / peak, mixed.b / peak, 1.0).lerp(Color.WHITE, 0.4)
		light.light_energy = luminance * SCENE_LIGHT_ENERGY_SCALE

func _physics_process(_delta: float) -> void:
	_update_scene_lights()
	if not is_instance_valid(light_manager):
		return
	var left_lasers_active: bool = (
		left_waving_lasers_holder.is_visible_in_tree()
		and left_laser_anim_player.speed_scale > 0.0
		and light_manager.has_visible_lights(EventInfo.TYPE_LEFT_WAVING_LASERS)
	)
	var right_lasers_active: bool = (
		right_waving_lasers_holder.is_visible_in_tree()
		and right_laser_anim_player.speed_scale > 0.0
		and light_manager.has_visible_lights(EventInfo.TYPE_RIGHT_WAVING_LASERS)
	)
	if left_lasers_active or right_lasers_active:
		light_manager.sync_batched_transforms()

func _process(_delta: float) -> void :
	pass

func update_left_color(color: Color) -> void :
	normal_left_color = color
	if not boost_enabled:
		left_color = color
		turn_light_on(EventInfo.TYPE_DIAGONAL_LASERS, color)
		turn_light_on(EventInfo.TYPE_LEFT_WAVING_LASERS, color)
		turn_light_on(EventInfo.TYPE_RIGHT_WAVING_LASERS, color)
	_update_environment_base()

func update_right_color(color: Color) -> void :
	normal_right_color = color
	if not boost_enabled:
		right_color = color
		turn_light_on(EventInfo.TYPE_SQUARE_LASERS, color)
		turn_light_on(EventInfo.TYPE_FLOOR_LIGHTS, color)
	_update_environment_base()

func set_all_off() -> void :
	boost_enabled = false
	left_color = normal_left_color
	right_color = normal_right_color
	if disabled:
		for i in range(1, 4):
			turn_light_off(i)
		turn_light_off(EventInfo.TYPE_FLOOR_LIGHTS)
		ring_holder.visible = false
	else:
		for i in range(5):
			turn_light_off(i)

func set_all_on(left: Color, right: Color) -> void :
	boost_enabled = false
	update_left_color(left)
	update_right_color(right)
	ring_holder.visible = true

func process_event(data: EventInfo) -> void :
	if disabled: return

	events_processed += 1
	var type_count: int = int(events_by_type.get(data.type, 0))
	events_by_type[data.type] = type_count + 1

	if data.type >= 0 and data.type <= 4:
		var l := left_color
		var r := right_color
		var w := Color.WHITE
		if data.custom_data.has("_v3PaletteColor"):
			var palette_color: int = int(data.custom_data["_v3PaletteColor"])
			var brightness: float = float(data.custom_data.get("_v3Brightness", 1.0))
			match palette_color:
				0:
					l *= brightness
					r = l
				1:
					r *= brightness
					l = r
				_:
					w *= brightness
		elif data.color.size() >= 3:
			var custom_color := Color(data.color[0], data.color[1], data.color[2])
			l = custom_color
			r = custom_color
			w = custom_color

		# If event has lightID array (Chroma), use LightManager for targeted control
		var lights_by_id: Dictionary = light_manager.lights_by_type_and_id.get(data.type, {}) if is_instance_valid(light_manager) else {}
		if not data.lightID.is_empty() and not lights_by_id.is_empty():
			_prepare_targeted_light_event(data, l, r, w)
			light_manager.process_light_event(data, l, r, w)
		else:
			# Legacy behavior: control all lights of this type
			match data.value:
				EventInfo.VALUE_LIGHTS_OFF:
					turn_light_off(data.type)
				EventInfo.VALUE_LIGHTS_RIGHT_ON:
					turn_light_on(data.type, r)
				EventInfo.VALUE_LIGHTS_RIGHT_FLASH:
					flash_light_on(data.type, r)
				EventInfo.VALUE_LIGHTS_RIGHT_FADE:
					flash_light_then_fade_off(data.type, r)
				EventInfo.VALUE_LIGHTS_FADE_TO_RIGHT:
					fade_light_from_current(data.type, r, _event_fade_duration(data))
				EventInfo.VALUE_LIGHTS_LEFT_ON:
					turn_light_on(data.type, l)
				EventInfo.VALUE_LIGHTS_LEFT_FLASH:
					flash_light_on(data.type, l)
				EventInfo.VALUE_LIGHTS_LEFT_FADE:
					flash_light_then_fade_off(data.type, l)
				EventInfo.VALUE_LIGHTS_FADE_TO_LEFT:
					fade_light_from_current(data.type, l, _event_fade_duration(data))
				EventInfo.VALUE_LIGHTS_WHITE_ON:
					turn_light_on(data.type, w)
				EventInfo.VALUE_LIGHTS_WHITE_FLASH:
					flash_light_on(data.type, w)
				EventInfo.VALUE_LIGHTS_WHITE_FADE:
					flash_light_then_fade_off(data.type, w)
				EventInfo.VALUE_LIGHTS_FADE_TO_WHITE:
					fade_light_from_current(data.type, w, _event_fade_duration(data))
	else:
		match data.type:
			EventInfo.TYPE_COLOR_BOOST:
				boost_enabled = data.value != 0
				left_color = Map.color_left_boost if boost_enabled else Map.color_left
				right_color = Map.color_right_boost if boost_enabled else Map.color_right
				_update_environment_base()
				if not floor_lights_active:
					_apply_floor_idle()
			EventInfo.TYPE_RING_SPIN:
				ring_holder.spin()
			EventInfo.TYPE_RING_ZOOM:
				ring_holder.zoom()
			EventInfo.TYPE_LEFT_LASER_SPEED:
				var val: = float(data.value) * 0.125
				left_laser_anim_player.speed_scale = val
				left_laser_anim_player.seek(randf_range(0.0, left_laser_anim_player.current_animation_length), true)
			EventInfo.TYPE_RIGHT_LASER_SPEED:
				var val: = float(data.value) * 0.125
				right_laser_anim_player.speed_scale = val
				right_laser_anim_player.seek(randf_range(0.0, right_laser_anim_player.current_animation_length), true)

var prev_tweeners: Array[Tween] = [null, null, null, null, null]

func stop_prev_tween(type: int) -> void :
	if prev_tweeners[type] != null:
		prev_tweeners[type].kill()
		prev_tweeners[type] = null

func turn_light_off(type: int) -> void :
	stop_prev_tween(type)
	if type == EventInfo.TYPE_FLOOR_LIGHTS:
		floor_lights_active = false
		_apply_floor_idle()
		return
	_on_Tween_tween_step(Color.BLACK, type)
	if is_instance_valid(light_manager):
		light_manager.set_all_lights_of_type(type, Color.BLACK, false)
	_set_light_holder_visible(type, false)

func turn_light_on(type: int, color: Color) -> void :
	sphere_material.set_shader_parameter(TINT_PARAMS[type], color)
	stop_prev_tween(type)
	_on_Tween_tween_step(color, type)
	_set_light_holder_visible(type, true)
	if is_instance_valid(light_manager):
		light_manager.set_all_lights_of_type(type, color, true)
	if type == EventInfo.TYPE_FLOOR_LIGHTS:
		floor_lights_active = true
		_set_floor_event_color(color)

func _prepare_targeted_light_event(
	data: EventInfo,
	event_left_color: Color,
	event_right_color: Color,
	event_white_color: Color
) -> void:
	var group: Node3D = _get_light_holder(data.type)
	if group == null:
		return
	group.visible = true

	var target_color := Color.BLACK
	match data.value:
		EventInfo.VALUE_LIGHTS_RIGHT_ON, EventInfo.VALUE_LIGHTS_RIGHT_FLASH, EventInfo.VALUE_LIGHTS_RIGHT_FADE, EventInfo.VALUE_LIGHTS_FADE_TO_RIGHT:
			target_color = event_right_color
		EventInfo.VALUE_LIGHTS_LEFT_ON, EventInfo.VALUE_LIGHTS_LEFT_FLASH, EventInfo.VALUE_LIGHTS_LEFT_FADE, EventInfo.VALUE_LIGHTS_FADE_TO_LEFT:
			target_color = event_left_color
		EventInfo.VALUE_LIGHTS_WHITE_ON, EventInfo.VALUE_LIGHTS_WHITE_FLASH, EventInfo.VALUE_LIGHTS_WHITE_FADE, EventInfo.VALUE_LIGHTS_FADE_TO_WHITE:
			target_color = event_white_color

	match data.value:
		EventInfo.VALUE_LIGHTS_OFF:
			stop_prev_tween(data.type)
			_on_Tween_tween_step(Color.BLACK, data.type)
		EventInfo.VALUE_LIGHTS_RIGHT_ON, EventInfo.VALUE_LIGHTS_LEFT_ON, EventInfo.VALUE_LIGHTS_WHITE_ON:
			sphere_material.set_shader_parameter(TINT_PARAMS[data.type], target_color)
			stop_prev_tween(data.type)
			_on_Tween_tween_step(target_color, data.type)
		EventInfo.VALUE_LIGHTS_RIGHT_FLASH, EventInfo.VALUE_LIGHTS_LEFT_FLASH, EventInfo.VALUE_LIGHTS_WHITE_FLASH:
			sphere_material.set_shader_parameter(TINT_PARAMS[data.type], target_color)
			_fade_background(data.type, target_color * 3.0, target_color, Tween.TRANS_LINEAR, Tween.EASE_OUT)
		EventInfo.VALUE_LIGHTS_RIGHT_FADE, EventInfo.VALUE_LIGHTS_LEFT_FADE, EventInfo.VALUE_LIGHTS_WHITE_FADE:
			sphere_material.set_shader_parameter(TINT_PARAMS[data.type], target_color)
			_fade_background(data.type, target_color * 3.0, Color.BLACK, Tween.TRANS_QUAD, Tween.EASE_IN)
		EventInfo.VALUE_LIGHTS_FADE_TO_RIGHT, EventInfo.VALUE_LIGHTS_FADE_TO_LEFT, EventInfo.VALUE_LIGHTS_FADE_TO_WHITE:
			_fade_background(
				data.type,
				_get_current_light_color(data.type),
				target_color,
				Tween.TRANS_LINEAR,
				Tween.EASE_IN,
				_event_fade_duration(data)
			)

func _get_light_holder(type: int) -> Node3D:
	match type:
		EventInfo.TYPE_DIAGONAL_LASERS:
			return diagonal_lasers_holder
		EventInfo.TYPE_SQUARE_LASERS:
			return square_lasers_holder
		EventInfo.TYPE_LEFT_WAVING_LASERS:
			return left_waving_lasers_holder
		EventInfo.TYPE_RIGHT_WAVING_LASERS:
			return right_waving_lasers_holder
		EventInfo.TYPE_FLOOR_LIGHTS:
			return track_lights_holder
	return null

func _set_light_holder_visible(type: int, is_visible: bool) -> void:
	var holder: Node3D = _get_light_holder(type)
	if holder != null:
		holder.visible = is_visible

func _get_current_light_color(type: int) -> Color:
	if is_instance_valid(light_manager):
		return light_manager.get_light_color(type)
	match type:
		EventInfo.TYPE_DIAGONAL_LASERS:
			return diagonal_lasers_material.albedo_color
		EventInfo.TYPE_SQUARE_LASERS:
			return square_lasers_material.albedo_color
		EventInfo.TYPE_LEFT_WAVING_LASERS:
			return left_waving_lasers_material.albedo_color
		EventInfo.TYPE_RIGHT_WAVING_LASERS:
			return right_waving_lasers_material.albedo_color
		EventInfo.TYPE_FLOOR_LIGHTS:
			return _get_floor_event_color()
	return Color.BLACK

func _fade_background(
	type: int,
	from: Color,
	to: Color,
	trans_type: Tween.TransitionType,
	ease_type: Tween.EaseType,
	duration: float = 1.0
) -> void:
	var group: Node3D = _get_light_holder(type)
	if group == null:
		return
	stop_prev_tween(type)
	var tween := group.create_tween()
	@warning_ignore("return_value_discarded")
	tween.set_trans(trans_type).set_ease(ease_type)
	@warning_ignore("return_value_discarded")
	tween.tween_method(_on_Tween_tween_step.bind(type), from, to, duration)
	prev_tweeners[type] = tween

func flash_light_on(type: int, color: Color) -> void :
	sphere_material.set_shader_parameter(TINT_PARAMS[type], color)
	fade_light(type, color * 3.0, color, false, Tween.TRANS_LINEAR, Tween.EASE_OUT)

func flash_light_then_fade_off(type: int, color: Color) -> void :
	sphere_material.set_shader_parameter(TINT_PARAMS[type], color)
	fade_light(type, color * 3.0, Color.BLACK, true, Tween.TRANS_QUAD, Tween.EASE_IN)

func fade_light_from_current(type: int, to_color: Color, duration: float = 1.0) -> void :
	var current_color := _get_current_light_color(type)
	fade_light(type, current_color, to_color, false, Tween.TRANS_LINEAR, Tween.EASE_IN, duration)

func fade_light(
	type: int,
	from: Color,
	to: Color,
	turn_off_after_fade: bool,
	trans_type: Tween.TransitionType,
	ease_type: Tween.EaseType,
	duration: float = 1.0
) -> void :
	stop_prev_tween(type)
	var target_color: Color = to
	if type == EventInfo.TYPE_FLOOR_LIGHTS and turn_off_after_fade:
		target_color = _get_floor_idle_color()

	var group: Node3D
	match type:
		EventInfo.TYPE_DIAGONAL_LASERS:
			group = diagonal_lasers_holder
		EventInfo.TYPE_SQUARE_LASERS:
			group = square_lasers_holder
		EventInfo.TYPE_LEFT_WAVING_LASERS:
			group = left_waving_lasers_holder
		EventInfo.TYPE_RIGHT_WAVING_LASERS:
			group = right_waving_lasers_holder
		EventInfo.TYPE_FLOOR_LIGHTS:
			group = track_lights_holder

	group.visible = true
	if is_instance_valid(light_manager):
		light_manager.set_all_lights_of_type(type, from, true)

	var tween: = group.create_tween()
	@warning_ignore("return_value_discarded")
	tween.set_parallel().set_trans(trans_type).set_ease(ease_type)
	if type == EventInfo.TYPE_FLOOR_LIGHTS:
		@warning_ignore("return_value_discarded")
		tween.tween_method(_set_floor_event_color, from, target_color, duration)
	if is_instance_valid(light_manager):
		@warning_ignore("return_value_discarded")
		tween.tween_method(
			light_manager.set_all_lights_color.bind(type),
			from,
			target_color,
			duration
		)
	@warning_ignore("return_value_discarded")
	tween.tween_method(_on_Tween_tween_step.bind(type), from, target_color, duration)
	tween.play()
	prev_tweeners[type] = tween
	tween.finished.connect(
		_on_light_fade_finished.bind(turn_off_after_fade, tween, type),
		CONNECT_ONE_SHOT
	)

func _on_light_fade_finished(
	turn_off_after_fade: bool, tween: Tween, type: int
) -> void:
	if turn_off_after_fade:
		if type == EventInfo.TYPE_FLOOR_LIGHTS:
			floor_lights_active = false
			_apply_floor_idle()
			tween.kill()
			return
		if is_instance_valid(light_manager):
			light_manager.set_all_lights_visible(type, false)
		_set_light_holder_visible(type, false)
		tween.kill()
		_on_Tween_tween_step(Color.BLACK, type)

func _on_Tween_tween_step(value: Color, id: int) -> void :
	sphere_material.set_shader_parameter(INTENSITY_PARAMS[id], value.v)
	if id == EventInfo.TYPE_SQUARE_LASERS:
		ring_holder.set_ring_color(value)

func _event_fade_duration(data: EventInfo) -> float:
	var duration_beats: float = float(data.custom_data.get("_v3FadeDurationBeats", 0.0))
	if duration_beats <= 0.0:
		return 1.0
	var end_beat: float = data.beat + duration_beats
	return maxf(Map.beat_to_seconds(end_beat) - Map.beat_to_seconds(data.beat), 0.001)

static func get_environment_base_color(color_left: Color, color_right: Color) -> Color:
	var mixed_color: Color = color_left.lerp(color_right, 0.5)
	var luminance: float = mixed_color.get_luminance()
	var gray: Color = Color(luminance, luminance, luminance, 1.0)
	var desaturated: Color = mixed_color.lerp(gray, 0.25)
	var peak: float = maxf(desaturated.r, maxf(desaturated.g, desaturated.b))
	if peak <= 0.001:
		return Color.BLACK
	var scale: float = ENVIRONMENT_BASE_BRIGHTNESS / peak
	return Color(
		desaturated.r * scale,
		desaturated.g * scale,
		desaturated.b * scale,
		1.0
	)

func _update_environment_base() -> void:
	var base_color: Color = get_environment_base_color(left_color, right_color)
	sphere_material.set_shader_parameter(&"base_color", base_color)
	sphere_material.set_shader_parameter(&"left_color", left_color)
	sphere_material.set_shader_parameter(&"right_color", right_color)
	floor_material.set_shader_parameter(&"base_color", base_color)
	floor_material.set_shader_parameter(&"left_color", left_color)
	floor_material.set_shader_parameter(&"right_color", right_color)
	environment_palette_changed.emit(left_color, right_color)

func _set_floor_event_color(color: Color) -> void:
	floor_material.set_shader_parameter(&"event_color", color)

func _get_floor_event_color() -> Color:
	var color_value: Variant = floor_material.get_shader_parameter(&"event_color")
	if color_value is Color:
		return color_value as Color
	return Color.BLACK

func _get_floor_idle_color() -> Color:
	var idle_left: Color = Color(
		left_color.r * IDLE_LIGHT_SCALE,
		left_color.g * IDLE_LIGHT_SCALE,
		left_color.b * IDLE_LIGHT_SCALE,
		1.0
	)
	var idle_right: Color = Color(
		right_color.r * IDLE_LIGHT_SCALE,
		right_color.g * IDLE_LIGHT_SCALE,
		right_color.b * IDLE_LIGHT_SCALE,
		1.0
	)
	return idle_left.lerp(idle_right, 0.5)

func _apply_floor_idle() -> void:
	var idle_left: Color = Color(
		left_color.r * IDLE_LIGHT_SCALE,
		left_color.g * IDLE_LIGHT_SCALE,
		left_color.b * IDLE_LIGHT_SCALE,
		1.0
	)
	var idle_right: Color = Color(
		right_color.r * IDLE_LIGHT_SCALE,
		right_color.g * IDLE_LIGHT_SCALE,
		right_color.b * IDLE_LIGHT_SCALE,
		1.0
	)
	var idle_mix: Color = idle_left.lerp(idle_right, 0.5)
	_on_Tween_tween_step(idle_mix, EventInfo.TYPE_FLOOR_LIGHTS)
	_set_light_holder_visible(EventInfo.TYPE_FLOOR_LIGHTS, true)
	_set_floor_event_color(idle_mix)
	if not is_instance_valid(light_manager):
		return
	light_manager.set_all_lights_of_type(
		EventInfo.TYPE_FLOOR_LIGHTS,
		idle_mix,
		true
	)
	var floor_lights: Dictionary = light_manager.lights_by_type_and_id.get(
		EventInfo.TYPE_FLOOR_LIGHTS,
		{}
	)
	for light_value: Variant in floor_lights.values():
		var light: LightManager.LightInstance = light_value as LightManager.LightInstance
		if light == null or not is_instance_valid(light.mesh_instance):
			continue
		var side_position: float = light.mesh_instance.global_position.x
		if side_position < -0.01:
			light.set_color(idle_left)
		elif side_position > 0.01:
			light.set_color(idle_right)
