# This file contains the main game logic for the BeepSaber demo implementation
extends Node3D
class_name BeepSaber_Game

var gamestate_bootup := GameState.new()
var gamestate_mapcomplete := GameStateMapComplete.new()
var gamestate_mapselection := GameStateMapSelection.new()
var gamestate_newhighscore := GameStateNewHighScore.new()
var gamestate_paused := GameStatePaused.new()
var gamestate_playing := GameStatePlaying.new()
var gamestate_settings := GameStateSettings.new()
var gamestate: GameState = gamestate_bootup

@onready var left_controller := $XROrigin3D/LeftController as BeepSaberController
@onready var right_controller := $XROrigin3D/RightController as BeepSaberController

@onready var left_saber := $XROrigin3D/LeftController/LeftLightSaber as LightSaber
@onready var right_saber := $XROrigin3D/RightController/RightLightSaber as LightSaber

@onready var right_ui_raycast := $XROrigin3D/RightController/UIRaycast as UIRaycast
@onready var left_ui_raycast := $XROrigin3D/LeftController/UIRaycast as UIRaycast

@onready var main_menu := $MainMenu_OQ_UI2DCanvas as OQ_UI2DCanvas
@onready var pause_menu := $PauseMenu_canvas as OQ_UI2DCanvas
@onready var settings_canvas := $Settings_canvas as OQ_UI2DCanvas
@onready var highscore_canvas := $Highscores_Canvas as OQ_UI2DCanvas
@onready var highscore_panel := highscore_canvas.ui_control as HighscorePanel
@onready var name_selector_canvas := $NameSelector_Canvas as OQ_UI2DCanvas
@onready var highscore_keyboard := $Keyboard_highscore as OQ_UI2DKeyboard
@onready var endscore := $EndScore as EndScore

@onready var points_label_driver := $Points_label_driver as PointsLabelDriver
@onready var event_driver := $event_driver as EventDriver
@onready var cube_pool := $BeepCubePool as BeepCubePool

@onready var multiplier_label := $Multiplier_Label as MeshInstance3D
@onready var point_label := $Point_Label as MeshInstance3D
@onready var percent_indicator := $Percent_Indicator as PercentIndicator

@onready var map_source_dialogs := $MapSourceDialogs as Node3D
@onready var online_search_keyboard := $Keyboard_online_search as OQ_UI2DKeyboard

@onready var fps_label := $XROrigin3D/XRCamera3D/PlayerHead/FPS_Label as OQ_UI2DLabel

@onready var cube_template := preload("res://game/BeepCube.tscn").instantiate() as BeepCube
@onready var wall_template := preload("res://game/Wall/Wall.tscn").instantiate() as Wall

@onready var track := $Track as Node3D

@onready var song_player := $SongPlayer as AudioStreamPlayer

@onready var menu := main_menu.ui_control as MainMenu

var COLOR_LEFT := Color(1.0, 0.1, 0.1, 1.0) : get = _get_color_left
var COLOR_RIGHT := Color(0.1, 0.1, 1.0, 1.0) : get = _get_color_right

var COLOR_LEFT_ONCE: Color = Color.TRANSPARENT
var COLOR_RIGHT_ONCE: Color = Color.TRANSPARENT
var disable_map_color := false


# There's an interesting issue where the AudioStreamPlayer's playback_position
# doesn't immediately return to 0.0 after restarting the song_player. This
# causes issues with restarting a map because the process_physics routine will
# execute for a times and attempt to process the map up to the playback_position
# prior to the AudioStreamPlayer restart. This bug can presents itself as notes
# persisting between map restarts.
# To remidy this issue, this flag is set to true when the map is restarted. The
# process_physics routine won't begin processing the map until after the
# AudioStreamPlayer has reset it's playback_position to zero. This flag is set
# to false once the AudioStreamPlayer reset is detected.
var _audio_synced_after_restart := false

# current difficulty name (Easy, Normal, Hard, etc.)
var _current_diff_name := ""
# current difficulty rank (1,3,5,etc.)
var _current_diff_rank := -1


