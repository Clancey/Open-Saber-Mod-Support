# This is a stand-alone version of the demo game Beep Saber. It started (and is still included)
# in the godot oculus quest toolkit (https://github.com/NeoSpark314/godot_oculus_quest_toolkit)
# But this stand-alone version as additional features and will be developed independently
# This file contains the main game logic for the BeepSaber demo implementation
extends Node3D
class_name BeepSaber_Game

var version := "0.5.0"

var gamestate_bootup := GameState.new()
var gamestate_failed := GameStateFailed.new()
var gamestate_mapcomplete := GameStateMapComplete.new()
var gamestate_mapselection := GameStateMapSelection.new()
var gamestate_newhighscore := GameStateNewHighScore.new()
var gamestate_paused := GameStatePaused.new()
var gamestate_playing := GameStatePlaying.new()
var gamestate_settings := GameStateSettings.new()
var gamestate: GameState = gamestate_bootup

@onready var xr_origin := $XROrigin3D as XROrigin3D
@onready var left_controller := $XROrigin3D/LeftController as BeepSaberController
@onready var right_controller := $XROrigin3D/RightController as BeepSaberController
@onready var left_saber := $XROrigin3D/LeftController/LeftLightSaber as LightSaber
@onready var right_saber := $XROrigin3D/RightController/RightLightSaber as LightSaber
@onready var left_ui_raycast := $XROrigin3D/LeftController/LeftLightSaber/UIRaycast as UIRaycast
@onready var right_ui_raycast := $XROrigin3D/RightController/RightLightSaber/UIRaycast as UIRaycast
@onready var goggles_shader := ($XROrigin3D/XRCamera3D/VRGoggles as MeshInstance3D).material_override as ShaderMaterial
@onready var debug_info_label := $XROrigin3D/XRCamera3D/PlayerHead/DebugInfoLabel as MeshInstance3D

@onready var main_menu := $MainMenu_OQ_UI2DCanvas as OQ_UI2DCanvas
@onready var pause_menu := $PauseMenu_canvas as OQ_UI2DCanvas
@onready var pause_countdown := $Pause_countdown as OQ_UI2DLabel
@onready var pause_countdown_viewport := $Pause_countdown/SubViewport as SubViewport
@onready var settings_canvas := $Settings_canvas as OQ_UI2DCanvas
@onready var settings_panel := settings_canvas.ui_control as SettingsPanel
@onready var highscore_canvas := $Highscores_Canvas as OQ_UI2DCanvas
@onready var highscore_panel := highscore_canvas.ui_control as HighscorePanel
@onready var name_selector_canvas := $NameSelector_Canvas as OQ_UI2DCanvas
@onready var highscore_keyboard := $Keyboard_highscore as OQ_UI2DKeyboard
@onready var endscore := $EndScore as EndScore

@onready var points_label_driver := $Points_label_driver as PointsLabelDriver
@onready var event_driver := $event_driver as EventDriver
@onready var world_environment := $WorldEnvironment as WorldEnvironment

@onready var multiplier_label := $Multiplier_Label as MeshInstance3D
@onready var point_label := $Point_Label as MeshInstance3D
@onready var percent_indicator := $Percent_Indicator as PercentIndicator
@onready var energy_bar := $EnergyBar as EnergyBar

@onready var map_source_dialogs := $MapSourceDialogs as Node3D
@onready var online_search_keyboard := $Keyboard_online_search as OQ_UI2DKeyboard

@onready var cube_template := preload("res://game/BeepCube/BeepCube.tscn").instantiate() as BeepCube

@onready var track := $Track as Node3D
@onready var standing_ground := $StandingGround as Floor
@onready var cube_pool := $BeepCubePool as ScenePool
@onready var link_pool := $ChainLinkPool as ScenePool
@onready var bomb_pool := $BombPool as ScenePool
@onready var wall_pool := $WallPool as ScenePool
@onready var arc_pool := $ArcPool as ScenePool

@onready var song_player := $SongPlayer as AudioStreamPlayer

@onready var menu := main_menu.ui_control as MainMenu


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
var _environment_left_color: Color = Color.BLACK
var _environment_right_color: Color = Color.BLACK

#prevents the song for starting from the start when pausing and unpausing
var pause_position := 0.0

class MapLoadResult:
	extends RefCounted

	var succeeded: bool = false
	var error_message: String = ""
	var song_stream: AudioStreamOggVorbis

var is_loading_map: bool = false
var _load_generation: int = 0
var _load_thread: Thread

