extends RefCounted
class_name ClockSync

# NTP-style clock offset estimation between this peer and the lobby host.
# Each sample is one ping/pong round trip:
#   t_send  local time (ms) when the ping left
#   t_host  host time (ms) when the host answered
#   t_recv  local time (ms) when the pong arrived
# host_time ~= local_time + offset. The sample with the shortest round trip
# is the least distorted by queueing, so its offset wins (classic NTP filter),
# and we keep a bounded window so a later, better sample can replace it.

const MAX_SAMPLES := 16

var _samples: Array[Dictionary] = []


func clear() -> void:
	_samples.clear()


func add_sample(t_send: int, t_host: int, t_recv: int) -> void:
	var rtt: int = maxi(t_recv - t_send, 0)
	@warning_ignore("integer_division")
	var offset: int = t_host + rtt / 2 - t_recv
	_samples.append({"rtt": rtt, "offset": offset})
	while _samples.size() > MAX_SAMPLES:
		_samples.pop_front()


func sample_count() -> int:
	return _samples.size()


func is_synced() -> bool:
	return not _samples.is_empty()


## Best-known offset in ms: host_time = local_time + offset.
func offset_ms() -> int:
	var best: Dictionary = _best_sample()
	return int(best.get("offset", 0))


## Round trip time of the best sample in ms.
func rtt_ms() -> int:
	var best: Dictionary = _best_sample()
	return int(best.get("rtt", 0))


func host_from_local(local_ms: int) -> int:
	return local_ms + offset_ms()


func local_from_host(host_ms: int) -> int:
	return host_ms - offset_ms()


func _best_sample() -> Dictionary:
	var best: Dictionary = {}
	for sample: Dictionary in _samples:
		if best.is_empty() or int(sample["rtt"]) < int(best["rtt"]):
			best = sample
	return best
