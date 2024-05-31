# This file contains the main game logic for the BeepSaber demo implementation
#
extends Node3D
class_name BeepSaber_Game

static var game: BeepSaber_Game

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
@onready var dominant_hand := right_controller
@onready var non_dominant_hand := left_controller

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

@onready var multiplier_label := $Multiplier_Label as MeshInstance3D
@onready var point_label := $Point_Label as MeshInstance3D
@onready var percent_indicator := $Percent_Indicator as PercentIndicator

@onready var map_source_dialogs := $MapSourceDialogs as Node3D
@onready var online_search_keyboard := $Keyboard_online_search as OQ_UI2DKeyboard

@onready var fps_label = $XROrigin3D/XRCamera3D/PlayerHead/FPS_Label

@onready var cube_template = preload("res://game/BeepCube.tscn").instantiate()
@onready var wall_template = preload("res://game/Wall/Wall.tscn").instantiate()
@onready var LinkedList := preload("res://game/scripts/LinkedList.gd")

@onready var _cube_pool := $BeepCubePool

@onready var track := $Track as Node3D

@onready var song_player := $SongPlayer as AudioStreamPlayer

@onready var menu := main_menu.ui_control as MainMenu

var COLOR_LEFT := Color(1.0, 0.1, 0.1, 1.0) : get = _get_color_left
var COLOR_RIGHT := Color(0.1, 0.1, 1.0, 1.0) : get = _get_color_right

var COLOR_LEFT_ONCE: Color = Color.TRANSPARENT;
var COLOR_RIGHT_ONCE: Color = Color.TRANSPARENT;
var disable_map_color = false;

var _current_map := {}
var _current_note_speed = 1.0
var _current_info := {}
var _current_note = 0
var _current_obstacle = 0
var _current_event = 0

var _cut_cube_sw := StopwatchFactory.create("cute_cube",10,true)
var _update_points_sw := StopwatchFactory.create("update_points",10,true)
var _create_cut_pieces_sw := StopwatchFactory.create("create_cut_pieces",10,true)

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
var _audio_synced_after_restart = false

# current difficulty name (Easy, Normal, Hard, etc.)
var _current_diff_name := ""
# current difficulty rank (1,3,5,etc.)
var _current_diff_rank := -1


var _in_wall = false;

#prevents the song for starting from the start when pausing and unpausing
var pause_position = 0.0;

#settings
var cube_cuts_falloff = true
var bombs_enabled = true

func restart_map():
	_audio_synced_after_restart = false
	song_player.play(0.0)
	song_player.volume_db = 0.0
	_in_wall = false
	_current_note = 0
	_current_obstacle = 0
	_current_event = 0
	Scoreboard.restart()

	_display_points()
	percent_indicator.start_map()
	update_saber_colors()
	if _current_map.has("_events") and _current_map._events.size() > 0:
		$event_driver.set_all_off()
	else:
		$event_driver.set_all_on()
	
	_clear_track()
	_transition_game_state(gamestate_playing)

func start_map(info: Dictionary, map_data: Dictionary, map_difficulty: int):
	if !map_data.has("_notes"): 
		print("Map has no '_notes'")
		return
	_current_map = map_data
	_current_info = info
	
	set_colors_from_map(info, map_difficulty)
	
	print("loading: ",info._path + info._songFilename)
	var stream := AudioStreamOggVorbis.load_from_file(info._path + info._songFilename)
	
	song_player.stream = stream
	restart_map()

func set_colors_from_map(info: Dictionary, map_difficulty: int):
	COLOR_LEFT_ONCE = Color.TRANSPARENT
	COLOR_RIGHT_ONCE = Color.TRANSPARENT
	var roots := []
	for color_name in ["_envColor%sBoost", "_envColor%s", "_color%s"]:
		if info.has("_customData"): 
			roots.append(info["_customData"])
		if info["_difficultyBeatmapSets"][0]["_difficultyBeatmaps"][map_difficulty].has("_customData"): 
			roots.append(info["_difficultyBeatmapSets"][0]["_difficultyBeatmaps"][map_difficulty]["_customData"])
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
func _transition_game_state(next_state: GameState):
	gamestate = next_state
	gamestate._ready(self)

