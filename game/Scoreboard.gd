extends Node

signal score_changed()
signal points_awarded(position: Vector3, amount: String)

var points: int
var combo: int
var multiplier: int
var right_notes: float
var wrong_notes: float
var full_combo: bool

func restart() -> void:
	points = 0
	multiplier = 1
	combo = 0
	right_notes = 0.0
	wrong_notes = 0.0
	full_combo = true
	score_changed.emit()

func reset_combo() -> void:
	multiplier = 1
	combo = 0
	wrong_notes += 1.0
	full_combo = false
	score_changed.emit()

func update_points_from_cut(position: Vector3, beat_accuracy: float, cut_angle_accuracy: float, cut_distance_accuracy: float, travel_distance_factor: float) -> void:
	combo += 1
	multiplier = 1 + roundi(mini((combo / 10), 7))
	
	# point computation based on the accuracy of the swing
	var points_new := 0.0
	points_new += beat_accuracy * 50.0
	points_new += cut_angle_accuracy * 50.0
	points_new += cut_distance_accuracy * 50.0
	points_new += points_new * travel_distance_factor
	
	points_new = roundf(points_new)
	points += int(points_new) * multiplier
	
	points_awarded.emit(position, str(points_new))
	score_changed.emit()
	# track acurracy percent
	var normalized_points := clampf(points/80, 0.0, 1.0);
	right_notes += normalized_points
	wrong_notes += 1.0-normalized_points
