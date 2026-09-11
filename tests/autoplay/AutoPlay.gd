extends Node

const GAME_SCENE: PackedScene = preload("res://game/BeepSaber_Game.tscn")
const DEFAULT_SONG: String = "res://game/data/maps/Songs/48088 (Golden - sammy & Tonkie)/"
const DEFAULT_OUTPUT: String = "user://autoplay"
const STARTUP_FRAME_COUNT: int = 90
const CENSUS_TIME_SECONDS: float = 6.0
const CENSUS_CATEGORY_LIMIT: int = 25
const SWING_FRAMES: int = 6
const SWING_DISTANCE: float = 0.5
const STRIKE_MIN_Z: float = -1.25
const STRIKE_MAX_Z: float = 0.75

class Swing:
	var cube: BeepCube
	var controller: BeepSaberController
	var direction: Vector3
	var frame: int = 0
	var saber_type: int = 0

	func _init(
		target_cube: BeepCube,
		target_controller: BeepSaberController,
		swing_direction: Vector3,
		target_saber_type: int
	) -> void:
		cube = target_cube
		controller = target_controller
		direction = swing_direction
		saber_type = target_saber_type

var _game: BeepSaber_Game
var _xr_origin: XROrigin3D
var _camera: XRCamera3D
var _left_controller: BeepSaberController
var _right_controller: BeepSaberController
var _song_player: AudioStreamPlayer
var _event_driver: EventDriver
var _light_manager: LightManager

var _song_path: String = DEFAULT_SONG
var _difficulty_query: String = ""
var _output_path: String = DEFAULT_OUTPUT
var _duration_limit: float = -1.0
var _shot_every: float = 0.0
var _bot_enabled: bool = true

var _started: bool = false
var _finishing: bool = false
var _failed: bool = false
var _startup_frame_index: int = -1
var _start_ticks_msec: int = 0
var _last_sample_second: int = -1
var _next_shot_time: float = INF
var _selected_difficulty: DifficultyInfo
var _six_second_census_complete: bool = false

var _samples: Array[Dictionary] = []
var _census_snapshots: Array[Dictionary] = []
var _cube_connected: Dictionary = {}
var _cube_active: Dictionary = {}
var _cube_cut: Dictionary = {}
var _queued: Dictionary = {}
var _left_queue: Array[BeepCube] = []
var _right_queue: Array[BeepCube] = []
var _active_swings: Array[Swing] = []

var _spawned: int = 0
var _cut: int = 0
var _missed: int = 0
var _max_combo: int = 0

