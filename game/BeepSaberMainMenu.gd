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

var _cover_texture_create_sw := StopwatchFactory.create("cover_texture_create",10,true)

@onready var playlist_selector := $PlaylistSelector as OptionButton
@onready var _bg_img_loader := preload("res://game/scripts/BackgroundImgLoader.gd").new()

@onready var cover := $cover as TextureRect
@onready var songs_menu := $SongsMenu as ItemList
@onready var diff_menu := $DifficultyMenu as ItemList
@onready var delete_button := $Delete_Button as Button

var current_selected: Map.Info

enum PlaylistOptions {
	AllSongs,
	RecentlyAdded,
	MostPlayed
}

#var bspath = "/sdcard/OpenSaber/"
var bspath := "user://OpenSaber/"
@export var keyboard: OQ_UI2DKeyboard

var _playlists: Array

# [{id:<song_dir_name>, source:<path_to_song?>},...]
var _all_songs: Array[Map.Info]
var _recently_added_songs: Array[Map.Info] # newest is first, oldest is last
var _most_played_songs: Array[Map.Info] # most played is first, least played is last

func refresh_playlist() -> void:
	var id := playlist_selector.get_selected_id()
	_on_PlaylistSelector_item_selected(id)

class MapInfoWithSort:
	var num: int
	var info: Map.Info
	
	func _init(n: int, i: Map.Info) -> void:
		num = n
		info = i

func compare(a: MapInfoWithSort, b: MapInfoWithSort) -> bool:
	return a.num > b.num

func _load_playlists() -> void:
	_playlists = []
	
	#copy sample songs to main playlist folder on first run
	var config_path := "user://config.dat"
	if not FileAccess.file_exists(config_path):
		@warning_ignore("return_value_discarded")
		DirAccess.make_dir_recursive_absolute(bspath+"Songs/")
		const maps_path := "res://game/data/maps/"
		var dir := DirAccess.open(maps_path + "Songs/")
		@warning_ignore("return_value_discarded")
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while not file_name.is_empty():
			if dir.current_is_dir():
				var new_dir := maps_path+"Songs/"+file_name
				@warning_ignore("return_value_discarded")
				DirAccess.make_dir_recursive_absolute(bspath+"Songs/"+file_name)
				var copy := DirAccess.open(new_dir)
				@warning_ignore("return_value_discarded")
				copy.list_dir_begin()
				var copy_file_name := copy.get_next()
				while not copy_file_name.is_empty():
					var copy_new_dir := new_dir+"/"+copy_file_name
					@warning_ignore("return_value_discarded")
					dir.copy(copy_new_dir,bspath+"Songs/"+file_name+"/"+copy_file_name)
					copy_file_name = copy.get_next()
			file_name = dir.get_next()
	
	_all_songs = _discover_all_songs(bspath+"Songs/")
	var songs_with_modify_times: Array[MapInfoWithSort] = []
	var songs_with_play_count: Array[MapInfoWithSort] = []
	for song in _all_songs:
		var song_path := song.filepath
		var modified_time := FileAccess.get_modified_time(song_path)
		var play_count := PlayCount.get_total_play_count(song)
		songs_with_modify_times.append(MapInfoWithSort.new(modified_time, song))
		songs_with_play_count.append(MapInfoWithSort.new(play_count, song))
	
	songs_with_modify_times.sort_custom(compare)
	songs_with_play_count.sort_custom(compare)
	_recently_added_songs = []
	_most_played_songs = []
	for song in songs_with_modify_times:
		_recently_added_songs.append(song.info)
	for song in songs_with_play_count:
		_most_played_songs.append(song.info)
	
	refresh_playlist()
	
	var canvas := get_parent().get_parent()
	if canvas is OQ_UI2DCanvas:
		(canvas as OQ_UI2DCanvas)._input_update()

func _discover_all_songs(seek_path: String) -> Array[Map.Info]:
	var songlist: Array[Map.Info] = []
	var dir := DirAccess.open(seek_path)
	if dir:
		@warning_ignore("return_value_discarded")
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
		@warning_ignore("return_value_discarded")
		songs_menu.add_item("%s - %s" % [map.song_author_name, map.song_name], default_song_icon)
		var filepath := map.filepath + map.cover_image_filename
		_bg_img_loader.load_texture(filepath, _on_cover_loaded, false, map_index)
		map_index += 1
	
	if current_id.size() > 0:
		var selected_id := current_id[0]
		if selected_id >= song_count:
			selected_id = song_count - 1
		_select_song(selected_id)

var default_song_icon := preload("res://game/data/beepsaber_logo.png")

