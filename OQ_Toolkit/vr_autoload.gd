# This file needs to be set as AutoLoad script in your Project Settings and called 'vr'
# It contains all the glue code and helper functions to make individual features work together.
extends Node

const UI_PIXELS_TO_METER := 1.0 / 1024 # defines the (auto) size of UI elements in 3D

var toolkit_version := "0.4.3_dev"

var inVR := false
var active_arvr_interface_name := "Unknown"

# we use this to be position indepented of the OQ_Toolkit directory
# so make sure to always use this if instancing nodes/features via code
@onready var oq_base_dir: String = (get_script() as Script).get_path().get_base_dir()

###############################################################################
# VR logging systems
###############################################################################

enum VRLogType {
	INFO,
	WARNING,
	ERROR
}

class VRLogEntry:
	var type: VRLogType
	var message: String
	var times_repeated: int
	
	@warning_ignore("shadowed_variable")
	static func from(type: VRLogType, message: String, times_repeated: int) -> VRLogEntry:
		var entry := VRLogEntry.new()
		entry.type = type
		entry.message = message
		entry.times_repeated = times_repeated
		return entry

var _log_buffer: Array[VRLogEntry] = []
var _log_buffer_index := -1
var _log_buffer_count := 0

func _init_vr_log() -> void:
	for _i in range(1024):
		_log_buffer.append(VRLogEntry.from(VRLogType.INFO, "", 0))

func _append_to_log(type: VRLogType, message: String) -> void:
	if (_log_buffer.size() == 0): _init_vr_log()
	
	if _log_buffer_index >= 0 && _log_buffer[_log_buffer_index].message == message:
		_log_buffer[_log_buffer_index].times_repeated += 1
	else:
		_log_buffer_index = (_log_buffer_index+1) % _log_buffer.size()
		_log_buffer[_log_buffer_index].type = type
		_log_buffer[_log_buffer_index].message = message
		_log_buffer[_log_buffer_index].times_repeated = 1
		_log_buffer_count = min(_log_buffer_count+1, _log_buffer.size())

func log_info(s: String) -> void:
	_append_to_log(VRLogType.INFO, s);
	print(s);

func log_warning(s: String) -> void:
	_append_to_log(VRLogType.WARNING, s);
	print("WARNING: ", s);

func log_error(s: String) -> void:
	_append_to_log(VRLogType.ERROR, s);
	print("ERROR: : ", s);

func log_file_error(error: Error, filename: String, where: String) -> void:
	var message := "[color=red]Uh oh, you messed up[/color] [rainbow]real bad![/rainbow]\nError with file [color=cyan][url]%s[/url][/color] in [color=yellow]%s[/color]:\n[color=magenta]" % [filename, where]
	match error:
		ERR_FILE_ALREADY_IN_USE:
			message += "File already in use"
		ERR_FILE_BAD_DRIVE:
			message += "Bad drive"
		ERR_FILE_BAD_PATH:
			message += "Bad path"
		ERR_FILE_CANT_OPEN:
			message += "Can't open"
		ERR_FILE_CANT_READ:
			message += "Can't read"
		ERR_FILE_CANT_WRITE:
			message += "Can't write"
		ERR_FILE_CORRUPT:
			message += "File is corrupt"
		ERR_FILE_NOT_FOUND:
			message += "File not found"
		ERR_FILE_NO_PERMISSION:
			message += "No permission"
		_:
			message += "Turbo-screwed! Unrecognized error code %s" % error
	message += "[/color]"
	_append_to_log(VRLogType.ERROR, message)
	print_rich(message)


# returns the current player height based on the difference between
# the height of origin and camera; this assumes that tracking is floor level
func get_current_player_height() -> float:
	return vrCamera.global_transform.origin.y - vrOrigin.global_transform.origin.y;

###############################################################################
# Some generic useful helper functions
###############################################################################


# helper function to read and parse a JSON file and return the contents as a dictionary
# Note: if you want to use it with .json files that are part of your project you 
#       need to make sure they are exported by including *.json in the 
#       ExportSettings->Resources->Filters options
# TODO: Dictionary keys and values are currently only weak typed.
# if it's possible to make them strong-typed in the future, do that.
func load_json_file(filename: String) -> Dictionary:
	var save := FileAccess.open(filename, FileAccess.READ)
	if save:
		var parsed_result: Variant = JSON.parse_string(save.get_as_text())
		save.close()
		if parsed_result is Dictionary:
			return parsed_result as Dictionary
		else:
			log_error("Failed to parse JSON as Dictionary from file: " + filename)
			return {}
	else:
		log_file_error(FileAccess.get_open_error(), filename, "load_json_file in vr_autoload.gd")
		return {}

