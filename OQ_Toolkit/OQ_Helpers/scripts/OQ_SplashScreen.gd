extends Node3D

var currentPosition: Vector3
var movePosition: Vector3
var targetPosition: Vector3
var distance :=  3.0
var time_to_move := 0.5

@onready var camera := $XROrigin3D/XRCamera3D as Node3D
@onready var splash_screen := $SplashScreen as Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var viewDir := -camera.global_transform.basis.z
	var camPos := -camera.global_transform.origin
	currentPosition = camPos + viewDir * distance
	targetPosition = currentPosition
	movePosition = currentPosition
	
	splash_screen.look_at_from_position(currentPosition, camPos, Vector3(0,1,0))
	
	($SplashScreen/DebugLabel as Node3D).visible = OS.is_debug_build()

var moving := false
var moveTimer := 0.0

func _process(dt: float) -> void:
	var viewDir := -camera.global_transform.basis.z
	viewDir.y = 0.0
	viewDir = viewDir.normalized()
	
	var camPos := camera.global_transform.origin
	
	#TODO: rotate instead of move
	targetPosition = camPos + viewDir * distance
	var distToTarget := (targetPosition - currentPosition).length()
	if moving:
		currentPosition = currentPosition + (movePosition - currentPosition) * dt
		if (distToTarget < 0.05):
			moving = false
	
	if (distToTarget > 0.5):
		moveTimer += dt
	else:
		moveTimer = 0.0
	
	if (moveTimer > time_to_move):
		moving = true
		movePosition = targetPosition
	
	splash_screen.look_at_from_position(currentPosition, camPos, Vector3(0,1,0))
