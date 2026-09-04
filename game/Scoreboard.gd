extends Node

signal score_changed()
signal points_awarded(position: Vector3, amount: String)
signal energy_changed(value: float)
signal level_failed()

const STARTING_ENERGY := 0.5
const GOOD_NOTE_ENERGY := 0.01
const CHAIN_LINK_ENERGY := 0.002
const MISS_ENERGY := -0.1
const BAD_CUT_ENERGY := -0.1
const WALL_DRAIN_PER_SECOND := 0.13

var points: int
var combo: int
var multiplier: int
var right_notes: float
var wrong_notes: float
var full_combo: bool
var paused: bool
var energy: float = STARTING_ENERGY

var _failure_emitted := false

func restart() -> void:
	points = 0
	multiplier = 1
	combo = 0
	right_notes = 0.0
	wrong_notes = 0.0
	full_combo = true
	energy = STARTING_ENERGY
	_failure_emitted = false
	score_changed.emit()
	energy_changed.emit(energy)

func reset_combo(deduct_energy: bool = true) -> void:
	multiplier = 1
	combo = 0
	wrong_notes += 1.0
	full_combo = false
	score_changed.emit()
	if deduct_energy:
		_change_energy(MISS_ENERGY)

func add_points(position: Vector3, amount: int, energy_gain: float = GOOD_NOTE_ENERGY) -> void:
	combo += 1
	@warning_ignore("integer_division")
	multiplier = 1 + mini(combo / 10, 7)
	points += amount * multiplier
	
	points_awarded.emit(position, str(amount))
	score_changed.emit()
	# track accuracy percent
	var normalized_points := clampf(float(points)/80.0, 0.0, 1.0);
	right_notes += normalized_points
	wrong_notes += 1.0-normalized_points
	_change_energy(energy_gain)

func chain_link_cut(position: Vector3) -> void:
	add_points(position, 20, CHAIN_LINK_ENERGY)

func note_cut(position: Vector3, beat_accuracy: float, cut_angle_accuracy: float, cut_distance_accuracy: float, travel_distance_factor: float) -> void:# point computation based on the accuracy of the swing
	var points_new := 0.0
	points_new += beat_accuracy * 50.0
	points_new += cut_angle_accuracy * 50.0
	points_new += cut_distance_accuracy * 50.0
	points_new += points_new * travel_distance_factor
	
	points_new = roundf(points_new)
	add_points(position, int(points_new))

func bad_cut(position: Vector3) -> void:
	reset_combo(false)
	_change_energy(BAD_CUT_ENERGY)
	points_awarded.emit(position, "x")

func drain(delta: float) -> void:
	_change_energy(-WALL_DRAIN_PER_SECOND * maxf(delta, 0.0))

func _change_energy(amount: float) -> void:
	var previous_energy: float = energy
	energy = clampf(energy + amount, 0.0, 1.0)
	if not is_equal_approx(energy, previous_energy):
		energy_changed.emit(energy)
	if (
		previous_energy > 0.0
		and energy <= 0.0
		and not Settings.no_fail
		and not _failure_emitted
	):
		_failure_emitted = true
		level_failed.emit()
