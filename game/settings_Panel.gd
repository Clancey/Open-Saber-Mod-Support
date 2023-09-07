extends Panel

signal apply()

@export var game_path: NodePath;
var game;
var savedata = {
	thickness=100,
	cube_cuts_falloff=true,
	COLOR_LEFT = Color("ff1a1a"),
	COLOR_RIGHT = Color("1a1aff"),
	saber_tail = true,
	glare = true,
	show_fps = false,
	bombs_enabled = true,
	events = true,
	saber = 0,
	ui_volume = 10.0,
	left_saber_offset = [Vector3.ZERO, Vector3.ZERO],
	right_saber_offset = [Vector3.ZERO, Vector3.ZERO],
	disable_map_color = false
}
var defaults
const config_path = "user://config.dat"

@onready var saber = $ScrollContainer/VBox/SaberTypeRow/saber
@onready var glare = $ScrollContainer/VBox/glare
@onready var sabe_tail = $ScrollContainer/VBox/saber_tail
@onready var saber_thickness = $ScrollContainer/VBox/SaberThicknessRow/saber_thickness
@onready var cut_blocks = $ScrollContainer/VBox/cut_blocks
@onready var d_background = $ScrollContainer/VBox/d_background
@onready var left_saber_col = $ScrollContainer/VBox/SaberColorsRow/left_saber_col
@onready var right_saber_col = $ScrollContainer/VBox/SaberColorsRow/right_saber_col
@onready var show_fps = $ScrollContainer/VBox/show_fps
@onready var show_collisions = $ScrollContainer/VBox/show_collisions
@onready var bombs_enabled = $ScrollContainer/VBox/bombs_enabled
@onready var ui_volume_slider = $ScrollContainer/VBox/UI_VolumeRow/ui_volume_slider
@onready var left_saber_offset = [
	$ScrollContainer/VBox/left_saber_offset/posx,
	$ScrollContainer/VBox/left_saber_offset/posy,
	$ScrollContainer/VBox/left_saber_offset/posz,
	$ScrollContainer/VBox/left_saber_offset/rotx,
	$ScrollContainer/VBox/left_saber_offset/roty,
	$ScrollContainer/VBox/left_saber_offset/rotz,
]
@onready var right_saber_offset = [
	$ScrollContainer/VBox/right_saber_offset/posx,
	$ScrollContainer/VBox/right_saber_offset/posy,
	$ScrollContainer/VBox/right_saber_offset/posz,
	$ScrollContainer/VBox/right_saber_offset/rotx,
	$ScrollContainer/VBox/right_saber_offset/roty,
	$ScrollContainer/VBox/right_saber_offset/rotz,
]
@onready var disable_map_color = $ScrollContainer/VBox/disable_map_color

var sabers = [
	["Default saber","res://game/sabers/default/default_saber.tscn"],
	["Particle sword","res://game/sabers/particles/particles_saber.tscn"]
]
var _play_ui_sound_demo = false

func _ready():
	UI_AudioEngine.attach_children(self)
	if not game:
		game = get_node(game_path);
	defaults = savedata.duplicate()
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path,FileAccess.READ)
		savedata = file.get_var(true)
		file.close()
	
	saber.clear()
	for s in sabers:
		saber.add_item(s[0])
	
	show_collisions.button_pressed = get_tree().debug_collisions_hint
	show_collisions.visible = OS.is_debug_build()
	
	#correct controls
	await get_tree().process_frame
	_on_HSlider_value_changed(savedata.thickness,false)
	_on_cut_blocks_toggled(savedata.cube_cuts_falloff,false)
	_on_left_saber_col_color_changed(savedata.COLOR_LEFT,false)
	_on_right_saber_col_color_changed(savedata.COLOR_RIGHT,false)
	_on_saber_tail_toggled(savedata.saber_tail,false)
	if savedata.has("glare"):
		_on_glare_toggled(savedata.glare,false)
	if savedata.has("events"):
		_on_d_background_toggled(savedata.events,false)
	if savedata.has("saber"):
		_on_saber_item_selected(savedata.saber,false)
	if savedata.has("show_fps"):
		_on_show_fps_toggled(savedata.show_fps,false)
	if savedata.has("bombs_enabled"):
		_on_bombs_enabled_toggled(savedata.bombs_enabled,false)
	if savedata.has("ui_volume"):
		_on_ui_volume_slider_value_changed(savedata.ui_volume,false)
	if savedata.has("disable_map_color"):
		_on_disable_map_color_toggled(savedata.disable_map_color,false)
	if savedata.has("left_saber_offset"):
		_on_left_saber_offset_value_changed(savedata.left_saber_offset,false)
	if savedata.has("right_saber_offset"):
		_on_right_saber_offset_value_changed(savedata.right_saber_offset,false)
		
	_play_ui_sound_demo = true

