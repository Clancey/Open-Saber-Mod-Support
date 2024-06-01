# This file contains the main game logic for the BeepSaber demo implementation
#
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

@onready var multiplier_label := $Multiplier_Label as MeshInstance3D
@onready var point_label := $Point_Label as MeshInstance3D
@onready var percent_indicator := $Percent_Indicator as PercentIndicator

@onready var map_source_dialogs := $MapSourceDialogs as Node3D
@onready var online_search_keyboard := $Keyboard_online_search as OQ_UI2DKeyboard

@onready var fps_label = $XROrigin3D/XRCamera3D/PlayerHead/FPS_Label

@onready var cube_template = preload("res://game/BeepCube.tscn").instantiate();
@onready var wall_template = preload("res://game/Wall/Wall.tscn").instantiate();
@onready var LinkedList := preload("res://game/scripts/LinkedList.gd")
@export var bomb_template: PackedScene

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


var _current_points := 0;
var _current_multiplier = 1;
var _current_combo = 0;

var _in_wall = false;

var _right_notes := 0.0;
var _wrong_notes := 0.0;
var _full_combo = true;

#prevents the song for starting from the start when pausing and unpausing
var pause_position = 0.0;

#settings
var cube_cuts_falloff = true
var bombs_enabled = true

# structure of nodes that represent a cut piece of a cube (ie. one half)
class CutPieceNodes:
	extends RefCounted
	
	var rigid_body := RigidBody3D.new()
	var mesh := MeshInstance3D.new()
	var coll := CollisionShape3D.new()
	
	func _init():
		rigid_body.add_to_group("cutted_cube")
		rigid_body.collision_layer = 0
		rigid_body.collision_mask = CollisionLayerConstants.Floor_mask
		rigid_body.gravity_scale = 1
		# set a phyiscs material for some more bouncy behaviour
		rigid_body.physics_material_override = preload("res://game/BeepCube_Cut.phymat")
		
		coll.shape = BoxShape3D.new()
		
		rigid_body.add_child(coll)
		rigid_body.add_child(mesh)
		
		rigid_body.set_script(preload("res://game/BeepCube_CutFadeout.gd"))

# structure of nodes that are used to produce effects when cutting a cube
class CutCubeResources:
	extends RefCounted
	
	var particles : BeepCubeSliceParticles = null
	var piece1 := CutPieceNodes.new()
	var piece2 := CutPieceNodes.new()
	
	func _init():
		particles = preload("res://game/BeepCube_SliceParticles.tscn").instantiate() as BeepCubeSliceParticles

const MAX_CUT_CUBE_RESOURCES = 32
@onready var _cut_cube_resources := LinkedList.new()

func restart_map():
	_audio_synced_after_restart = false
	song_player.play(0.0);
	song_player.volume_db = 0.0;
	_in_wall = false;
	_current_note = 0;
	_current_obstacle = 0;
	_current_event = 0;
	_current_points = 0;
	_current_multiplier = 1;
	_current_combo = 0;

	#set_percent_to_null
	_right_notes = 0.0
	_wrong_notes = 0.0
	_full_combo = true;

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
		highscore = _current_points
	elif _current_points > highscore:
		# player's score is the new highscore!
		highscore = _current_points;
		new_record = true

	var current_percent := _right_notes/(_right_notes+_wrong_notes)
	endscore.show_score(
		_current_points,
		highscore,
		current_percent,
		"%s By %s\n%s     Map author: %s" % [
			_current_info["_songName"],
			_current_info["_songAuthorName"],
			menu._map_difficulty_name,
			_current_info["_levelAuthorName"]],
		_full_combo,
		new_record
	)
	
	if Highscores.is_new_highscore(_current_info,_current_diff_rank,_current_points):
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
			_current_points)
			
		_transition_game_state(gamestate_mapcomplete)

const beat_distance = 4.0;
const beats_ahead = 4.0;
const CUBE_ROTATIONS = [180, 0, 270, 90, -135, 135, -45, 45, 0];

func _get_color_left():
	if disable_map_color: return COLOR_LEFT
	return COLOR_LEFT_ONCE if COLOR_LEFT_ONCE != Color.TRANSPARENT else COLOR_LEFT

