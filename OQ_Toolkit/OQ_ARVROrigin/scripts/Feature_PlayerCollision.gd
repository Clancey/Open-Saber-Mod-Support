extends CharacterBody3D

@export var enabled := true;
@export var debug_information := false;
@export var capsule_radius := 0.15;

@export var step_offset := 0.0;

@onready var collision_object = $CollisionShape3D;

func _ready():
	if (not get_parent() is XROrigin3D):
		vr.log_error("Feature_StickMovement: parent is not XROrigin3D");
		
	_update_collsion_shape_start_position();


func _show_debug_information():
	var slide_count = get_slide_collision_count();
	var on_floor = 1 if is_on_floor() else 0;
	var on_wall = 1 if is_on_wall() else 0;
	
	
	var colliders = "";
	for c in range(0, slide_count):
		colliders += get_slide_collision(c).collider.name + ",";
	
	
	vr.show_dbg_info("Feature_PlayerCollision", "Slide Count: %d; on floor: %d; on wall: %d; last update: %d;\n         Colliders: %s" % [slide_count, on_floor, on_wall, vr.frame_counter, colliders]);


func _update_collsion_shape_start_position():
	var player_height = vr.get_current_player_height();
	collision_object.shape.radius = capsule_radius;
	collision_object.shape.height = player_height - 2.0 * capsule_radius - step_offset;
	global_transform.origin = vr.vrCamera.global_transform.origin;
	global_transform.origin.y -= (player_height-step_offset) * 0.5;
	
	

func oq_locomotion_stick_check_move(velocity, dt):
	if (!enabled): return velocity;

	_update_collsion_shape_start_position();

	set_velocity(velocity)
	set_up_direction(Vector3(0.0, 1.0, 0.0))
	move_and_slide()
	velocity = velocity;
	
	if (debug_information):
		_show_debug_information();
	
	return velocity;
