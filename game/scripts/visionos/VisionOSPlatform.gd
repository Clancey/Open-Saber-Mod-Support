## Adapter for the native visionOS XR backend (CompositorServices + Metal + ARKit).
##
## This is deliberately a thin, side-effect-free-where-possible helper so the pure
## decisions (input source classification, near plane, immersion mapping) can be
## unit tested on a headless host without an XR runtime.
##
## It never touches the OpenXR path used by Quest, desktop or the Web build.
extends RefCounted
class_name VisionOSPlatform

## `OS.get_name()` and `XRServer.find_interface()` both use this name.
const PLATFORM_NAME := "visionOS"
const INTERFACE_NAME := "visionOS"

## Tracker names populated by the native spatial controller module. Optical hand
## tracking mirrors its gestures onto these same trackers, so the tracker
## existing is not evidence of a physical accessory.
const LEFT_CONTROLLER_TRACKER := &"left_hand"
const RIGHT_CONTROLLER_TRACKER := &"right_hand"

## Tracker profiles the native modules publish.
const ACCESSORY_PROFILE := "visionos_accessory"
const OPTICAL_PROFILE := "visionos_hand_tracking"

## visionOS requires a physical near plane of at least 0.1 m. The extra margin
## matches what the reference ports shipped.
const MIN_PHYSICAL_NEAR_PLANE_M := 0.11

## Prefix applied to settings that must not be shared with the Quest/desktop build.
const SCOPED_KEY_PREFIX := "visionos_"

## Saber offsets are a visual calibration of the held saber model against the
## platform's aim pose, so a value tuned against a Touch controller is meaningless
## against a visionOS aim pose. These keys persist per platform: visionOS starts at
## zero relative to its own already correct alignment instead of inheriting the
## Quest preference, and the Quest value stays saved under its original key.
const PLATFORM_SCOPED_KEYS := [
	"left_saber_offset_pos",
	"left_saber_offset_rot",
	"right_saber_offset_pos",
	"right_saber_offset_rot",
]

## Mirrors VisionOSXRInterface.ImmersionStyle so callers do not depend on the
## native enum being registered on other platforms.
enum ImmersionStyle {
	FULL = 0,
	MIXED = 1,
	PROGRESSIVE = 2,
}

enum InputSource {
	NONE, ## No usable tracking for this hand.
	OPTICAL_HAND, ## ARKit hand skeleton mirrored onto the controller tracker.
	SPATIAL_CONTROLLER, ## A real tracked accessory.
}


static func is_native_platform() -> bool:
	return OS.get_name() == PLATFORM_NAME


## Maps a settings key to the key it is persisted under on the current platform.
##
## Every platform other than visionOS keeps its existing keys untouched, so old
## config files keep loading exactly as before.
static func config_key(key: String) -> String:
	if is_native_platform() and key in PLATFORM_SCOPED_KEYS:
		return SCOPED_KEY_PREFIX + key
	return key


## Classifies a hand from the tracker profile plus live pose validity.
##
## Kept free of XRServer so it can be exercised directly. A profile alone is not
## enough: a stale accessory profile with no valid grip/aim must not be treated
## as a usable physical controller.
static func classify_input_source(
	profile: String,
	has_valid_aim: bool,
	has_valid_grip: bool
) -> InputSource:
	if not has_valid_aim and not has_valid_grip:
		return InputSource.NONE
	match profile:
		ACCESSORY_PROFILE:
			# A real accessory must report both poses before we hand it gameplay.
			return InputSource.SPATIAL_CONTROLLER if (has_valid_aim and has_valid_grip) else InputSource.NONE
		OPTICAL_PROFILE:
			return InputSource.OPTICAL_HAND
		_:
			return InputSource.NONE


## Resolves the live input source for one of the reserved controller trackers.
static func resolve_input_source(tracker_name: StringName) -> InputSource:
	var tracker := XRServer.get_tracker(tracker_name)
	if tracker == null:
		return InputSource.NONE
	return classify_input_source(
		tracker.get_tracker_profile(),
		_is_pose_valid(tracker, &"aim"),
		_is_pose_valid(tracker, &"grip")
	)


static func _is_pose_valid(tracker: XRPositionalTracker, pose_name: StringName) -> bool:
	if not tracker.has_pose(pose_name):
		return false
	var pose := tracker.get_pose(pose_name)
	return pose != null and pose.has_tracking_data


## Near plane that keeps the physical distance at or above the platform minimum.
##
## Never lowers an existing near plane, so a project that already pushes it out
## further keeps its own value.
static func near_plane_for_world_scale(world_scale: float, current_near: float) -> float:
	var minimum := MIN_PHYSICAL_NEAR_PLANE_M * maxf(world_scale, 0.0001)
	return maxf(current_near, minimum)


## True when the style composites the passthrough view of the real room.
static func style_shows_passthrough(style: ImmersionStyle) -> bool:
	return style != ImmersionStyle.FULL


static func style_for_passthrough(passthrough_enabled: bool) -> ImmersionStyle:
	return ImmersionStyle.MIXED if passthrough_enabled else ImmersionStyle.FULL