var _in_wall := false

#prevents the song for starting from the start when pausing and unpausing
var pause_position := 0.0

#settings
var cube_cuts_falloff := true
var bombs_enabled := true

func restart_map() -> void:
	_audio_synced_after_restart = false
	song_player.play(0.0)
	song_player.volume_db = 0.0
	_in_wall = false
	MapInfo.current_note = 0
	MapInfo.current_obstacle = 0
	MapInfo.current_event = 0
	Scoreboard.restart()

	_display_points()
	percent_indicator.start_map()
	update_saber_colors()
	if MapInfo.events.size() > 0:
		event_driver.set_all_off()
	else:
		event_driver.set_all_on(COLOR_LEFT, COLOR_RIGHT)
	
	_clear_track()
	_transition_game_state(gamestate_playing)

func start_map(info: MapInfo.Map, map_data: Dictionary, map_difficulty: int) -> void:
	if not map_data.has("_notes"):
		print("Map has no '_notes'")
		return
	MapInfo.current_map = info
	MapInfo.notes = map_data._notes
	if map_data.has("_obstacles"):
		MapInfo.obstacles = map_data._obstacles
	else:
		MapInfo.obstacles = []
	if map_data.has("_events"):
		MapInfo.events = map_data._events
	else:
		MapInfo.events = []
	
	set_colors_from_map(info, map_difficulty)
	
	print("loading: ",info.filepath + info.song_filename)
	var stream := AudioStreamOggVorbis.load_from_file(info.filepath + info.song_filename)
	
	song_player.stream = stream
	restart_map()

func set_colors_from_map(info: MapInfo.Map, map_difficulty: int) -> void:
	COLOR_LEFT_ONCE = Color.TRANSPARENT
	COLOR_RIGHT_ONCE = Color.TRANSPARENT
	var roots := []
	for color_name in ["_envColor%sBoost", "_envColor%s", "_color%s"]:
		roots.append(info.custom_data)
		roots.append(info.difficulty_beatmaps[map_difficulty].custom_data)
		for r in roots:
			if r.has(color_name%["Right"]) and r.has(color_name%["Left"]):
				COLOR_LEFT_ONCE = Color(
					r[color_name%["Left"]].get("r",COLOR_LEFT.r),
					r[color_name%["Left"]].get("g",COLOR_LEFT.g),
					r[color_name%["Left"]].get("b",COLOR_LEFT.b))
				COLOR_RIGHT_ONCE = Color(
					r[color_name%["Right"]].get("r",COLOR_RIGHT.r),
					r[color_name%["Right"]].get("g",COLOR_RIGHT.g),
					r[color_name%["Right"]].get("b",COLOR_RIGHT.b))

# This function will transitioning the game from it's current state into
# the provided 'next_state'.
func _transition_game_state(next_state: GameState) -> void:
	gamestate = next_state
	gamestate._ready(self)

func show_MapSourceDialogs(showing: bool = true) -> void:
	map_source_dialogs.visible = showing
	for c in map_source_dialogs.get_children():
		c._hide()
	if showing:
		map_source_dialogs.get_child(0)._show()

# when the song ended we want to display the current score and
# the high score
func _on_song_ended() -> void:
	song_player.stop()
	PlayCount.increment_play_count(MapInfo.current_map,_current_diff_rank)
	
	var new_record := false
	var highscore := Highscores.get_highscore(MapInfo.current_map,_current_diff_rank)
	if highscore == -1:
		# no highscores exist yet
		highscore = Scoreboard.points
	elif Scoreboard.points > highscore:
		# player's score is the new highscore!
		highscore = Scoreboard.points
		new_record = true

	var current_percent := Scoreboard.right_notes/(Scoreboard.right_notes+Scoreboard.wrong_notes)
	endscore.show_score(
		Scoreboard.points,
		highscore,
		current_percent,
		"%s By %s\n%s     Map author: %s" % [
			MapInfo.current_map.song_name,
			MapInfo.current_map.song_author_name,
			menu._map_difficulty_name,
			MapInfo.current_map.level_author_name],
		Scoreboard.full_combo,
		new_record
	)
	
	if Highscores.is_new_highscore(MapInfo.current_map,_current_diff_rank,Scoreboard.points):
		_transition_game_state(gamestate_newhighscore)
	else:
		_transition_game_state(gamestate_mapcomplete)

