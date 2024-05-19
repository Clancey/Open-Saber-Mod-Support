extends Node3D
class_name EndScore

signal mainmenu
signal repeat

var animated_percent: float = 0.0
@onready var raycast_area := $RaycastArea as Area3D
@onready var percent_indicator := $PercentIndicator as PercentIndicator
@onready var details := ($Details as MeshInstance3D).mesh as TextMesh
@onready var grade_label := $GradeViewport/GradeLabel as RichTextLabel
@onready var fc_label := $FCViewport/FCLabel as RichTextLabel
@onready var nr_label := $NRViewport/NRLabel as RichTextLabel
@onready var name_label := ($NameLabel as MeshInstance3D).mesh as TextMesh

func _ready() -> void:
	set_buttons_disabled(true)

func _show() -> void:
	raycast_area.collision_layer = 1
	show()

func _hide() -> void:
	raycast_area.collision_layer = 0
	hide()

func show_score(score: int, record: int, percent: float, song_string: String, is_full_combo: bool, is_new_record: bool) -> void:
	var transparent := Color(1,1,1,0)
	(details.material as StandardMaterial3D).albedo_color = transparent
	grade_label.modulate = transparent
	fc_label.modulate = transparent
	nr_label.modulate = transparent
	percent_indicator.endscore()
	fc_label.visible = is_full_combo
	nr_label.visible = is_new_record
	name_label.text = song_string
	details.text = "Your Score:\n%d\n\nRecord:\n%d" % [score,record]
	
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
	
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(self,^"animated_percent",percent,3.0).from(0.0)
	tw.play()
	while tw.is_running():
		percent_indicator.update_percent(animated_percent)
		await get_tree().process_frame
	#_on_Tween_tween_completed()
	
	tw = create_tween()
	percent_indicator.update_percent(animated_percent)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_IN_OUT)
	tw.set_parallel()
	tw.tween_property(details.material,^"albedo_color",Color.WHITE,2).from(transparent)
	tw.tween_property(grade_label,^"modulate",Color.WHITE,2).from(transparent)
	tw.tween_property(fc_label,^"modulate",Color.WHITE,2).from(transparent)
	tw.tween_property(nr_label,^"modulate",Color.WHITE,2).from(transparent)
	tw.play()

func set_buttons_disabled(disabled: bool) -> void:
	($Repeat/Collision as CollisionShape3D).disabled = disabled
	($MainMenu/Collision as CollisionShape3D).disabled = disabled

func _on_Repeat_button_up() -> void:
	repeat.emit()

func _on_MainMenu_button_up() -> void:
	set_buttons_disabled(true)
	mainmenu.emit()
