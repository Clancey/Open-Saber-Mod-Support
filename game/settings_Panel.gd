extends Panel
class_name SettingsPanel

signal apply()
@export var beepsaber_game : BeepSaber_Game

const SABER_COLORS: Array[Color] = [
	Color("ff1a1a"),
	Color("ff7a1a"),
	Color("ffd21a"),
	Color("33ff66"),
	Color("1affe6"),
	Color("1a1aff"),
	Color("9a4dff"),
	Color("ff4dd2"),
]
const SWATCH_MATCH_DISTANCE_SQUARED := 0.0025
const SWATCH_BORDER_WIDTH := 5

@onready var saber_control := $ScrollContainer/VBox/SaberTypeRow/saber as OptionButton
@onready var glare_control := $ScrollContainer/VBox/glare as CheckButton
@onready var saber_tail_control := $ScrollContainer/VBox/saber_tail as CheckButton
@onready var saber_thickness := $ScrollContainer/VBox/SaberThicknessRow/saber_thickness as HSlider
@onready var cut_blocks := $ScrollContainer/VBox/cut_blocks as CheckButton
@onready var d_background := $ScrollContainer/VBox/d_background as CheckButton
@onready var left_saber_swatches := $ScrollContainer/VBox/SaberColorsRow/LeftSaberColors/Swatches as HBoxContainer
@onready var right_saber_swatches := $ScrollContainer/VBox/SaberColorsRow/RightSaberColors/Swatches as HBoxContainer
@onready var show_debug_control := $ScrollContainer/VBox/show_debug as CheckButton
@onready var show_collisions := $ScrollContainer/VBox/show_collisions as CheckButton
@onready var bombs_enabled_control := $ScrollContainer/VBox/bombs_enabled as CheckButton
@onready var no_fail_control := $ScrollContainer/VBox/no_fail as CheckButton
@onready var ui_volume_slider := $ScrollContainer/VBox/UI_VolumeRow/ui_volume_slider as HSlider
@onready var disable_map_color_control := $ScrollContainer/VBox/disable_map_color as CheckButton
@onready var left_saber_posx_control := $ScrollContainer/VBox/left_saber_offset/posx as SpinBox
@onready var left_saber_posy_control := $ScrollContainer/VBox/left_saber_offset/posy as SpinBox
@onready var left_saber_posz_control := $ScrollContainer/VBox/left_saber_offset/posz as SpinBox
@onready var left_saber_rotx_control := $ScrollContainer/VBox/left_saber_offset/rotx as SpinBox
@onready var left_saber_roty_control := $ScrollContainer/VBox/left_saber_offset/roty as SpinBox
@onready var left_saber_rotz_control := $ScrollContainer/VBox/left_saber_offset/rotz as SpinBox
@onready var right_saber_posx_control := $ScrollContainer/VBox/right_saber_offset/posx as SpinBox
@onready var right_saber_posy_control := $ScrollContainer/VBox/right_saber_offset/posy as SpinBox
@onready var right_saber_posz_control := $ScrollContainer/VBox/right_saber_offset/posz as SpinBox
@onready var right_saber_rotx_control := $ScrollContainer/VBox/right_saber_offset/rotx as SpinBox
@onready var right_saber_roty_control := $ScrollContainer/VBox/right_saber_offset/roty as SpinBox
@onready var right_saber_rotz_control := $ScrollContainer/VBox/right_saber_offset/rotz as SpinBox
@onready var player_height_offset_control := $ScrollContainer/VBox/player_height_offset/pos as SpinBox
@onready var audio_master_control := $ScrollContainer/VBox/audio/master/master_slider as HSlider
@onready var audio_music_control := $ScrollContainer/VBox/audio/music/music_slider as HSlider
@onready var audio_sfx_control := $ScrollContainer/VBox/audio/sfx/sfx_slider as HSlider
@onready var spectator_view_control := $ScrollContainer/VBox/spectator_view as CheckButton
@onready var spectator_hud_control := $ScrollContainer/VBox/spectator_hud as CheckButton
@onready var visionos_passthrough_control := $ScrollContainer/VBox/visionos_passthrough as CheckButton

var _play_ui_sound_demo := false

func _ready() -> void:
	UI_AudioEngine.attach_children(self)
	_setup_saber_swatches(left_saber_swatches, true)
	_setup_saber_swatches(right_saber_swatches, false)
	visibility_changed.connect(_on_visibility_changed)
	
	set_controls_from_settings()
	_play_ui_sound_demo = true
	
	if OS.get_name() == &"Web":
		# way too heavy for webxr
		$ScrollContainer/VBox/glare.hide()
	
	# Immersion style only exists on the native visionOS backend.
	visionos_passthrough_control.visible = VisionOSPlatform.is_native_platform()

