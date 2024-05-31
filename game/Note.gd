extends Node3D
class_name Note

# strucutre of information sourced from the map file for this note instance
# https://bsmg.wiki/mapping/map-format.html#notes-2
var _note
var collision_disabled := false

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
