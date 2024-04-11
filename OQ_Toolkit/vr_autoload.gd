# This file needs to be set as AutoLoad script in your Project Settings and called 'vr'
# It contains all the glue code and helper functions to make individual features work together.
extends Node

const UI_PIXELS_TO_METER = 1.0 / 1024; # defines the (auto) size of UI elements in 3D

var toolkit_version = "0.4.3_dev"

var inVR = false;
var active_arvr_interface_name = "Unknown";

# we use this to be position indepented of the OQ_Toolkit directory
# so make sure to always use this if instancing nodes/features via code
@onready var oq_base_dir = self.get_script().get_path().get_base_dir();

# a global counter for frames; incremented in the process of vr
# usefule for remembering time-stamps when sth. happened
var frame_counter := 0;

var physics_frame_counter := 0;

###############################################################################
# VR logging systems
###############################################################################

var _log_buffer = [];
var _log_buffer_index = -1;
var _log_buffer_count = 0;

func _init_vr_log():
	for _i in range(1024):
		_log_buffer.append([0, "", 0]);
		
func _append_to_log(type, message):
	if (_log_buffer.size() == 0): _init_vr_log();
	
	if _log_buffer_index >= 0 && _log_buffer[_log_buffer_index][1] == message:
		_log_buffer[_log_buffer_index][2] += 1;
	else:
		_log_buffer_index = (_log_buffer_index+1) % _log_buffer.size();
		_log_buffer[_log_buffer_index][0] = type;
		_log_buffer[_log_buffer_index][1] = message;
		_log_buffer[_log_buffer_index][2] = 1;
		_log_buffer_count = min(_log_buffer_count+1, _log_buffer.size());

func log_info(s):
	_append_to_log(0, s);
	print(s);

func log_warning(s):
	_append_to_log(1, s);
	print("WARNING: ", s);

func log_error(s):
	_append_to_log(2, s);
	print("ERROR: : ", s);
	
	
var _label_scene = null;
var _dbg_labels = {};


func _reorder_dbg_labels():
	# reorder all available labels
	var offset = 0.0;
	for labels in _dbg_labels.values():
		labels.position = Vector3(0.2, 0.25 - offset, -0.75);
		offset += 0.08;

# this funciton attaches a UI label to the camera to show debug information
func show_dbg_info(key, value):
	if (!_dbg_labels.has(key)):
		# we could not preload the scene as it depends on the vr. singleton which
		# somehow prevented parsing...
		if (_label_scene == null): _label_scene = load(oq_base_dir + "/OQ_UI2D/OQ_UI2DLabel.tscn");
		var l = _label_scene.instantiate();
		l.depth_test = false;
		_dbg_labels[key] = l;
		vrCamera.add_child(l);
		_reorder_dbg_labels();
	_dbg_labels[key].set_label_text(key + ": " + str(value));
	
func remove_dbg_info(key):
	if (!_dbg_labels.has(key)): return;
	vrCamera.remove_child(_dbg_labels[key]);
	_dbg_labels[key].queue_free();
	_dbg_labels.erase(key);
	_reorder_dbg_labels();


var _notification_scene = null;

func show_notification(title, text = ""):
	if (_notification_scene == null): _notification_scene = load(oq_base_dir + "/OQ_UI2D/OQ_UI2DNotificationWindow.tscn");
	var nw = _notification_scene.instantiate();
	
	nw.set_notificaiton_text(title, text);

	if (scene_switch_root):
		scene_switch_root.add_child(nw);
	else:
		vr.vrOrigin.get_parent().add_child(nw);
	var pos = vr.vrCamera.global_transform.origin - vr.vrCamera.global_transform.basis.z;
	
	nw.look_at_from_position(pos, vr.vrCamera.global_transform.origin, Vector3(0,1,0));

# returns the current player height based on the difference between
# the height of origin and camera; this assumes that tracking is floor level
func get_current_player_height():
	return vrCamera.global_transform.origin.y - vrOrigin.global_transform.origin.y;