# callback from ImageUtils when background image loading is complete. if image
# failed to load, tex will be null
func _on_cover_loaded(img_tex: Texture2D, is_main_cover: bool, list_idx: int) -> void:
	if img_tex != null:
		if is_main_cover:
			cover.call_deferred("set_texture", img_tex)
		else:
			songs_menu.call_deferred("set_item_icon", list_idx,img_tex)
			#songs_menu.set_item_icon(list_idx,img_tex)

func _load_cover(cover_path: String, filename: String) -> ImageTexture:
	# parse buffer into an ImageTexture
	_cover_texture_create_sw.start()
	var tex := ImageTexture.create_from_image(Image.load_from_file(cover_path+filename))
	_cover_texture_create_sw.stop()
	return tex

func play_preview(buffer: PackedByteArray, start_time: float = 0.0, duration: float = -1.0, buffer_data_type_hint: String = 'ogg') -> void:
	var stream: AudioStream
	# take song preview data from buffer as-is. trust passed type hint
	if buffer_data_type_hint == 'ogg':
		stream = AudioStreamOggVorbis.load_from_buffer(buffer)
	elif buffer_data_type_hint == 'mp3':
		stream = AudioStreamMP3.new()
		(stream as AudioStreamMP3).data = buffer
	
	if not stream: return
	
	if duration < 0.0:
		# assume preview duration based on parsed audio length
		duration = stream.get_length()
	
	
	# fade out preview if ones already running
	if song_prev.playing:
		await _on_stop_prev_timeout()
	
	# start the requested preview
	#if not _beepsaber.song_player.playing:
	song_prev.stream = stream
	var song_prev_Tween := song_prev.create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	@warning_ignore("return_value_discarded")
	song_prev_Tween.tween_property(song_prev, ^"volume_db", 0, song_prev_transition_time)
	song_prev_Tween.play()
	
	song_prev.play(float(start_time))
	($song_prev/stop_prev as Timer).start(float(duration))

@onready var song_prev := $song_prev as AudioStreamPlayer
var song_prev_transition_time := 1.0

func _select_song(id: int) -> void:
	songs_menu.select(id)
	songs_menu.ensure_current_is_visible()
	var map := _all_songs[id]
	delete_button.disabled = false
	current_selected = Map.load_info_from_folder(map.filepath)
	
	var play_count := PlayCount.get_total_play_count(current_selected)
	($SongInfo_Label as Label).text = """Song Author: %s
	Song Title: %s
	Beatmap Author: %s
	Play Count: %d""" % [
		current_selected.song_author_name,
		current_selected.song_name,
		current_selected.level_author_name,
		play_count
	]

	# load cover in background to avoid freezing UI
	var filepath := current_selected.filepath + current_selected.cover_image_filename
	_bg_img_loader.load_texture(filepath, _on_cover_loaded, true, -1)
	
	diff_menu.clear()
	for ii_dif in range(current_selected.difficulty_beatmaps.size()):
		var diff_name := current_selected.difficulty_beatmaps[ii_dif].difficulty
		var diff_display_name := ""
		var diff_custom_data := current_selected.difficulty_beatmaps[ii_dif].custom_data
		if ((not diff_custom_data.is_empty()) and
			diff_custom_data.has("_difficultyLabel")):
				diff_display_name = diff_custom_data._difficultyLabel
		if diff_display_name.is_empty():
			diff_display_name = diff_name
		@warning_ignore("return_value_discarded")
		diff_menu.add_item(diff_display_name)
		diff_menu.set_item_tooltip(diff_menu.get_item_count()-1, diff_name + " / " + diff_display_name)
		diff_menu.set_item_metadata(diff_menu.get_item_count()-1,{id=ii_dif,DisplayName=diff_display_name,Name=diff_name})
	
	_select_difficulty(0)
	
	# preview songg
	var song_filepath := current_selected.filepath + current_selected.song_filename
	var song_data := FileAccess.get_file_as_bytes(song_filepath)
	play_preview(song_data, current_selected.preview_start_time, current_selected.preview_duration)

func _on_stop_prev_timeout() -> void:
	var song_prev_Tween := song_prev.create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	@warning_ignore("return_value_discarded")
	song_prev_Tween.tween_property(song_prev, "volume_db", -50, song_prev_transition_time)
	song_prev_Tween.play()
	await get_tree().create_timer(song_prev_transition_time).timeout
	song_prev.stop()


var _map_difficulty := 0
var _map_difficulty_name := ""
var _map_difficulty_noteJumpMovementSpeed := 9.0

func _select_difficulty(id: int) -> void:
	var item_meta: Dictionary = diff_menu.get_item_metadata(id)
	_map_difficulty = item_meta.id
	_map_difficulty_name = item_meta.Name
	diff_menu.select(id)
	
	# notify listeners that difficulty has changed
	var difficulty := current_selected.difficulty_beatmaps[id]
	difficulty_changed.emit(current_selected, difficulty.difficulty, difficulty.difficulty_rank)


