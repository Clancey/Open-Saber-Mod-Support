extends MeshInstance3D
class_name PercentIndicator

var how_full := 0.0
var how_full_display := 0.0
var label: TextMesh
var shader: ShaderMaterial

func _ready() -> void:
	# deduplicating nonsense to avoid the shader getting written to twice
	mesh = mesh.duplicate(true) as QuadMesh
	shader = (mesh as QuadMesh).material as ShaderMaterial
	var pl := $PercentLabel as MeshInstance3D
	pl.mesh = pl.mesh.duplicate(true) as TextMesh
	label = pl.mesh as TextMesh

func _process(delta: float) -> void:
	how_full_display = lerpf(how_full_display, how_full, delta*8)
	shader.set_shader_parameter("how_full", how_full_display)

func start_map() -> void:
	how_full = 1.0
	how_full_display = 0.0
	label.text = "100%"

func endscore() -> void:
	how_full = 0.0
	how_full_display = 0.0
	label.text = "0%"

func update_percent(amount: float) -> void:
	how_full = amount
	label.text = "%d%%" % int(amount * 100)