func _ready() -> void:
	_parse_arguments()
	if not _ensure_output_directory():
		_fail("Could not create output directory: %s" % _output_path)
		return

	_game = GAME_SCENE.instantiate() as BeepSaber_Game
	if not is_instance_valid(_game):
		_fail("Could not instantiate res://game/BeepSaber_Game.tscn")
		return
	add_child(_game)

	for _frame: int in range(6):
		await get_tree().process_frame

	if not _resolve_game_nodes():
		_fail("Required game nodes were not found after scene initialization")
		return
	_position_player()
	_connect_cube_pool()

	var info: MapInfo = Map.load_map_info(_song_path)
	if info == null:
		_fail("Song lookup failed: %s" % _song_path)
		return
	_selected_difficulty = _find_difficulty(info, _difficulty_query)
	if _selected_difficulty == null:
		_fail("Difficulty lookup failed: '%s' in %s" % [_difficulty_query, _song_path])
		return

	_game.start_map(info, _selected_difficulty)
	await get_tree().process_frame
	if Map.current_info != info or Map.current_difficulty != _selected_difficulty:
		_fail("Map failed to start: %s / %s" % [info.song_name, _selected_difficulty.custom_name])
		return

	var song_ready: bool = false
	var load_wait_started_msec: int = Time.get_ticks_msec()
	var load_wait_reported: bool = false
	var preplay_frame: int = 0
	while Time.get_ticks_msec() - load_wait_started_msec < 15000:
		await get_tree().process_frame
		var preplay_delta_ms: float = get_process_delta_time() * 1000.0
		var preplay_physics_ms: float = (
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		)
		print(
			"AUTOPLAY|PREPLAY|frame=%d|delta=%.3f|phys=%.3f"
			% [preplay_frame, preplay_delta_ms, preplay_physics_ms]
		)
		preplay_frame += 1
		var load_wait_seconds: float = (
			float(Time.get_ticks_msec() - load_wait_started_msec) / 1000.0
		)
		if not load_wait_reported and load_wait_seconds > 2.0:
			print("AUTOPLAY|LOADWAIT|%.3f" % load_wait_seconds)
			load_wait_reported = true
		if _game.gamestate == _game.gamestate_playing and _song_player.playing:
			song_ready = true
			break
	if not song_ready:
		var gamestate_name: String = "null"
		if _game.gamestate != null:
			var gamestate_script: Script = _game.gamestate.get_script() as Script
			gamestate_name = _game.gamestate.get_class()
			if gamestate_script != null and not gamestate_script.get_global_name().is_empty():
				gamestate_name = str(gamestate_script.get_global_name())
		var player_path: String = "null"
		var stream_name: String = "null"
		var playing: bool = false
		var stream_length: float = 0.0
		if is_instance_valid(_song_player):
			player_path = str(_song_player.get_path())
			playing = _song_player.playing
			if _song_player.stream != null:
				stream_name = _song_player.stream.get_class()
				stream_length = _song_player.stream.get_length()
		print(
			"AUTOPLAY|DIAG|gamestate=%s|player=%s|stream=%s|playing=%s|stream_length=%f"
			% [gamestate_name, player_path, stream_name, playing, stream_length]
		)
		_fail("Song audio or playing state failed to start: %s" % info.song_name)
		return
	print(
		"AUTOPLAY|START|song=%s|diff=%s|notes=%d"
		% [info.song_name, _selected_difficulty.custom_name, Map.note_stack.size()]
	)
	_startup_frame_index = 0

	if _duration_limit < 0.0:
		_duration_limit = _whole_song_duration(info)
	if _duration_limit <= 0.0:
		_duration_limit = INF
		print("AUTOPLAY|WARN|song duration unavailable; waiting for song end")

	_started = true
	_start_ticks_msec = Time.get_ticks_msec()
	_next_shot_time = _shot_every if _shot_every > 0.0 else INF
	await get_tree().process_frame
	_capture_screenshot(0.0)

func _process(_delta: float) -> void:
	if _startup_frame_index < 0 or _startup_frame_index >= STARTUP_FRAME_COUNT:
		return
	var process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var delta_ms: float = get_process_delta_time() * 1000.0
	var draw_calls: int = int(
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	)
	print(
		"AUTOPLAY|FRAME|%d|proc=%.3f|phys=%.3f|delta=%.3f|draw=%d|active_cubes=%d"
		% [
			_startup_frame_index,
			process_ms,
			physics_ms,
			delta_ms,
			draw_calls,
			_count_non_released_cubes(),
		]
	)
	_startup_frame_index += 1

func _physics_process(_delta: float) -> void:
	if not _started or _finishing:
		return

	if _game.gamestate == _game.gamestate_failed:
		_failed = true
		print("AUTOPLAY|FAILED|t=%.3f" % _played_seconds())
		_finishing = true
		call_deferred("_finish")
		return

	_track_cubes()
	if _bot_enabled:
		_queue_strikes()
		_start_queued_swings()
		_advance_swings()
	_max_combo = maxi(_max_combo, Scoreboard.combo)

	var played: float = _played_seconds()
	var whole_second: int = int(floor(played))
	if whole_second > _last_sample_second:
		_last_sample_second = whole_second
		_sample_performance(played)
	if played >= _next_shot_time:
		_capture_screenshot(played)
		_next_shot_time += _shot_every
	if not _six_second_census_complete and played >= CENSUS_TIME_SECONDS:
		_six_second_census_complete = true
		_run_draw_call_census("6_seconds", played)

	if played >= _duration_limit or _song_has_ended():
		_finishing = true
		call_deferred("_finish")

