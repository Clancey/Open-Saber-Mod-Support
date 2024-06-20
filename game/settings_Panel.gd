extends Panel

signal apply()

@export var game: BeepSaber_Game

var thickness := 100.0
var COLOR_LEFT := Color("ff1a1a")
var COLOR_RIGHT := Color("1a1aff")
var saber := 0
var ui_volume := 10.0
var left_saber_offset_pos := Vector3.ZERO
var left_saber_offset_rot := Vector3.ZERO
var right_saber_offset_pos := Vector3.ZERO
var right_saber_offset_rot := Vector3.ZERO
var cube_cuts_falloff := true
var saber_tail := true
var glare := true
var show_fps := false
var bombs_enabled := true
var events := true
var disable_map_color := false
const config_path := "user://config.dat"

@onready var saber_control := $ScrollContainer/VBox/SaberTypeRow/saber as OptionButton
@onready var glare_control := $ScrollContainer/VBox/glare as CheckButton
@onready var saber_tail_control := $ScrollContainer/VBox/saber_tail as CheckButton
@onready var saber_thickness := $ScrollContainer/VBox/SaberThicknessRow/saber_thickness as HSlider
@onready var cut_blocks := $ScrollContainer/VBox/cut_blocks as CheckButton
@onready var d_background := $ScrollContainer/VBox/d_background as CheckButton
@onready var left_saber_col := $ScrollContainer/VBox/SaberColorsRow/left_saber_col as ColorPickerButton
@onready var right_saber_col := $ScrollContainer/VBox/SaberColorsRow/right_saber_col as ColorPickerButton
@onready var show_fps_control := $ScrollContainer/VBox/show_fps as CheckButton
@onready var show_collisions := $ScrollContainer/VBox/show_collisions as CheckButton
@onready var bombs_enabled_control := $ScrollContainer/VBox/bombs_enabled as CheckButton
@onready var ui_volume_slider := $ScrollContainer/VBox/UI_VolumeRow/ui_volume_slider as HSlider
@onready var disable_map_color_control := $ScrollContainer/VBox/disable_map_color as CheckButton

var sabers: Array[PackedStringArray]= [
	PackedStringArray(["Default saber","res://game/sabers/default/default_saber.tscn"]),
	PackedStringArray(["Particle sword","res://game/sabers/particles/particles_saber.tscn"])
]
var _play_ui_sound_demo := false

