# This script contains the button logic for the controller
extends XRController3D
class_name BeepSaberController


var ax := false
var ax_last_frame := false
var by := false
var by_last_frame := false
var trigger := false
var trigger_last_frame := false


# Sets up everything as it is expected by the helper scripts in the vr singleton
func _enter_tree() -> void:
	if (!vr):
		vr.log_error(" in OQ_ARVRController._enter_tree(): no vr singleton")
		return
	if (tracker == "left_hand"):
		if (vr.leftController != null):
			vr.log_warning(" in OQ_ARVRController._enter_tree(): left controller already set; overwriting it")
		vr.leftController = self
	elif (tracker == "right_hand"):
		if (vr.rightController != null):
			vr.log_warning(" in OQ_ARVRController._enter_tree(): right controller already set; overwriting it")
		vr.rightController = self
	else:
		vr.log_error(" in OQ_ARVRController._enter_tree(): unexpected controller id %s" % tracker)

# Reset when we exit the tree
func _exit_tree() -> void:
	if (!vr):
		vr.log_error(" in OQ_ARVRController._exit_tree(): no vr singleton")
		return
	if (tracker == "left_hand"):
		if (vr.leftController != self):
			vr.log_warning(" in OQ_ARVRController._exit_tree(): left controller different")
			return
		vr.leftController = null
	elif (tracker == "right_hand"):
		if (vr.rightController != self):
			vr.log_warning(" in OQ_ARVRController._exit_tree(): right controller different")
			return
		vr.rightController = null
	else:
		vr.log_error(" in OQ_ARVRController._exit_tree(): unexpected controller id %d" % tracker)

func ax_pressed() -> bool:
	return ax

func ax_just_pressed() -> bool:
	return ax and not ax_last_frame

func ax_just_released() -> bool:
	return ax_last_frame and not ax

func by_pressed() -> bool:
	return by

func by_just_pressed() -> bool:
	return by and not by_last_frame

func by_just_released() -> bool:
	return by_last_frame and not by

func trigger_pressed() -> bool:
	return trigger

func trigger_just_pressed() -> bool:
	return trigger and not trigger_last_frame

func trigger_just_released() -> bool:
	return trigger_last_frame and not trigger

func _update_buttons_and_sticks() -> void:
	ax_last_frame = ax
	ax = is_button_pressed(&"ax_button")
	by_last_frame = by
	by = is_button_pressed(&"by_button")
	trigger_last_frame = trigger
	trigger = is_button_pressed(&"trigger")

var _rumble_intensity := 0.0
var _rumble_duration := -128.0 #-1 means deactivated so applications can also set their own rumble

func simple_rumble(intensity: float, duration: float) -> void:
	_rumble_intensity = intensity;
	_rumble_duration = duration;
	trigger_haptic_pulse("haptic", 20, intensity, duration, 0)
	
func is_simple_rumbling() -> bool:
	return _rumble_duration > 0.0
	
func _update_rumble(dt: float) -> void:
	if _rumble_duration < -100: return
	simple_rumble(_rumble_intensity, _rumble_duration)
	_rumble_duration -= dt
	if _rumble_duration <= 0.0:
		_rumble_duration = -128.0
		simple_rumble(0.0, _rumble_duration)

var first_time = true

func _physics_process(dt: float) -> void:
	if get_is_active(): # wait for active controller
		_update_buttons_and_sticks()
		_update_rumble(dt)
		# this avoid getting just_pressed events when a key is pressed and the controller becomes
		# active (like it happens on vr.scene_change!)
		if (first_time):
			_update_buttons_and_sticks()
			first_time = false
