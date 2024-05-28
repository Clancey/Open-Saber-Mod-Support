extends Node3D
class_name UIRaycast

@export var active := true
@export var ui_raycast_length := 3.0
@export var ui_mesh_length := 1.0

var controller: BeepSaberController = null
@onready var ui_raycast := $RayCastPosition/RayCast3D as RayCast3D
@onready var ui_raycast_mesh := $RayCastPosition/RayCastMesh as MeshInstance3D
@onready var ui_raycast_hitmarker := $RayCastPosition/RayCastHitMarker as MeshInstance3D

const hand_click_button := vr.CONTROLLER_BUTTON.XA;

var is_colliding := false;
var colliding_with: Object = null


func _update_raycasts() -> void:
	ui_raycast_hitmarker.visible = false
	
	ui_raycast_mesh.visible = true
	
	ui_raycast.force_raycast_update() # need to update here to get the current position; else the marker laggs behind
	
	var c := ui_raycast.get_collider()
	if c != colliding_with and colliding_with != null and colliding_with is UIRaycastTarget:
		(colliding_with as UIRaycastTarget).ui_raycast_exit()
	colliding_with = c
	if c:
		if (!c is UIRaycastTarget): return
		
		var click := controller.trigger_just_pressed()
		var release := controller.trigger_just_released()
		
		var position := ui_raycast.get_collision_point()
		ui_raycast_hitmarker.visible = true
		ui_raycast_hitmarker.global_transform.origin = position
		
		(c as UIRaycastTarget).ui_raycast_hit_event(position, click, release)
		is_colliding = true
	else:
		is_colliding = false

func _ready() -> void:
	var parent := get_parent()
	if (not parent is BeepSaberController):
		vr.log_error(" in Feature_UIRayCast: parent not XRController3D.")
	controller = parent as BeepSaberController
	
	ui_raycast.set_target_position(Vector3(0, 0, -ui_raycast_length))
	
	#setup the mesh
	(ui_raycast_mesh.mesh as BoxMesh).size.z = ui_mesh_length
	ui_raycast_mesh.position.z = -ui_mesh_length * 0.5
	
	ui_raycast_hitmarker.visible = false
	ui_raycast_mesh.visible = false

# we use the physics process here be in sync with the controller position
func _physics_process(_dt: float) -> void:
	if (!active): return
	if (!visible): return
	_update_raycasts()
