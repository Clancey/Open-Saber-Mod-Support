# The main menu is shown at game start or pause on an OQ_UI2DCanvas
# some logic is in the BeepSaber_Game.gd to set the correct state
#
# This file also contains the logic to load a beatmap in the format that
# normal Beat Saber uses. So you can load here custom beat saber songs too
extends Panel
class_name MainMenu

# emitted when a new map difficulty is selected
signal difficulty_changed(map_info: Map.Info, diff_name: String, diff_rank: int)
# emitted when the settings button is pressed
signal settings_requested()
signal start_map(info: Map.Info, data: Dictionary, difficulty: int)

# we need the main game class here to trigger game start/restart/continue
#var _beepsaber = null;
var _cover_file_load_sw := StopwatchFactory.create("cover_file_load",10,true)
var _cover_texture_create_sw := StopwatchFactory.create("cover_texture_create",10,true)

@onready var playlist_selector := $PlaylistSelector as OptionButton
@onready var _bg_img_loader := preload("res://game/scripts/BackgroundImgLoader.gd").new()

@onready var cover = $cover
@onready var songs_menu = $SongsMenu as ItemList

enum PlaylistOptions {
	AllSongs,
	RecentlyAdded,
	MostPlayed
}
const PLAYLIST_ITEMS := {
	PlaylistOptions.AllSongs : "All Songs",
	PlaylistOptions.RecentlyAdded : "Recently Added",
	PlaylistOptions.MostPlayed : "Most Played"
}



var dlpath = str(OS.get_system_dir(3))+"/";
#var bspath = "/sdcard/OpenSaber/";
var bspath := "user://OpenSaber/"
@export var keyboard_path: NodePath
@onready var keyboard := get_node(keyboard_path) as OQ_UI2DKeyboard

var _playlists: Array

# [{id:<song_dir_name>, source:<path_to_song?>},...]
var _all_songs: Array[Map.Info]
var _recently_added_songs: Array[Map.Info] # newest is first, oldest is last
var _most_played_songs: Array[Map.Info] # most played is first, least played is last

func refresh_playlist() -> void:
	var id := playlist_selector.get_selected_id()
	_on_PlaylistSelector_item_selected(id)

func _load_playlists() -> void:
	_playlists = []
	
	#copy sample songs to main playlist folder on first run
	var config_path := "user://config.dat"
	if not FileAccess.file_exists(config_path):
		DirAccess.make_dir_recursive_absolute(bspath+"Songs/")
		const maps_path := "res://game/data/maps/"
		var dir := DirAccess.open(maps_path + "Songs/")
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while not file_name.is_empty():
			if dir.current_is_dir():
				var new_dir := maps_path+"Songs/"+file_name
				DirAccess.make_dir_recursive_absolute(bspath+"Songs/"+file_name)
				var copy := DirAccess.open(new_dir)
				copy.list_dir_begin()
				var copy_file_name := copy.get_next()
				while not copy_file_name.is_empty():
					var copy_new_dir := new_dir+"/"+copy_file_name
					dir.copy(copy_new_dir,bspath+"Songs/"+file_name+"/"+copy_file_name)
					copy_file_name = copy.get_next()
			file_name = dir.get_next()
	
	_all_songs = _discover_all_songs(bspath+"Songs/")
	var songs_with_modify_times = []
	var songs_with_play_count = []
	for song in _all_songs:
		var song_path := song.filepath
		var modified_time := FileAccess.get_modified_time(song_path)
		var play_count := PlayCount.get_total_play_count(song)
		songs_with_modify_times.append([modified_time,song])
		songs_with_play_count.append([play_count,song])
	
	var tuple_compare = TupleCompare.new(0,false)
	songs_with_modify_times.sort_custom(Callable(tuple_compare, "compare"))
	songs_with_play_count.sort_custom(Callable(tuple_compare, "compare"))
	_recently_added_songs = []
	_most_played_songs = []
	for tuple in songs_with_modify_times:
		_recently_added_songs.append(tuple[1])
	for tuple in songs_with_play_count:
		_most_played_songs.append(tuple[1])
	
	refresh_playlist()
	
	var canvas = get_parent().get_parent()
	if canvas.has_method("_input_update"):
		canvas._input_update()

