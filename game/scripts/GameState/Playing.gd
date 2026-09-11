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
	game.left_saber.set_swingcast_enabled(true)
	game.right_saber.set_swingcast_enabled(true)
	Scoreboard.paused = false

func _physics_process(game: BeepSaber_Game) -> void:
	if game.is_loading_map:
		return
	if (
		game.left_controller.by_just_pressed()
		or game.left_controller.menu_just_pressed()
		or game.right_controller.menu_just_pressed()
	):
		game._transition_game_state(game.gamestate_paused)
	if game._audio_synced_after_restart:
		_process_map(game)
	else:
		# 0.5 seconds is a pretty concervative number to use for the audio
		# resync check. Having this duration be this long might only be an
		# issue for maps that spawn notes extremely early into the song.
		if game.song_player.get_playback_position() < 0.5:
			game._audio_synced_after_restart = true

var note_info_refs: Array[ColorNoteInfo] = []
var cube_refs: Array[BeepCube] = []

# Beat Saber spawns every object "moveDuration + halfJumpDuration" seconds
# before its beat.
static func _should_spawn(object_beat: float, njs: float, start_beat_offset: float, song_time: float) -> bool:
	var object_time := Map.beat_to_seconds(object_beat)
	return object_time - song_time <= NoteMovementData.spawn_ahead_time(njs, start_beat_offset)

func _process_map(game: BeepSaber_Game) -> void:
	if (Map.current_info == null):
		return

	var song_time := NoteMovementData.song_time
	var current_beat := Map.seconds_to_beat(song_time)

	# chains connect to a regular colornote and modify it, so we have to keep
	# track of what notes were spawned this frame, in case any become the head
	# of a chain.
	# why did they do this?
	note_info_refs.clear()
	cube_refs.clear()
	var default_njs: float = NoteMovementData.default_njs
	var default_spawn_offset: float = NoteMovementData.default_start_beat_offset

	# spawn notes
	while not Map.note_stack.is_empty():
		var pending_note := Map.note_stack[-1] as ColorNoteInfo
		if not _should_spawn(
			pending_note.beat,
			pending_note.get_note_jump_movement_speed(default_njs),
			pending_note.get_note_jump_start_beat_offset(default_spawn_offset),
			song_time
		):
			break
		var note := GlobalReferences.cube_pool.acquire() as BeepCube
		var note_info := Map.note_stack.pop_back() as ColorNoteInfo
		var color: = Map.color_left if note_info.color == 0 else Map.color_right
		note.spawn(note_info, current_beat, note_info.get_color(color))
		note_info_refs.append(note_info)
		cube_refs.append(note)

	# spawn bombs
	while not Map.bomb_stack.is_empty():
		var pending_bomb := Map.bomb_stack[-1] as BombInfo
		if not _should_spawn(
			pending_bomb.beat,
			pending_bomb.get_note_jump_movement_speed(default_njs),
			pending_bomb.get_note_jump_start_beat_offset(default_spawn_offset),
			song_time
		):
			break
		var bomb := game.bomb_pool.acquire() as Bomb
		bomb.spawn(Map.bomb_stack.pop_back() as BombInfo, current_beat)

	# spawn obstacles (walls)
	while not Map.obstacle_stack.is_empty():
		var pending_wall := Map.obstacle_stack[-1] as ObstacleInfo
		if not _should_spawn(
			pending_wall.beat,
			pending_wall.get_note_jump_movement_speed(default_njs),
			pending_wall.get_note_jump_start_beat_offset(default_spawn_offset),
			song_time
		):
			break
		var wall := game.wall_pool.acquire() as Wall
		var wall_info: = Map.obstacle_stack.pop_back() as ObstacleInfo
		var wall_color := wall_info.get_color(Settings.default_values.obstacle_color)
		wall.spawn(wall_info, current_beat, wall_color)

	while not Map.arc_stack.is_empty():
		var pending_arc := Map.arc_stack[-1] as ArcInfo
		if not _should_spawn(
			pending_arc.head_beat,
			pending_arc.get_note_jump_movement_speed(default_njs),
			pending_arc.get_note_jump_start_beat_offset(default_spawn_offset),
			song_time
		):
			break
		var arc := game.arc_pool.acquire() as Arc
		var arc_info := Map.arc_stack.pop_back() as ArcInfo

		# find starting cube to use as magnet trigger
		var cube : BeepCube
		var cube_id := cube_refs.size()-1
		while cube_id >= 0:
			var current_cube : BeepCube = cube_refs[cube_id]
			if (current_cube.beat == arc_info.head_beat
				and current_cube.which_saber == arc_info.color
				and current_cube.note_info != null
				and not current_cube.note_info.uninteractable
				):
					cube = current_cube
					break
			cube_id -= 1

		# Check for Chroma custom color
		var arc_color := arc_info.get_color(Color.TRANSPARENT)

		arc.spawn(arc_info, current_beat, cube, arc_color)

	while not Map.chain_stack.is_empty():
		var pending_chain := Map.chain_stack[-1] as ChainInfo
		if not _should_spawn(
			pending_chain.head_beat,
			pending_chain.get_note_jump_movement_speed(default_njs),
			pending_chain.get_note_jump_start_beat_offset(default_spawn_offset),
			song_time
		):
			break
		var chain_info := Map.chain_stack.pop_back() as ChainInfo
		if chain_info.slice_count > 1: # skip if the chain doesn't have any links
			ChainLink.construct_chain(chain_info, current_beat, note_info_refs, cube_refs)

	while not Map.event_stack.is_empty() and Map.event_stack[-1].beat <= current_beat:
		game.event_driver.process_event(Map.event_stack.pop_back() as EventInfo)