###############################################################################
# Some generic useful helper functions
###############################################################################

func randomArrayElement(rng, array):
	return array[rng.randi_range(0, array.size()-1)];


# helper function to read and parse a JSON file and return the contents as a dictionary
# Note: if you want to use it with .json files that are part of your project you 
#       need to make sure they are exported by including *.json in the 
#       ExportSettings->Resources->Filters options
func load_json_file(filename) -> Dictionary:
	var save = FileAccess.open(filename, FileAccess.READ);
	if save:
		var r = JSON.parse_string(save.get_as_text())
		save.close();
		return r;
	else:
		#vr.log_error("Could not load_json_file from " + filename);
		return {}

###############################################################################
# Controller Handling
###############################################################################

# Global accessors to the tracked vr objects; they will be set by the scripts attached
# to the OQ_ objects
var leftController : OQ_ARVRController = null;
var rightController : OQ_ARVRController = null;
var vrOrigin : XROrigin3D = null;
var vrCamera : XRCamera3D = null;

# these two variable point to leftController/rightController
# and are swapped when calling
var dominantController : XRController3D = rightController;
var nonDominantController : XRController3D = leftController;

func set_dominant_controller_left(is_left_handed):
	if (is_left_handed):
		dominantController = leftController;
		nonDominantController = rightController;
	else:
		dominantController = rightController;
		nonDominantController = leftController;
		
func is_dominant_controller_left():
	return dominantController == leftController;
	

enum VR_CONTROLLER_TYPE {
	OCULUS_TOUCH,
	WEBXR
}

enum AXIS {
	None = -1,
	
	LEFT_JOYSTICK_X = 0,
	LEFT_JOYSTICK_Y = 1,
	LEFT_INDEX_TRIGGER = 2,
	LEFT_GRIP_TRIGGER = 3,
	
	RIGHT_JOYSTICK_X = 0 + 16,
	RIGHT_JOYSTICK_Y = 1 + 16,
	RIGHT_INDEX_TRIGGER = 2 + 16,
	RIGHT_GRIP_TRIGGER = 3 + 16,
}

enum CONTROLLER_AXIS {
	None = -1,
	
	JOYSTICK_X = 0,
	JOYSTICK_Y = 1,
	INDEX_TRIGGER = 2,
	GRIP_TRIGGER = 3,
}

# the individual buttons directly identified left or right controller
enum BUTTON {
	None = -1,

	Y = 1,
	LEFT_GRIP_TRIGGER = 2, # grip trigger pressed over threshold
	ENTER = 3, # Menu Button on left controller

	TOUCH_X = 5,
	TOUCH_Y = 6,
	X = 7,

	LEFT_TOUCH_THUMB_UP = 10,
	LEFT_TOUCH_INDEX_TRIGGER = 11,
	LEFT_TOUCH_INDEX_POINTING = 12,

	LEFT_THUMBSTICK = 14, # left/right thumb stick pressed
	LEFT_INDEX_TRIGGER = 15, # index trigger pressed over threshold
	
	B = 1 + 16,
	RIGHT_GRIP_TRIGGER = 2 + 16, # grip trigger pressed over threshold
	TOUCH_A = 5 + 16,
	TOUCH_B = 6 + 16,
	A = 7 + 16,
	
	RIGHT_TOUCH_THUMB_UP = 10 + 16,
	RIGHT_TOUCH_INDEX_TRIGGER = 11 + 16,
	RIGHT_TOUCH_INDEX_POINTING = 12 + 16,

	RIGHT_THUMBSTICK = 14 + 16, # left/right thumb stick pressed
	RIGHT_INDEX_TRIGGER = 15 + 16, # index trigger pressed over threshold
}


# Button list mapping to both controllers (needed for actions assigned to specific controllers instead of global)
enum CONTROLLER_BUTTON {
	None = -1,

