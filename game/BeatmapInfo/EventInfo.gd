extends RefCounted
class_name EventInfo

const TYPE_DIAGONAL_LASERS: = 0
const TYPE_SQUARE_LASERS: = 1
const TYPE_LEFT_WAVING_LASERS: = 2
const TYPE_RIGHT_WAVING_LASERS: = 3
const TYPE_FLOOR_LIGHTS: = 4
const TYPE_COLOR_BOOST: = 5
const TYPE_RING_SPIN: = 8
const TYPE_RING_ZOOM: = 9
const TYPE_LEFT_LASER_SPEED: = 12
const TYPE_RIGHT_LASER_SPEED: = 13

const VALUE_LIGHTS_OFF: = 0
const VALUE_LIGHTS_RIGHT_ON: = 1
const VALUE_LIGHTS_RIGHT_FLASH: = 2
const VALUE_LIGHTS_RIGHT_FADE: = 3
const VALUE_LIGHTS_FADE_TO_RIGHT: = 4
const VALUE_LIGHTS_LEFT_ON: = 5
const VALUE_LIGHTS_LEFT_FLASH: = 6
const VALUE_LIGHTS_LEFT_FADE: = 7
const VALUE_LIGHTS_FADE_TO_LEFT: = 8
const VALUE_LIGHTS_WHITE_ON: = 9
const VALUE_LIGHTS_WHITE_FLASH: = 10
const VALUE_LIGHTS_WHITE_FADE: = 11
const VALUE_LIGHTS_FADE_TO_WHITE: = 12

var beat: float
var type: int
var value: int
var float_value: float
var color: Array[float] = []  # Array of floats [r, g, b] for Chroma colors
var lightID: Array[int] = []  # Array of ints for Chroma light IDs
var custom_data: Dictionary

@warning_ignore("shadowed_variable")
func _init(beat: float, type: int, value: int, float_value: float, custom_data: Dictionary, is_v3: bool = false) -> void :
	self.beat = beat
	self.type = type
	self.value = value
	self.float_value = float_value
	self.custom_data = custom_data

	# Parse Chroma custom data
	var color_key: String = "color" if is_v3 else "_color"
	if custom_data.has(color_key):
		var color_data: Variant = custom_data[color_key]
		if color_data is Array:
			# Convert to typed array
			for component in color_data:
				if component is float or component is int:
					self.color.append(float(component))

	var light_id_key: String = "lightID" if is_v3 else "_lightID"
	if custom_data.has(light_id_key):
		var id_data: Variant = custom_data[light_id_key]
		if id_data is float or id_data is int:
			self.lightID = [int(id_data)]
		elif id_data is Array:
			# Convert to typed array
			for id in id_data:
				if id is float or id is int:
					self.lightID.append(int(id))

static func new_v2(event_dict: Dictionary) -> EventInfo:
	return EventInfo.new(
		Utils.get_float(event_dict, "_time", 0.0),
		int(Utils.get_float(event_dict, "_type", 0)),
		int(Utils.get_float(event_dict, "_value", 0)),
		Utils.get_float(event_dict, "_floatValue", -1.0),
		Utils.get_dict(event_dict, "_customData", {})
	)

static func new_v3(event_dict: Dictionary) -> EventInfo:
	return EventInfo.new(
		Utils.get_float(event_dict, "b", 0.0),
		int(Utils.get_float(event_dict, "et", 0)),
		int(Utils.get_float(event_dict, "i", 0)),
		Utils.get_float(event_dict, "f", -1.0),
		Utils.get_dict(event_dict, "customData", {}),
		true
	)
