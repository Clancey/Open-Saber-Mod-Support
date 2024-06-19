extends Cuttable
class_name Bomb

@export var min_speed := 0.5
@onready var collision_shape := $Area3D/CollisionShape3D as CollisionShape3D

func set_collision_disabled(value: bool) -> void:
	collision_shape.disabled = value

func cut(saber_type: int, cut_speed: Vector3, cut_plane: Plane, controller: BeepSaberController) -> void:
	Scoreboard.bad_cut(transform.origin)
	queue_free()

func on_miss() -> void:
	queue_free()

func spawn(info: Map.BombInfo, current_beat: float) -> void:
	beat = info.beat
	var line: float = -(Constants.CUBE_DISTANCE * 3.0 / 2.0) + info.line_index * Constants.CUBE_DISTANCE
	var layer: float = Constants.CUBE_DISTANCE + info.line_layer * Constants.CUBE_DISTANCE
	
	var distance: float = info.beat - current_beat
	
	transform.origin = Vector3(
		line,
		Constants.CUBE_HEIGHT_OFFSET + layer,
		-distance * Constants.BEAT_DISTANCE
	)
	
	var anim := $AnimationPlayer as AnimationPlayer
	anim.speed_scale = maxf(min_speed, speed)
	anim.play(&"Spawn")