	YB = 1,
	GRIP_TRIGGER = 2, # grip trigger pressed over threshold
	ENTER = 3, # Menu Button on left controller

	TOUCH_XA = 5,
	TOUCH_YB = 6,
	XA = 7,

	TOUCH_THUMB_UP = 10,
	TOUCH_INDEX_TRIGGER = 11,
	TOUCH_INDEX_POINTING = 12,

	THUMBSTICK = 14, # left/right thumb stick pressed
	INDEX_TRIGGER = 15, # index trigger pressed over threshold
}


###############################################################################
# Global defines used across the toolkit
###############################################################################

enum GrabTypes {
	KINEMATIC,
	VELOCITY,
	HINGEJOINT,
}


enum LocomotionStickTurnType {
	CLICK,
	SMOOTH
}


var _need_settings_refresh = false;


func _notification(what):
	if (what == NOTIFICATION_APPLICATION_PAUSED):
		pass;
	if (what == NOTIFICATION_APPLICATION_RESUMED):
		_need_settings_refresh = true;
		pass;


###############################################################################
# Scene Switching Helper Logic
###############################################################################

var _active_scene_path = null; # this assumes that only a single scene will ever be switched
var scene_switch_root = null;

# helper function to switch different scenes; this will be in the
# future extend to allow for some transtioning to happen as well as maybe some shader caching
func _perform_switch_scene(scene_path):
	print("_perform_switch_scene to " + scene_path);
	
	if scene_switch_root != null:
		for s in scene_switch_root.get_children():
			if (s.has_method("scene_exit")): s.scene_exit();
			scene_switch_root.remove_child(s);
			s.queue_free();
			_dbg_labels.clear(); # make sure to also clear the debug label dictionary as they might be created in the scene above

		var next_scene_resource = load(scene_path);
		if (next_scene_resource):
			_active_scene_path = scene_path;
			var next_scene = next_scene_resource.instantiate();
			log_info("    switching to scene '%s'" % scene_path)
			scene_switch_root.add_child(next_scene);
			if (next_scene.has_method("scene_enter")): next_scene.scene_enter();
		else:
			log_error("could not load scene '%s'" % scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)
	


var _target_scene_path = null;
var _scene_switch_fade_out_duration := 0.0;
var _scene_switch_fade_out_time := 0.0;
var _scene_switch_fade_in_duration := 0.0;
var _scene_switch_fade_in_time := 0.0;
var _switch_performed := false;

var switch_scene_in_progress := false;

func switch_scene(scene_path, fade_time = 0.1, wait_time = 0.0):
	if (wait_time > 0.0 && _active_scene_path != null):
		await get_tree().create_timer(wait_time).timeout

	if (scene_switch_root == null):
		log_error("vr.switch_scene(...) called but no scene_switch_root configured. Will use default scene change.");
	if (_active_scene_path == scene_path): return;

	if (fade_time <= 0.0):
		_perform_switch_scene(scene_path);
		return;
	_target_scene_path = scene_path;
	
	_scene_switch_fade_out_duration = fade_time;
	_scene_switch_fade_in_duration = fade_time;
	_scene_switch_fade_out_time = 0.0;
	_scene_switch_fade_in_time = 0.0;
	_switch_performed = false;
	

func _check_for_scene_switch_and_fade(dt):
	# first fade out before switch
	switch_scene_in_progress = false;
	if (_target_scene_path != null && !_switch_performed):
		if (_scene_switch_fade_out_time < _scene_switch_fade_out_duration):
			var c = 1.0 - min(1.0, _scene_switch_fade_out_time / (_scene_switch_fade_out_duration*0.9));
			_scene_switch_fade_out_time += dt;
			switch_scene_in_progress = true;
		else:
			_perform_switch_scene(_target_scene_path);
			_switch_performed = true;
			switch_scene_in_progress = true;
	elif (_target_scene_path != null && _switch_performed):
		if (_scene_switch_fade_in_time < _scene_switch_fade_in_duration):
			var c = _scene_switch_fade_in_time / _scene_switch_fade_in_duration;
			_scene_switch_fade_in_time += dt;
			switch_scene_in_progress = true;
		else:
			_target_scene_path = null;