func _parse_arguments() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = 0
	while index < args.size():
		var argument: String = args[index]
		var key: String = argument
		var value: String = ""
		var equals_index: int = argument.find("=")
		if equals_index >= 0:
			key = argument.left(equals_index)
			value = argument.substr(equals_index + 1)
		elif index + 1 < args.size() and not args[index + 1].begins_with("--"):
			value = args[index + 1]
			index += 1
		match key:
			"--song":
				_song_path = value
			"--diff":
				_difficulty_query = value
			"--duration":
				_duration_limit = value.to_float()
			"--out":
				_output_path = value
			"--shot-every":
				_shot_every = maxf(0.0, value.to_float())
			"--bot":
				_bot_enabled = value != "0"
			"--nofail":
				Settings.no_fail = value != "0"
		index += 1
	if not _song_path.ends_with("/"):
		_song_path += "/"

func _resolve_game_nodes() -> bool:
	_xr_origin = _game.xr_origin
	if not is_instance_valid(_xr_origin):
		_xr_origin = vr.vrOrigin
	if not is_instance_valid(_xr_origin):
		_xr_origin = _game.find_child("XROrigin3D", true, false) as XROrigin3D

	_camera = vr.vrCamera
	if not is_instance_valid(_camera):
		_camera = _game.find_child("XRCamera3D", true, false) as XRCamera3D

	_left_controller = _game.left_controller
	if not is_instance_valid(_left_controller):
		_left_controller = vr.leftController
	if not is_instance_valid(_left_controller):
		_left_controller = _game.find_child("LeftController", true, false) as BeepSaberController

	_right_controller = _game.right_controller
	if not is_instance_valid(_right_controller):
		_right_controller = vr.rightController
	if not is_instance_valid(_right_controller):
		_right_controller = _game.find_child("RightController", true, false) as BeepSaberController

	_song_player = _game.song_player
	if not is_instance_valid(_song_player):
		_song_player = _game.find_child("SongPlayer", true, false) as AudioStreamPlayer

	_event_driver = _game.event_driver
	if not is_instance_valid(_event_driver):
		_event_driver = _game.find_child("event_driver", true, false) as EventDriver
	if is_instance_valid(_event_driver):
		_light_manager = _event_driver.light_manager

	return (
		is_instance_valid(_xr_origin)
		and is_instance_valid(_camera)
		and is_instance_valid(_left_controller)
		and is_instance_valid(_right_controller)
		and is_instance_valid(_song_player)
	)

func _position_player() -> void:
	_xr_origin.global_transform = Transform3D.IDENTITY
	_camera.position = Vector3(0.0, 1.7, 0.0)
	_camera.rotation = Vector3.ZERO
	_left_controller.global_transform = Transform3D(Basis.IDENTITY, Vector3(-0.25, 1.2, -0.5))
	_right_controller.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.25, 1.2, -0.5))

func _connect_cube_pool() -> void:
	var track: Node = _game.track
	if not is_instance_valid(track):
		track = _game.find_child("Track", true, false)
	if not is_instance_valid(track):
		print("AUTOPLAY|WARN|track node unavailable; cube counters and bot disabled")
		_bot_enabled = false
		return
	for child: Node in track.get_children():
		if child is BeepCube:
			_connect_cube(child as BeepCube)

func _connect_cube(cube: BeepCube) -> void:
	var cube_id: int = cube.get_instance_id()
	if _cube_connected.has(cube_id):
		return
	_cube_connected[cube_id] = true
	cube.cutted.connect(_on_cube_cutted.bind(cube))
	cube.released.connect(_on_cube_released.bind(cube))

func _track_cubes() -> void:
	if not is_instance_valid(_game.track):
		return
	for child: Node in _game.track.get_children():
		if not child is BeepCube:
			continue
		var cube: BeepCube = child as BeepCube
		_connect_cube(cube)
		var cube_id: int = cube.get_instance_id()
		var active: bool = (
			not cube.is_released()
			and cube.note_info != null
			and not cube.note_info.uninteractable
		)
		var was_active: bool = bool(_cube_active.get(cube_id, false))
		if active and not was_active:
			_spawned += 1
			_cube_cut[cube_id] = false
			_queued.erase(cube_id)
			_cube_active[cube_id] = true
		elif not active and was_active:
			_cube_active[cube_id] = false

