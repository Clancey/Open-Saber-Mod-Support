extends "res://tests/test_case.gd"


func test_get_color_supports_v3_v2_and_default() -> void:
	var default: Color = Color(0.2, 0.3, 0.4, 0.6)

	assert_eq(Utils.get_color({"color": [1, 0, 0]}, default), Color(1, 0, 0), "V3 color")
	assert_eq(
		Utils.get_color({"_color": [0, 1, 0, 0.5]}, default).a,
		0.5,
		"V2 color alpha"
	)
	assert_eq(Utils.get_color({"color": "bad"}, default), default, "Invalid color should use default")