func start_map(info: MapInfo, map_difficulty: DifficultyInfo) -> void:
	_load_generation += 1
	var generation: int = _load_generation
	is_loading_map = true
	Scoreboard.paused = true
	song_player.stop()

	while _load_thread != null:
		await get_tree().process_frame
		if generation != _load_generation:
			return

	Map.prepare_beatmap_load(info, map_difficulty)
	var map_filename: String = info.filepath + map_difficulty.beatmap_filename
	var song_filename: String = info.filepath + info.song_filename
	_load_thread = Thread.new()
	var start_error: Error = _load_thread.start(
		_load_map_worker.bind(info, map_difficulty, map_filename, song_filename)
	)
	if start_error != OK:
		_load_thread = null
		_finish_failed_map_load(generation, "Could not start map loading thread")
		return

	while _load_thread.is_alive():
		await get_tree().process_frame

	var thread_result: Variant = _load_thread.wait_to_finish()
	_load_thread = null
	if generation != _load_generation:
		return
	for warning: String in Map.load_warnings:
		vr.log_warning(warning)
	for info_message: String in Map.load_info_messages:
		vr.log_info(info_message)
	var result: MapLoadResult = thread_result as MapLoadResult
	if result == null or not result.succeeded:
		var error_message: String = "Could not load map"
		if result != null and not result.error_message.is_empty():
			error_message = result.error_message
		_finish_failed_map_load(generation, error_message)
		return

	update_left_color(Map.color_left)
	update_right_color(Map.color_right)
	if Map.event_stack.is_empty():
		event_driver.set_all_on(Map.color_left, Map.color_right)
	else:
		event_driver.set_all_off()

	vr.log_info("loading: " + song_filename)
	song_player.stream = result.song_stream
	_audio_synced_after_restart = false
	song_player.volume_db = 0.0
	_in_wall = false
	Scoreboard.restart()
	_display_points()
	percent_indicator.start_map()
	_clear_track()
	track.visible = true
	var prewarm_completed: bool = await _prewarm_map_start(generation)
	if not prewarm_completed:
		return

	is_loading_map = false
	song_player.play(0.0)
	_transition_game_state(gamestate_playing)

static func _load_map_worker(
	info: MapInfo,
	map_difficulty: DifficultyInfo,
	map_filename: String,
	song_filename: String
) -> MapLoadResult:
	var result := MapLoadResult.new()
	var map_data: Dictionary = Map.load_json_file_threaded(map_filename)
	if map_data.is_empty():
		result.error_message = "Could not read map data from " + map_filename
		return result
	if not Map.load_beatmap(info, map_difficulty, map_data):
		result.error_message = Map.load_error
		return result
	result.song_stream = AudioStreamOggVorbis.load_from_file(song_filename)
	if result.song_stream == null:
		result.error_message = "Could not load OGG audio from " + song_filename
		return result
	result.succeeded = true
	return result

func _prewarm_map_start(generation: int) -> bool:
	await get_tree().process_frame
	var stable_frames: int = 0
	var deadline_msec: int = Time.get_ticks_msec() + 2000
	while stable_frames < 3 and Time.get_ticks_msec() < deadline_msec:
		await get_tree().process_frame
		if generation != _load_generation:
			return false
		if get_process_delta_time() < 1.0 / 40.0:
			stable_frames += 1
		else:
			stable_frames = 0
	return generation == _load_generation

func _finish_failed_map_load(generation: int, error_message: String) -> void:
	if generation != _load_generation:
		return
	vr.log_error(error_message)
	is_loading_map = false
	_clear_track()
	_transition_game_state(gamestate_mapselection)

func _exit_tree() -> void:
	_load_generation += 1
	if _load_thread != null:
		_load_thread.wait_to_finish()
		_load_thread = null

# This function will transitioning the game from it's current state into
# the provided 'next_state'.
func _transition_game_state(next_state: GameState) -> void:
	gamestate = next_state
	energy_bar.visible = next_state == gamestate_playing or next_state == gamestate_paused
	gamestate._ready(self)

func show_MapSourceDialogs(showing: bool = true) -> void:
	map_source_dialogs.visible = showing
	for c in map_source_dialogs.get_children():
		if c is OQ_UI2DCanvas:
			(c as OQ_UI2DCanvas)._hide()
	if showing:
		var first_dialog := map_source_dialogs.get_child(0)
		if first_dialog is OQ_UI2DCanvas:
			(first_dialog as OQ_UI2DCanvas)._show()