func _count_non_released_cubes() -> int:
	if not is_instance_valid(_game.track):
		return 0
	var count: int = 0
	for child: Node in _game.track.get_children():
		if child is BeepCube and not (child as BeepCube).is_released():
			count += 1
	return count

func _queue_strikes() -> void:
	for child: Node in _game.track.get_children():
		if not child is BeepCube:
			continue
		var cube: BeepCube = child as BeepCube
		if cube.is_released() or cube.note_info == null or cube.note_info.uninteractable:
			continue
		var cube_id: int = cube.get_instance_id()
		if _queued.has(cube_id) or _is_cube_in_active_swing(cube):
			continue
		var z_position: float = cube.global_position.z
		if z_position < STRIKE_MIN_Z or z_position > STRIKE_MAX_Z:
			continue
		_queued[cube_id] = true
		if cube.which_saber == 0:
			_left_queue.append(cube)
		else:
			_right_queue.append(cube)

func _start_queued_swings() -> void:
	if not _has_active_saber(0):
		_start_next_swing(_left_queue, _left_controller, 0)
	if not _has_active_saber(1):
		_start_next_swing(_right_queue, _right_controller, 1)

func _start_next_swing(
	queue: Array[BeepCube],
	controller: BeepSaberController,
	saber_type: int
	) -> void:
	while not queue.is_empty():
		var cube: BeepCube = queue.pop_front() as BeepCube
		if not is_instance_valid(cube) or cube.is_released() or cube.note_info == null:
			continue
		var direction: Vector3 = _swing_direction(cube)
		_active_swings.append(Swing.new(cube, controller, direction, saber_type))
		return

func _advance_swings() -> void:
	for index: int in range(_active_swings.size() - 1, -1, -1):
		var swing: Swing = _active_swings[index]
		if not is_instance_valid(swing.cube) or swing.cube.is_released():
			_active_swings.remove_at(index)
			continue
		var progress: float = float(swing.frame) / float(SWING_FRAMES - 1)
		var offset: float = lerpf(-SWING_DISTANCE, SWING_DISTANCE, progress)
		var target: Vector3 = swing.cube.global_position + swing.direction * offset
		var controller_basis: Basis = Basis(Vector3.RIGHT, deg_to_rad(48.297))
		swing.controller.global_transform = Transform3D(controller_basis, target)
		swing.frame += 1
		if swing.frame >= SWING_FRAMES:
			_queued.erase(swing.cube.get_instance_id())
			_active_swings.remove_at(index)

func _swing_direction(cube: BeepCube) -> Vector3:
	if cube.is_dot or cube.note_info == null:
		return Vector3.DOWN
	var direction: Vector3 = -cube.global_transform.basis.y
	direction.z = 0.0
	if direction.length_squared() > 0.0:
		return direction.normalized()
	var cut_direction: int = cube.note_info.cut_direction
	if cut_direction >= 0 and cut_direction < Constants.ROTATION_UNIT_VECTORS.size():
		var arrow: Vector2 = Constants.ROTATION_UNIT_VECTORS[cut_direction]
		return Vector3(arrow.x, arrow.y, 0.0).normalized()
	return Vector3.DOWN

func _has_active_saber(saber_type: int) -> bool:
	for swing: Swing in _active_swings:
		if swing.saber_type == saber_type:
			return true
	return false

func _is_cube_in_active_swing(cube: BeepCube) -> bool:
	for swing: Swing in _active_swings:
		if swing.cube == cube:
			return true
	return false

func _on_cube_cutted(correct_saber: bool, cube: BeepCube) -> void:
	var cube_id: int = cube.get_instance_id()
	if (
		correct_saber
		and bool(_cube_active.get(cube_id, false))
		and not bool(_cube_cut.get(cube_id, false))
	):
		_cube_cut[cube_id] = true
		_cut += 1

func _on_cube_released(cube: BeepCube) -> void:
	var cube_id: int = cube.get_instance_id()
	if bool(_cube_active.get(cube_id, false)) and not bool(_cube_cut.get(cube_id, false)):
		_missed += 1
	_cube_active[cube_id] = false
	_queued.erase(cube_id)

