extends PooledNode3D
class_name Cuttable

var speed: float
var beat: float
@onready var _collision_shape := find_children("*", "CollisionShape3D", true, false).front() as CollisionShape3D

# used to release the cube once both of it's cut pieces have died off
# Note: serves no purpose for bombs
var _piece_death_count := 0

# overridden by bombs and cubes
@warning_ignore("unused_parameter")
func set_collision_disabled(value: bool) -> void:
	return

# overriden by bombs and cubes
@warning_ignore("unused_parameter")
func cut(saber_type: int, cut_speed: Vector3, cut_plane: Plane, controller: BeepSaberController) -> void:
	return

# this too
func on_miss() -> void:
	return

func _on_cut_piece_died():
	_piece_death_count += 1
	if _piece_death_count >= 2:
		release()

func _physics_process(delta: float) -> void:
	if Scoreboard.paused or not is_visible_in_tree() or not Map.current_info: return
	transform.origin.z += speed * delta
	
	# enable collisions when cuttable gets close enough to player
	if global_transform.origin.z > -3.0 and _collision_shape != null and _collision_shape.disabled:
		set_collision_disabled(false)
	
	# remove children that go to far
	if global_transform.origin.z > Constants.MISS_Z:
		on_miss()