func _get_color_right():
	if disable_map_color: return COLOR_RIGHT
	return COLOR_RIGHT_ONCE if COLOR_RIGHT_ONCE != Color.TRANSPARENT else COLOR_RIGHT

func _spawn_event(data,beat):
	$event_driver.procces_event(data,beat)


# with this variable we track the movement volume of the controller
# since the last cut (used to give a higher score when moved a lot)
var _controller_movement_aabb = {
	"left_hand" = AABB(),
	"right_hand" = AABB(),
}


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


var left_saber_end = Vector3()
var right_saber_end = Vector3()
var left_saber_end_past = Vector3()
var right_saber_end_past = Vector3()
var last_dt = 0.0


func _update_saber_end_variabless(dt):
	left_saber_end_past = left_saber_end
	right_saber_end_past = right_saber_end
	left_saber_end = left_controller.global_transform.origin + left_saber.global_transform.basis.y
	right_saber_end = right_controller.global_transform.origin + right_saber.global_transform.basis.y
	last_dt = dt


func _physics_process(dt: float) -> void:
	if fps_label.visible:
		fps_label.set_label_text("FPS: %d" % Engine.get_frames_per_second())
	
	gamestate._physics_process(self, dt)
	
	_check_and_update_saber(left_controller, left_saber);
	_check_and_update_saber(right_controller, right_saber);
	
	_update_saber_end_variabless(dt)

var _main_menu = null
var _lpf = null

func _ready():
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

	# initialize list of cut cube resources
	for _i in range(MAX_CUT_CUBE_RESOURCES):
		var new_res := CutCubeResources.new()
		add_child(new_res.particles)
		add_child(new_res.piece1.rigid_body)
		add_child(new_res.piece2.rigid_body)
		_cut_cube_resources.push_back(new_res)

	UI_AudioEngine.attach_children(highscore_keyboard)
	UI_AudioEngine.attach_children(online_search_keyboard)

	_transition_game_state(gamestate_mapselection)
	
	#render common assets for a couple of frames to prevent performance issues when loading them mid game
	$pre_renderer.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	$pre_renderer.queue_free()

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


# cut the cube by creating two rigid bodies and using a CSGBox to create
# the cut plane
func _create_cut_rigid_body(_sign, cube : Node3D, cutplane : Plane, cut_distance, controller_speed, saber_ends, cut_res: CutCubeResources):
	if not cube_cuts_falloff: 
		return
	
	# this function gets run twice, one for each piece of the cube
	var piece : CutPieceNodes = cut_res.piece1
	if is_equal_approx(_sign,1):
		piece = cut_res.piece2
	
	# make piece invisible and stop it's processing while we're updating it
	piece.rigid_body.reset()
	
	# the original cube mesh
	piece.mesh.mesh = cube._mesh;
	piece.mesh.transform = cube._cube_mesh_orientation.transform;
	piece.mesh.material_override = cube._mat.duplicate()
	
	# calculate angle and position of the cut
	piece.mesh.material_override.set_shader_parameter("cutted",true)
	piece.mesh.material_override.set_shader_parameter("inverted_cut",!bool((_sign+1)/2))
	# TODO: cutplane is unused and replaced by this? what
	var saber_end_mov = saber_ends[0]-saber_ends[1]
	var saber_end_angle = rad_to_deg(Vector2(saber_end_mov.x,saber_end_mov.y).angle())
	var saber_end_angle_rel = (int(((saber_end_angle+90)+(360-piece.mesh.rotation_degrees.z))+180)%360)-180
	
	var rot_dir = saber_end_angle_rel > 90 or saber_end_angle_rel < -90
	var rot_dir_flt = (float(rot_dir)*2)-1
	piece.mesh.material_override.set_shader_parameter("cut_pos",cut_distance*rot_dir_flt)
	piece.mesh.material_override.set_shader_parameter("cut_angle",deg_to_rad(saber_end_angle_rel))

	# transform the normal into the orientation of the actual cube mesh
	var normal = piece.mesh.transform.basis.inverse() * cutplane.normal;
	
	# Next we are adding a simple collision cube to the rigid body. Note that
	# his is really just a very crude approximation of the actual cut geometry
	# but for now it's enough to give them some physics behaviour
	piece.coll.shape.size = Vector3(0.25, 0.25, 0.125)
	piece.coll.look_at_from_position(-cutplane.normal*_sign*0.125, cutplane.normal, Vector3(0,1,0))

	piece.rigid_body.global_transform = cube.global_transform
	piece.rigid_body.linear_velocity = Vector3.ZERO
	piece.rigid_body.angular_velocity = Vector3.ZERO
	# make piece visible and start its simulation
	piece.rigid_body.fire()
	
	# some impulse so the cube half moves
	var cutplane_2d = Vector3(saber_end_mov.x,saber_end_mov.y,0.0)
	var splitplane_2d = cutplane_2d.cross(piece.mesh.transform.basis.z)
	piece.rigid_body.apply_central_impulse((_sign * splitplane_2d * 15) + (cutplane_2d*10))
	
	# This function gets run twice so we don't want two particle effects
	if is_equal_approx(_sign,1):
		cut_res.particles.transform.origin = cube.global_transform.origin
		cut_res.particles.rotation_degrees.z = saber_end_angle+90
		cut_res.particles.fire()

