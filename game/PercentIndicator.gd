extends MeshInstance3D
class_name PercentIndicator

# Beat Saber's score panel: a circle that fills with the score multiplier
# progress and shows the multiplier, with the immediate rank and relative
# score below it.

var how_full := 0.0
var how_full_display := 0.0
var label: Label3D
var rank_label: Label3D
var shader: ShaderMaterial
var _multiplier := 1

func _ready() -> void:
	shader = material_override as ShaderMaterial
	label = $PercentLabel as Label3D
	label.layers = layers
	rank_label = get_node_or_null("RankLabel") as Label3D
	if rank_label != null:
		rank_label.layers = layers

func _process(delta: float) -> void:
	how_full_display = lerpf(how_full_display, how_full, delta*8)
	shader.set_shader_parameter(&"how_full", how_full_display)

func start_map() -> void:
	how_full = 1.0
	how_full_display = 0.0
	_multiplier = 1
	label.text = "x1"
	if rank_label != null:
		rank_label.text = "SS  100%"

func endscore() -> void:
	how_full = 0.0
	how_full_display = 0.0
	label.text = ""
	if rank_label != null:
		rank_label.text = ""

static func rank_for(relative_score: float) -> String:
	if relative_score >= 0.9:
		return "SS"
	if relative_score >= 0.8:
		return "S"
	if relative_score >= 0.65:
		return "A"
	if relative_score >= 0.5:
		return "B"
	if relative_score >= 0.35:
		return "C"
	if relative_score >= 0.2:
		return "D"
	return "E"

func update_percent(amount: float) -> void:
	how_full = amount
	if rank_label != null:
		rank_label.text = "%s  %d%%" % [rank_for(amount), int(amount * 100)]
	else:
		label.text = "%d%%" % int(amount * 100)

func update_multiplier(multiplier: int) -> void:
	_multiplier = multiplier
	label.text = "x%d" % multiplier
