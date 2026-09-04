extends "res://tests/test_case.gd"

var _failure_count := 0

func test_energy_clamps_at_both_ends() -> void:
	var previous_no_fail: bool = Settings.no_fail
	Settings.no_fail = true
	Scoreboard.restart()
	for _index: int in range(100):
		Scoreboard.add_points(Vector3.ZERO, 80)
	assert_eq(Scoreboard.energy, 1.0, "Energy should clamp at one")
	Scoreboard.drain(100.0)
	assert_eq(Scoreboard.energy, 0.0, "Energy should clamp at zero")
	Settings.no_fail = previous_no_fail

func test_failure_emits_once_and_respects_no_fail() -> void:
	var previous_no_fail: bool = Settings.no_fail
	var failure_callback: Callable = Callable(self, "_on_level_failed")
	if not Scoreboard.level_failed.is_connected(failure_callback):
		Scoreboard.level_failed.connect(failure_callback)

	_failure_count = 0
	Settings.no_fail = false
	Scoreboard.restart()
	Scoreboard.drain(10.0)
	Scoreboard.drain(10.0)
	assert_eq(_failure_count, 1, "Failure should emit exactly once")

	_failure_count = 0
	Settings.no_fail = true
	Scoreboard.restart()
	Scoreboard.drain(10.0)
	Scoreboard.drain(10.0)
	assert_eq(_failure_count, 0, "No Fail should suppress failure")

	Settings.no_fail = previous_no_fail

func test_good_cuts_add_energy() -> void:
	Scoreboard.restart()
	for _index: int in range(10):
		Scoreboard.add_points(Vector3.ZERO, 80)
	assert_eq(Scoreboard.energy, 0.6, "Ten good cuts should add 0.1 energy")

func test_miss_deducts_energy() -> void:
	Scoreboard.restart()
	Scoreboard.reset_combo()
	assert_eq(Scoreboard.energy, 0.4, "A miss should deduct 0.1 energy")

func test_restart_sets_half_energy() -> void:
	Scoreboard.restart()
	assert_eq(Scoreboard.energy, 0.5, "Restart should set half energy")

func _on_level_failed() -> void:
	_failure_count += 1