func show_MapSourceDialogs(showing := true):
	map_source_dialogs.visible = showing
	for c in map_source_dialogs.get_children():
		c._hide()
	if showing:
		map_source_dialogs.get_child(0)._show()

# when the song ended we want to display the current score and
# the high score
func _on_song_ended():
	song_player.stop();
	PlayCount.increment_play_count(_current_info,_current_diff_rank)
	
	var new_record = false
	var highscore = Highscores.get_highscore(_current_info,_current_diff_rank)
	if highscore == null:
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
			_current_info["_songName"],
			_current_info["_songAuthorName"],
			menu._map_difficulty_name,
			_current_info["_levelAuthorName"]],
		Scoreboard.full_combo,
		new_record
	)
	
	if Highscores.is_new_highscore(_current_info,_current_diff_rank,Scoreboard.points):
		_transition_game_state(gamestate_newhighscore)
	else:
		_transition_game_state(gamestate_mapcomplete)

# call this method to submit a new highscore to the database
func _submit_highscore(player_name: String):
	if gamestate == gamestate_newhighscore:
		Highscores.add_highscore(
			_current_info,
			_current_diff_rank,
			player_name,
			Scoreboard.points)
			
		_transition_game_state(gamestate_mapcomplete)

const beat_distance := 4.0
const beats_ahead := 4.0
const CUBE_ROTATIONS: Array[float] = [180, 0, 270, 90, -135, 135, -45, 45, 0]

func _get_color_left():
	if disable_map_color: return COLOR_LEFT
	return COLOR_LEFT_ONCE if COLOR_LEFT_ONCE != Color.TRANSPARENT else COLOR_LEFT

func _get_color_right():
	if disable_map_color: return COLOR_RIGHT
	return COLOR_RIGHT_ONCE if COLOR_RIGHT_ONCE != Color.TRANSPARENT else COLOR_RIGHT

func _spawn_event(data,beat):
	$event_driver.procces_event(data,beat)

func _check_and_update_saber(controller: BeepSaberController, saber: Area3D):
	# to allow extending/sheething the saber while not playing a song
	if ((not song_player.playing)
		and (controller.ax_just_pressed() or controller.by_just_pressed())
		and (not saber._anim.is_playing())):
		if (saber.is_extended()): saber._hide()
		else: saber._show()
					
	
	# check for saber rumble (only when extended and not already rumbling)
	# this check is necessary to not overwrite a rumble set from somewhere else
	# (in this case it can come from cutting cubes)
	if (!controller.is_simple_rumbling()): 
		if (_in_wall):
			# weak rumble on both controllers when player is inside wall
			controller.simple_rumble(0.1, 0.1);
		elif (saber.get_overlapping_areas().size() > 0 || saber.get_overlapping_bodies().size() > 0):
			# strong rumble when saber is cutting into wall or other saber
			controller.simple_rumble(0.5, 0.1);
		else:
			controller.simple_rumble(0.0, 0.1);


func _physics_process(dt: float) -> void:
	if fps_label.visible:
		fps_label.set_label_text("FPS: %d" % Engine.get_frames_per_second())
	
	gamestate._physics_process(self, dt)
	
	_check_and_update_saber(left_controller, left_saber)
	_check_and_update_saber(right_controller, right_saber)

var _main_menu = null
var _lpf = null

