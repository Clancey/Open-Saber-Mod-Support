extends "res://tests/test_case.gd"


func test_single_sample_offset_and_conversion() -> void:
	var clock := ClockSync.new()
	assert_false(clock.is_synced(), "No samples means not synced")
	# Ping left at 1000, host answered at 50000 on its clock, pong arrived at 1100.
	clock.add_sample(1000, 50000, 1100)
	assert_true(clock.is_synced(), "One sample is enough to be synced")
	assert_eq(clock.rtt_ms(), 100, "Round trip")
	assert_eq(clock.offset_ms(), 48950, "offset = t_host + rtt/2 - t_recv")
	assert_eq(clock.host_from_local(1100), 50050, "Local to host time")
	assert_eq(clock.local_from_host(50050), 1100, "Host to local time")
	assert_eq(clock.local_from_host(clock.host_from_local(123456)), 123456, "Round trip conversion")


func test_lowest_rtt_sample_wins() -> void:
	var clock := ClockSync.new()
	clock.add_sample(0, 10000, 300)      # rtt 300, offset 9850
	clock.add_sample(1000, 11020, 1040)  # rtt 40, offset 10000
	clock.add_sample(2000, 12200, 2200)  # rtt 200, offset 10100
	assert_eq(clock.rtt_ms(), 40, "Best sample RTT")
	assert_eq(clock.offset_ms(), 10000, "Offset from the lowest RTT sample")
	assert_eq(clock.sample_count(), 3)


func test_sample_window_is_bounded() -> void:
	var clock := ClockSync.new()
	clock.add_sample(0, 5000, 2)  # rtt 2, will fall out of the window
	for i: int in range(ClockSync.MAX_SAMPLES + 3):
		var t_send := 1000 + i * 100
		clock.add_sample(t_send, t_send + 5000 + 50, t_send + 100)
	assert_eq(clock.sample_count(), ClockSync.MAX_SAMPLES, "Window size")
	assert_eq(clock.rtt_ms(), 100, "The early low-RTT sample was dropped")
	assert_eq(clock.offset_ms(), 5000, "Offset from the remaining samples")


func test_start_time_arrives_lead_ahead_on_both_clocks() -> void:
	var clock := ClockSync.new()
	clock.add_sample(500, 70000, 560)  # client clock is ~69470 behind the host
	var host_now := 70030
	var start_at_host := host_now + 3000
	var local_now := clock.local_from_host(host_now)
	var local_start := clock.local_from_host(start_at_host)
	assert_eq(local_start - local_now, 3000, "Lead time survives the conversion")


func test_lobby_code_validation() -> void:
	assert_true(WebRtcSignaling.is_valid_code("AB27"), "Letters and digits 2-9")
	assert_false(WebRtcSignaling.is_valid_code("AB01"), "0 and 1 are not in the alphabet")
	assert_false(WebRtcSignaling.is_valid_code("abcd"), "Lower case is rejected")
	assert_false(WebRtcSignaling.is_valid_code("ABCDE"), "Wrong length")
	assert_false(WebRtcSignaling.is_valid_code(""), "Empty")
	for _i: int in range(20):
		assert_true(WebRtcSignaling.is_valid_code(WebRtcSignaling.generate_code()), "Generated codes are valid")
