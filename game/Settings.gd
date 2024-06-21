extends Node

const config_path := "user://config.dat"
var thickness := 100.0
var color_left := Color("ff1a1a")
var color_right := Color("1a1aff")
var saber_visual := 0
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

var SABER_VISUALS: Array[PackedStringArray] = [
	PackedStringArray(["Default saber","res://game/sabers/default/default_saber.tscn"]),
	PackedStringArray(["Particle sword","res://game/sabers/particles/particles_saber.tscn"])
]

func _ready() -> void:
	if FileAccess.file_exists(config_path):
		reload()
	else:
		restore_defaults()

func reload() -> void:
	var file := FileAccess.open(config_path,FileAccess.READ)
	if not file:
		var error := FileAccess.get_open_error()
		if error != ERR_FILE_NOT_FOUND:
			vr.log_file_error(error, config_path, "load() in Settings.gd")
		return
	thickness = file.get_float()
	color_left = Color(file.get_float(), file.get_float(), file.get_float(), file.get_float())
	color_right = Color(file.get_float(), file.get_float(), file.get_float(), file.get_float())
	saber_visual = file.get_8()
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

func save() -> void:
	var file := FileAccess.open(config_path,FileAccess.WRITE)
	if not file:
		vr.log_file_error(FileAccess.get_open_error(), config_path, "save() in Settings.gd")
		return
	file.store_float(thickness)
	file.store_float(color_left.r)
	file.store_float(color_left.g)
	file.store_float(color_left.b)
	file.store_float(color_left.a)
	file.store_float(color_right.r)
	file.store_float(color_right.g)
	file.store_float(color_right.b)
	file.store_float(color_right.a)
	file.store_8(saber_visual)
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

func restore_defaults() -> void:
	thickness = 100
	cube_cuts_falloff = true
	color_left = Color("ff1a1a")
	color_right = Color("1a1aff")
	saber_tail = true
	glare = true
	show_fps = false
	bombs_enabled = true
	events = true
	saber_visual = 0
	ui_volume = 10.0
	left_saber_offset_pos = Vector3.ZERO
	left_saber_offset_rot = Vector3.ZERO
	right_saber_offset_pos = Vector3.ZERO
	right_saber_offset_rot = Vector3.ZERO
	disable_map_color = false
	save()
