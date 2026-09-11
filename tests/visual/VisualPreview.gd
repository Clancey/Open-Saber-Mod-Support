extends Node3D
# Renders the gameplay objects (notes, bomb, wall, sabers) in a fixed layout
# and saves a screenshot, so their look can be checked without a headset.
#
# Godot --path . --xr-mode off --resolution 1280x720 tests/visual/VisualPreview.tscn -- --out=C:/tmp/preview.png

const NOTE_SCENE: PackedScene = preload("res://game/BeepCube/BeepCube.tscn")
const BOMB_SCENE: PackedScene = preload("res://game/Bomb/Bomb.tscn")
const WALL_SCENE: PackedScene = preload("res://game/Wall/Wall.tscn")
const SABER_SCENE: PackedScene = preload("res://game/sabers/default/default_saber.tscn")
const ENVIRONMENT_SCENE: PackedScene = preload("res://game/event_driver.tscn")
const CHAIN_LINK_SCENE: PackedScene = preload("res://game/Chain/ChainLink.tscn")

const LEFT_COLOR := Color(0.7843, 0.0784, 0.0784)
const RIGHT_COLOR := Color(0.1569, 0.5569, 0.8235)
const OBSTACLE_COLOR := Color(1.0, 0.1882, 0.1882)

var _output_path := "user://visual_preview.png"
var _frames := 0
var _sabers: Array[DefaultSaber] = []
var _time := 0.0

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_output_path = arg.trim_prefix("--out=")
	_build_scene()

func _debug_environment(environment: EventDriver) -> void:
	for type in range(5):
		var holder: Node3D = environment._get_light_holder(type)
		var batch := holder.get_node_or_null("LightBatch") as MultiMeshInstance3D
		var count: int = batch.multimesh.instance_count if (batch != null and batch.multimesh != null) else -1
		var first := ""
		if count > 0:
			first = str(batch.multimesh.get_instance_transform(0).origin) + " " + str(batch.multimesh.get_instance_custom_data(0))
		print("ENVDEBUG|type=%d holder_visible=%s batch_visible=%s instances=%d lights=%d lit=%s first=%s" % [type, holder.visible, batch.visible if batch else false, count, environment.light_manager._get_type_lights(type).size(), environment.light_manager.has_visible_lights(type), first])
	for child: Node in environment.get_node("Level").get_children():
		if child is DirectionalLight3D:
			print("ENVDEBUG|light %s energy=%.2f color=%s" % [child.name, (child as DirectionalLight3D).light_energy, (child as DirectionalLight3D).light_color])

func _build_scene() -> void:
	if OS.has_environment("PREVIEW_ENV"):
		# the full "The First" environment with all lights on, seen from the player's place
		var environment_scene: PackedScene = ENVIRONMENT_SCENE
		if OS.has_environment("PREVIEW_ENV_SCENE"):
			environment_scene = load(OS.get_environment("PREVIEW_ENV_SCENE")) as PackedScene
		var environment := environment_scene.instantiate() as EventDriver
		add_child(environment)
		environment.call_deferred("set_all_on", LEFT_COLOR, RIGHT_COLOR)
		if OS.has_environment("PREVIEW_DEBUG"):
			call_deferred("_debug_environment", environment)
		($Floor as MeshInstance3D).visible = false
		($Camera3D as Camera3D).position = Vector3(0.0, 1.7, 1.0)
		($Sun as DirectionalLight3D).visible = false
		($Fill as DirectionalLight3D).visible = false
		for hidden_name: String in OS.get_environment("PREVIEW_HIDE").split(",", false):
			var hidden: Node = environment.get_node_or_null("Level/" + hidden_name)
			if hidden is Node3D:
				(hidden as Node3D).visible = false
		if OS.has_environment("PREVIEW_CAMERA_UP"):
			($Camera3D as Camera3D).position = Vector3(0.0, 40.0, 30.0)
			($Camera3D as Camera3D).rotation_degrees = Vector3(-40.0, 0.0, 0.0)
		if OS.get_environment("PREVIEW_ENV") == "only":
			return
	# notes: one per cut direction, two colors, a dot note and a bomb
	var directions := [0, 1, 2, 3, 4, 5, 6, 7, 8]
	for i in range(directions.size()):
		var note := NOTE_SCENE.instantiate() as BeepCube
		add_child(note)
		var color := LEFT_COLOR if i % 2 == 0 else RIGHT_COLOR
		note.position = Vector3(-2.4 + i * 0.6, 1.4, -2.6)
		note.rotation.z = Constants.CUBE_ROTATIONS[directions[i]]
		note.is_dot = directions[i] == 8
		note.call_deferred("_preview_setup", color)
	# a chain: head note plus three links
	for i in range(3):
		var link := CHAIN_LINK_SCENE.instantiate() as ChainLink
		add_child(link)
		link.position = Vector3(-2.4, 0.95 - i * 0.16, -2.6)
		link.call_deferred("_preview_setup", RIGHT_COLOR)
	var bomb := BOMB_SCENE.instantiate() as Bomb
	add_child(bomb)
	bomb.position = Vector3(3.0, 1.4, -2.6)
	# wall: 1 lane wide, full height, 4 m long on the right
	var wall := WALL_SCENE.instantiate() as Wall
	add_child(wall)
	wall.position = Vector3(1.5, 0.1, -3.5)
	wall.call_deferred("_preview_setup", Vector3(0.6 * 0.98, 3.0, 4.0), OBSTACLE_COLOR)
	# sabers held in front of the camera
	for i in range(2):
		var saber := SABER_SCENE.instantiate() as DefaultSaber
		add_child(saber)
		saber.position = Vector3(-0.45 + i * 0.9, 0.9, -0.8)
		saber.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
		saber.call_deferred("set_color", LEFT_COLOR if i == 0 else RIGHT_COLOR)
		_sabers.append(saber)

func _process(delta: float) -> void:
	_frames += 1
	_time += delta
	if _frames == 5:
		for saber: DefaultSaber in _sabers:
			saber._show()
			saber.set_trail(not OS.has_environment("PREVIEW_TRAIL_OFF"))
	# swing the sabers between 0.4 s and 1.0 s so the trails show up
	if _time > 0.4 and _time < 1.0:
		var t := (_time - 0.4) / 0.6
		for i in range(_sabers.size()):
			var saber: DefaultSaber = _sabers[i]
			var side := 1.0 if i == 0 else -1.0
			saber.position.x = (-0.45 + i * 0.9) + sin(t * PI) * 0.45 * side
			saber.rotation_degrees.z = side * (t - 0.5) * 70.0
	if _time >= 1.05:
		var image: Image = get_viewport().get_texture().get_image()
		var error: Error = image.save_png(_output_path)
		print("VISUAL|saved=%s|error=%d|frames=%d" % [_output_path, error, _frames])
		get_tree().quit()