func _reset_combo():
	_current_multiplier = 1;
	_current_combo = 0;
	_wrong_notes += 1.0;
	_full_combo = false;
	_display_points();
	
func _clear_track():
	for c in track.get_children():
		if c is BeepCube:
			if c.visible:
				c.release()
		else:
			c.visible = false;
			track.remove_child(c);
			c.queue_free();

func _update_points_from_cut(saber, cube, beat_accuracy, cut_angle_accuracy, cut_distance_accuracy, travel_distance_factor):
	
	#send data to saber for esthetics effects
	saber.hit(cube) 
	
	# check if we hit the cube with the correctly colored saber
	if (saber.type != cube._note._type):
		_reset_combo();
		_wrong_notes += 1.0
		$Points_label_driver.show_points(cube.transform.origin,"x")
		return;

	_current_combo += 1;
	_current_multiplier = 1 + round(min((_current_combo / 10), 7.0));

	# point computation based on the accuracy of the swing
	var points = 0;
	points += beat_accuracy * 50;
	points += cut_angle_accuracy * 50;
	points += cut_distance_accuracy * 50;
	points += points * travel_distance_factor;

	points = round(points);
	_current_points += points * _current_multiplier;
	
	$Points_label_driver.show_points(cube.transform.origin,str(points))
	# track acurracy percent
	var normalized_points = clamp(points/80, 0.0, 1.0);
	_right_notes += normalized_points;
	_wrong_notes += 1.0-normalized_points;

	_display_points();
	


func _display_points():
	var hit_rate: float
	if _right_notes+_wrong_notes > 0:
		hit_rate = _right_notes/(_right_notes+_wrong_notes)
	else:
		hit_rate = 1.0
	
	(point_label.mesh as TextMesh).text = "Score: %6d" % _current_points
	(multiplier_label.mesh as TextMesh).text = "x %d\nCombo %d" % [_current_multiplier, _current_combo]
	percent_indicator.update_percent(hit_rate)

