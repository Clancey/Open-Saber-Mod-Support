extends Window
class_name SpectatorWindow

@onready var point_label := $Camera3D/PointLabel as MeshInstance3D
@onready var multiplier_label := $Camera3D/MultiplierLabel as MeshInstance3D
# made local to reposition the text to be flush with the circle
@onready var percent_indicator := $Camera3D/PIPivot/PercentIndicator as PercentIndicator
@onready var spectator_camera := $Camera3D as Camera3D

func _ready() -> void:
	@warning_ignore("return_value_discarded")
	Scoreboard.score_changed.connect(on_scoreboard_update)
	@warning_ignore("return_value_discarded")
	Settings.changed.connect(on_settings_changed)

	if OS.get_name() == "Android":
		spectator_camera.current = false
		visible = false
		_apply_hud_visibility()
	else:
		_apply_rendering_state()
	reposition_ui_elements()

func on_settings_changed(key: StringName) -> void:
	match key:
		&"spectator_view":
			_apply_rendering_state()
		&"spectator_hud":
			_apply_hud_visibility()

func _apply_rendering_state() -> void:
	var rendering_enabled := not (OS.get_name() == "Android" and vr.inVR)
	spectator_camera.current = rendering_enabled
	visible = rendering_enabled and Settings.spectator_view
	_apply_hud_visibility()

func _apply_hud_visibility() -> void:
	var hud_visible := spectator_camera.current and Settings.spectator_hud
	point_label.visible = hud_visible
	multiplier_label.visible = hud_visible
	percent_indicator.visible = hud_visible

func resize_to_main_window_size() -> void:
	if visible:
		size = get_tree().get_root().size
		reposition_ui_elements()

func reposition_ui_elements() -> void:
	if not visible: return
	
	var cam := $Camera3D as Camera3D
	($Camera3D/PIPivot as Node3D).global_transform.origin = cam.project_position(size, 1.0)
	multiplier_label.global_transform.origin = cam.project_position(Vector2.ZERO, 1.0)
	point_label.global_transform.origin = cam.project_position(Vector2(size.x, 0.0), 1.0)

func on_scoreboard_update() -> void:
	if not visible: return
	
	var hit_rate: float
	if Scoreboard.right_notes+Scoreboard.wrong_notes > 0:
		hit_rate = Scoreboard.right_notes/(Scoreboard.right_notes+Scoreboard.wrong_notes)
	else:
		hit_rate = 1.0
	
	(point_label.mesh as TextMesh).text = "SCORE
%d" % Scoreboard.points
	(multiplier_label.mesh as TextMesh).text = "COMBO
%d" % Scoreboard.combo
	percent_indicator.update_percent(hit_rate)

func close() -> void:
	visible = false