# call this method to submit a new highscore to the database
func _submit_highscore(player_name: String) -> void:
	if gamestate == gamestate_newhighscore:
		Highscores.add_highscore(
			Map.current_info,
			Map.current_difficulty.difficulty_rank,
			player_name,
			Scoreboard.points)
			
		_transition_game_state(gamestate_mapcomplete)

func _check_and_update_saber(controller: BeepSaberController, saber: LightSaber) -> void:
	# Allow extending/sheathing sabers only from the map selection menu.
	if ((gamestate == gamestate_mapselection)
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
	if debug_info_label.visible:
		var dbg_text := "FPS: %d\nCube Pool: %d free of %d\nLink Pool: %d free of %d\nBomb Pool: %d free of %d\nWall Pool: %d free of %d\nArc Pool: %d free of %d" % [
			Engine.get_frames_per_second(),
			GlobalReferences.cube_pool.free_count(), GlobalReferences.cube_pool.total_count(),
			GlobalReferences.link_pool.free_count(), GlobalReferences.link_pool.total_count(),
			bomb_pool.free_count(), bomb_pool.total_count(),
			wall_pool.free_count(), wall_pool.total_count(),
			arc_pool.free_count(), arc_pool.total_count()]
		(debug_info_label.mesh as TextMesh).text = dbg_text
	
	if gamestate == gamestate_playing and _in_wall:
		Scoreboard.drain(dt)

	gamestate._physics_process(self)
	
	_check_and_update_saber(left_controller, left_saber)
	_check_and_update_saber(right_controller, right_saber)

func _enter_tree() -> void:
	GlobalReferences.main_game_scene = self
	
	@warning_ignore("return_value_discarded")
	Settings.changed.connect(on_settings_changed)

func _ready() -> void:
	@warning_ignore("return_value_discarded")
	pause_countdown.visibility_changed.connect(_sync_pause_countdown_viewport)
	@warning_ignore("return_value_discarded")
	event_driver.environment_palette_changed.connect(_on_environment_palette_changed)
	_sync_pause_countdown_viewport()

	# pre-allocate scenes in our scene pools
	GlobalReferences.cube_pool = cube_pool
	GlobalReferences.link_pool = link_pool
	cube_pool.presize(100)
	link_pool.presize(100)
	bomb_pool.presize(16)
	wall_pool.presize(16)
	arc_pool.presize(8)
	await _flush_presize_render_batch()
	
	var xr_camera := $XROrigin3D/XRCamera3D as XRCamera3D
	vr.initialize(
		xr_origin,
		xr_camera,
		left_controller,
		right_controller
	)
	_connect_xr_session_signals()
	var primary_interface := XRServer.primary_interface
	if vr.inVR and primary_interface != null:
		var display_refresh_rate: float = primary_interface.get_display_refresh_rate()
		if display_refresh_rate > 0.0:
			Engine.physics_ticks_per_second = int(round(display_refresh_rate))
	
	debug_info_label.visible = Settings.show_debug_info
	set_colors_from_settings()
	world_environment.environment.glow_enabled = Settings.glare
	
	if not vr.inVR:
		xr_origin.add_child(preload("res://OQ_Toolkit/OQ_ARVROrigin/Feature_VRSimulator.tscn").instantiate())
	
	UI_AudioEngine.attach_children(highscore_keyboard)
	UI_AudioEngine.attach_children(online_search_keyboard)
	
	_transition_game_state(gamestate_mapselection)
	
	@warning_ignore("return_value_discarded")
	Scoreboard.score_changed.connect(_display_points)
	@warning_ignore("return_value_discarded")
	Scoreboard.points_awarded.connect(points_label_driver.show_points)
	@warning_ignore("return_value_discarded")
	Scoreboard.level_failed.connect(_on_level_failed)
	
	#render common assets for a couple of frames to prevent performance issues when loading them mid game
	($pre_renderer as Node3D).visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	($pre_renderer as Node3D).queue_free()
	
	recenter()

func _connect_xr_session_signals() -> void:
	if not vr.inVR or not is_instance_valid(vr.xr_interface):
		return
	var xr_interface: XRInterface = vr.xr_interface
	var signal_handlers: Dictionary[StringName, Callable] = {
		&"session_visible": _on_xr_session_visible,
		&"session_stopping": _on_xr_session_stopping,
		&"pose_recentered": _on_xr_pose_recentered,
		&"session_focussed": _on_xr_session_focussed,
	}
	for signal_name: StringName in signal_handlers:
		var handler: Callable = signal_handlers[signal_name]
		if xr_interface.has_signal(signal_name) and not xr_interface.is_connected(signal_name, handler):
			@warning_ignore("return_value_discarded")
			xr_interface.connect(signal_name, handler)

func _on_xr_session_visible() -> void:
	if gamestate == gamestate_playing:
		_transition_game_state(gamestate_paused)

func _on_xr_session_stopping() -> void:
	if gamestate == gamestate_playing:
		_transition_game_state(gamestate_paused)
	if song_player.playing:
		song_player.stop()

func _on_xr_pose_recentered() -> void:
	recenter()

func _on_xr_session_focussed() -> void:
	pass

func _sync_pause_countdown_viewport() -> void:
	pause_countdown_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS
		if pause_countdown.is_visible_in_tree()
		else SubViewport.UPDATE_DISABLED
	)