func set_controls_from_settings() -> void:
	saber_control.clear()
	for s in Settings.SABER_VISUALS:
		saber_control.add_item(s[0])
	
	show_collisions.button_pressed = get_tree().debug_collisions_hint
	show_collisions.visible = OS.is_debug_build()
	
	# set the selections to the loaded values
	await get_tree().process_frame
	saber_thickness.value = Settings.thickness
	cut_blocks.button_pressed = Settings.cube_cuts_falloff
	_update_saber_swatch_selection(left_saber_swatches, Settings.color_left)
	_update_saber_swatch_selection(right_saber_swatches, Settings.color_right)
	saber_tail_control.button_pressed = Settings.saber_tail
	glare_control.button_pressed = Settings.glare
	d_background.button_pressed = Settings.events
	saber_control.select(Settings.saber_visual)
	show_debug_control.button_pressed = Settings.show_debug_info
	bombs_enabled_control.button_pressed = Settings.bombs_enabled
	no_fail_control.button_pressed = Settings.no_fail
	ui_volume_slider.value = Settings.ui_volume
	disable_map_color_control.button_pressed = Settings.disable_map_color
	left_saber_posx_control.value = Settings.left_saber_offset_pos.x
	left_saber_posy_control.value = Settings.left_saber_offset_pos.y
	left_saber_posz_control.value = Settings.left_saber_offset_pos.z
	left_saber_rotx_control.value = Settings.left_saber_offset_rot.x
	left_saber_roty_control.value = Settings.left_saber_offset_rot.y
	left_saber_rotz_control.value = Settings.left_saber_offset_rot.z
	right_saber_posx_control.value = Settings.right_saber_offset_pos.x
	right_saber_posy_control.value = Settings.right_saber_offset_pos.y
	right_saber_posz_control.value = Settings.right_saber_offset_pos.z
	right_saber_rotx_control.value = Settings.right_saber_offset_rot.x
	right_saber_roty_control.value = Settings.right_saber_offset_rot.y
	right_saber_rotz_control.value = Settings.right_saber_offset_rot.z
	player_height_offset_control.value = Settings.player_height_offset
	audio_master_control.value = Settings.audio_master
	audio_music_control.value = Settings.audio_music
	audio_sfx_control.value = Settings.audio_sfx
	spectator_view_control.button_pressed = Settings.spectator_view
	spectator_hud_control.button_pressed = Settings.spectator_hud
	visionos_passthrough_control.button_pressed = Settings.visionos_passthrough

func _restore_defaults() -> void:
	Settings.restore_defaults()
	set_controls_from_settings()

#settings down here
func _on_thickness_value_changed(value: float) -> void:
	Settings.thickness = value

func _on_cut_blocks_toggled(button_pressed: bool) -> void:
	Settings.cube_cuts_falloff = button_pressed

func _setup_saber_swatches(container: HBoxContainer, is_left: bool) -> void:
	for index: int in range(SABER_COLORS.size()):
		var button := container.get_child(index) as Button
		button.pressed.connect(_on_saber_swatch_pressed.bind(index, is_left))
		_set_swatch_style(button, SABER_COLORS[index], false)

func _set_swatch_style(button: Button, color: Color, selected: bool) -> void:
	var normal_style := _make_swatch_style(color, selected, 0.0)
	var hover_style := _make_swatch_style(color, selected, 0.12)
	var pressed_style := _make_swatch_style(color, selected, -0.12)
	button.add_theme_stylebox_override(&"normal", normal_style)
	button.add_theme_stylebox_override(&"hover", hover_style)
	button.add_theme_stylebox_override(&"pressed", pressed_style)