# call this method to submit a new highscore to the database
func _submit_highscore(player_name: String) -> void:
	if gamestate == gamestate_newhighscore:
		Highscores.add_highscore(
			MapInfo.current_map,
			_current_diff_rank,
			player_name,
			Scoreboard.points)
			
		_transition_game_state(gamestate_mapcomplete)

const beat_distance := 4.0
const beats_ahead := 4.0
const CUBE_ROTATIONS: Array[float] = [180, 0, 270, 90, -135, 135, -45, 45, 0]

func _get_color_left() -> Color:
	if disable_map_color: return COLOR_LEFT
	return COLOR_LEFT_ONCE if COLOR_LEFT_ONCE != Color.TRANSPARENT else COLOR_LEFT

func _get_color_right() -> Color:
	if disable_map_color: return COLOR_RIGHT
	return COLOR_RIGHT_ONCE if COLOR_RIGHT_ONCE != Color.TRANSPARENT else COLOR_RIGHT

func _spawn_event(data,beat) -> void:
	event_driver.process_event(data,beat, COLOR_LEFT, COLOR_RIGHT)

func _check_and_update_saber(controller: BeepSaberController, saber: LightSaber) -> void:
	# to allow extending/sheething the saber while not playing a song
	if ((not song_player.playing)
		and (controller.ax_just_pressed() or controller.by_just_pressed())
		and (not saber._anim.is_playing())):
		if (saber.is_extended()): saber._hide()
		else: saber._show()
	
	# check for saber rumble (only when extended and not already rumbling)
	# this check is necessary to not overwrite a rumble set from somewhere else
	# (in this case it can come from cutting cubes)
	if not controller.is_simple_rumbling(): 
		if _in_wall:
			# weak rumble on both controllers when player is inside wall
			controller.simple_rumble(0.1, 0.1)
		elif saber.get_overlapping_areas().size() > 0 or saber.get_overlapping_bodies().size() > 0:
			# strong rumble when saber is cutting into wall or other saber
			controller.simple_rumble(0.5, 0.1)
		else:
			controller.simple_rumble(0.0, 0.1)


func _physics_process(dt: float) -> void:
	if fps_label.visible:
		fps_label.set_label_text("FPS: %d" % Engine.get_frames_per_second())
	
	gamestate._physics_process(self, dt)
	
	_check_and_update_saber(left_controller, left_saber)
	_check_and_update_saber(right_controller, right_saber)

func _ready() -> void:
	#var _main_menu := $MainMenu_OQ_UI2DCanvas/BeepSaberMainMenu as MainMenu
	#_main_menu.initialize(self)
	#($MapSourceDialogs/BeatSaver_Canvas as OQ_UI2DCanvas).ui_control.main_menu_node = _main_menu
	vr.vrOrigin = $XROrigin3D as XROrigin3D
	vr.vrCamera = $XROrigin3D/XRCamera3D as XRCamera3D
	vr.leftController = left_controller
	vr.rightController = right_controller
	
	if !vr.inVR:
		$XROrigin3D.add_child(preload("res://OQ_Toolkit/OQ_ARVROrigin/Feature_VRSimulator.tscn").instantiate())
	update_saber_colors()
	
	UI_AudioEngine.attach_children(highscore_keyboard)
	UI_AudioEngine.attach_children(online_search_keyboard)
	
	_transition_game_state(gamestate_mapselection)
	
	Scoreboard.score_changed.connect(_display_points)
	Scoreboard.points_awarded.connect(points_label_driver.show_points)
	
	#render common assets for a couple of frames to prevent performance issues when loading them mid game
	($pre_renderer as Node3D).visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	($pre_renderer as Node3D).queue_free()