func save_current_settings():
	var file = FileAccess.open(config_path,FileAccess.WRITE)
	file.store_var(savedata,true)
	file.close()
	
func _on_Button_button_up():
	savedata = defaults
	save_current_settings()
	_ready()


#settings down here
func _on_HSlider_value_changed(value,overwrite=true):
	if game:
		game.left_saber.set_thickness(float(value)/100);
		game.right_saber.set_thickness(float(value)/100);
	
	if overwrite:
		savedata.thickness = value
		save_current_settings()
	else:
		saber_thickness.value = value



func _on_cut_blocks_toggled(button_pressed,overwrite=true):
	if game:
		game.cube_cuts_falloff = button_pressed;
	
	if overwrite:
		savedata.cube_cuts_falloff = button_pressed
		save_current_settings()
	else:
		cut_blocks.button_pressed = button_pressed


func _on_left_saber_col_color_changed(color,overwrite=true):
	if game:
		game.COLOR_LEFT = color
		game.update_saber_colors()
	
	if overwrite:
		savedata.COLOR_LEFT = color
		save_current_settings()
	else:
		left_saber_col.color = color


func _on_right_saber_col_color_changed(color,overwrite=true):
	if game:
		game.COLOR_RIGHT = color
		game.update_saber_colors()
	
	if overwrite:
		savedata.COLOR_RIGHT = color
		save_current_settings()
	else:
		right_saber_col.color = color


func _on_saber_tail_toggled(button_pressed,overwrite=true):
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		ls.set_trail(button_pressed)
	
	if overwrite:
		savedata.saber_tail = button_pressed
		save_current_settings()
	else:
		sabe_tail.button_pressed = button_pressed


func _on_glare_toggled(button_pressed,overwrite=true):
	var env_nodes = get_tree().get_nodes_in_group("enviroment")
	for node in env_nodes:
		node.environment.glow_enabled = button_pressed
	
	if overwrite:
		savedata.glare = button_pressed
		save_current_settings()
	else:
		glare.button_pressed = button_pressed


func _on_d_background_toggled(button_pressed,overwrite=true):
	if game:
		game.disable_events(!button_pressed)
	
	if overwrite:
		savedata.events = button_pressed
		save_current_settings()
	else:
		d_background.button_pressed = button_pressed

func _on_saber_item_selected(index,overwrite=true):
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		ls.set_saber(sabers[index][1])
	await get_tree().process_frame
	if game != null:
		game.update_saber_colors()
	_on_saber_tail_toggled(savedata.saber_tail,false)
		
	if overwrite:
		savedata.saber = index
		save_current_settings()
	else:
		saber.select(index)

func _on_show_fps_toggled(button_pressed,overwrite=true):
	if game:
		game.fps_label.visible = button_pressed
	
	if overwrite:
		savedata.show_fps = button_pressed
		save_current_settings()
	else:
		show_fps.button_pressed = button_pressed


func _on_bombs_enabled_toggled(button_pressed,overwrite=true):
	if game:
		game.bombs_enabled = button_pressed
	
	if overwrite:
		savedata.bombs_enabled = button_pressed
		save_current_settings()
	else:
		bombs_enabled.button_pressed = button_pressed

