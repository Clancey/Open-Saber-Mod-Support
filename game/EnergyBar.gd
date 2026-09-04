extends MeshInstance3D
class_name EnergyBar

const TWEEN_DURATION: float = 0.15
const BAR_POSITION: Vector3 = Vector3(0.0, 0.28, -2.4)
const BAR_TILT_DEGREES: float = 25.0

var displayed_energy: float = Scoreboard.energy:
	set(value):
		displayed_energy = clampf(value, 0.0, 1.0)
		if is_instance_valid(_material):
			_material.set_shader_parameter(&"fill", displayed_energy)

var _material: ShaderMaterial
var _energy_tween: Tween

func _ready() -> void:
	position = BAR_POSITION
	rotation_degrees = Vector3(BAR_TILT_DEGREES, 0.0, 0.0)
	_material = material_override as ShaderMaterial
	_material.set_shader_parameter(&"bar_color", Settings.color_left)
	displayed_energy = Scoreboard.energy
	@warning_ignore("return_value_discarded")
	Scoreboard.energy_changed.connect(_on_energy_changed)
	@warning_ignore("return_value_discarded")
	Settings.changed.connect(_on_settings_changed)

func _on_settings_changed(key: StringName) -> void:
	if key == &"color_left":
		_material.set_shader_parameter(&"bar_color", Settings.color_left)

func _on_energy_changed(value: float) -> void:
	if is_instance_valid(_energy_tween):
		_energy_tween.kill()
	_energy_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_energy_tween.tween_property(self, ^"displayed_energy", value, TWEEN_DURATION)