###############################################################################
# Main Funcitonality for initialize and process
###############################################################################

func _ready():
	pass;
	
func _physics_process(_dt):
	physics_frame_counter += 1;
	
func _process(dt):
	frame_counter += 1;
	
	_check_for_scene_switch_and_fade(dt);


# webxr callback
func _webxr_cb_session_supported(a, b):
	log_info("WebXR session is supported: " + str(a) + ", " + str(b));
	pass

func _webxr_cb_session_started():
	get_viewport().use_xr = true
	log_info("WebXR Session Started; reference space type: " + arvr_webxr_interface.reference_space_type);

signal signal_webxr_started;

func _webxr_initialize(enable_vr):
	if (!enable_vr):
		inVR = false;
		log_info("  WebXR starting only in simulator mode.");
		emit_signal("signal_webxr_started");
		return;
		
	if (arvr_webxr_interface.initialize()):
		get_viewport().use_xr = true;
		#DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if (false;) else DisplayServer.VSYNC_DISABLED)
		inVR = true;
		log_info("  Success initializing WebXR Interface.");
		emit_signal("signal_webxr_started")
	else:
		OS.alert("Failed to initialize WebXR Interface")
		inVR = false;
		emit_signal("signal_webxr_started");
		
# create two buttons and connect them to _webxr_initialize; this is required
# for WebXR because initializing it on webpage load might fail
func _webxr_create_entervr_buttons():
	var enter_vr_button = Button.new();
	var simulate_vr_button = Button.new();
	
	# the info label here is only for info during dev right now; it will be replaced
	# in the future by something more generic
	var info_label = Label.new();
	info_label.text = "Godot Oculus Quest Toolkit Demo\n  " + toolkit_version + "\n";
	
	enter_vr_button.text = "Enter VR";
	simulate_vr_button.text = "Simulator Only"

	var vbox = VBoxContainer.new();
	vbox.add_child(info_label);
	vbox.add_child(enter_vr_button);
	vbox.add_child(simulate_vr_button);
	var centercontainer = CenterContainer.new();
	centercontainer.theme = load("res://OQ_Toolkit/OQ_UI2D/theme/oq_ui2d_standard.theme")
	centercontainer.size = get_window().get_size_with_decorations();
	centercontainer.add_child(vbox);
	get_tree().get_current_scene().add_child(centercontainer);

	enter_vr_button.connect("pressed", Callable(self, "_webxr_initialize").bind(true));
	simulate_vr_button.connect("pressed", Callable(self, "_webxr_initialize").bind(false));

var arvr_ovr_mobile_interface = null;
var arvr_oculus_interface = null;
var arvr_open_vr_interface = null;
var arvr_webxr_interface = null;
var arvr_openxr_interface = null;

var webxr_initializer
var xr_interface: XRInterface

func initialize(render_scale = 1.0):
	_init_vr_log();
	
	if OS.get_name() == "Web":
		var webxr = load("res://game/scripts/webxr/webxr_initializer.tscn").instantiate()
		add_child(webxr)
		webxr_initializer = webxr
		return
	
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface: xr_interface.render_target_size_multiplier = render_scale
	if xr_interface and xr_interface.is_initialized():
		log_info("OpenXR initialised successfully")
		var fps = xr_interface.get_available_display_refresh_rates()
		log_info("avaliable fps: "+str(fps))
		if fps.size() >= 1:
			xr_interface.set_display_refresh_rate(fps[fps.size()-1])

		# Turn off v-sync!
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

		# Change our main viewport to output to the HMD
		get_viewport().use_xr = true
		inVR = true;
	else:
		log_info("OpenXR not initialized, please check if your headset is connected")
		inVR = false;
		return false