###############################################################################
# Controller Handling
###############################################################################

# Global accessors to the tracked vr objects; they will be set by the scripts attached
# to the OQ_ objects
var leftController: BeepSaberController
var rightController: BeepSaberController
var vrOrigin: XROrigin3D
var vrCamera: XRCamera3D

# these two variable point to leftController/rightController
# and are swapped when calling
var dominantController: XRController3D = rightController
var nonDominantController: XRController3D = leftController

func set_dominant_controller_left(is_left_handed: bool) -> void:
	if (is_left_handed):
		dominantController = leftController
		nonDominantController = rightController
	else:
		dominantController = rightController
		nonDominantController = leftController
		
func is_dominant_controller_left() -> bool:
	return dominantController == leftController

###############################################################################
# Global defines used across the toolkit
###############################################################################

var _need_settings_refresh := false

func _notification(what: int) -> void:
	if (what == NOTIFICATION_APPLICATION_RESUMED):
		_need_settings_refresh = true

###############################################################################
# Scene Switching Helper Logic
###############################################################################

# Removed unused variable _active_scene_path

###############################################################################
# Main Funcitonality for initialize and process
###############################################################################

var webxr_initializer: CanvasLayer
var xr_interface: XRInterface

## True once the native visionOS (CompositorServices) interface owns presentation.
## The OpenXR path below is untouched on every other platform.
var is_native_visionos := false

func initialize(origin: XROrigin3D, camera: XRCamera3D, left_hand: BeepSaberController, right_hand: BeepSaberController,
	render_scale: float = 1.0) -> void:
	_init_vr_log()
	
	vrOrigin = origin
	vrCamera = camera
	leftController = left_hand
	rightController = right_hand
	
	if OS.get_name() == "Web":
		var webxr := (load("res://game/scripts/webxr/webxr_initializer.tscn") as PackedScene).instantiate() as CanvasLayer
		add_child(webxr)
		webxr_initializer = webxr
		return
	
	if VisionOSPlatform.is_native_platform():
		_initialize_native_visionos(render_scale)
		return
	
	xr_interface = XRServer.find_interface("OpenXR") as XRInterface
	if xr_interface: xr_interface.render_target_size_multiplier = render_scale
	if xr_interface and xr_interface.is_initialized():
		log_info("OpenXR initialised successfully")
		active_arvr_interface_name = "OpenXR"
		if xr_interface.has_method(&"get_available_display_refresh_rates"):
			var fps: Array = xr_interface.get_available_display_refresh_rates()
			log_info("avaliable fps: "+str(fps))
			if fps and fps.size() >= 1:
				var max_fps: Variant = fps[fps.size() - 1]
				if max_fps is float:
					xr_interface.set_display_refresh_rate(max_fps)
				elif max_fps is int:
					xr_interface.set_display_refresh_rate(float(max_fps))
					Engine.set_physics_ticks_per_second(max_fps as int)
		
		# Turn off v-sync!
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		
		# Change our main viewport to output to the HMD
		get_viewport().use_xr = true
		inVR = true
	else:
		log_info("OpenXR not initialized, please check if your headset is connected")
		inVR = false


## Native visionOS startup. CompositorServices owns presentation, so this only
## initialises the interface once and hands the root viewport to it.
func _initialize_native_visionos(render_scale: float) -> void:
	var interface := XRServer.find_interface(VisionOSPlatform.INTERFACE_NAME) as XRInterface
	if interface == null:
		log_error("visionOS XR interface not found. The build is missing the native XR module.")
		inVR = false
		return
	
	if not interface.is_initialized() and not interface.initialize():
		log_error("visionOS XR interface failed to initialize; rendering would have no presenter.")
		inVR = false
		return
	
	xr_interface = interface
	_apply_visionos_render_quality(interface, render_scale)
	is_native_visionos = true
	active_arvr_interface_name = VisionOSPlatform.INTERFACE_NAME
	
	var viewport := get_viewport()
	_apply_visionos_msaa(viewport)
	viewport.use_xr = true
	viewport.vrs_mode = Viewport.VRS_XR
	viewport.use_hdr_2d = true
	inVR = true
	
	apply_camera_near_plane()
	apply_upper_limb_visibility()
	log_info("visionOS XR interface initialised successfully")