func _ready() -> void:
	_main_menu = main_menu.find_child("BeepSaberMainMenu", true, false)
	_main_menu.initialize(self);
	$MapSourceDialogs/BeatSaver_Canvas.ui_control.main_menu_node = _main_menu
	vr.vrOrigin = $XROrigin3D
	vr.vrCamera = $XROrigin3D/XRCamera3D
	vr.leftController = left_controller
	vr.rightController = right_controller
	
	if !vr.inVR:
		$XROrigin3D.add_child(preload("res://OQ_Toolkit/OQ_ARVROrigin/Feature_VRSimulator.tscn").instantiate())
	update_saber_colors()
	game = self
	
	UI_AudioEngine.attach_children(highscore_keyboard)
	UI_AudioEngine.attach_children(online_search_keyboard)
	
	_transition_game_state(gamestate_mapselection)
	
	#render common assets for a couple of frames to prevent performance issues when loading them mid game
	$pre_renderer.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	$pre_renderer.queue_free()
	
	Scoreboard.score_changed.connect(_display_points)
	Scoreboard.points_awarded.connect(points_label_driver.show_points)

func update_saber_colors():
	left_saber.set_color(COLOR_LEFT)
	right_saber.set_color(COLOR_RIGHT)
	#also updates map colors
	$event_driver.update_colors()
	$StandingGround.update_colors(COLOR_LEFT,COLOR_RIGHT)

func disable_events(disabled):
	$event_driver.disabled = disabled
	if disabled:
		$event_driver.set_all_off()
	else:
		$event_driver.set_all_on()

func _clear_track():
	for c in track.get_children():
		if c is BeepCube:
			if c.visible:
				c.release()
		else:
			c.visible = false;
			track.remove_child(c);
			c.queue_free();

func _display_points():
	var hit_rate: float
	if Scoreboard.right_notes+Scoreboard.wrong_notes > 0:
		hit_rate = Scoreboard.right_notes/(Scoreboard.right_notes+Scoreboard.wrong_notes)
	else:
		hit_rate = 1.0
	
	(point_label.mesh as TextMesh).text = "Score: %6d" % Scoreboard.points
	(multiplier_label.mesh as TextMesh).text = "x %d\nCombo %d" % [Scoreboard.multiplier, Scoreboard.combo]
	percent_indicator.update_percent(hit_rate)

# quiets song when player enters into a wall
func _quiet_song():
	song_player.volume_db = -15.0;

# restores song volume when player leaves wall
func _louden_song():
	song_player.volume_db = 0.0;

# accessor method for the player name selector UI element
func _name_selector() -> NameSelector:
	return name_selector_canvas.ui_control

func _on_PlayerHead_area_entered(area):
	if area.is_in_group("wall"):
		if not _in_wall:
			_quiet_song();
		
		_in_wall = true;

func _on_PlayerHead_area_exited(area):
	if area.is_in_group("wall"):
		if _in_wall:
			_louden_song();
		
		_in_wall = false;


func _on_EndScore_panel_repeat():
	restart_map()
	endscore.visible = false
	pause_menu.visible = false


func _on_EndScore_panel_goto_mainmenu():
	_clear_track()
	_transition_game_state(gamestate_mapselection)


func _on_Pause_Panel_continue_button():
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

func _on_BeepSaberMainMenu_difficulty_changed(map_info: Dictionary, diff_name: String, diff_rank: int):
	_current_diff_name = diff_name
	_current_diff_rank = diff_rank
	
	# menu loads playlist in _ready(), must yield until scene is loaded
	if not highscore_canvas:
		await self.ready
	
	highscore_canvas._show()
	highscore_panel.load_highscores(map_info,diff_rank)

func _on_BeepSaberMainMenu_settings_requested():
	_transition_game_state(gamestate_settings)

func _on_settings_Panel_apply():
	_transition_game_state(gamestate_mapselection)

func _on_Keyboard_highscore_text_input_enter(text: String):
	if gamestate == gamestate_newhighscore:
		_submit_highscore(text)

func _on_NameSelector_name_selected(name: String):
	if gamestate == gamestate_newhighscore:
		_submit_highscore(name)

func _on_BeepCubePool_scene_instanced(cube: Node3D):
	cube.visible = false
	$Track.add_child(cube)
