extends Cuttable
class_name Bomb

@export var min_speed := 0.5
@onready var collision_shape := $Area3D/CollisionShape3D as CollisionShape3D

func _ready() -> void:
	var anim := $AnimationPlayer as AnimationPlayer
	# play the spawn animation when this bomb enters the scene
	anim.speed_scale = maxf(min_speed,speed)
	anim.play(&"Spawn")

func set_collision_disabled(value: bool) -> void:
	collision_shape.disabled = value

func cut(saber_type: int, cut_speed: Vector3, cut_plane: Plane, controller: BeepSaberController) -> void:
	Scoreboard.bad_cut(transform.origin)
	queue_free()

func on_miss() -> void:
	queue_free()

const CUBE_DISTANCE := 0.5
const CUBE_HEIGHT_OFFSET := 0.4
func spawn(info: Map.BombInfo, current_beat: float) -> void:
	beat = info.beat
	var line: float = -(CUBE_DISTANCE * 3.0 / 2.0) + info.line_index * CUBE_DISTANCE
	var layer: float = CUBE_DISTANCE + info.line_layer * CUBE_DISTANCE
	
	var distance: float = info.beat - current_beat
	
	transform.origin = Vector3(
		line,
		CUBE_HEIGHT_OFFSET + layer,
		-distance * BeepSaber_Game.beat_distance)
