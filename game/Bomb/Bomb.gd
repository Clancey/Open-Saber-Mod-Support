extends Note
class_name Bomb

@export var min_speed := 0.5
@onready var collision_shape := $Area3D/CollisionShape3D as CollisionShape3D

func _ready() -> void:
	var anim := $AnimationPlayer as AnimationPlayer
	# play the spawn animation when this bomb enters the scene
	anim.speed_scale = maxf(min_speed,speed)
	anim.play(&"Spawn")

func set_collision_disabled(value: bool) -> void:
	collision_disabled = value
	collision_shape.disabled = value

func cut(saber_type: int, cut_speed: Vector3, cut_plane: Plane, controller: BeepSaberController) -> void:
	Scoreboard.reset_combo()
	Scoreboard.points_awarded.emit(transform.origin, "x")
	queue_free()
