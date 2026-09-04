extends StaticBody3D
class_name Floor

var left_last_position := Vector2(0,-50)
var right_last_position := Vector2(0,-50)

var C_LEFT := Color()
var C_RIGHT := Color()

@onready var sub_viewport := $SubViewport as SubViewport
@onready var color_rect := $SubViewport/ColorRect as ColorRect
@onready var burn_l := $SubViewport/ColorRect/burn_l as Node2D
@onready var burn_r := $SubViewport/ColorRect/burn_r as Node2D
@onready var l_sprite := $SubViewport/ColorRect/burn_l/sprite as Panel
@onready var r_sprite := $SubViewport/ColorRect/burn_r/sprite as Panel
@onready var timer_clear := $TimerClear as Timer
@onready var left_edge_material := (
	$Node3D/Node3D/MeshInstance3D2 as MeshInstance3D
).material_override as ShaderMaterial
@onready var platform_material := (
	$Node3D/cutFloor as MeshInstance3D
).material_override as ShaderMaterial

var is_disabled := false
var _viewport_refresh_generation := 0

func _ready() -> void:
	platform_material.set_shader_parameter(&"burn_texture", sub_viewport.get_texture())

	if OS.get_name() in [&"Android", &"Web"]:
		timer_clear.stop()
		is_disabled = true
	@warning_ignore("return_value_discarded")
	visibility_changed.connect(_sync_viewport_update_mode)
	_sync_viewport_update_mode()

func _sync_viewport_update_mode() -> void:
	_viewport_refresh_generation += 1
	if is_disabled or not is_visible_in_tree():
		sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return

	var refresh_generation := _viewport_refresh_generation
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if refresh_generation != _viewport_refresh_generation:
		return
	sub_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS
		if is_visible_in_tree()
		else SubViewport.UPDATE_DISABLED
	)

func update_left_color(color: Color) -> void:
	C_LEFT = color
	burn_l.modulate = color*6
	left_edge_material.set_shader_parameter(&"left_color", color)
	_update_platform_mix()

func update_right_color(color: Color) -> void:
	C_RIGHT = color
	burn_r.modulate = color*6
	left_edge_material.set_shader_parameter(&"right_color", color)
	_update_platform_mix()

func _update_platform_mix() -> void:
	var mixed_color: Color = C_LEFT.lerp(C_RIGHT, 0.5)
	var surface_color: Color = Color(
		mixed_color.r * 0.05,
		mixed_color.g * 0.05,
		mixed_color.b * 0.05,
		1.0
	)
	platform_material.set_shader_parameter(&"base_color", surface_color)

var left_is_out := false
var right_is_out := false
func burn_mark(pos:=Vector3(0,0,-50),type:=0) -> void:
	if is_disabled:
		return
	var newpos := Vector2(
		(pos.x+1)*256,
		pos.z*256
	)
	var burn_mark_sprite: Node2D
	var burn_mark_sprite_long: Panel
	var dist: float
	if type == 0:
		burn_mark_sprite = burn_l
		burn_mark_sprite_long = l_sprite
		left_is_out = false
		burn_mark_sprite.rotation = newpos.angle_to_point(left_last_position)
		dist = left_last_position.distance_to(newpos)
	elif type == 1:
		burn_mark_sprite = burn_r
		burn_mark_sprite_long = r_sprite
		right_is_out = false
		burn_mark_sprite.rotation = newpos.angle_to_point(right_last_position)
		dist = right_last_position.distance_to(newpos)
	else:
		return
	var was_out := !burn_mark_sprite.visible
	burn_mark_sprite.visible = true
	
	burn_mark_sprite.position = newpos
	
	burn_mark_sprite.rotation_degrees += 180
	if dist > 12 and not was_out:
		burn_mark_sprite_long.size.x = dist+12
	else:
		burn_mark_sprite_long.size.x = 24
	
	if type == 0:
		left_last_position = newpos
	elif type == 1:
		right_last_position = newpos

func _process(_delta: float) -> void:
	if left_is_out:
		burn_l.visible = false
	if right_is_out:
		burn_r.visible = false
	left_is_out = true
	right_is_out = true

func _on_timer_clear_timeout() -> void:
	color_rect.self_modulate.a = 1
	await get_tree().process_frame
	color_rect.self_modulate.a = 0
	timer_clear.start()
