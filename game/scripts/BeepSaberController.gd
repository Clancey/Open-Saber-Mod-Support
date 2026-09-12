# This script contains the button logic for the controller
extends XRController3D
class_name BeepSaberController


var ax := false
var ax_last_frame := false
var by := false
var by_last_frame := false
var menu := false
var menu_last_frame := false
var trigger := false
var trigger_last_frame := false

var movement_aabb := AABB()

## Which physical source is currently driving this hand. Only meaningful on the
## native visionOS backend, where optical hand tracking and real spatial
## accessories both publish onto the reserved `left_hand`/`right_hand` trackers.
var input_source: VisionOSPlatform.InputSource = VisionOSPlatform.InputSource.NONE

var _is_native_visionos := false

func _ready() -> void:
	_is_native_visionos = VisionOSPlatform.is_native_platform()

## True when this hand is driven by ARKit optical joints rather than a real
## accessory. Optical hands have no face buttons, thumbstick or haptics.
func is_optical_hand() -> bool:
	return input_source == VisionOSPlatform.InputSource.OPTICAL_HAND

## Haptics need a real accessory; firing them at an optical hand only produces
## engine errors.
func supports_haptics() -> bool:
	return not _is_native_visionos or input_source == VisionOSPlatform.InputSource.SPATIAL_CONTROLLER

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

func menu_pressed() -> bool:
	return menu

func menu_just_pressed() -> bool:
	return menu and not menu_last_frame

func trigger_pressed() -> bool:
	return trigger

func trigger_just_pressed() -> bool:
	return trigger and not trigger_last_frame

func trigger_just_released() -> bool:
	return trigger_last_frame and not trigger

func _update_buttons_and_sticks() -> void:
	ax_last_frame = ax
	by_last_frame = by
	menu_last_frame = menu
	trigger_last_frame = trigger
	ax = is_button_pressed(&"ax_button")
	by = is_button_pressed(&"by_button")
	menu = is_button_pressed(&"menu_button")
	trigger = is_button_pressed(&"trigger")
	if is_optical_hand():
		# An optical hand only publishes pinch (trigger) and grasp (grip). Grasp
		# is the single owner of the menu action there, so pausing stays reachable
		# without an accessory.
		menu = menu or is_button_pressed(&"grip_click")

func _clear_button_state() -> void:
	ax = false
	ax_last_frame = false
	by = false
	by_last_frame = false
	menu = false
	menu_last_frame = false
	trigger = false
	trigger_last_frame = false

## Re-resolves which source drives this hand. A change is an input state
## transition: everything held on the old source is dropped and neutral input is
## required before the new source can trigger an action.
func _update_input_source() -> void:
	if not _is_native_visionos:
		return
	var resolved := VisionOSPlatform.resolve_input_source(tracker)
	if resolved == input_source:
		return
	input_source = resolved
	_clear_button_state()
	first_time = true
	vr.apply_upper_limb_visibility()

func _update_movement_aabb() -> void:
	movement_aabb = movement_aabb.expand(global_transform.origin)

func reset_movement_aabb() -> void:
	movement_aabb = AABB(global_transform.origin, Vector3.ZERO)

var _is_simple_rumbling := false
var _rumble_duration_remaining := 0.0

func simple_rumble(intensity: float, duration: float) -> void:
	_rumble_duration_remaining = duration;
	_is_simple_rumbling = true
	if not supports_haptics():
		return
	trigger_haptic_pulse("haptic", 20, intensity, duration, 0)
	
func is_simple_rumbling() -> bool:
	return _is_simple_rumbling
	
func _update_rumble(dt: float) -> void:
	if _rumble_duration_remaining > 0.0:
		_rumble_duration_remaining -= dt
	if _rumble_duration_remaining <= 0.0:
		_rumble_duration_remaining = 0.0
		_is_simple_rumbling = false

var first_time := true

func _physics_process(dt: float) -> void:
	if not Scoreboard.paused:
		_update_movement_aabb()
	
	_update_input_source()
	
	if get_is_active(): # wait for active controller
		_update_rumble(dt)
		_update_buttons_and_sticks()
		# this avoid getting just_pressed events when a key is pressed and the controller becomes
		# active (like it happens on vr.scene_change!)
		if first_time:
			_update_buttons_and_sticks()
			first_time = false
	else:
		first_time = true
		_clear_button_state()
