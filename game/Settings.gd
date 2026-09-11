extends Node

var config := ConfigFile.new()

const SECTION := "OpenSaber"
const CONFIG_PATH := "user://config.ini"
const OLD_CONFIG_PATH := "user://config.dat"
# Beat Saber's "The First" color scheme
const DEFAULT_COLOR_LEFT := Color(0.7843137, 0.0784314, 0.0784314)
const DEFAULT_COLOR_RIGHT := Color(0.1568627, 0.5568628, 0.8235294)
const MIN_SABER_COLOR_CHANNEL := 0.15
const MIN_SABER_COLOR_ALPHA := 0.5
var SABER_VISUALS: Array[PackedStringArray] = [
	PackedStringArray(["Default saber","res://game/sabers/default/default_saber.tscn"]),
	PackedStringArray(["Particle sword","res://game/sabers/particles/particles_saber.tscn"])
]

signal changed(name: StringName)

var thickness: float:
	set(value):
		thickness = value
		set_and_emit(&"thickness", value)
var color_left: Color:
	set(value):
		var validated_color: Color = _validate_saber_color(value, DEFAULT_COLOR_LEFT, &"color_left")
		color_left = validated_color
		set_and_emit(&"color_left", validated_color)
var color_right: Color:
	set(value):
		var validated_color: Color = _validate_saber_color(value, DEFAULT_COLOR_RIGHT, &"color_right")
		color_right = validated_color
		set_and_emit(&"color_right", validated_color)
var saber_visual: int:
	set(value):
		saber_visual = value
		set_and_emit(&"saber_visual", value)
var ui_volume: float:
	set(value):
		ui_volume = value
		set_and_emit(&"ui_volume", value)
var left_saber_offset_pos: Vector3:
	set(value):
		left_saber_offset_pos = value
		set_and_emit(&"left_saber_offset_pos", value)
var left_saber_offset_rot: Vector3:
	set(value):
		left_saber_offset_rot = value
		set_and_emit(&"left_saber_offset_rot", value)
var right_saber_offset_pos: Vector3:
	set(value):
		right_saber_offset_pos = value
		set_and_emit(&"right_saber_offset_pos", value)
var right_saber_offset_rot: Vector3:
	set(value):
		right_saber_offset_rot = value
		set_and_emit(&"right_saber_offset_rot", value)
var cube_cuts_falloff: bool:
	set(value):
		cube_cuts_falloff = value
		set_and_emit(&"cube_cuts_falloff", value)
var saber_tail: bool:
	set(value):
		saber_tail = value
		set_and_emit(&"saber_tail", value)
var glare: bool:
	set(value):
		glare = value
		set_and_emit(&"glare", value)
var show_debug_info: bool:
	set(value):
		show_debug_info = value
		set_and_emit(&"show_debug_info", value)
var bombs_enabled: bool:
	set(value):
		bombs_enabled = value
		set_and_emit(&"bombs_enabled", value)
var no_fail: bool:
	set(value):
		no_fail = value
		set_and_emit(&"no_fail", value)
var events: bool:
	set(value):
		events = value
		set_and_emit(&"events", value)
var disable_map_color: bool:
	set(value):
		disable_map_color = value
		set_and_emit(&"disable_map_color", value)
var player_height_offset: float:
	set(value):
		player_height_offset = value
		set_and_emit(&"player_height_offset", value)
var audio_master: float:
	set(value):
		audio_master = value
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Master"), linear_to_db(value))
		set_and_emit(&"audio_master", value)
var audio_music: float:
	set(value):
		audio_music = value
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), linear_to_db(value))
		set_and_emit(&"audio_music", value)
var audio_sfx: float:
	set(value):
		audio_sfx = value
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"SFX"), linear_to_db(value))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"UI"), linear_to_db(value))
		set_and_emit(&"audio_sfx", value)
var spectator_view: bool:
	set(value):
		spectator_view = value
		set_and_emit(&"spectator_view", value)
var spectator_hud: bool:
	set(value):
		spectator_hud = value
		set_and_emit(&"spectator_hud", value)
## visionOS only: render the real room behind the game instead of the full
## immersive environment. Ignored on every other platform.
var visionos_passthrough: bool:
	set(value):
		visionos_passthrough = value
		set_and_emit(&"visionos_passthrough", value)