func _on_ui_volume_slider_value_changed(value,overwrite=true):
	UI_AudioEngine.set_volume(linear_to_db(float(value)/10.0))
	if _play_ui_sound_demo:
		UI_AudioEngine.play_click()
	
	if overwrite:
		savedata.ui_volume = value
		save_current_settings()
	else:
		ui_volume_slider.value = value


func _on_left_saber_offset_value_changed(value,overwrite=true):
	if not value is Array:
		value = [
			Vector3(left_saber_offset[0].value,left_saber_offset[1].value,left_saber_offset[2].value),
			Vector3(left_saber_offset[3].value,left_saber_offset[4].value,left_saber_offset[5].value)]
	
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		if ls.type == 0:
			ls.extra_offset_pos = value[0]
			ls.extra_offset_rot = value[1]
	
	if overwrite:
		savedata.left_saber_offset = value
		save_current_settings()
	else:
		left_saber_offset[0].value = value[0].x
		left_saber_offset[1].value = value[0].y
		left_saber_offset[2].value = value[0].z
		left_saber_offset[3].value = value[1].x
		left_saber_offset[4].value = value[1].y
		left_saber_offset[5].value = value[1].z

func _on_right_saber_offset_value_changed(value,overwrite=true):
	if not value is Array:
		value = [
			Vector3(right_saber_offset[0].value,right_saber_offset[1].value,right_saber_offset[2].value),
			Vector3(right_saber_offset[3].value,right_saber_offset[4].value,right_saber_offset[5].value)]
	
	for ls in get_tree().get_nodes_in_group("lightsaber"):
		if ls.type == 1:
			ls.extra_offset_pos = value[0]
			ls.extra_offset_rot = value[1]
	
	if overwrite:
		savedata.right_saber_offset = value
		save_current_settings()
	else:
		right_saber_offset[0].value = value[0].x
		right_saber_offset[1].value = value[0].y
		right_saber_offset[2].value = value[0].z
		right_saber_offset[3].value = value[1].x
		right_saber_offset[4].value = value[1].y
		right_saber_offset[5].value = value[1].z

func _on_disable_map_color_toggled(toggled_on,overwrite=true):
	if game:
		game.disable_map_color = toggled_on
	
	if overwrite:
		savedata.disable_map_color = toggled_on
		save_current_settings()
	else:
		disable_map_color.button_pressed = toggled_on

func _force_update_show_coll_shapes(node):
	# toggle enable to make engine show collision shapes
	if node is CollisionShape3D:
		node.disabled = ! node.disabled
		node.disabled = ! node.disabled
			
	elif node is RayCast3D:
		node.enabled = ! node.enabled
		node.enabled = ! node.enabled
		
	for c in node.get_children():
		_force_update_show_coll_shapes(c)

func _on_show_collisions_toggled(button_pressed):
	get_tree().debug_collisions_hint = button_pressed
	# must toggle 
	_force_update_show_coll_shapes(get_tree().root)

#check if A, B and right thumbstick buttons are pressed at the same time to delete settings
func _on_wipe_check_timeout():
	if game == null:
		return
	
	if (game.menu.visible
		and ((vr.button_pressed(vr.BUTTON.A) 
		and vr.button_pressed(vr.BUTTON.B)
		and vr.button_pressed(vr.BUTTON.RIGHT_THUMBSTICK) 
		or Input.is_action_pressed("ui_page_up") and Input.is_action_pressed("ui_page_down")))
		):
			DirAccess.remove_absolute(config_path)
			get_tree().change_scene_to_file("res://GameMain.tscn")

func _on_apply_pressed():
	emit_signal("apply")
	$ScrollContainer/VBox/SaberColorsRow/left_saber_col.get_popup().hide()
	$ScrollContainer/VBox/SaberColorsRow/right_saber_col.get_popup().hide()