## Drops MSAA where the GPU cannot support multisampled array textures, which is
## the shape stereo XR rendering requires. Hardware keeps the configured level.
##
## Must run before `use_xr` is enabled: setting MSAA on a viewport that is
## already driving the compositor leaves the live render target multisampled,
## so the gate would appear not to work at all. Logs the adapter and the
## resulting level unconditionally, so the outcome can be read back rather than
## assumed.
func _apply_visionos_msaa(viewport: Viewport) -> void:
	var adapter := RenderingServer.get_video_adapter_name()
	var resolved := VisionOSPlatform.resolve_msaa_3d(int(viewport.msaa_3d), adapter)
	if resolved != int(viewport.msaa_3d):
		viewport.msaa_3d = resolved as Viewport.MSAA
	log_info("visionOS GPU '%s': 3D MSAA resolved to %d." % [adapter, int(viewport.msaa_3d)])


## Keeps the compositor's real-hand overlay consistent with whatever is currently
## driving the sabers. Safe to call on any platform and at any time.
func apply_upper_limb_visibility() -> void:
	if not is_native_visionos or xr_interface == null:
		return
	var left_source := VisionOSPlatform.InputSource.NONE
	if leftController != null:
		left_source = leftController.input_source
	var right_source := VisionOSPlatform.InputSource.NONE
	if rightController != null:
		right_source = rightController.input_source
	xr_interface.set(
		&"upper_limb_visibility",
		int(VisionOSPlatform.resolve_upper_limb_visibility(left_source, right_source))
	)


## Display refresh rate in Hz, or 0.0 when the platform cannot report one.
##
## `get_display_refresh_rate()` is an OpenXR-only method. Calling it on
## `VisionOSXRInterface` raises a GDScript error that aborts the caller, so this
## probes for the method and falls back to the native display server, which
## reports the headset's true 90 Hz instead of leaving physics at the 60 Hz default.
func get_display_refresh_rate() -> float:
	var interface := XRServer.primary_interface
	if interface != null and interface.has_method(&"get_display_refresh_rate"):
		return float(interface.get_display_refresh_rate())
	if is_native_visionos:
		return maxf(DisplayServer.screen_get_refresh_rate(), 0.0)
	return 0.0


## Size of the XR compositor's render target, or zero when it is not published
## yet. visionOS only fills this in during its first `pre_render()`, so callers
## that need a real framebuffer must wait for it.
func get_xr_render_target_size() -> Vector2:
	if not is_instance_valid(xr_interface):
		return Vector2.ZERO
	return xr_interface.get_render_target_size()


## Waits until the compositor publishes a usable render target.
##
## Creating pipelines before this point builds them against a zero-sized
## framebuffer: every `framebuffer_create` and pipeline creation fails, so a
## shader warm-up run that early is silently thrown away and the shaders end up
## compiling mid-song instead.
func await_xr_render_target(tree: SceneTree) -> bool:
	if not is_native_visionos:
		return true
	for frame in VisionOSPlatform.MAX_POSE_WAIT_FRAMES:
		if VisionOSPlatform.is_render_target_ready(get_xr_render_target_size()):
			log_info("visionOS render target ready after %d frames at %v" % [
				frame, get_xr_render_target_size()])
			return true
		await tree.process_frame
	log_warning("visionOS render target never became valid; shader warm-up may be ineffective")
	return false


## Applies the requested render scale using the native interface's own property.
##
## `render_target_size_multiplier` does not exist on `VisionOSXRInterface`, and
## assigning it aborts this whole function, which silently leaves the root
## viewport without an XR target and renders a black scene.
func _apply_visionos_render_quality(interface: XRInterface, render_scale: float) -> void:
	var quality := VisionOSPlatform.resolve_render_quality(
		render_scale,
		bool(ProjectSettings.get_setting(VisionOSPlatform.DYNAMIC_RENDER_QUALITY_ENABLED_SETTING, false)),
		float(ProjectSettings.get_setting(VisionOSPlatform.DYNAMIC_RENDER_QUALITY_MAX_SETTING, 1.0))
	)
	if quality == VisionOSPlatform.SKIP_RENDER_QUALITY:
		return
	interface.set(&"current_render_quality", quality)


## Keeps the tracked camera's near plane at or above the platform's physical
## minimum. Safe to call again after a scene load, recenter or world scale change.
func apply_camera_near_plane() -> void:
	if not is_native_visionos or vrCamera == null:
		return
	vrCamera.near = VisionOSPlatform.near_plane_for_world_scale(XRServer.world_scale, vrCamera.near)