func on_settings_changed(key: StringName) -> void:
	# ensures proper initialization of tree for proper first frame setting loading
	await get_tree().process_frame
	match key:
		&"color_left":
			update_left_color(Settings.color_left)
		&"color_right":
			update_right_color(Settings.color_right)
		&"events":
			disable_events(not Settings.events)
		&"show_debug_info":
			debug_info_label.visible = Settings.show_debug_info
		&"glare":
			world_environment.environment.glow_enabled = Settings.glare
		&"player_height_offset":
			xr_origin.transform.origin.y = Settings.player_height_offset

func set_colors_from_settings() -> void:
	update_left_color(Settings.color_left)
	update_right_color(Settings.color_right)

func update_left_color(color: Color) -> void:
	if !left_saber:
		await get_tree().process_frame
	_environment_left_color = color
	energy_bar.set_colors(_environment_left_color, _environment_right_color)
	left_saber.set_color(color)
	Arc.left_color = color
	Arc.left_material.set_shader_parameter(&"color", color)
	goggles_shader.set_shader_parameter(&"left_color", color)
	event_driver.update_left_color(color)
	standing_ground.update_left_color(color)
	_update_environment_tint()

func update_right_color(color: Color) -> void:
	if !left_saber:
		await get_tree().process_frame
	_environment_right_color = color
	energy_bar.set_colors(_environment_left_color, _environment_right_color)
	right_saber.set_color(color)
	Arc.right_color = color
	Arc.right_material.set_shader_parameter(&"color", color)
	goggles_shader.set_shader_parameter(&"right_color", color)
	event_driver.update_right_color(color)
	standing_ground.update_right_color(color)
	_update_environment_tint()

func _on_environment_palette_changed(color_left: Color, color_right: Color) -> void:
	_environment_left_color = color_left
	_environment_right_color = color_right
	_update_environment_tint()

func _update_environment_tint() -> void:
	var left_hue: float = _environment_left_color.h
	var right_hue: float = _environment_right_color.h
	var hue_delta: float = fposmod(right_hue - left_hue + 0.5, 1.0) - 0.5
	var average_hue: float = fposmod(left_hue + hue_delta * 0.5, 1.0)
	var average_saturation: float = minf(
		(_environment_left_color.s + _environment_right_color.s) * 0.5,
		0.35
	)
	var average_value: float = clampf(
		(_environment_left_color.v + _environment_right_color.v) * 0.5,
		0.0,
		1.0
	) * 0.12
	world_environment.environment.fog_light_color = Color.from_hsv(
		average_hue,
		average_saturation,
		average_value,
		1.0
	)

func disable_events(disabled: bool) -> void:
	event_driver.disabled = disabled
	if disabled:
		event_driver.set_all_off()
	else:
		event_driver.set_all_on(Settings.color_left, Settings.color_right)

func _clear_track() -> void:
	for c in track.get_children():
		if c.has_method("clear_from_track"):
			c.clear_from_track()
		else:
			track.remove_child(c)
			c.queue_free()

func _display_points() -> void:
	var hit_rate: float
	if Scoreboard.right_notes+Scoreboard.wrong_notes > 0:
		hit_rate = Scoreboard.right_notes/(Scoreboard.right_notes+Scoreboard.wrong_notes)
	else:
		hit_rate = 1.0
	
	(point_label.mesh as TextMesh).text = "Score: %6d" % Scoreboard.points
	(multiplier_label.mesh as TextMesh).text = "x %d\nCombo %d" % [Scoreboard.multiplier, Scoreboard.combo]
	percent_indicator.update_percent(hit_rate)

# accessor method for the player name selector UI element
func _name_selector() -> NameSelector:
	return name_selector_canvas.ui_control

func _on_PlayerHead_area_entered(area: Area3D) -> void:
	if area.is_in_group(&"wall"):
		song_player.volume_db = -15.0
		_in_wall = true