func update_saber_colors() -> void:
	left_saber.set_color(COLOR_LEFT)
	right_saber.set_color(COLOR_RIGHT)
	#also updates map colors
	event_driver.update_colors(COLOR_LEFT, COLOR_RIGHT)
	($StandingGround as Floor).update_colors(COLOR_LEFT,COLOR_RIGHT)

func disable_events(disabled: bool) -> void:
	event_driver.disabled = disabled
	if disabled:
		event_driver.set_all_off()
	else:
		event_driver.set_all_on(COLOR_LEFT, COLOR_RIGHT)

func _clear_track() -> void:
	for c in track.get_children():
		if c is BeepCube:
			var b := c as BeepCube
			if b.visible:
				b.release()
		elif c is Node3D:
			var n := c as Node3D
			n.visible = false
			track.remove_child(n)
			n.queue_free()

func _display_points() -> void:
	var hit_rate: float
	if Scoreboard.right_notes+Scoreboard.wrong_notes > 0:
		hit_rate = Scoreboard.right_notes/(Scoreboard.right_notes+Scoreboard.wrong_notes)
	else:
		hit_rate = 1.0
	
	(point_label.mesh as TextMesh).text = "Score: %6d" % Scoreboard.points
	(multiplier_label.mesh as TextMesh).text = "x %d\nCombo %d" % [Scoreboard.multiplier, Scoreboard.combo]
	percent_indicator.update_percent(hit_rate)

# quiets song when player enters into a wall
func _quiet_song() -> void:
	song_player.volume_db = -15.0

# restores song volume when player leaves wall
func _louden_song() -> void:
	song_player.volume_db = 0.0

# accessor method for the player name selector UI element
func _name_selector() -> NameSelector:
	return name_selector_canvas.ui_control

func _on_PlayerHead_area_entered(area: Area3D) -> void:
	if area.is_in_group(&"wall"):
		if not _in_wall:
			_quiet_song()
		
		_in_wall = true

func _on_PlayerHead_area_exited(area: Area3D) -> void:
	if area.is_in_group(&"wall"):
		if _in_wall:
			_louden_song()
		
		_in_wall = false


func _on_EndScore_panel_repeat() -> void:
	restart_map()
	endscore.visible = false
	pause_menu.visible = false


func _on_EndScore_panel_goto_mainmenu() -> void:
	_clear_track()
	_transition_game_state(gamestate_mapselection)


func _on_Pause_Panel_continue_button() -> void:
	pause_menu.visible = false
	$Pause_countdown.visible = true
	track.visible = true
	$Pause_countdown.set_label_text("3")
	await get_tree().create_timer(0.5).timeout
	$Pause_countdown.set_label_text("2")
	await get_tree().create_timer(0.5).timeout
	$Pause_countdown.set_label_text("1")
	await get_tree().create_timer(0.5).timeout
	$Pause_countdown.visible = false
	
	# continue game play
	song_player.play(pause_position)
	_transition_game_state(gamestate_playing)

func _on_BeepSaberMainMenu_difficulty_changed(map_info: MapInfo.Map, diff_name: String, diff_rank: int) -> void:
	_current_diff_name = diff_name
	_current_diff_rank = diff_rank
	
	# menu loads playlist in _ready(), must yield until scene is loaded
	if not highscore_canvas:
		await self.ready
	
	highscore_canvas._show()
	highscore_panel.load_highscores(map_info,diff_rank)

func _on_BeepSaberMainMenu_settings_requested() -> void:
	_transition_game_state(gamestate_settings)

func _on_settings_Panel_apply() -> void:
	_transition_game_state(gamestate_mapselection)

func _on_Keyboard_highscore_text_input_enter(text: String) -> void:
	if gamestate == gamestate_newhighscore:
		_submit_highscore(text)

func _on_NameSelector_name_selected(name: String) -> void:
	if gamestate == gamestate_newhighscore:
		_submit_highscore(name)

func _on_BeepCubePool_scene_instanced(cube: BeepCube) -> void:
	cube.visible = false
	track.add_child(cube)