func _sample_performance(played: float) -> void:
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var process_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var draw_calls: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objects: float = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var primitives: float = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var nodes: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var physics_objects: float = Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	var static_memory: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var light_updates: int = _light_manager.light_updates if is_instance_valid(_light_manager) else 0
	var events: int = _event_driver.events_processed if is_instance_valid(_event_driver) else 0
	var sample: Dictionary = {
		"time": played,
		"fps": fps,
		"process_ms": process_ms,
		"physics_ms": physics_ms,
		"draw_calls": draw_calls,
		"objects": objects,
		"primitives": primitives,
		"nodes": nodes,
		"physics_objects": physics_objects,
		"static_memory": static_memory,
		"score": Scoreboard.points,
		"points": Scoreboard.points,
		"combo": Scoreboard.combo,
		"energy": Scoreboard.energy,
		"spawned": _spawned,
		"cut": _cut,
		"missed": _missed,
		"events": events,
		"light_updates": light_updates,
	}
	_samples.append(sample)
	print(
		"AUTOPLAY|t=%.1f|fps=%.1f|proc=%.2fms|phys=%.2fms|draw=%.0f|obj=%.0f|score=%d|combo=%d|energy=%.2f|spawn=%d|cut=%d|miss=%d|events=%d|lights=%d"
		% [
			played, fps, process_ms, physics_ms, draw_calls, objects,
			Scoreboard.points, Scoreboard.combo, Scoreboard.energy, _spawned, _cut, _missed,
			events, light_updates
		]
	)

func _capture_screenshot(played: float) -> void:
	if DisplayServer.get_name() == "headless":
		print("AUTOPLAY|WARN|screenshot skipped in headless display mode")
		return
	var image: Image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		print("AUTOPLAY|WARN|screenshot unavailable at %.1fs" % played)
		return
	var seconds: int = maxi(0, int(round(played)))
	var screenshot_path: String = _output_file("shot_%d.png" % seconds)
	var error: Error = image.save_png(screenshot_path)
	if error != OK:
		print("AUTOPLAY|WARN|screenshot save failed (%d): %s" % [error, screenshot_path])

func _run_draw_call_census(label: String, played: float) -> void:
	var visual_classes: Dictionary = {}
	var visual_scenes: Dictionary = {}
	var mesh_surfaces_by_scene: Dictionary = {}
	var canvas_groups: Dictionary = {}
	var particle_states: Dictionary = {}
	var totals: Dictionary = {
		"visual_instances": 0,
		"mesh_surfaces": 0,
		"particles": 0,
		"canvas_items": 0,
		"draw_calls_monitor": int(
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		),
	}
	_census_node(
		get_tree().root,
		visual_classes,
		visual_scenes,
		mesh_surfaces_by_scene,
		canvas_groups,
		particle_states,
		totals
	)
	var categories: Dictionary = {
		"VISUAL_CLASS": _top_census_entries(visual_classes),
		"VISUAL_SCENE": _top_census_entries(visual_scenes),
		"MESH_SURFACES_SCENE": _top_census_entries(mesh_surfaces_by_scene),
		"CANVAS_GROUP": _top_census_entries(canvas_groups),
		"PARTICLES_STATE": _top_census_entries(particle_states),
	}
	for category: String in categories:
		var entries: Array = categories[category] as Array
		for entry_variant: Variant in entries:
			var entry: Dictionary = entry_variant as Dictionary
			print(
				"AUTOPLAY|CENSUS|%s|%s|%d"
				% [category, str(entry["name"]), int(entry["count"])]
			)
	print(
		(
			"AUTOPLAY|CENSUS|TOTAL|visual_instances=%d|mesh_surfaces=%d"
			+ "|particles=%d|canvas_items=%d|draw_calls_monitor=%d"
		)
		% [
			int(totals["visual_instances"]),
			int(totals["mesh_surfaces"]),
			int(totals["particles"]),
			int(totals["canvas_items"]),
			int(totals["draw_calls_monitor"]),
		]
	)
	_census_snapshots.append({
		"label": label,
		"time": played,
		"categories": categories,
		"totals": totals,
	})
	_write_census_json()

