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

## A tracked head sits well above the floor. visionOS reports an identity head
## pose for the first frames after startup, where OpenXR already has a real one.
## Recentering against that identity pose leaves the rig about a metre out of
## place, which makes world-anchored menus unreachable or clipped.
const MIN_VALID_HEAD_HEIGHT_M := 0.5

## Upper bound on the wait so a genuinely untracked session still starts.
const MAX_POSE_WAIT_FRAMES := 120

## Smallest render target dimension treated as a real compositor target.
const MIN_RENDER_TARGET_PX := 1.0

## Frames to hold the shader warm-up scene on screen.
const DEFAULT_WARMUP_FRAMES := 3
const VISIONOS_WARMUP_FRAMES := 12

## The visionOS simulator runs on a paravirtual GPU that reports itself as
## Apple2 and cannot allocate `MTLTextureType2DMultisampleArray` outside
## memoryless storage. Stereo XR rendering with MSAA needs exactly that texture
## type, so Metal rejects the framebuffer and the app dies mid-render. Hardware
## has no such limit, so MSAA is only dropped where it cannot work.
const MSAA_DISABLED := 0

## visionOS publishes its hand aim pose with the blade axis flipped relative to
## the OpenXR aim pose the saber model is authored against, so the blade extends
## backwards down the forearm instead of forwards out of the fist. Correct the
## model alignment rather than the aim, and do it through the existing
## per-platform saber offset so the wearer can still tune it in Settings.
const SABER_ROT_CORRECTION_DEG := Vector3(180.0, 0.0, 0.0)


## Default rotation offset for a saber on the current platform.
static func default_saber_offset_rot() -> Vector3:
	return SABER_ROT_CORRECTION_DEG if is_native_platform() else Vector3.ZERO

## Returned by `resolve_render_quality()` to mean "leave the compositor's own
## render quality alone".
const SKIP_RENDER_QUALITY := -1.0

## Project settings the native compositor reads for dynamic render quality.
const DYNAMIC_RENDER_QUALITY_ENABLED_SETTING := "xr/visionos/dynamic_render_quality/enable"
const DYNAMIC_RENDER_QUALITY_MAX_SETTING := "xr/visionos/dynamic_render_quality/maximum_quality"

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

## Mirrors VisionOSXRInterface.Visibility. The compositor draws the wearer's real
## hands over the scene by default, which reads as a glitch next to a held saber,
## so the port hides them and lets the saber represent the hand.
enum Visibility {
	AUTOMATIC = 0,
	VISIBLE = 1,
	HIDDEN = 2,
}

enum InputSource {
	NONE, ## No usable tracking for this hand.
	OPTICAL_HAND, ## ARKit hand skeleton mirrored onto the controller tracker.
	SPATIAL_CONTROLLER, ## A real tracked accessory.
}


static func is_native_platform() -> bool:
	return OS.get_name() == PLATFORM_NAME


## True once the headset reports a head pose that can be recentered against.
static func is_head_pose_valid(head_height_m: float) -> bool:
	return head_height_m > MIN_VALID_HEAD_HEIGHT_M


## The compositor only publishes the XR render target size after its first frame,
## so `get_render_target_size()` reads back zero until then. Building the shader
## warm-up pipelines against that zero-sized target makes every framebuffer and
## pipeline creation fail, which silently wastes the warm-up and pushes shader
## compilation into gameplay as hitching.
static func is_render_target_ready(render_target_size: Vector2) -> bool:
	return render_target_size.x >= MIN_RENDER_TARGET_PX \
		and render_target_size.y >= MIN_RENDER_TARGET_PX


## How many frames to keep the warm-up scene visible. visionOS compiles Metal
## pipelines lazily, so it needs more than the handful the other backends use.
static func warmup_frames(native_visionos: bool) -> int:
	return VISIONOS_WARMUP_FRAMES if native_visionos else DEFAULT_WARMUP_FRAMES


## Detects the visionOS simulator from the Metal adapter name, which reads
## `Apple xrOS simulator GPU (Apple2)` there and names real silicon on device.
static func is_simulator_adapter(adapter_name: String) -> bool:
	return adapter_name.to_lower().contains("simulator")


## Resolves the 3D MSAA level to use, dropping it only on the simulator's
## paravirtual GPU, which cannot allocate multisampled array textures.
static func resolve_msaa_3d(configured_msaa: int, adapter_name: String) -> int:
	if is_simulator_adapter(adapter_name):
		return MSAA_DISABLED
	return configured_msaa


## Resolves the render quality to hand to the native interface, or
## `SKIP_RENDER_QUALITY` when it must be left untouched.
##
## visionOS has no `render_target_size_multiplier`; that property is OpenXR-only,
## and assigning it to a `VisionOSXRInterface` raises a GDScript error that aborts
## initialisation. The native equivalent is `current_render_quality`, whose setter
## additionally hard-fails unless dynamic render quality is enabled in project
## settings, so the scale is only applied when the project opted in.
static func resolve_render_quality(render_scale: float, dynamic_enabled: bool, max_quality: float) -> float:
	if not dynamic_enabled:
		return SKIP_RENDER_QUALITY
	if not is_finite(render_scale) or render_scale <= 0.0:
		return SKIP_RENDER_QUALITY
	if not is_finite(max_quality) or max_quality <= 0.0:
		return SKIP_RENDER_QUALITY
	return minf(render_scale, max_quality)


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


## Whether the compositor should keep drawing the wearer's real hands.
##
## Under optical tracking the hand *is* the input device, so hiding it would
## leave a saber floating off an invisible hand. A real accessory already fills
## the hand, and the composited hand around it reads as a glitch, so it is hidden
## as soon as either hand picks up a controller.
static func resolve_upper_limb_visibility(left: InputSource, right: InputSource) -> Visibility:
	if left == InputSource.SPATIAL_CONTROLLER or right == InputSource.SPATIAL_CONTROLLER:
		return Visibility.HIDDEN
	return Visibility.VISIBLE


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