func _ready() -> void:
	if OS.get_name() in platform_default_values.keys():
		for key in platform_default_values[OS.get_name()].keys():
			default_values[key] = platform_default_values[OS.get_name()][key]
	
	if FileAccess.file_exists(CONFIG_PATH):
		reload()
	elif FileAccess.file_exists(OLD_CONFIG_PATH):
		load_old_config()
	else:
		restore_defaults()
		save()

const platform_default_values = {
	Android = {
		glare = true,
	},
	Web = {
		glare = false,
		saber_tail = false,
		cube_cuts_falloff = false,
		events = false,
	},
}

var default_values = {
	thickness = 1.0,
	cube_cuts_falloff = true,
	color_left = DEFAULT_COLOR_LEFT,
	color_right = DEFAULT_COLOR_RIGHT,
	saber_tail = true,
	glare = true,
	show_debug_info = false,
	bombs_enabled = true,
	no_fail = false,
	events = true,
	saber_visual = 0,
	ui_volume = 10.0,
	left_saber_offset_pos = Vector3.ZERO,
	left_saber_offset_rot = Vector3.ZERO,
	right_saber_offset_pos = Vector3.ZERO,
	right_saber_offset_rot = Vector3.ZERO,
	disable_map_color = false,
	player_height_offset = 0.0,
	audio_master = 0.8,
	audio_music = 0.8,
	audio_sfx = 0.8,
	spectator_view = false,
	spectator_hud = true,
	visionos_passthrough = false,
	obstacle_color = Color(1.0, 0.1882353, 0.1882353)
}

func cast_or_default(key: String, to_type: int = -1) -> Variant:
	var default = default_values[key] if key in default_values else null
	return convert(config.get_value(SECTION, config_key(key), default), typeof(default) if to_type < 0 else to_type)

func set_and_emit(key: StringName, value: Variant) -> void:
	config.set_value(SECTION, config_key(String(key)), value if default_values[key] != value else null)
	changed.emit(key)

## Saber offsets are a visual calibration of the held model against the platform's
## aim pose, so a value tuned on Quest is meaningless on visionOS. The scoping
## policy lives in VisionOSPlatform so it can be unit tested without booting the
## Settings autoload.
func config_key(key: String) -> String:
	return VisionOSPlatform.config_key(key)

func _is_valid_saber_color(value: Color) -> bool:
	return maxf(value.r, maxf(value.g, value.b)) >= MIN_SABER_COLOR_CHANNEL \
		and value.a >= MIN_SABER_COLOR_ALPHA

func _validate_saber_color(value: Color, default_color: Color, setting_name: StringName) -> Color:
	if _is_valid_saber_color(value):
		return value
	push_warning("Invalid %s value %s; restoring default %s." % [setting_name, value, default_color])
	return default_color

func _validate_loaded_saber_color(
	value: Variant,
	default_color: Color,
	setting_name: StringName
) -> Color:
	if typeof(value) != TYPE_COLOR:
		push_warning(
			"Invalid %s type %s; restoring default %s."
			% [setting_name, type_string(typeof(value)), default_color]
		)
		return default_color
	return _validate_saber_color(value as Color, default_color, setting_name)

# load() is the name of a built-in function,
# so i went with the next best thing.
func reload() -> void:
	var config_error := config.load(CONFIG_PATH)
	if config_error != OK:
		vr.log_file_error(config_error, CONFIG_PATH, "reload() in Settings.gd")
		return
	
	var corrected_saber_color := false
	for key: String in default_values:
		var loaded_value: Variant = cast_or_default(key)
		if key == "color_left":
			var loaded_left_color: Color = _validate_loaded_saber_color(
				loaded_value, DEFAULT_COLOR_LEFT, &"color_left"
			)
			corrected_saber_color = corrected_saber_color or loaded_left_color != loaded_value
			loaded_value = loaded_left_color
		elif key == "color_right":
			var loaded_right_color: Color = _validate_loaded_saber_color(
				loaded_value, DEFAULT_COLOR_RIGHT, &"color_right"
			)
			corrected_saber_color = corrected_saber_color or loaded_right_color != loaded_value
			loaded_value = loaded_right_color
		set(key, loaded_value)
	if corrected_saber_color:
		save()