func _census_node(
	node: Node,
	visual_classes: Dictionary,
	visual_scenes: Dictionary,
	mesh_surfaces_by_scene: Dictionary,
	canvas_groups: Dictionary,
	particle_states: Dictionary,
	totals: Dictionary
	) -> void:
	if node is VisualInstance3D:
		var visual_instance: VisualInstance3D = node as VisualInstance3D
		if visual_instance.is_visible_in_tree():
			var visual_class: String = visual_instance.get_class()
			var visual_scene: String = _census_scene_name(visual_instance)
			_increment_census_count(visual_classes, visual_class)
			_increment_census_count(visual_scenes, visual_scene)
			totals["visual_instances"] = int(totals["visual_instances"]) + 1
			if visual_instance is MeshInstance3D:
				var mesh_instance: MeshInstance3D = visual_instance as MeshInstance3D
				if mesh_instance.mesh != null:
					var surface_count: int = mesh_instance.mesh.get_surface_count()
					_increment_census_count(
						mesh_surfaces_by_scene,
						visual_scene,
						surface_count
					)
					totals["mesh_surfaces"] = int(totals["mesh_surfaces"]) + surface_count
			if visual_instance is GPUParticles3D:
				var particles: GPUParticles3D = visual_instance as GPUParticles3D
				var particle_state: String = "emitting" if particles.emitting else "not_emitting"
				_increment_census_count(particle_states, particle_state)
				if particles.emitting:
					totals["particles"] = int(totals["particles"]) + 1
	if node is CanvasItem:
		var canvas_item: CanvasItem = node as CanvasItem
		if canvas_item.is_visible_in_tree():
			_increment_census_count(canvas_groups, _census_canvas_group(canvas_item))
			totals["canvas_items"] = int(totals["canvas_items"]) + 1
	for child: Node in node.get_children():
		_census_node(
			child,
			visual_classes,
			visual_scenes,
			mesh_surfaces_by_scene,
			canvas_groups,
			particle_states,
			totals
		)

func _census_scene_name(node: Node) -> String:
	var current: Node = node
	while is_instance_valid(current):
		if not current.scene_file_path.is_empty():
			return current.scene_file_path.get_file().get_basename()
		if current == _game:
			break
		current = current.get_parent()
	current = node
	while is_instance_valid(current.get_parent()) and current.get_parent() != _game:
		current = current.get_parent()
	return current.name

func _census_canvas_group(canvas_item: CanvasItem) -> String:
	var current: Node = canvas_item
	while is_instance_valid(current):
		if current is CanvasLayer or current is SubViewport:
			return "%s:%s" % [current.get_class(), str(current.get_path())]
		current = current.get_parent()
	return "Viewport:%s" % str(canvas_item.get_viewport().get_path())

func _increment_census_count(counts: Dictionary, name: String, amount: int = 1) -> void:
	counts[name] = int(counts.get(name, 0)) + amount