# perform the necessay computations to cut a cube with the saber
func _cut_cube(controller : XRController3D, saber : Area3D, cube : Node3D):
	_cut_cube_sw.start()
	
	# perform haptic feedback for the cut
	controller.simple_rumble(0.75, 0.1);
	var o = controller.global_transform.origin;
	var saber_end : Vector3
	var saber_end_past : Vector3
	if(controller.tracker == "left_hand"): # Check if it's the left controller
		saber_end = left_saber_end
		saber_end_past = left_saber_end_past
	else:
		saber_end = right_saber_end
		saber_end_past = right_saber_end_past
	
	var cutplane := Plane(o, saber_end, saber_end_past + (beat_distance *_current_info._beatsPerMinute * last_dt / 30) * Vector3(0, 0, 1)); # Account for relative position to track speed
	var cut_distance = cutplane.distance_to(cube.global_transform.origin);
	
	var controller_speed : Vector3 = (saber_end - saber_end_past) / (5*last_dt) + 0.2*(beat_distance *_current_info._beatsPerMinute / 60) * Vector3(0, 0, 1) # Account for inertial track speed

	# compute the angle between the cube orientation and the cut direction
	var cut_direction_xy = -Vector3(controller_speed.x, controller_speed.y, 0.0).normalized();
	var base_cut_angle_accuracy = cube._cube_mesh_orientation.global_transform.basis.y.dot(cut_direction_xy);
	var cut_angle_accuracy = clamp((base_cut_angle_accuracy-0.7)/0.3, 0.0, 1.0);
	if cube._note._cutDirection==8: #ignore angle if is a dot
		cut_angle_accuracy = 1.0;
	var cut_distance_accuracy = clamp((0.1 - abs(cut_distance))/0.1, 0.0, 1.0);
	var travel_distance_factor = _controller_movement_aabb[controller.tracker].get_longest_axis_size();
	travel_distance_factor = clamp((travel_distance_factor-0.5)/0.5, 0.0, 1.0);

	_create_cut_pieces_sw.start()
	# acquire oldest CutCubeResources to use for this event. we reused these
	# resource for performance reasons. it gets placed onto the back of the
	# list so that it won't get used again for a couple more cycles.
	var cut_res : CutCubeResources = _cut_cube_resources.pop_front()
	_cut_cube_resources.push_back(cut_res)
	_create_cut_rigid_body(-1, cube, cutplane, cut_distance, controller_speed, [saber_end,saber_end_past], cut_res);
	_create_cut_rigid_body( 1, cube, cutplane, cut_distance, controller_speed, [saber_end,saber_end_past], cut_res);
	_create_cut_pieces_sw.stop()
	
	# allows a bit of save margin where the beat is considered 100% correct
	var beat_accuracy = clamp((1.0 - abs(cube.global_transform.origin.z)) / 0.5, 0.0, 1.0);

	_update_points_sw.start()
	_update_points_from_cut(saber, cube, beat_accuracy, cut_angle_accuracy, cut_distance_accuracy, travel_distance_factor);
	_update_points_sw.stop()

	# reset the movement tracking volume for the next cut
	_controller_movement_aabb[controller.tracker] = AABB(controller.global_transform.origin, Vector3(0,0,0));

	#vr.show_dbg_info("cut_accuracy", str(beat_accuracy) + ", " + str(cut_angle_accuracy) + ", " + str(cut_distance_accuracy) + ", " + str(travel_distance_factor));
	cube.release();
	
	_cut_cube_sw.stop()

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

func _on_LeftLightSaber_cube_collide(cube: Node3D):
	# check 'playing' to prevent cutting items while resuming from pause menu
	# where items are visible at this point, but there a count down before the
	# song starts to play again
	if song_player.playing:
		_cut_cube(left_controller, left_saber, cube);

func _on_RightLightSaber_cube_collide(cube: Node3D):
	# check 'playing' to prevent cutting items while resuming from pause menu
	# where items are visible at this point, but there a count down before the
	# song starts to play again
	if song_player.playing:
		_cut_cube(right_controller, right_saber, cube);

func _on_LeftLightSaber_bomb_collide(bomb: Node3D):
	# check 'playing' to prevent cutting items while resuming from pause menu
	# where items are visible at this point, but there a count down before the
	# song starts to play again
	if song_player.playing:
		_reset_combo()
		$Points_label_driver.show_points(bomb.transform.origin,"x")
		bomb.queue_free()
		left_controller.simple_rumble(1.0, 0.15)

func _on_RightLightSaber_bomb_collide(bomb: Node3D):
	# check 'playing' to prevent cutting items while resuming from pause menu
	# where items are visible at this point, but there a count down before the
	# song starts to play again
	if song_player.playing:
		_reset_combo()
		$Points_label_driver.show_points(bomb.transform.origin,"x")
		bomb.queue_free()
		right_controller.simple_rumble(1.0, 0.15)

func _on_BeepCubePool_scene_instanced(cube: Node3D):
	cube.visible = false
	$Track.add_child(cube)
