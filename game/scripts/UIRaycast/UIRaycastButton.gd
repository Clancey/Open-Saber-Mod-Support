extends UIRaycastTarget
class_name UIRaycastButton

signal pressed
signal released

@export var size := Vector2.ONE
@export var text := "Button"

var shader: ShaderMaterial
var held := false

func _ready() -> void:
	var collision_shape := $Collision as CollisionShape3D
	collision_shape.shape = collision_shape.shape.duplicate(true) as BoxShape3D
	var collision := collision_shape.shape as BoxShape3D
	collision.size.x = size.x
	collision.size.y = size.y
	
	var back_panel := $BackPanel as MeshInstance3D
	back_panel.mesh = back_panel.mesh.duplicate(true) as QuadMesh
	var mesh := back_panel.mesh as QuadMesh
	mesh.size.x = size.x
	mesh.size.y = size.y
	shader = mesh.material as ShaderMaterial
	
	var text_mesh := $Text as MeshInstance3D
	text_mesh.mesh = text_mesh.mesh.duplicate(true) as TextMesh
	(text_mesh.mesh as TextMesh).text = text

func ui_raycast_hit_event(_pos: Vector3, click: bool, release: bool) -> void:
	if click:
		if not held:
			pressed.emit()
		held = true
	elif release and held:
		released.emit()
		held = false
	shader.set_shader_parameter("highlight", 1.0 + float(held))

func ui_raycast_exit() -> void:
	held = false
	shader.set_shader_parameter("highlight", 0.0)
