extends Node3D
class_name Cuttable

# strucutre of information sourced from the map file for this note instance
# https://bsmg.wiki/mapping/map-format.html#notes-2
var beat: float

# the note's velocity toward the player
# currently set to _noteJumpMovementSpeed / 9.0 in main game. I'm not sure what
# the 9.0 is for...
# units: meters / second
var speed := 1.0

# overridden by bombs and cubes
func set_collision_disabled(value: bool) -> void:
	return

# also overriden by bombs and cubes
func cut(saber_type: int, cut_speed: Vector3, cut_plane: Plane, controller: BeepSaberController) -> void:
	return

# this too
func on_miss() -> void:
	return

func _physics_process(delta: float) -> void:
	if Scoreboard.paused or not is_visible_in_tree() or not Map.current_info: return
	var speed := Vector3(0.0, 0.0, Constants.BEAT_DISTANCE * Map.current_info.beats_per_minute / 60.0) * delta
	translate(speed)
	
	var depth := 0.5
	# enable bomb/cube collision when it gets closer enough to player
	if global_transform.origin.z > -3.0:
		set_collision_disabled(false)
	
	# remove children that go to far
	if ((global_transform.origin.z - depth) > 2.0):
		on_miss()