func load_old_config() -> void:
	var file := FileAccess.open(OLD_CONFIG_PATH, FileAccess.READ)
	if FileAccess.get_open_error() != OK:
		vr.log_file_error(FileAccess.get_open_error(), OLD_CONFIG_PATH, "load_old_config() in Settings.gd")
		return
	var settings_var: Variant = file.get_var(true)
	file.close()
	if not settings_var is Dictionary:
		restore_defaults()
		return
	var settings_dict := settings_var as Dictionary
	var corrected_saber_color := false
	thickness = Utils.get_float(settings_dict, "thickness", 1)
	if settings_dict.has("COLOR_LEFT"):
		var old_left_value: Variant = settings_dict["COLOR_LEFT"]
		color_left = _validate_loaded_saber_color(
			old_left_value, DEFAULT_COLOR_LEFT, &"color_left"
		)
		corrected_saber_color = corrected_saber_color or color_left != old_left_value
	else:
		color_left = DEFAULT_COLOR_LEFT
	if settings_dict.has("COLOR_RIGHT"):
		var old_right_value: Variant = settings_dict["COLOR_RIGHT"]
		color_right = _validate_loaded_saber_color(
			old_right_value, DEFAULT_COLOR_RIGHT, &"color_right"
		)
		corrected_saber_color = corrected_saber_color or color_right != old_right_value
	else:
		color_right = DEFAULT_COLOR_RIGHT
	saber_visual = int(Utils.get_float(settings_dict, "saber", 0))
	ui_volume = Utils.get_float(settings_dict, "ui_volume", 10.0)
	left_saber_offset_pos = Vector3.ZERO
	left_saber_offset_rot = Vector3.ZERO
	if settings_dict.has("left_saber_offset") and settings_dict["left_saber_offset"] is Array:
		@warning_ignore("unsafe_cast")
		var left_array: Array = settings_dict["left_saber_offset"] as Array
		if left_array.size() == 2:
			if left_array[0] is Vector3:
				@warning_ignore("unsafe_cast")
				left_saber_offset_pos = left_array[0] as Vector3
			if left_array[1] is Vector3:
				@warning_ignore("unsafe_cast")
				left_saber_offset_rot = left_array[1] as Vector3
	right_saber_offset_pos = Vector3.ZERO
	right_saber_offset_rot = Vector3.ZERO
	if settings_dict.has("right_saber_offset") and settings_dict["right_saber_offset"] is Array:
		@warning_ignore("unsafe_cast")
		var right_array: Array = settings_dict["right_saber_offset"] as Array
		if right_array.size() == 2:
			if right_array[0] is Vector3:
				@warning_ignore("unsafe_cast")
				right_saber_offset_pos = right_array[0] as Vector3
			if right_array[1] is Vector3:
				@warning_ignore("unsafe_cast")
				right_saber_offset_rot = right_array[1] as Vector3
	cube_cuts_falloff = Utils.get_bool(settings_dict, "cube_cuts_falloff", true, {"Web": false})
	saber_tail = Utils.get_bool(settings_dict, "saber_tail", true, {"Web": false})
	glare = Utils.get_bool(settings_dict, "glare", true, {"Android": true, "Web": false})
	show_debug_info = Utils.get_bool(settings_dict, "show_debug_info", false)
	bombs_enabled = Utils.get_bool(settings_dict, "bombs_enabled", true)
	no_fail = Utils.get_bool(settings_dict, "no_fail", false)
	events = Utils.get_bool(settings_dict, "events", true, {"Web": false})
	disable_map_color = Utils.get_bool(settings_dict, "disable_map_color", false)
	player_height_offset = Utils.get_float(settings_dict, "player_height_offset", 0.0)
	visionos_passthrough = Utils.get_bool(settings_dict, "visionos_passthrough", false)
	if corrected_saber_color:
		save()

func save() -> void:
	var error := config.save(CONFIG_PATH)
	if error != OK:
		vr.log_file_error(error, CONFIG_PATH, "save() in Settings.gd")
		return
	# remove old config
	if FileAccess.file_exists(OLD_CONFIG_PATH):
		error = DirAccess.open("user://").remove(OLD_CONFIG_PATH)
		if error != OK:
			vr.log_file_error(error, OLD_CONFIG_PATH, "save() in Settings.gd")

func restore_defaults() -> void:
	config.clear()
	save()
	reload()