# compare two tuples
# this is used to sort songs by most recently downloaded, most player, etc
class TupleCompare:
	var idx = 0
	var ascending = true
	
	func _init(idx,ascending=true):
		self.idx = idx
		self.ascending = ascending
		
	func compare(a,b):
		if ascending:
			return a[idx] < b[idx]
		else:
			return a[idx] > b[idx]
		
func _discover_all_songs(seek_path: String) -> Array[Map.Info]:
	var songlist: Array[Map.Info]
	var dir := DirAccess.open(seek_path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while not file_name.is_empty():
			if dir.current_is_dir(): # TODO: or file_name.ends_with(".zip"):
				var new_dir := seek_path+file_name+"/"
				var song := Map.load_info_from_folder(new_dir)
				if song:
					songlist.append(song)
			file_name = dir.get_next()
	return songlist

func _set_cur_playlist(songs: Array[Map.Info]) -> void:
	var current_id := songs_menu.get_selected_items()
	
	songs_menu.clear()
	
	var song_count := songs.size()
	var map_index := 0
	for map in songs:
		songs_menu.add_item("%s - %s" % [map.song_author_name, map.song_name],default_song_icon)
		var filepath := map.filepath + map.cover_image_filename
		_bg_img_loader.load_texture(filepath, self, "_on_cover_loaded", [false, map_index])
		map_index += 1
	
	if current_id.size() > 0:
		var selected_id := current_id[0]
		if selected_id >= song_count:
			selected_id = song_count - 1
		_select_song(selected_id)

var default_song_icon = preload("res://game/data/beepsaber_logo.png")

# callback from ImageUtils when background image loading is complete. if image
# failed to load, tex will be null
func _on_cover_loaded(img_tex, filepath, is_main_cover, list_idx):
	if img_tex != null:
		if is_main_cover:
			cover.call_deferred("set_texture", img_tex)
		else:
			songs_menu.call_deferred("set_item_icon", list_idx,img_tex)
			#songs_menu.set_item_icon(list_idx,img_tex)

func _load_cover(cover_path, filename):
	# parse buffer into an ImageTexture
	_cover_texture_create_sw.start()
	var tex = ImageTexture.create_from_image(Image.load_from_file(cover_path+filename));
	_cover_texture_create_sw.stop()
	return tex;

func play_preview(filepath_or_buffer, start_time = 0, duration = -1, buffer_data_type_hint = 'ogg'):
	var stream = null
	if filepath_or_buffer is String:
		# get song preview data from file
		if buffer_data_type_hint == 'ogg':
			stream = AudioStreamOggVorbis.load_from_file(filepath_or_buffer)
	elif filepath_or_buffer is PackedByteArray:
		# take song preview data from buffer as-is. trust passed type hint
		if buffer_data_type_hint == 'ogg':
			stream = AudioStreamOggVorbis.load_from_buffer(filepath_or_buffer)
		elif buffer_data_type_hint == 'mp3':
			stream = AudioStreamMP3.new()
			stream.data = filepath_or_buffer
	else:
		vr.log_error('_play_preview() - Unsupported song preview data type %s' % typeof(filepath_or_buffer))
		return
	
	if not stream: return
	
	if duration == -1:
		# assume preview duration based on parsed audio length
		duration = stream.get_length()
	
	
	# fade out preview if ones already running
	if song_prev.playing:
		await _on_stop_prev_timeout()
	
	# start the requested preview
	#if not _beepsaber.song_player.playing:
	song_prev.stream = stream;
	var song_prev_Tween = song_prev.create_tween()
	song_prev_Tween.set_trans(Tween.TRANS_LINEAR)
	song_prev_Tween.set_ease(Tween.EASE_IN_OUT)
	song_prev_Tween.tween_property(song_prev, "volume_db", 0, song_prev_transition_time)
	song_prev_Tween.play()
	
	song_prev.play(float(start_time))
	$song_prev/stop_prev.start(float(duration))

var _map_path: String

@onready var song_prev = $song_prev
var song_prev_lastid = -1
var song_prev_transition_time = 1.0

func _select_song(id: int) -> void:
	songs_menu.select(id)
	songs_menu.ensure_current_is_visible()
	var map := _all_songs[id]
	_map_path = map.filepath
	$Delete_Button.disabled = false
	Map.current_info = Map.load_info_from_folder(_map_path)
	
	var play_count := PlayCount.get_total_play_count(Map.current_info)
	($SongInfo_Label as Label).text = """Song Author: %s
	Song Title: %s
	Beatmap Author: %s
	Play Count: %d""" % [
		Map.current_info.song_author_name,
		Map.current_info.song_name,
		Map.current_info.level_author_name,
		play_count
	]

	# load cover in background to avoid freezing UI
	var filepath := Map.current_info.filepath + Map.current_info.cover_image_filename
	_bg_img_loader.load_texture(filepath, self, "_on_cover_loaded", [true,-1])
	
	$DifficultyMenu.clear()
	for ii_dif in range(Map.current_info.difficulty_beatmaps.size()):
		var diff_name := Map.current_info.difficulty_beatmaps[ii_dif].difficulty
		var diff_display_name := ""
		var diff_custom_data := Map.current_info.difficulty_beatmaps[ii_dif].custom_data
		if ((not diff_custom_data.is_empty()) and
			diff_custom_data.has("_difficultyLabel")):
				diff_display_name = diff_custom_data._difficultyLabel
		if diff_display_name.is_empty():
			diff_display_name = diff_name
		$DifficultyMenu.add_item(diff_display_name)
		$DifficultyMenu.set_item_tooltip($DifficultyMenu.get_item_count()-1, diff_name + " / " + diff_display_name)
		$DifficultyMenu.set_item_metadata($DifficultyMenu.get_item_count()-1,{id=ii_dif,DisplayName=diff_display_name,Name=diff_name})
	
	_select_difficulty(0)
	
	# preview songg
	var song_filepath := Map.current_info.filepath + Map.current_info.song_filename
	play_preview(song_filepath, Map.current_info.preview_start_time, Map.current_info.preview_duration)

func _on_stop_prev_timeout():
	var song_prev_Tween = song_prev.create_tween()
	song_prev_Tween.set_trans(Tween.TRANS_LINEAR)
	song_prev_Tween.set_ease(Tween.EASE_IN_OUT)
	song_prev_Tween.tween_property(song_prev, "volume_db", -50, song_prev_transition_time)
	song_prev_Tween.play()
	await get_tree().create_timer(song_prev_transition_time).timeout
	song_prev.stop()


var _map_difficulty = 0
var _map_difficulty_name := ""
var _map_difficulty_noteJumpMovementSpeed = 9.0

func _select_difficulty(id):
	var item_meta = $DifficultyMenu.get_item_metadata(id)
	_map_difficulty = item_meta["id"]
	_map_difficulty_name = item_meta["Name"]
	$DifficultyMenu.select(id)
	
	# notify listeners that difficulty has changed
	var difficulty := Map.current_info.difficulty_beatmaps[id]
	difficulty_changed.emit(Map.current_info, difficulty.difficulty, difficulty.difficulty_rank)


func _load_map_and_start() -> void:
	if Map.current_info.is_empty(): return
	
	var set0 := Map.current_info.difficulty_beatmaps
	if (set0.size() == 0):
		vr.log_error("No _difficultyBeatmaps in set")
		return
		
	var diff_info := set0[_map_difficulty]
	var map_filename := Map.current_info.filepath + diff_info.beatmap_filename
	var map_data := vr.load_json_file(map_filename)
	_map_difficulty_noteJumpMovementSpeed = set0[_map_difficulty].note_jump_movement_speed
	
	if (map_data == null):
		vr.log_error("Could not read map data from " + map_filename)
	
	start_map.emit(Map.current_info, map_data, _map_difficulty)

func _on_Delete_Button_button_up():
	if $Delete_Button.text != "Sure?":
		$Delete_Button.text = "Sure?";
		await get_tree().create_timer(5).timeout;
		$Delete_Button.text = "Delete";
	else:
		$Delete_Button.text = "Delete";
		_delete_map();
	
func _delete_map():
	if Map.current_info:
		Highscores.remove_map(Map.current_info)
		PlayCount.remove_map(Map.current_info)
		
	if not _map_path.is_empty():
		var dir = DirAccess.open(_map_path);
		if dir:
			dir.list_dir_begin() ;# TODOConverter3To4 fill missing arguments https://github.com/godotengine/godot/pull/40547
			var current_file = dir.get_next();
			while current_file != "":
				DirAccess.remove_absolute(_map_path+current_file);
				current_file = dir.get_next();
			DirAccess.remove_absolute(_map_path);
			vr.log_info(_map_path+" Removed");
			_map_path = ""
			$Delete_Button.disabled = true;
		else:
			vr.log_info("Error removing song "+_map_path);
		_on_LoadPlaylists_Button_pressed()

func _ready() -> void:
	UI_AudioEngine.attach_children(self)
	#if OS.get_name() != "Android":
		#bspath = dlpath+"BeepSaber/";
	vr.log_info("BeepSaber search path is " + bspath)
	
	playlist_selector.clear()
	for option in PLAYLIST_ITEMS.keys():
		playlist_selector.add_item(PLAYLIST_ITEMS[option],option)
	
	_load_playlists()
	
	await keyboard.ready
	keyboard.text_input_enter.connect(_text_input_enter)
	keyboard.text_input_cancel.connect(_text_input_cancel)
	keyboard._text_edit.text_changed.connect(_text_input_changed)
	keyboard._text_edit.focus_exited.connect(_text_input_enter)


func _on_Play_Button_pressed() -> void:
	$song_prev.stop()
	_load_map_and_start()


func _on_Exit_Button_pressed():
	get_tree().quit()


func _on_Settings_Button_pressed():
	emit_signal("settings_requested")

const READ_PERMISSION = "android.permission.READ_EXTERNAL_STORAGE"

func is_in_array(arr : Array, val):
	for e in arr:
		if (e == val): return true;
	return false;
	
func _check_required_permissions():
	if (!vr.inVR): return true; # desktop is always allowed
	
	var permissions = OS.get_granted_permissions()
	var read_storage_permission = is_in_array(permissions, READ_PERMISSION)
	
	vr.log_info(str(permissions));
	
	if !(read_storage_permission):
		return false;

	return true;

func _check_and_request_permission():
	vr.log_info("Checking permissions")

	if !(_check_required_permissions()):
		vr.log_info("Requesting permissions")
		OS.request_permissions()
		return false;
	else:
		return true;


func _on_LoadPlaylists_Button_pressed() -> void:
	# Note: this call is non-blocking; so a user has to click again after
	#       granting the permissions; we need to find a solutio for this
	#       maybe polling after the button press?
	_check_and_request_permission()
	_load_playlists()


func _on_Search_Button_button_up() -> void:
	keyboard.visible=true
	keyboard._text_edit.grab_focus();

func _text_input_enter(text: String) -> void:
	keyboard.visible=false

func _text_input_cancel() -> void:
	keyboard.visible=false
	_clean_search()

func _text_input_changed() -> void:
	var text = keyboard._text_edit.text
	$Search_Button/Label.text = text
	if text == "":
		_clean_search()
		return
	var most_similar = 0.0
	for song in range(0,songs_menu.get_item_count()):
		var similarity = songs_menu.get_item_text(song).similarity(text)
		if similarity > most_similar:
			most_similar = similarity
			songs_menu.move_item(song,0)

func _clean_search():
	songs_menu.sort_items_by_text()
	$Search_Button/Label.text = ""

func _on_PlaylistSelector_item_selected(id: int) -> void:
	match id:
		PlaylistOptions.AllSongs:
			_set_cur_playlist(_all_songs)
		PlaylistOptions.MostPlayed:
			_set_cur_playlist(_most_played_songs)
		PlaylistOptions.RecentlyAdded:
			_set_cur_playlist(_recently_added_songs)
		_:
			vr.log_warning("Unsupported playlist option %s" % id)
			_set_cur_playlist(_all_songs)