func _on_PlayerHead_area_exited(area: Area3D) -> void:
	if area.is_in_group(&"wall"):
		song_player.volume_db = 0.0
		_in_wall = false

# when the song ended we want to display the current score and
# the high score
func _on_song_ended() -> void:
	if gamestate != gamestate_playing:
		return
	song_player.stop()
	Scoreboard.paused = true
	_clear_track()
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

	var current_percent: float
	if Scoreboard.right_notes + Scoreboard.wrong_notes > 0:
		current_percent = Scoreboard.right_notes / (Scoreboard.right_notes + Scoreboard.wrong_notes)
	else:
		current_percent = 1.0
	endscore.show_score(
		Scoreboard.points,
		highscore,
		current_percent,
		"%s By %s\n%s     Map author: %s" % [
			Map.current_info.song_name,
			Map.current_info.song_author_name,
			Map.current_difficulty.custom_name,
			Map.current_info.level_author_name],
		Scoreboard.full_combo,
		new_record
	)
	
	if Highscores.is_new_highscore(Map.current_info,Map.current_difficulty.difficulty_rank,Scoreboard.points):
		_transition_game_state(gamestate_newhighscore)
	else:
		_transition_game_state(gamestate_mapcomplete)

func _on_level_failed() -> void:
	if gamestate == gamestate_playing:
		_transition_game_state(gamestate_failed)

func _restart_button() -> void:
	start_map(Map.current_info, Map.current_difficulty)
	endscore._hide()
	pause_menu.visible = false

func _main_menu_button() -> void:
	_load_generation += 1
	is_loading_map = false
	_clear_track()
	_transition_game_state(gamestate_mapselection)

func _unpause_button() -> void:
	pause_menu.visible = false
	pause_countdown.visible = true
	track.visible = true
	pause_countdown.set_label_text("3")
	await get_tree().create_timer(0.5).timeout
	pause_countdown.set_label_text("2")
	await get_tree().create_timer(0.5).timeout
	pause_countdown.set_label_text("1")
	await get_tree().create_timer(0.5).timeout
	pause_countdown.visible = false
	
	# continue game play
	song_player.play(pause_position)
	_transition_game_state(gamestate_playing)

func _on_BeepSaberMainMenu_difficulty_changed(map_info: MapInfo, diff_rank: int) -> void:
	# menu loads playlist in _ready(), must yield until scene is loaded
	if not highscore_canvas:
		await self.ready
	
	highscore_canvas._show()
	highscore_panel.load_highscores(map_info,diff_rank)

func _settings_button() -> void:
	_transition_game_state(gamestate_settings)

func _on_settings_Panel_apply() -> void:
	set_colors_from_settings()
	_transition_game_state(gamestate_mapselection)

var _presize_render_batch: Array[Node3D] = []

func _on_ScenePool_new_scene_instanced(obj: Node3D, during_presizing: bool) -> void:
	# add obj to the track. it will reside inside the track for eternity, only
	# to be reposition and made visible again when it is acquired and spawned.
	track.add_child(obj)
	
	# Render presized scenes in batches so their shaders are loaded without
	# yielding once for every individual object.
	if during_presizing:
		obj.position.z = -2.0
		_presize_render_batch.append(obj)
		if _presize_render_batch.size() < 20:
			return

		await _flush_presize_render_batch()

func _flush_presize_render_batch() -> void:
	if _presize_render_batch.is_empty():
		return
	var render_batch: Array[Node3D] = _presize_render_batch.duplicate()
	_presize_render_batch.clear()
	await get_tree().process_frame
	for pooled_obj: Node3D in render_batch:
		_hide_pooled_scene(pooled_obj)

func _hide_pooled_scene(obj: Node3D) -> void:
	if obj is BeepCube:
		(obj as BeepCube).hide_cube()
	elif obj is ChainLink:
		(obj as ChainLink).hide_cube()
	elif obj is Bomb:
		(obj as Bomb).hide_bomb()
	elif obj is Wall:
		(obj as Wall).hide_wall()
	elif obj is Arc:
		(obj as Arc).hide_arc()
	else:
		obj.visible = false
		obj.process_mode = Node.PROCESS_MODE_DISABLED

func recenter() -> void:
	var xr_camera := $XROrigin3D/XRCamera3D as XRCamera3D
	xr_origin.rotation.y -= xr_camera.global_rotation.y
	xr_origin.position -= (xr_camera.global_position * Vector3(1,0,1)) - Vector3(0,0,1)
