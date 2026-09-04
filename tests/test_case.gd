extends RefCounted

const FLOAT_TOLERANCE := 0.0001

var failures: Array[String] = []


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	var equal: bool = actual == expected
	if (actual is float or expected is float) and (actual is int or actual is float) and (expected is int or expected is float):
		equal = absf(float(actual) - float(expected)) <= FLOAT_TOLERANCE
	if equal:
		return

	var detail: String = "Expected %s, got %s" % [str(expected), str(actual)]
	failures.append("%s: %s" % [message, detail] if not message.is_empty() else detail)


func assert_true(value: bool, message: String = "") -> void:
	if value:
		return
	failures.append(message if not message.is_empty() else "Expected true, got false")


func assert_false(value: bool, msg: String = "") -> void:
	if not value:
		return
	failures.append(msg if not msg.is_empty() else "Expected false, got true")