func _ready() -> void:
	UI_AudioEngine.attach_children(self)
	
	if OS.get_name() in ["Web"] and game:
		#savedata.saber_tail = false
		#savedata.cube_cuts_falloff = false
		glare = false
		#savedata.events = false
		(game.get_node("StandingGround/SubViewport") as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	
	if FileAccess.file_exists(config_path):
		var file := FileAccess.open(config_path,FileAccess.READ)
		thickness = file.get_float()
		COLOR_LEFT = Color(file.get_float(), file.get_float(), file.get_float(), file.get_float())
		COLOR_RIGHT = Color(file.get_float(), file.get_float(), file.get_float(), file.get_float())
		saber = file.get_8()
		ui_volume = file.get_float()
		left_saber_offset_pos.x = file.get_float()
		left_saber_offset_pos.y = file.get_float()
		left_saber_offset_pos.z = file.get_float()
		left_saber_offset_rot.x = file.get_float()
		left_saber_offset_rot.y = file.get_float()
		left_saber_offset_rot.z = file.get_float()
		right_saber_offset_pos.x = file.get_float()
		right_saber_offset_pos.y = file.get_float()
		right_saber_offset_pos.z = file.get_float()
		right_saber_offset_rot.x = file.get_float()
		right_saber_offset_rot.y = file.get_float()
		right_saber_offset_rot.z = file.get_float()
		var bools_as_byte := file.get_8()
		file.close()
		cube_cuts_falloff = bools_as_byte & 64
		saber_tail = bools_as_byte & 32
		glare = bools_as_byte & 16
		show_fps = bools_as_byte & 8
		bombs_enabled = bools_as_byte & 4
		events = bools_as_byte & 2
		disable_map_color = bools_as_byte & 1
	
	saber_control.clear()
	for s in sabers:
		saber_control.add_item(s[0])
	
	show_collisions.button_pressed = get_tree().debug_collisions_hint
	show_collisions.visible = OS.is_debug_build()
	
	#correct controls
	await get_tree().process_frame
	_on_HSlider_value_changed(thickness,false)
	_on_cut_blocks_toggled(cube_cuts_falloff,false)
	_on_left_saber_col_color_changed(COLOR_LEFT,false)
	_on_right_saber_col_color_changed(COLOR_RIGHT,false)
	_on_saber_tail_toggled(saber_tail,false)
	_on_glare_toggled(glare,false)
	_on_d_background_toggled(events,false)
	_on_saber_item_selected(saber,false)
	_on_show_fps_toggled(show_fps,false)
	_on_bombs_enabled_toggled(bombs_enabled,false)
	_on_ui_volume_slider_value_changed(ui_volume,false)
	_on_disable_map_color_toggled(disable_map_color,false)
	_on_left_saber_pos_x_changed(left_saber_offset_pos.x,false)
	_on_left_saber_pos_y_changed(left_saber_offset_pos.y,false)
	_on_left_saber_pos_z_changed(left_saber_offset_pos.z,false)
	_on_left_saber_rot_x_changed(left_saber_offset_rot.x,false)
	_on_left_saber_rot_y_changed(left_saber_offset_rot.y,false)
	_on_left_saber_rot_z_changed(left_saber_offset_rot.z,false)
	_on_right_saber_pos_x_changed(right_saber_offset_pos.x,false)
	_on_right_saber_pos_y_changed(right_saber_offset_pos.y,false)
	_on_right_saber_pos_z_changed(right_saber_offset_pos.z,false)
	_on_right_saber_rot_x_changed(right_saber_offset_rot.x,false)
	_on_right_saber_rot_y_changed(right_saber_offset_rot.y,false)
	_on_right_saber_rot_z_changed(right_saber_offset_rot.z,false)
	
	_play_ui_sound_demo = true

func save_current_settings() -> void:
	var file := FileAccess.open(config_path,FileAccess.WRITE)
	file.store_float(thickness)
	file.store_float(COLOR_LEFT.r)
	file.store_float(COLOR_LEFT.g)
	file.store_float(COLOR_LEFT.b)
	file.store_float(COLOR_LEFT.a)
	file.store_float(COLOR_RIGHT.r)
	file.store_float(COLOR_RIGHT.g)
	file.store_float(COLOR_RIGHT.b)
	file.store_float(COLOR_RIGHT.a)
	file.store_8(saber)
	file.store_float(ui_volume)
	file.store_float(left_saber_offset_pos.x)
	file.store_float(left_saber_offset_pos.y)
	file.store_float(left_saber_offset_pos.z)
	file.store_float(left_saber_offset_rot.x)
	file.store_float(left_saber_offset_rot.y)
	file.store_float(left_saber_offset_rot.z)
	file.store_float(right_saber_offset_pos.x)
	file.store_float(right_saber_offset_pos.y)
	file.store_float(right_saber_offset_pos.z)
	file.store_float(right_saber_offset_rot.x)
	file.store_float(right_saber_offset_rot.y)
	file.store_float(right_saber_offset_rot.z)
	var bools_to_byte := (
		int(cube_cuts_falloff) * 64
		+ int(saber_tail) * 32
		+ int(glare) * 16
		+ int(show_fps) * 8
		+ int(bombs_enabled) * 4
		+ int(events) * 2
		+ int(disable_map_color)
	)
	file.store_8(bools_to_byte)
	file.close()

func _on_Button_button_up() -> void:
	thickness = 100
	cube_cuts_falloff = true
	COLOR_LEFT = Color("ff1a1a")
	COLOR_RIGHT = Color("1a1aff")
	saber_tail = true
	glare = true
	show_fps = false
	bombs_enabled = true
	events = true
	saber = 0
	ui_volume = 10.0
	left_saber_offset_pos = Vector3.ZERO
	left_saber_offset_rot = Vector3.ZERO
	right_saber_offset_pos = Vector3.ZERO
	right_saber_offset_rot = Vector3.ZERO
	disable_map_color = false
	save_current_settings()
	_ready()

#settings down here
func _on_HSlider_value_changed(value: float, overwrite: bool=true) -> void:
	if game:
		game.left_saber.set_thickness(float(value)/100);
		game.right_saber.set_thickness(float(value)/100);
	
	if overwrite:
		thickness = value
		save_current_settings()
	else:
		saber_thickness.value = value

func _on_cut_blocks_toggled(button_pressed: bool, overwrite: bool=true) -> void:
	if game:
		game.cube_cuts_falloff = button_pressed;
	
	if overwrite:
		cube_cuts_falloff = button_pressed
		save_current_settings()
	else:
		cut_blocks.button_pressed = button_pressed

func _on_left_saber_col_color_changed(color: Color, overwrite: bool=true) -> void:
	game.COLOR_LEFT = color
	game.update_saber_colors()
	
	if overwrite:
		COLOR_LEFT = color
		save_current_settings()
	else:
		left_saber_col.color = color

func _on_right_saber_col_color_changed(color: Color,overwrite: bool=true) -> void:
	game.COLOR_RIGHT = color
	game.update_saber_colors()
	
	if overwrite:
		COLOR_RIGHT = color
		save_current_settings()
	else:
		right_saber_col.color = color

func _on_saber_tail_toggled(button_pressed: bool, overwrite: bool=true) -> void:
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		if ls is LightSaber:
			(ls as LightSaber).set_trail(button_pressed)
	
	if overwrite:
		saber_tail = button_pressed
		save_current_settings()
	else:
		saber_tail_control.button_pressed = button_pressed

func _on_glare_toggled(button_pressed: bool, overwrite: bool=true) -> void:
	var env_nodes := get_tree().get_nodes_in_group("enviroment")
	for node in env_nodes:
		if node is WorldEnvironment:
			(node as WorldEnvironment).environment.glow_enabled = button_pressed
	
	if overwrite:
		glare = button_pressed
		save_current_settings()
	else:
		glare_control.button_pressed = button_pressed

func _on_d_background_toggled(button_pressed: bool, overwrite: bool=true) -> void:
	game.disable_events(!button_pressed)
	if OS.get_name() in ["Web"]:
		game.event_driver.visible = button_pressed
	
	if overwrite:
		events = button_pressed
		save_current_settings()
	else:
		d_background.button_pressed = button_pressed

func _on_saber_item_selected(index: int, overwrite: bool=true) -> void:
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		if ls is LightSaber:
			(ls as LightSaber).set_saber(sabers[index][1])
	await get_tree().process_frame
	game.update_saber_colors()
	_on_saber_tail_toggled(saber_tail,false)
	
	if overwrite:
		saber = index
		save_current_settings()
	else:
		saber_control.select(index)

func _on_show_fps_toggled(button_pressed: bool, overwrite: bool=true) -> void:
	game.fps_label.visible = button_pressed
	
	if overwrite:
		show_fps = button_pressed
		save_current_settings()
	else:
		show_fps_control.button_pressed = button_pressed

func _on_bombs_enabled_toggled(button_pressed: bool, overwrite: bool=true) -> void:
	game.bombs_enabled = button_pressed
	
	if overwrite:
		bombs_enabled = button_pressed
		save_current_settings()
	else:
		bombs_enabled_control.button_pressed = button_pressed

func _on_ui_volume_slider_value_changed(value: float, overwrite: bool=true) -> void:
	UI_AudioEngine.set_volume(linear_to_db(float(value)/10.0))
	if _play_ui_sound_demo:
		UI_AudioEngine.play_click()
	
	if overwrite:
		ui_volume = value
		save_current_settings()
	else:
		ui_volume_slider.value = value

func _on_left_saber_pos_x_changed(value: float, overwrite: bool=true) -> void:
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		if ls is LightSaber and (ls as LightSaber).type == 0:
			(ls as LightSaber).extra_offset_pos.x = value
	
	left_saber_offset_pos.x = value
	if overwrite:
		save_current_settings()

func _on_left_saber_pos_y_changed(value: float, overwrite: bool=true) -> void:
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		if ls is LightSaber and (ls as LightSaber).type == 0:
			(ls as LightSaber).extra_offset_pos.y = value
	
	left_saber_offset_pos.y = value
	if overwrite:
		save_current_settings()

func _on_left_saber_pos_z_changed(value: float, overwrite: bool=true) -> void:
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		if ls is LightSaber and (ls as LightSaber).type == 0:
			(ls as LightSaber).extra_offset_pos.z = value
	
	left_saber_offset_pos.z = value
	if overwrite:
		save_current_settings()

func _on_left_saber_rot_x_changed(value: float, overwrite: bool=true) -> void:
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		if ls is LightSaber and (ls as LightSaber).type == 0:
			(ls as LightSaber).extra_offset_rot.x = value
	
	left_saber_offset_rot.x = value
	if overwrite:
		save_current_settings()

func _on_left_saber_rot_y_changed(value: float, overwrite: bool=true) -> void:
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		if ls is LightSaber and (ls as LightSaber).type == 0:
			(ls as LightSaber).extra_offset_rot.y = value
	
	left_saber_offset_rot.y = value
	if overwrite:
		save_current_settings()

func _on_left_saber_rot_z_changed(value: float, overwrite: bool=true) -> void:
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		if ls is LightSaber and (ls as LightSaber).type == 0:
			(ls as LightSaber).extra_offset_rot.z = value
	
	left_saber_offset_rot.z = value
	if overwrite:
		save_current_settings()

func _on_right_saber_pos_x_changed(value: float, overwrite: bool=true) -> void:
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		if ls is LightSaber and (ls as LightSaber).type == 1:
			(ls as LightSaber).extra_offset_pos.x = value
	
	right_saber_offset_pos.x = value
	if overwrite:
		save_current_settings()

func _on_right_saber_pos_y_changed(value: float, overwrite: bool=true) -> void:
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		if ls is LightSaber and (ls as LightSaber).type == 1:
			(ls as LightSaber).extra_offset_pos.y = value
	
	right_saber_offset_pos.y = value
	if overwrite:
		save_current_settings()

func _on_right_saber_pos_z_changed(value: float, overwrite: bool=true) -> void:
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		if ls is LightSaber and (ls as LightSaber).type == 1:
			(ls as LightSaber).extra_offset_pos.z = value
	
	right_saber_offset_pos.z = value
	if overwrite:
		save_current_settings()

func _on_right_saber_rot_x_changed(value: float, overwrite: bool=true) -> void:
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		if ls is LightSaber and (ls as LightSaber).type == 1:
			(ls as LightSaber).extra_offset_rot.x = value
	
	right_saber_offset_rot.x = value
	if overwrite:
		save_current_settings()

func _on_right_saber_rot_y_changed(value: float, overwrite: bool=true) -> void:
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		if ls is LightSaber and (ls as LightSaber).type == 1:
			(ls as LightSaber).extra_offset_rot.y = value
	
	right_saber_offset_rot.y = value
	if overwrite:
		save_current_settings()

func _on_right_saber_rot_z_changed(value: float, overwrite: bool=true) -> void:
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		if ls is LightSaber and (ls as LightSaber).type == 1:
			(ls as LightSaber).extra_offset_rot.z = value
	
	right_saber_offset_rot.z = value
	if overwrite:
		save_current_settings()

func _on_disable_map_color_toggled(toggled_on: bool, overwrite: bool=true) -> void:
	game.disable_map_color = toggled_on
	
	if overwrite:
		disable_map_color = toggled_on
		save_current_settings()
	else:
		disable_map_color_control.button_pressed = toggled_on

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
	apply.emit()
	left_saber_col.get_popup().hide()
	right_saber_col.get_popup().hide()
