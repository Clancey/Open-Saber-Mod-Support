extends RefCounted
class_name BpmChangeInfo

var beat: float
var bpm: float

@warning_ignore("shadowed_variable")
func _init(beat: float, bpm: float) -> void:
	self.beat = beat
	self.bpm = bpm

static func new_v2(data: Dictionary) -> BpmChangeInfo:
	return BpmChangeInfo.new(
		Utils.get_float(data, "_time", 0.0),
		Utils.get_float(data, "_BPM", 120.0)
	)

static func new_v3(data: Dictionary) -> BpmChangeInfo:
	return BpmChangeInfo.new(
		Utils.get_float(data, "b", 0.0),
		Utils.get_float(data, "m", 120.0)
	)