func _load_map_and_start(map: Map.Info) -> void:
	if map.is_empty(): return
	
	var set0 := map.difficulty_beatmaps
	if (set0.size() == 0):
		vr.log_error("No _difficultyBeatmaps in set")
		return
	
	var diff_info := set0[_map_difficulty]
	var map_filename := map.filepath + diff_info.beatmap_filename
	var map_data := vr.load_json_file(map_filename)
	_map_difficulty_noteJumpMovementSpeed = set0[_map_difficulty].note_jump_movement_speed
	
	if (map_data == null):
		vr.log_error("Could not read map data from " + map_filename)
	
	start_map.emit(map, _map_difficulty)

func _on_Delete_Button_button_up() -> void:
	if delete_button.text != "Sure?":
		delete_button.text = "Sure?"
		await get_tree().create_timer(5).timeout
		delete_button.text = "Delete"
	else:
		delete_button.text = "Delete"
		_delete_map(current_selected)
	
func _delete_map(map: Map.Info) -> void:
	if map:
		Highscores.remove_map(map)
		PlayCount.remove_map(map)
	
	if not map.filepath.is_empty():
		var dir := DirAccess.open(map.filepath)
		if dir:
			@warning_ignore("return_value_discarded")
			dir.list_dir_begin()
			var current_file := dir.get_next()
			while current_file != "":
				@warning_ignore("return_value_discarded")
				DirAccess.remove_absolute(map.filepath+current_file)
				current_file = dir.get_next()
			@warning_ignore("return_value_discarded")
			DirAccess.remove_absolute(map.filepath)
			vr.log_info(map.filepath+" Removed")
			delete_button.disabled = true
		else:
			vr.log_info("Error removing song " + map.filepath)
		_on_LoadPlaylists_Button_pressed()

func _ready() -> void:
	UI_AudioEngine.attach_children(self)
	vr.log_info("BeepSaber search path is " + bspath)
	
	playlist_selector.clear()
	playlist_selector.add_item("All Songs")
	playlist_selector.add_item("Recently Added")
	playlist_selector.add_item("Most Played")
	
	_load_playlists()
	
	await keyboard.ready
	@warning_ignore("return_value_discarded")
	keyboard.text_input_enter.connect(_text_input_enter)
	@warning_ignore("return_value_discarded")
	keyboard.text_input_cancel.connect(_text_input_cancel)
	@warning_ignore("return_value_discarded")
	keyboard._text_edit.text_changed.connect(_text_input_changed)
	@warning_ignore("return_value_discarded")
	keyboard._text_edit.focus_exited.connect(_text_input_enter)


func _on_Play_Button_pressed() -> void:
	song_prev.stop()
	_load_map_and_start(current_selected)


func _on_Exit_Button_pressed() -> void:
	get_tree().quit()


func _on_Settings_Button_pressed() -> void:
	settings_requested.emit()

const READ_PERMISSION = "android.permission.READ_EXTERNAL_STORAGE"

func is_in_array(arr: Array, val: Variant) -> bool:
	for e: Variant in arr:
		if (e == val): return true
	return false
	
func _check_required_permissions() -> bool:
	if not vr.inVR: return true # desktop is always allowed
	
	var permissions := OS.get_granted_permissions()
	var read_storage_permission := is_in_array(permissions, READ_PERMISSION)
	
	vr.log_info(str(permissions))
	
	if not read_storage_permission:
		return false

	return true

func _check_and_request_permission() -> bool:
	vr.log_info("Checking permissions")
	
	if not _check_required_permissions():
		vr.log_info("Requesting permissions")
		OS.request_permissions()
		return false
	else:
		return true


func _on_LoadPlaylists_Button_pressed() -> void:
	# Note: this call is non-blocking; so a user has to click again after
	#       granting the permissions; we need to find a solutio for this
	#       maybe polling after the button press?
	_check_and_request_permission()
	_load_playlists()


func _on_Search_Button_button_up() -> void:
	keyboard.visible=true
	keyboard._text_edit.grab_focus()

func _text_input_enter(_text: String) -> void:
	keyboard.visible=false

func _text_input_cancel() -> void:
	keyboard.visible=false
	_clean_search()

func _text_input_changed() -> void:
	var text := keyboard._text_edit.text
	($Search_Button/Label as Label).text = text
	if text == "":
		_clean_search()
		return
	var most_similar := 0.0
	for song in range(0,songs_menu.get_item_count()):
		var similarity := songs_menu.get_item_text(song).similarity(text)
		if similarity > most_similar:
			most_similar = similarity
			songs_menu.move_item(song,0)

func _clean_search() -> void:
	songs_menu.sort_items_by_text()
	($Search_Button/Label as Label).text = ""

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