func _top_census_entries(counts: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for name: Variant in counts:
		entries.append({"name": str(name), "count": int(counts[name])})
	entries.sort_custom(_census_entry_precedes)
	if entries.size() > CENSUS_CATEGORY_LIMIT:
		entries.resize(CENSUS_CATEGORY_LIMIT)
	return entries

func _census_entry_precedes(left: Dictionary, right: Dictionary) -> bool:
	var left_count: int = int(left["count"])
	var right_count: int = int(right["count"])
	if left_count == right_count:
		return str(left["name"]) < str(right["name"])
	return left_count > right_count

func _write_census_json() -> void:
	var census_path: String = _output_file("census.json")
	var file: FileAccess = FileAccess.open(census_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write census: %s" % census_path)
		return
	file.store_string(JSON.stringify(_census_snapshots, "\t"))
	file.close()

func _finish() -> void:
	var played: float = _played_seconds()
	_run_draw_call_census("end", played)
	if _samples.is_empty() or float(_samples[-1].get("time", -1.0)) < played:
		_sample_performance(played)
	var report: Dictionary = {
		"song": Map.current_info.song_name if Map.current_info != null else _song_path,
		"difficulty": _selected_difficulty.custom_name if _selected_difficulty != null else _difficulty_query,
		"duration_played": played,
		"failed": _failed,
		"samples": _samples,
		"aggregates": {
			"avg_fps": _aggregate("fps", "avg"),
			"min_fps": _aggregate("fps", "min"),
			"max_fps": _aggregate("fps", "max"),
			"avg_draw_calls": _aggregate("draw_calls", "avg"),
			"max_draw_calls": _aggregate("draw_calls", "max"),
			"avg_objects": _aggregate("objects", "avg"),
			"max_objects": _aggregate("objects", "max"),
			"avg_process_ms": _aggregate("process_ms", "avg"),
		},
		"gameplay": {
			"spawned": _spawned,
			"cut": _cut,
			"missed": _missed,
			"final_score": Scoreboard.points,
			"max_combo": _max_combo,
		},
		"lighting": {
			"events_processed": _event_driver.events_processed if is_instance_valid(_event_driver) else 0,
			"events_by_type": _event_driver.events_by_type if is_instance_valid(_event_driver) else {},
			"light_updates": _light_manager.light_updates if is_instance_valid(_light_manager) else 0,
		},
		"script_errors": "unavailable from the running Godot API; none captured by the harness",
		"engine_frames_drawn": Engine.get_frames_drawn(),
	}
	var report_path: String = _output_file("report.json")
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write report: %s" % report_path)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("AUTOPLAY|DONE|report=%s|score=%d|spawned=%d|cut=%d|missed=%d" % [
		report_path, Scoreboard.points, _spawned, _cut, _missed
	])
	get_tree().quit(0)

func _aggregate(key: String, mode: String) -> float:
	if _samples.is_empty():
		return 0.0
	var result: float = float(_samples[0].get(key, 0.0))
	var total: float = 0.0
	for sample: Dictionary in _samples:
		var value: float = float(sample.get(key, 0.0))
		total += value
		if mode == "min":
			result = minf(result, value)
		elif mode == "max":
			result = maxf(result, value)
	if mode == "avg":
		return total / float(_samples.size())
	return result

func _find_difficulty(info: MapInfo, query: String) -> DifficultyInfo:
	if info.difficulty_beatmaps.is_empty():
		return null
	if query.is_empty():
		return info.difficulty_beatmaps[0]
	var wanted: String = query.to_lower()
	for difficulty: DifficultyInfo in info.difficulty_beatmaps:
		var filename: String = difficulty.beatmap_filename.get_file()
		var stem: String = filename.get_basename()
		if (
			filename.to_lower() == wanted
			or stem.to_lower() == wanted
			or difficulty.difficulty.to_lower() == wanted
			or difficulty.custom_name.to_lower() == wanted
		):
			return difficulty
	return null

func _whole_song_duration(info: MapInfo) -> float:
	if is_instance_valid(_song_player.stream):
		var stream_length: float = _song_player.stream.get_length()
		if stream_length > 0.0:
			return stream_length
	return info.song_duration

func _played_seconds() -> float:
	if _start_ticks_msec <= 0:
		return 0.0
	return float(Time.get_ticks_msec() - _start_ticks_msec) / 1000.0

func _song_has_ended() -> bool:
	if _game.endscore.visible:
		return true
	if _game.gamestate == _game.gamestate_mapcomplete or _game.gamestate == _game.gamestate_newhighscore:
		return true
	if _game.gamestate == _game.gamestate_failed:
		return true
	return _played_seconds() > 0.5 and not _song_player.playing

func _ensure_output_directory() -> bool:
	var absolute_path: String = ProjectSettings.globalize_path(_output_path)
	var error: Error = DirAccess.make_dir_recursive_absolute(absolute_path)
	return error == OK or error == ERR_ALREADY_EXISTS

func _output_file(filename: String) -> String:
	return _output_path.path_join(filename)

func _duration_text() -> String:
	return "song" if is_inf(_duration_limit) else "%.1f" % _duration_limit

func _fail(message: String) -> void:
	push_error("AUTOPLAY|ERROR|%s" % message)
	print("AUTOPLAY|ERROR|%s" % message)
	get_tree().quit(2)
