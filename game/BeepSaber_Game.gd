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

var _in_wall := false

#prevents the song for starting from the start when pausing and unpausing
var pause_position := 0.0

#settings
var cube_cuts_falloff := true
var bombs_enabled := true

func start_map(info: Map.Info, map_difficulty: int) -> void:
	var set0 := info.difficulty_beatmaps
	if (set0.is_empty()):
		vr.log_error("No _difficultyBeatmaps in set")
		return
	Map.current_difficulty_index = map_difficulty
	
	var map_data := vr.load_json_file(info.filepath + set0[map_difficulty].beatmap_filename)
	if not map_data.has("_notes"):
		print("Map has no '_notes'")
		return
	Map.current_info = info
	Map.load_beatmap_v2(map_data)
	
	set_colors_from_map(info.custom_data, info.difficulty_beatmaps[map_difficulty].custom_data)
	
	print("loading: ",info.filepath + info.song_filename)
	var stream := AudioStreamOggVorbis.load_from_file(info.filepath + info.song_filename)
	
	song_player.stream = stream
	_audio_synced_after_restart = false
	song_player.play(0.0)
	song_player.volume_db = 0.0
	_in_wall = false
	Scoreboard.restart()
	
	_display_points()
	percent_indicator.start_map()
	update_saber_colors()
	if Map.event_stack.size() > 0:
		event_driver.set_all_off()
	else:
		event_driver.set_all_on(COLOR_LEFT, COLOR_RIGHT)
	
	_clear_track()
	_transition_game_state(gamestate_playing)

func set_colors_from_map(info_data: Dictionary, diff_data: Dictionary) -> void:
	var set_colors := func(data: Dictionary, color_name: String) -> void:
		var left_name := color_name % "Left"
		var right_name := color_name % "Right"
		if (
			data.has(left_name) and data.has(right_name)
			and data[left_name] is Dictionary and data[right_name] is Dictionary
		):
			var left := data[left_name] as Dictionary
			var right := data[right_name] as Dictionary
			COLOR_LEFT_ONCE = Color(
				Map.get_float(left, "r", COLOR_LEFT.r),
				Map.get_float(left, "g", COLOR_LEFT.g),
				Map.get_float(left, "b", COLOR_LEFT.b)
			)
			COLOR_RIGHT_ONCE = Color(
				Map.get_float(right, "r", COLOR_RIGHT.r),
				Map.get_float(right, "g", COLOR_RIGHT.g),
				Map.get_float(right, "b", COLOR_RIGHT.b)
			)
	COLOR_LEFT_ONCE = Color.TRANSPARENT
	COLOR_RIGHT_ONCE = Color.TRANSPARENT
	set_colors.call(info_data, "_envColor%sBoost")
	set_colors.call(diff_data, "_envColor%sBoost")
	set_colors.call(info_data, "_envColor%s")
	set_colors.call(diff_data, "_envColor%s")
	set_colors.call(info_data, "_color%s")
	set_colors.call(diff_data, "_color%s")

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

# call this method to submit a new highscore to the database
func _submit_highscore(player_name: String) -> void:
	if gamestate == gamestate_newhighscore:
		Highscores.add_highscore(
			Map.current_info,
			Map.current_difficulty.difficulty_rank,
			player_name,
			Scoreboard.points)
			
		_transition_game_state(gamestate_mapcomplete)

func _get_color_left() -> Color:
	if disable_map_color: return COLOR_LEFT
	return COLOR_LEFT_ONCE if COLOR_LEFT_ONCE != Color.TRANSPARENT else COLOR_LEFT

func _get_color_right() -> Color:
	if disable_map_color: return COLOR_RIGHT
	return COLOR_RIGHT_ONCE if COLOR_RIGHT_ONCE != Color.TRANSPARENT else COLOR_RIGHT

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
	
	gamestate._physics_process(self)
	
	_check_and_update_saber(left_controller, left_saber)
	_check_and_update_saber(right_controller, right_saber)

func _ready() -> void:
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
	start_map(Map.current_info, Map.current_difficulty_index)
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

func _on_BeepSaberMainMenu_difficulty_changed(map_info: Map.Info, diff_name: String, diff_rank: int) -> void:
	Map.current_difficulty = null
	for diff in map_info.difficulty_beatmaps:
		if diff_rank == diff.difficulty_rank:
			Map.current_difficulty = diff
			break
	
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
