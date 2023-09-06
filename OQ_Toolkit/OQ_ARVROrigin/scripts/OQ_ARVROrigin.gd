extends XROrigin3D

@export var debug_information := false;

var is_fixed = false;

# Sets up everything as it is expected by the helper scripts in the vr singleton
func _enter_tree():
	if (!vr):
		vr.log_error("in OQ_ARVROrigin._enter_tree(): no vr singleton");
		return;
	if (vr.vrOrigin != null):
		vr.log_warning("in OQ_ARVROrigin._enter_tree(): origin already set; overwrting it");
	vr.vrOrigin = self;
	
	if vr.xr_interface:
		vr.xr_interface.connect("pose_recentered", pose_recentered)


func _exit_tree():
	if (!vr):
		vr.log_error("in OQ_ARVROrigin._exit_tree(): no vr singleton");
		return;
	if (vr.vrOrigin != null && vr.vrOrigin != self): # not sure why it can be null here on exit...
		vr.log_error("in OQ_ARVROrigin._exit_tree(): different vrOrigin");
		return;
	vr.vrOrigin = null;

func _show_debug_information():
	var vro = global_transform.origin;
	vr.show_dbg_info(name, "world_pos=(%.2f, %.2f, %.2f)" %
	[vro.x, vro.y, vro.z]);

func _process(_dt):
	if (debug_information): _show_debug_information();

func pose_recentered():
	print("recenter triggered")
	if vr.vrCamera:
		rotation_degrees.y = -vr.vrCamera.rotation_degrees.y
		global_position = (global_position - vr.vrCamera.global_position) * Vector3(1, 0, 1) + Vector3(0, 0, 1)
