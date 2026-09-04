extends Node3D
class_name EndScore

signal mainmenu
signal repeat

var animated_percent: float = 0.0
@onready var raycast_area := $RaycastArea as Area3D
@onready var collision := $RaycastArea/CollisionShape3D as CollisionShape3D
@onready var fc_viewport := $FCViewport as SubViewport
@onready var nr_viewport := $NRViewport as SubViewport
@onready var grade_viewport := $GradeViewport as SubViewport

var _viewport_refresh_generation := 0

func _ready() -> void:
	set_buttons_disabled(true)
	@warning_ignore("return_value_discarded")
	visibility_changed.connect(_sync_viewport_update_modes)
	_sync_viewport_update_modes()

func _show() -> void:
	raycast_area.collision_layer = CollisionLayerConstants.Ui_mask
	collision.disabled = false
	($Repeat as UIRaycastButton).collision_layer = CollisionLayerConstants.Ui_mask
	($MainMenu as UIRaycastButton).collision_layer = CollisionLayerConstants.Ui_mask
	show()
	_sync_viewport_update_modes()

func _hide() -> void:
	raycast_area.collision_layer = 0
	collision.disabled = true
	($Repeat as UIRaycastButton).collision_layer = 0
	($MainMenu as UIRaycastButton).collision_layer = 0
	hide()
	_sync_viewport_update_modes()

func _sync_viewport_update_modes() -> void:
	_viewport_refresh_generation += 1
	var viewports: Array[SubViewport] = [fc_viewport, nr_viewport, grade_viewport]
	if not is_visible_in_tree():
		for score_viewport: SubViewport in viewports:
			score_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return

	var refresh_generation := _viewport_refresh_generation
	for score_viewport: SubViewport in viewports:
		score_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if refresh_generation != _viewport_refresh_generation:
		return
	var update_mode := (
		SubViewport.UPDATE_ALWAYS
		if is_visible_in_tree()
		else SubViewport.UPDATE_DISABLED
	)
	for score_viewport: SubViewport in viewports:
		score_viewport.render_target_update_mode = update_mode

func show_score(score: int, record: int, percent: float, song_string: String, is_full_combo: bool, is_new_record: bool) -> void:
	_show_result(
		percent,
		song_string,
		"LEVEL COMPLETE",
		"Your Score:\n%d\n\nRecord:\n%d" % [score, record],
		is_full_combo,
		is_new_record
	)

func show_failed(score: int, percent: float, song_string: String) -> void:
	_show_result(
		percent,
		song_string,
		"LEVEL FAILED",
		"Your Score:\n%d" % score,
		false,
		false
	)

func _show_result(
	percent: float,
	song_string: String,
	title: String,
	details: String,
	is_full_combo: bool,
	is_new_record: bool
) -> void:
	var details_mesh := ($Details as MeshInstance3D).mesh as TextMesh
	var details_material := ($Details as MeshInstance3D).material_override as StandardMaterial3D
	var percent_indicator := $PercentIndicator as PercentIndicator
	var grade_label := $GradeViewport/GradeLabel as RichTextLabel
	var fc_label := $FCViewport/FCLabel as RichTextLabel
	var nr_label := $NRViewport/NRLabel as RichTextLabel
	var name_label := ($NameLabel as MeshInstance3D).mesh as TextMesh
	var title_label := ($Title as MeshInstance3D).mesh as TextMesh
	
	details_material.albedo_color = Color.TRANSPARENT
	grade_label.modulate = Color.TRANSPARENT
	fc_label.modulate = Color.TRANSPARENT
	nr_label.modulate = Color.TRANSPARENT
	percent_indicator.endscore()
	fc_label.visible = is_full_combo
	nr_label.visible = is_new_record
	name_label.text = song_string
	title_label.text = title
	details_mesh.text = details
	
	if percent >= 0.98:
		grade_label.text = "[center][rainbow freq=0.5 sat=0.7 val=2]S"
	elif percent >= 0.90:
		grade_label.text = "[center]A"
	elif percent >= 0.80:
		grade_label.text = "[center]B"
	elif percent >= 0.70:
		grade_label.text = "[center]C"
	elif percent >= 0.60:
		grade_label.text = "[center]D"
	elif percent >= 0.50:
		grade_label.text = "[center]E"
	else:
		grade_label.text = "[center]F"
	
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self,^"animated_percent",percent,3.0).from(0.0)
	tw.play()
	while tw.is_running():
		percent_indicator.update_percent(animated_percent)
		await get_tree().process_frame
	#_on_Tween_tween_completed()
	
	percent_indicator.update_percent(animated_percent)
	tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT).set_parallel()
	tw.tween_property(details_material,^"albedo_color",Color.WHITE,2).from(Color.TRANSPARENT)
	tw.tween_property(grade_label,^"modulate",Color.WHITE,2).from(Color.TRANSPARENT)
	tw.tween_property(fc_label,^"modulate",Color.WHITE,2).from(Color.TRANSPARENT)
	tw.tween_property(nr_label,^"modulate",Color.WHITE,2).from(Color.TRANSPARENT)
	tw.play()

func set_buttons_disabled(disabled: bool) -> void:
	($Repeat/Collision as CollisionShape3D).disabled = disabled
	($MainMenu/Collision as CollisionShape3D).disabled = disabled

func _on_Repeat_button_up() -> void:
	repeat.emit()

func _on_MainMenu_button_up() -> void:
	set_buttons_disabled(true)
	mainmenu.emit()
