extends GameState
class_name GameStatePlaying

func _ready(game: BeepSaber_Game) -> void:
	game.main_menu._hide()
	game.settings_canvas._hide()
	game.show_MapSourceDialogs(false)
	game.endscore._hide()
	game.pause_menu._hide()
	game.highscore_canvas._hide()
	game.name_selector_canvas._hide()
	game.left_saber._show()
	game.right_saber._show()
	game.multiplier_label.visible = true
	game.point_label.visible = true
	game.percent_indicator.visible = true
	game.track.visible = true
	game.left_ui_raycast.visible = false
	game.right_ui_raycast.visible = false
	game.highscore_keyboard._hide()
	game.online_search_keyboard._hide()

func _physics_process(game: BeepSaber_Game, delta: float) -> void:
	if game.non_dominant_hand.by_just_pressed():
		game._transition_game_state(game.gamestate_paused)
	if game.song_player.playing and not game._audio_synced_after_restart:
		# 0.5 seconds is a pretty concervative number to use for the audio
		# resync check. Having this duration be this long might only be an
		# issue for maps that spawn notes extremely early into the song.
		if game.song_player.get_playback_position() < 0.5:
			game._audio_synced_after_restart = true
	elif game.song_player.playing:
		_process_map(game, delta)
		game.left_controller._update_movement_aabb()
		game.right_controller._update_movement_aabb()

var _proc_map_sw := StopwatchFactory.create("process_map",10,true)
var _instance_cube_sw := StopwatchFactory.create("instance_cube",10,true)
var _add_cube_to_scene_sw := StopwatchFactory.create("add_cube_to_scene",10,true)

const CUBE_DISTANCE := 0.5
const CUBE_HEIGHT_OFFSET := 0.4

var bomb_template := preload("res://game/Bomb/Bomb.tscn") as PackedScene
func _spawn_note(game: BeepSaber_Game, note: Dictionary, current_beat: float) -> void:
	var note_node: Note
	var is_cube := true
	var color := game.COLOR_LEFT
	if (note._type == 0):
		_instance_cube_sw.start()
		note_node = game._cube_pool.acquire(game.track)
		color = game.COLOR_LEFT
		_instance_cube_sw.stop()
	elif (note._type == 1):
		_instance_cube_sw.start()
		note_node = game._cube_pool.acquire(game.track)
		color = game.COLOR_RIGHT
		_instance_cube_sw.stop()
	elif (note._type == 3) and game.bombs_enabled:
		is_cube = false
		note_node = bomb_template.instantiate()
	else:
		return
	
	if note_node == null:
		print("Failed to acquire a new note from scene pool")
		return
	
	if game.menu._map_difficulty_noteJumpMovementSpeed > 0:
		note_node.speed = float(game.menu._map_difficulty_noteJumpMovementSpeed)/9
	
	var line: float = -(CUBE_DISTANCE * 3.0 / 2.0) + note._lineIndex * CUBE_DISTANCE
	var layer: float = CUBE_DISTANCE + note._lineLayer * CUBE_DISTANCE
	
	var rotation_z := deg_to_rad(game.CUBE_ROTATIONS[note._cutDirection])
	
	var distance: float = note._time - current_beat
	
	note_node.transform.origin = Vector3(
		line,
		CUBE_HEIGHT_OFFSET + layer,
		-distance * game.beat_distance)
	
	var is_dot: bool = note._cutDirection == 8
	if is_cube:
		note_node.rotation.z = rotation_z
	
	note_node._note = note
	
	if note_node is BeepCube:
		_add_cube_to_scene_sw.start()
		note_node.spawn(note._type, color, is_dot)
		_add_cube_to_scene_sw.stop()
	else:
		# spawn bombs by adding to track
		game.track.add_child(note_node)

# constants used to interpret the '_type' field in map obstacles
const WALL_TYPE_FULL_HEIGHT := 0
const WALL_TYPE_CROUCH := 1

const WALL_HEIGHT := 3.0

func _spawn_wall(game: BeepSaber_Game, obstacle, current_beat: float) -> void:
	# instantiate new wall from template
	var wall = game.wall_template.duplicate()
	wall.duplicate_create() # gives it its own unique mesh and collision shape
	
	var height := 0.0
	
	if (obstacle._type == WALL_TYPE_FULL_HEIGHT):
		wall.height = WALL_HEIGHT
		height = 0.0
	elif (obstacle._type == WALL_TYPE_CROUCH):
		wall.height = WALL_HEIGHT / 2.0
		height = WALL_HEIGHT / 2.0
	else:
		return
	
	game.track.add_child(wall)
	
	var line = -(CUBE_DISTANCE * 3.0 / 2.0) + obstacle._lineIndex * CUBE_DISTANCE
	
	var distance = obstacle._time - current_beat
	
	wall.transform.origin = Vector3(line,height,-distance * game.beat_distance)
	wall.depth = game.beat_distance * obstacle._duration
	wall.width = CUBE_DISTANCE * obstacle._width
	
	# walls have slightly difference origins offsets than cubes do, so we must
	# translate them by half a cube distance to correct for the misalignment.
	wall.translate(Vector3(-CUBE_DISTANCE/2.0,-CUBE_DISTANCE/2.0,0.0))
	
	wall._obstacle = obstacle;

func _process_map(game: BeepSaber_Game, dt: float) -> void:
	if (game._current_map == null):
		return
	
	_proc_map_sw.start()
	
	var current_time := game.song_player.get_playback_position()
	
	var current_beat := current_time * (game._current_info._beatsPerMinute as float) / 60.0

	# spawn notes
	var n: Array = game._current_map._notes
	while (game._current_note < n.size() && n[game._current_note]._time <= current_beat+game.beats_ahead):
		_spawn_note(game, n[game._current_note], current_beat)
		game._current_note += 1

	# spawn obstacles (walls)
	var o = game._current_map._obstacles
	while (game._current_obstacle < o.size() && o[game._current_obstacle]._time <= current_beat+game.beats_ahead):
		_spawn_wall(game, o[game._current_obstacle], current_beat)
		game._current_obstacle += 1;

	var speed := Vector3(0.0, 0.0, game.beat_distance * game._current_info._beatsPerMinute / 60.0) * dt

	for c_idx in game.track.get_child_count():
		var c = game.track.get_child(c_idx)
		if ! c.visible:
			continue
		
		c.translate(speed)

		var depth = CUBE_DISTANCE
		if c is Wall:
			# compute wall's depth based on duration
			depth = game.beat_distance * c._obstacle._duration
		else:
			# enable bomb/cube collision when it gets closer enough to player
			if c.global_transform.origin.z > -3.0:
				c.set_collision_disabled(false)

		# remove children that go to far
		if ((c.global_transform.origin.z - depth) > 2.0):
			if c is BeepCube:
				game._reset_combo()
				# cubes must be released() instead of queue_free() because they
				# are part of a pool.
				c.release()
			else:
				c.queue_free()

	var e = game._current_map._events;
	while (game._current_event < e.size() && e[game._current_event]._time <= current_beat):
		game._spawn_event(e[game._current_event], current_beat)
		game._current_event += 1

	if (game.song_player.get_playback_position() >= game.song_player.stream.get_length()-1):
		game._on_song_ended()
		
	_proc_map_sw.stop()