func _make_swatch_style(color: Color, selected: bool, brightness_change: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color.lightened(brightness_change) if brightness_change >= 0.0 else color.darkened(-brightness_change)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	if selected:
		style.border_width_left = SWATCH_BORDER_WIDTH
		style.border_width_top = SWATCH_BORDER_WIDTH
		style.border_width_right = SWATCH_BORDER_WIDTH
		style.border_width_bottom = SWATCH_BORDER_WIDTH
		style.border_color = Color.WHITE
	return style

func _get_matching_swatch_index(color: Color) -> int:
	var closest_index := -1
	var closest_distance := INF
	for index: int in range(SABER_COLORS.size()):
		var palette_color: Color = SABER_COLORS[index]
		var red_difference := color.r - palette_color.r
		var green_difference := color.g - palette_color.g
		var blue_difference := color.b - palette_color.b
		var distance_squared := (
			red_difference * red_difference
			+ green_difference * green_difference
			+ blue_difference * blue_difference
		)
		if distance_squared < closest_distance:
			closest_distance = distance_squared
			closest_index = index
	return closest_index if closest_distance <= SWATCH_MATCH_DISTANCE_SQUARED else -1

func _update_saber_swatch_selection(container: HBoxContainer, color: Color) -> void:
	var selected_index := _get_matching_swatch_index(color)
	for index: int in range(SABER_COLORS.size()):
		var button := container.get_child(index) as Button
		_set_swatch_style(button, SABER_COLORS[index], index == selected_index)

func _on_saber_swatch_pressed(index: int, is_left: bool) -> void:
	var color: Color = SABER_COLORS[index]
	if is_left:
		Settings.color_left = color
		_update_saber_swatch_selection(left_saber_swatches, color)
	else:
		Settings.color_right = color
		_update_saber_swatch_selection(right_saber_swatches, color)

func _on_reset_saber_colors_pressed() -> void:
	Settings.color_left = Settings.DEFAULT_COLOR_LEFT
	Settings.color_right = Settings.DEFAULT_COLOR_RIGHT
	_update_saber_swatch_selection(left_saber_swatches, Settings.color_left)
	_update_saber_swatch_selection(right_saber_swatches, Settings.color_right)

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_update_saber_swatch_selection(left_saber_swatches, Settings.color_left)
		_update_saber_swatch_selection(right_saber_swatches, Settings.color_right)

func _on_saber_tail_toggled(button_pressed: bool) -> void:
	Settings.saber_tail = button_pressed

func _on_glare_toggled(button_pressed: bool) -> void:
	Settings.glare = button_pressed

func _on_d_background_toggled(button_pressed: bool) -> void:
	Settings.events = button_pressed

func _on_saber_item_selected(index: int) -> void:
	Settings.saber_visual = index

func _on_show_debug_toggled(button_pressed: bool) -> void:
	Settings.show_debug_info = button_pressed

func _on_bombs_enabled_toggled(button_pressed: bool) -> void:
	Settings.bombs_enabled = button_pressed

func _on_no_fail_toggled(button_pressed: bool) -> void:
	Settings.no_fail = button_pressed

func _on_ui_volume_slider_value_changed(value: float) -> void:
	UI_AudioEngine.set_volume(linear_to_db(float(value)/10.0))
	if _play_ui_sound_demo:
		UI_AudioEngine.play_click()
	
	Settings.ui_volume = value

func _on_left_saber_pos_x_changed(value: float) -> void:
	Settings.left_saber_offset_pos.x = value

func _on_left_saber_pos_y_changed(value: float) -> void:
	Settings.left_saber_offset_pos.y = value

func _on_left_saber_pos_z_changed(value: float) -> void:
	Settings.left_saber_offset_pos.z = value

func _on_left_saber_rot_x_changed(value: float) -> void:
	Settings.left_saber_offset_rot.x = value

func _on_left_saber_rot_y_changed(value: float) -> void:
	Settings.left_saber_offset_rot.y = value

func _on_left_saber_rot_z_changed(value: float) -> void:
	Settings.left_saber_offset_rot.z = value

func _on_right_saber_pos_x_changed(value: float) -> void:
	Settings.right_saber_offset_pos.x = value

func _on_right_saber_pos_y_changed(value: float) -> void:
	Settings.right_saber_offset_pos.y = value

func _on_right_saber_pos_z_changed(value: float) -> void:
	Settings.right_saber_offset_pos.z = value

func _on_right_saber_rot_x_changed(value: float) -> void:
	Settings.right_saber_offset_rot.x = value

func _on_right_saber_rot_y_changed(value: float) -> void:
	Settings.right_saber_offset_rot.y = value

func _on_right_saber_rot_z_changed(value: float) -> void:
	Settings.right_saber_offset_rot.z = value

func _on_player_height_offset_changed(value: float) -> void:
	Settings.player_height_offset = value

func _on_disable_map_color_toggled(toggled_on: bool) -> void:
	Settings.disable_map_color = toggled_on

func _force_update_show_coll_shapes(node: Node) -> void:
	# toggle enable to make engine show collision shapes
	if node is CollisionShape3D:
		var col := node as CollisionShape3D
		col.disabled = not col.disabled
		col.disabled = not col.disabled
	elif node is RayCast3D:
		var ray := node as RayCast3D
		ray.enabled = not ray.enabled
		ray.enabled = not ray.enabled
	
	for c in node.get_children():
		_force_update_show_coll_shapes(c)

func _on_show_collisions_toggled(button_pressed: bool) -> void:
	get_tree().debug_collisions_hint = button_pressed
	# must toggle 
	_force_update_show_coll_shapes(get_tree().root)

func _on_apply_pressed() -> void:
	Settings.save()
	apply.emit()


func _on_master_slider_value_changed(value: float) -> void:
	Settings.audio_master = value

func _on_music_slider_value_changed(value: float) -> void:
	Settings.audio_music = value

func _on_sfx_slider_value_changed(value: float) -> void:
	Settings.audio_sfx = value

func _on_spectator_view_toggled(value: bool) -> void:
	Settings.spectator_view = value

func _on_spectator_hud_toggled(value: bool) -> void:
	Settings.spectator_hud = value


func _on_visionos_passthrough_toggled(value: bool) -> void:
	Settings.visionos_passthrough = value


func _on_recenter_button_up() -> void:
	var recenter_button : Button = $ScrollContainer/VBox/recenter
	recenter_button.disabled = true
	recenter_button.text = "3.."
	await get_tree().create_timer(1).timeout
	recenter_button.text = "2.."
	await get_tree().create_timer(1).timeout
	recenter_button.text = "1.."
	await get_tree().create_timer(1).timeout
	recenter_button.text = "Recenter"
	recenter_button.disabled = false
	beepsaber_game.recenter()
