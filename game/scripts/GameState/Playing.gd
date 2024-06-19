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

func _physics_process(game: BeepSaber_Game, delta: float) -> void:
	if game.left_controller.by_just_pressed():
		game._transition_game_state(game.gamestate_paused)
	if game._audio_synced_after_restart:
		_process_map(game)
	else:
		# 0.5 seconds is a pretty concervative number to use for the audio
		# resync check. Having this duration be this long might only be an
		# issue for maps that spawn notes extremely early into the song.
		if game.song_player.get_playback_position() < 0.5:
			game._audio_synced_after_restart = true

var _proc_map_sw := StopwatchFactory.create("process_map",10,true)

func _spawn_note(game: BeepSaber_Game, note: Map.ColorNoteInfo, current_beat: float) -> void:
	var note_node := game.cube_pool.acquire()
	
	if note_node == null:
		print("Failed to acquire a new note from scene pool")
		return
	
	var color := game.COLOR_LEFT if note.color == 0 else game.COLOR_RIGHT
	note_node.spawn(note, current_beat, color)

var bomb_template := load("res://game/Bomb/Bomb.tscn") as PackedScene
func _spawn_bomb(game: BeepSaber_Game, bomb_info: Map.BombInfo, current_beat: float) -> void:
	var bomb := bomb_template.instantiate() as Bomb
	bomb.spawn(bomb_info, current_beat)
	game.track.add_child(bomb)

var wall_template := load("res://game/Wall/Wall.tscn") as PackedScene
func _spawn_wall(game: BeepSaber_Game, wall_info: Map.ObstacleInfo, current_beat: float) -> void:
	var wall := wall_template.instantiate() as Wall
	wall.spawn(wall_info, current_beat)
	game.track.add_child(wall)

func _spawn_event(game: BeepSaber_Game, data: Map.EventInfo) -> void:
	game.event_driver.process_event(data, game.COLOR_LEFT, game.COLOR_RIGHT)

# when the song ended we want to display the current score and
# the high score
func _on_song_ended(game: BeepSaber_Game) -> void:
	game.song_player.stop()
	PlayCount.increment_play_count(Map.current_info,Map.current_difficulty.difficulty_rank)
	
	var new_record := false
	var highscore := Highscores.get_highscore(Map.current_info,Map.current_difficulty.difficulty_rank)
	if highscore == -1:
		# no highscores exist yet
		highscore = Scoreboard.points
	elif Scoreboard.points > highscore:
		# player's score is the new highscore!
		highscore = Scoreboard.points
		new_record = true

	var current_percent := Scoreboard.right_notes/(Scoreboard.right_notes+Scoreboard.wrong_notes)
	game.endscore.show_score(
		Scoreboard.points,
		highscore,
		current_percent,
		"%s By %s\n%s     Map author: %s" % [
			Map.current_info.song_name,
			Map.current_info.song_author_name,
			game.menu._map_difficulty_name,
			Map.current_info.level_author_name],
		Scoreboard.full_combo,
		new_record
	)
	
	if Highscores.is_new_highscore(Map.current_info,Map.current_difficulty.difficulty_rank,Scoreboard.points):
		game._transition_game_state(game.gamestate_newhighscore)
	else:
		game._transition_game_state(game.gamestate_mapcomplete)

const BEATS_AHEAD := 4.0

func _process_map(game: BeepSaber_Game) -> void:
	if (Map.current_info == null):
		return
	
	_proc_map_sw.start()
	
	var current_time := game.song_player.get_playback_position()
	
	var current_beat := current_time * Map.current_info.beats_per_minute / 60.0
	
	# spawn notes
	while not Map.note_stack.is_empty() and Map.note_stack[-1].beat <= current_beat+BEATS_AHEAD:
		_spawn_note(game, Map.note_stack[-1], current_beat)
		Map.note_stack.pop_back()
	
	# spawn bombs
	while not Map.bomb_stack.is_empty() and Map.bomb_stack[-1].beat <= current_beat+BEATS_AHEAD:
		_spawn_bomb(game, Map.bomb_stack[-1], current_beat)
		Map.bomb_stack.pop_back()
	
	# spawn obstacles (walls)
	while not Map.obstacle_stack.is_empty() and Map.obstacle_stack[-1].beat <= current_beat+BEATS_AHEAD:
		_spawn_wall(game, Map.obstacle_stack[-1], current_beat)
		Map.obstacle_stack.pop_back()
	
	while not Map.event_stack.is_empty() and Map.event_stack[-1].beat <= current_beat:
		_spawn_event(game, Map.event_stack[-1])
		Map.event_stack.pop_back()
	
	if (game.song_player.get_playback_position() >= game.song_player.stream.get_length()-1):
		_on_song_ended(game)
	
	_proc_map_sw.stop()
