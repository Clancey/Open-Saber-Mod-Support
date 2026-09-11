extends Panel
class_name BeatSaverPanel

# In-game browser for beatsaver.com. Mirrors the site's browse categories
# (latest / top rated / most played / curated / ranked / verified mappers),
# its search filters (sort order, AI maps, NPS range, mod requirements) and
# its curated playlists (the monthly "Curator's Picks" etc.), and downloads
# maps into the local Songs folder.

const API_BASE := "https://api.beatsaver.com"
const PAGE_SIZE := 20

class BeatSaverSongInfo extends RefCounted:
	var id: String
	var name: String
	var description: String
	var song_name: String
	var song_author_name: String
	var level_author_name: String
	var duration: float
	var bpm: float
	var versions: Array
	var uploader_id: int
	var uploader_name: String
	var verified_mapper: bool
	var automapper: bool
	var ranked: bool
	var curated: bool
	var uploaded: String
	var tags: Array
	var upvotes: int
	var downvotes: int
	var score: float
	var downloads: int
	var plays: int

	func _init(song_info: Dictionary) -> void:
		id = Utils.get_str(song_info, "id", "")
		name = Utils.get_str(song_info, "name", "")
		description = Utils.get_str(song_info, "description", "")
		versions = Utils.get_array(song_info, "versions", [])
		var uploader := Utils.get_dict(song_info, "uploader", {})
		uploader_id = int(Utils.get_float(uploader, "id", -1))
		uploader_name = Utils.get_str(uploader, "name", "")
		verified_mapper = Utils.get_bool(uploader, "verifiedMapper", false)
		var metadata := Utils.get_dict(song_info, "metadata", {})
		song_name = Utils.get_str(metadata, "songName", "")
		song_author_name = Utils.get_str(metadata, "songAuthorName", "")
		level_author_name = Utils.get_str(metadata, "levelAuthorName", "")
		duration = Utils.get_float(metadata, "duration", 0.0)
		bpm = Utils.get_float(metadata, "bpm", 0.0)
		automapper = Utils.get_bool(song_info, "automapper", false)
		ranked = Utils.get_bool(song_info, "ranked", false) or Utils.get_bool(song_info, "blRanked", false)
		curated = Utils.get_str(song_info, "curatedAt", "") != ""
		uploaded = Utils.get_str(song_info, "uploaded", "")
		tags = Utils.get_array(song_info, "tags", [])
		var stats := Utils.get_dict(song_info, "stats", {})
		upvotes = int(Utils.get_float(stats, "upvotes", 0.0))
		downvotes = int(Utils.get_float(stats, "downvotes", 0.0))
		score = Utils.get_float(stats, "score", 0.0)
		downloads = int(Utils.get_float(stats, "downloads", 0.0))
		plays = int(Utils.get_float(stats, "plays", 0.0))

	func get_version() -> Dictionary:
		if versions.is_empty() or not versions[0] is Dictionary:
			return {}
		return versions[0] as Dictionary

	func get_cover_url() -> String:
		return Utils.get_str(get_version(), "coverURL", "")

class BeatSaverPlaylistInfo extends RefCounted:
	var id: int
	var name: String
	var description: String
	var image_url: String
	var owner_name: String
	var curator_name: String
	var total_maps: int
	var avg_score: float
	var min_nps: float
	var max_nps: float
	var curated_at: String

	func _init(info: Dictionary) -> void:
		id = int(Utils.get_float(info, "playlistId", -1))
		name = Utils.get_str(info, "name", "").strip_edges()
		description = Utils.get_str(info, "description", "")
		image_url = Utils.get_str(info, "playlistImage512", Utils.get_str(info, "playlistImage", ""))
		owner_name = Utils.get_str(Utils.get_dict(info, "owner", {}), "name", "")
		curator_name = Utils.get_str(Utils.get_dict(info, "curator", {}), "name", "")
		curated_at = Utils.get_str(info, "curatedAt", "")
		var stats := Utils.get_dict(info, "stats", {})
		total_maps = int(Utils.get_float(stats, "totalMaps", 0.0))
		avg_score = Utils.get_float(stats, "avgScore", 0.0)
		min_nps = Utils.get_float(stats, "minNps", 0.0)
		max_nps = Utils.get_float(stats, "maxNps", 0.0)

# structure representing a request we made (or can go back to) on beatsaver
class BeatSaverRequest extends RefCounted:
	var page: int = 0
	# one of REQ_* below
	var type: String
	# category index, search text, uploader id or playlist id depending on type
	var data: String
	# what to show in the title label for this request
	var title: String = ""

const REQ_CATEGORY := "category"
const REQ_TEXT_SEARCH := "text_search"
const REQ_UPLOADER := "uploader"
const REQ_PLAYLIST_SEARCH := "playlist_search"
const REQ_PLAYLIST_MAPS := "playlist_maps"

enum Category { LATEST, TOP_RATED, MOST_PLAYED, CURATED, RANKED, VERIFIED, PLAYLISTS }
const CATEGORY_TITLES: Array[String] = [
	"Latest maps", "Top rated", "Most played", "Curated maps",
	"Ranked maps", "Verified mappers", "Curated playlists"]
# sort order the API applies to each category by default
const CATEGORY_DEFAULT_SORT: Array[String] = [
	"Latest", "Rating", "Rating", "Curated", "Rating", "Rating", "Curated"]
# sort orders the user can cycle through for searches and filtered categories
const SORT_ORDERS: Array[String] = ["Rating", "Latest", "Relevance", "Curated"]
# [label, minNps, maxNps]; -1 = unbounded
const NPS_RANGES: Array = [
	["Any", -1.0, -1.0], ["< 3", -1.0, 3.0], ["3 - 5", 3.0, 5.0],
	["5 - 7", 5.0, 7.0], ["7 - 10", 7.0, 10.0], ["10+", 10.0, -1.0]]
# [label, query parameter]
const MOD_FILTERS: Array = [
	["Any", ""], ["Chroma", "chroma"], ["Noodle", "noodle"],
	["Cinema", "cinema"], ["Mapping Ext.", "me"]]

var song_data: Array[BeatSaverSongInfo] = []
var playlist_data: Array[BeatSaverPlaylistInfo] = []
# cover url for every row of the item list ("" = nothing to download)
var _cover_urls: Array[String] = []
# reference to the main main node (used for playing downloadable song previews)
@export var main_menu_ref: MainMenu
# the next requestable pages for the current list; -1 if prev/next page is
# not requestable (ie. reached end of the list)
var prev_page_available := -1
var next_page_available := -1
var search_word := ""
var item_selected := -1
var downloading := []#[["name","version_info"]]

# current filter state
var sort_index := 0
var include_ai_maps := false
var nps_index := 0
var mods_index := 0

@onready var item_list := $ItemList as ItemList
@onready var label := $Label as Label
@onready var title_label := $FilterRow/title as Label
@onready var back_button := $FilterRow/back as Button
@onready var sort_button := $FilterRow/sort as Button
@onready var ai_button := $FilterRow/ai as Button
@onready var nps_button := $FilterRow/nps as Button
@onready var mods_button := $FilterRow/mods as Button
@onready var category_row := $CategoryRow as HBoxContainer
@onready var download_button := $download as Button
@onready var download_all_button := $downloadAll as Button
@onready var httpreq := $HTTPReq as HTTPRequest
@onready var httpdownload := $HTTPDownload as HTTPRequest
@onready var httpcoverdownload := $CoverDownload as HTTPRequest
@onready var httppreviewdownload := $PreviewDownload as HTTPRequest
@onready var placeholder_cover := preload("res://game/data/beepsaber_logo.png")
@onready var goto_maps_by := $gotoMapsBy as Button
@onready var v_scroll := item_list.get_v_scroll_bar()

var _category_group := ButtonGroup.new()

const MAX_BACK_STACK_DEPTH := 10
# series of previous requests that you can go back to
var back_stack: Array[BeatSaverRequest] = []
var prev_request: BeatSaverRequest

@export var keyboard: OQ_UI2DKeyboard

func _ready() -> void:
	UI_AudioEngine.attach_children(self)
	back_button.visible = false
	v_scroll.value_changed.connect(_on_ListV_Scroll_value_changed)

	_category_group.allow_unpress = true
	for i in category_row.get_child_count():
		var button := category_row.get_child(i) as Button
		if button == null: continue
		button.button_group = _category_group
		button.pressed.connect(_on_category_pressed.bind(i))
	_update_filter_buttons()

	var is_web := OS.get_name() == "Web"

	if not is_web:
		httpreq.use_threads = true
		httpdownload.use_threads = true
		httpcoverdownload.use_threads = true
		httppreviewdownload.use_threads = true

	if keyboard != null:
		keyboard.text_input_enter.connect(_text_input_enter)
		keyboard.text_input_cancel.connect(_text_input_cancel)

	var parent_canvas: Node = self
	while parent_canvas != null:
		if parent_canvas is OQ_UI2DCanvas:
			(parent_canvas as OQ_UI2DCanvas).visibility_changed.connect(_on_BeatSaverPanel_visibility_changed)
			break
		parent_canvas = parent_canvas.get_parent()

# override hide() method to handle case where UI is inside a OQ_UI2DCanvas
func _hide() -> void:
	var parent_canvas: Node = self
	while parent_canvas != null:
		if parent_canvas is OQ_UI2DCanvas:
			(parent_canvas as OQ_UI2DCanvas).hide()
			break
		parent_canvas = parent_canvas.get_parent()

	if parent_canvas == null:
		self.visible = false

# override show() method to handle case where UI is inside a OQ_UI2DCanvas
func _show() -> void:
	var parent_canvas: Node = self
	while parent_canvas != null:
		if parent_canvas is OQ_UI2DCanvas:
			(parent_canvas as OQ_UI2DCanvas).show()
			break
		parent_canvas = parent_canvas.get_parent()

	if parent_canvas == null:
		self.visible = true
	_on_BeatSaverPanel_visibility_changed()

# ---------------------------------------------------------------------------
# request building

func _make_request(type: String, data: String, title: String) -> BeatSaverRequest:
	var req := BeatSaverRequest.new()
	req.page = 0
	req.type = type
	req.data = data
	req.title = title
	return req

func _category_of(req: BeatSaverRequest) -> int:
	if req == null or req.type != REQ_CATEGORY:
		return -1
	return int(req.data)

# true when the request lists playlists rather than maps
func _is_playlist_list(req: BeatSaverRequest) -> bool:
	if req == null: return false
	return req.type == REQ_PLAYLIST_SEARCH or _category_of(req) == Category.PLAYLISTS

# true when the sort / AI / NPS / mods filters influence this request
func _filters_apply(req: BeatSaverRequest) -> bool:
	if req == null: return false
	if req.type == REQ_TEXT_SEARCH: return true
	var category := _category_of(req)
	return category in [Category.LATEST, Category.TOP_RATED, Category.CURATED, Category.RANKED, Category.VERIFIED]

# true when the user may pick the sort order for this request
func _sort_selectable(req: BeatSaverRequest) -> bool:
	if req == null: return false
	if req.type == REQ_TEXT_SEARCH: return true
	return _category_of(req) in [Category.CURATED, Category.RANKED, Category.VERIFIED]

func _current_sort(req: BeatSaverRequest) -> String:
	if _sort_selectable(req):
		return SORT_ORDERS[sort_index]
	var category := _category_of(req)
	if category >= 0:
		return CATEGORY_DEFAULT_SORT[category]
	return SORT_ORDERS[sort_index]

# query string shared by every /search/text request (sort + user filters)
func _search_filter_params(req: BeatSaverRequest) -> String:
	var params := "pageSize=%d&order=%s" % [PAGE_SIZE, _current_sort(req)]
	# BeatSaver's automapper flag: omitted = human maps only, true = both
	if include_ai_maps:
		params += "&automapper=true"
	var nps: Array = NPS_RANGES[nps_index]
	if float(nps[1]) >= 0.0:
		params += "&minNps=%s" % str(nps[1])
	if float(nps[2]) >= 0.0:
		params += "&maxNps=%s" % str(nps[2])
	var mod: String = MOD_FILTERS[mods_index][1]
	if mod != "":
		params += "&%s=true" % mod
	return params

func _build_url(req: BeatSaverRequest) -> String:
	match req.type:
		REQ_CATEGORY:
			var search := "%s/search/text/%d?%s" % [API_BASE, req.page, _search_filter_params(req)]
			match _category_of(req):
				Category.LATEST, Category.TOP_RATED:
					return search
				Category.MOST_PLAYED:
					return "%s/maps/plays/%d" % [API_BASE, req.page]
				Category.CURATED:
					return search + "&curated=true"
				Category.RANKED:
					return search + "&leaderboard=Ranked"
				Category.VERIFIED:
					return search + "&verified=true"
				Category.PLAYLISTS:
					return "%s/playlists/search/%d?curated=true&order=Curated" % [API_BASE, req.page]
		REQ_TEXT_SEARCH:
			return "%s/search/text/%d?%s&q=%s" % [API_BASE, req.page, _search_filter_params(req), req.data.uri_encode()]
		REQ_UPLOADER:
			return "%s/maps/uploader/%s/%d" % [API_BASE, req.data, req.page]
		REQ_PLAYLIST_SEARCH:
			return "%s/playlists/search/%d?order=Relevance&q=%s" % [API_BASE, req.page, req.data.uri_encode()]
		REQ_PLAYLIST_MAPS:
			return "%s/playlists/id/%s/%d" % [API_BASE, req.data, req.page]
	vr.log_warning("Unsupported request type '%s'" % req.type)
	return ""

# start a request; replaces the current list when starting at page 0 and
# appends when requesting a further page
func update_list(req: BeatSaverRequest) -> void:
	if req == null: return
	if req.page == 0:
		# brand new request, clear list to prep for reload
		item_list.clear()
		_cover_urls.clear()
		_current_cover_to_download = 0
		if goto_maps_by:
			goto_maps_by.visible = false
		song_data = []
		playlist_data = []
		item_selected = -1
	if not httpcoverdownload:
		return
	httpcoverdownload.cancel_request()
	httpreq.cancel_request()
	prev_page_available = req.page
	next_page_available = -1
	_set_controls_enabled(false)
	title_label.text = req.title
	_sync_category_buttons(req)
	_update_filter_buttons()
	download_all_button.visible = req.type == REQ_PLAYLIST_MAPS
	download_button.text = "Open playlist" if _is_playlist_list(req) else "Download"
	if downloading.is_empty():
		label.text = "Loading..."

	var url := _build_url(req)
	if url == "":
		_show_list_message("Unsupported request")
		_request_finished()
		return
	var error := httpreq.request(url)
	if error != OK:
		vr.log_error("BeatSaver request failed to start (%d): %s" % [error, url])
		_show_list_message("Could not start the request (error %d)" % error)
		_request_finished()

func _run_new_request(req: BeatSaverRequest) -> void:
	_add_to_back_stack(prev_request)
	prev_request = req
	update_list(prev_request)

# re-run the current request from the first page (used when a filter changes)
func _refresh_current() -> void:
	if prev_request == null: return
	prev_request.page = 0
	update_list(prev_request)

func _add_to_back_stack(request: BeatSaverRequest) -> void:
	if request == null: return
	back_stack.push_back(request)
	if back_stack.size() > MAX_BACK_STACK_DEPTH:
		back_stack.pop_front()

func _set_controls_enabled(enabled: bool) -> void:
	for child in category_row.get_children():
		if child is Button:
			(child as Button).disabled = not enabled
	back_button.disabled = not enabled
	if enabled:
		_update_filter_buttons()
	else:
		sort_button.disabled = true
		ai_button.disabled = true
		nps_button.disabled = true
		mods_button.disabled = true

func _sync_category_buttons(req: BeatSaverRequest) -> void:
	var category := _category_of(req)
	for i in category_row.get_child_count():
		var button := category_row.get_child(i) as Button
		if button == null: continue
		button.set_pressed_no_signal(i == category)

func _update_filter_buttons() -> void:
	var filters_apply := _filters_apply(prev_request)
	sort_button.text = "Sort: %s" % _current_sort(prev_request)
	sort_button.disabled = not _sort_selectable(prev_request)
	ai_button.set_pressed_no_signal(include_ai_maps)
	ai_button.disabled = not filters_apply
	nps_button.text = "NPS: %s" % NPS_RANGES[nps_index][0]
	nps_button.disabled = not filters_apply
	mods_button.text = "Mods: %s" % MOD_FILTERS[mods_index][0]
	mods_button.disabled = not filters_apply

# add a non-selectable row to the list to tell the user what happened
func _show_list_message(message: String) -> void:
	var index := item_list.add_item(message, null, false)
	item_list.set_item_disabled(index, true)
	_cover_urls.append("")

func _request_finished() -> void:
	_set_controls_enabled(true)
	back_button.visible = back_stack.size() > 0
	_scroll_page_request_pending = false
	if downloading.is_empty() and label.text == "Loading...":
		label.text = ""
	_refresh_canvas()

func _refresh_canvas() -> void:
	var canvas := get_parent().get_parent()
	if canvas is OQ_UI2DCanvas: (canvas as OQ_UI2DCanvas)._input_update()

# return the selected song's data, or null if not song is selected
func _get_selected_song() -> BeatSaverSongInfo:
	if item_selected >= 0 && item_selected < song_data.size():
		return song_data[item_selected]
	return null

func _get_selected_playlist() -> BeatSaverPlaylistInfo:
	if item_selected >= 0 && item_selected < playlist_data.size():
		return playlist_data[item_selected]
	return null

# ---------------------------------------------------------------------------
# response handling

func _on_HTTPRequest_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		vr.log_error("BeatSaver request error %d" % result)
		_show_list_message("Could not reach beatsaver.com (error %d)" % result)
		_request_finished()
		return
	if response_code >= 400:
		vr.log_error("BeatSaver request returned HTTP %d" % response_code)
		_show_list_message("beatsaver.com returned an error (HTTP %d)" % response_code)
		_request_finished()
		return
	var json_data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not json_data is Dictionary:
		_show_list_message("Unexpected answer from beatsaver.com")
		_request_finished()
		return
	var json_dict := json_data as Dictionary

	var docs: Array = []
	var page_count := -1
	if json_dict.has("maps") and json_dict["maps"] is Array:
		# playlist page: {playlist, maps: [{map, order}]}
		var playlist := Utils.get_dict(json_dict, "playlist", {})
		if prev_request != null and prev_request.type == REQ_PLAYLIST_MAPS and playlist.has("name"):
			prev_request.title = "Playlist: %s" % Utils.get_str(playlist, "name", "").strip_edges()
			title_label.text = prev_request.title
		for entry: Variant in json_dict["maps"] as Array:
			if entry is Dictionary and (entry as Dictionary).has("map"):
				docs.append((entry as Dictionary)["map"])
	elif json_dict.has("docs") and json_dict["docs"] is Array:
		docs = json_dict["docs"] as Array
		var info := Utils.get_dict(json_dict, "info", {})
		if info.has("pages"):
			page_count = int(Utils.get_float(info, "pages", 0.0))
	else:
		var errors := Utils.get_array(json_dict, "errors", [])
		_show_list_message("beatsaver.com: %s" % (str(errors[0]) if errors.size() > 0 else "unexpected answer"))
		_request_finished()
		return

	var added := 0
	if _is_playlist_list(prev_request):
		added = _add_playlist_docs(docs)
	else:
		added = _add_map_docs(docs)

	if page_count >= 0:
		next_page_available = prev_page_available + 1 if prev_page_available + 1 < page_count else -1
	else:
		# endpoints without paging info: keep going until a page comes back empty
		next_page_available = prev_page_available + 1 if docs.size() > 0 else -1

	if added == 0 and item_list.item_count == 0:
		_show_list_message("No results")

	_request_finished()
	_update_all_covers()

func _add_map_docs(docs: Array) -> int:
	var added := 0
	var hide_ai := not include_ai_maps and _category_of(prev_request) == Category.MOST_PLAYED
	for i: Variant in docs:
		if not i is Dictionary: continue
		var parsed_song := BeatSaverSongInfo.new(i as Dictionary)
		if hide_ai and parsed_song.automapper:
			continue
		var index := item_list.add_item(parsed_song.name)
		item_list.set_item_icon(index, placeholder_cover)
		var tooltip := "Map author: %s" % parsed_song.level_author_name
		item_list.set_item_tooltip(index, tooltip)
		song_data.append(parsed_song)
		_cover_urls.append(parsed_song.get_cover_url())
		added += 1
	return added

func _add_playlist_docs(docs: Array) -> int:
	var added := 0
	for i: Variant in docs:
		if not i is Dictionary: continue
		var playlist := BeatSaverPlaylistInfo.new(i as Dictionary)
		var index := item_list.add_item(playlist.name)
		item_list.set_item_icon(index, placeholder_cover)
		item_list.set_item_tooltip(index, "%d maps, by %s" % [playlist.total_maps, playlist.owner_name])
		playlist_data.append(playlist)
		_cover_urls.append(playlist.image_url)
		added += 1
	return added

# ---------------------------------------------------------------------------
# category and filter buttons

func _on_category_pressed(category: int) -> void:
	if category < 0 or category >= CATEGORY_TITLES.size():
		return
	# a category comes with its own sort order; start from it
	var default_sort := SORT_ORDERS.find(CATEGORY_DEFAULT_SORT[category])
	if default_sort >= 0:
		sort_index = default_sort
	_run_new_request(_make_request(REQ_CATEGORY, str(category), CATEGORY_TITLES[category]))

func _on_sort_pressed() -> void:
	sort_index = (sort_index + 1) % SORT_ORDERS.size()
	_update_filter_buttons()
	_refresh_current()

func _on_ai_toggled(toggled_on: bool) -> void:
	include_ai_maps = toggled_on
	_refresh_current()

func _on_nps_pressed() -> void:
	nps_index = (nps_index + 1) % NPS_RANGES.size()
	_update_filter_buttons()
	_refresh_current()

func _on_mods_pressed() -> void:
	mods_index = (mods_index + 1) % MOD_FILTERS.size()
	_update_filter_buttons()
	_refresh_current()

# ---------------------------------------------------------------------------
# selection and details

func _on_ItemList_item_selected(index: int) -> void:
	item_selected = index
	if _is_playlist_list(prev_request):
		_show_playlist_details()
	else:
		_show_song_details()
	($TextureRect as TextureRect).texture = item_list.get_item_icon(index)

func _show_song_details() -> void:
	var selected_data := _get_selected_song()
	if selected_data == null: return
	var dur_s := int(selected_data.duration)
	var version := selected_data.get_version()
	goto_maps_by.text = "Maps by %s" % selected_data.level_author_name
	goto_maps_by.visible = true
	# difficulties grouped per characteristic, e.g. "Standard: Hard Expert, OneSaber: Expert"
	var per_characteristic := {}
	var min_nps := INF
	var max_nps := 0.0
	for diff: Variant in Utils.get_array(version, "diffs", []):
		if not diff is Dictionary: continue
		var characteristic := Utils.get_str(diff as Dictionary, "characteristic", "Standard")
		if not per_characteristic.has(characteristic):
			per_characteristic[characteristic] = []
		(per_characteristic[characteristic] as Array).append(Utils.get_str(diff as Dictionary, "difficulty", ""))
		var nps := Utils.get_float(diff as Dictionary, "nps", 0.0)
		min_nps = minf(min_nps, nps)
		max_nps = maxf(max_nps, nps)
	var groups: Array[String] = []
	for characteristic: String in per_characteristic:
		var names: Array[String] = []
		names.assign(per_characteristic[characteristic])
		if per_characteristic.size() == 1 and characteristic == "Standard":
			groups.append(" ".join(names))
		else:
			groups.append("%s: %s" % [characteristic, " ".join(names)])
	var difficulties := " " + ", ".join(groups)
	var nps_text := ""
	if min_nps != INF:
		nps_text = "%.1f - %.1f" % [min_nps, max_nps] if max_nps - min_nps > 0.05 else "%.1f" % max_nps
	var flags: Array[String] = []
	if selected_data.curated: flags.append("Curated")
	if selected_data.ranked: flags.append("Ranked")
	if selected_data.verified_mapper: flags.append("Verified mapper")
	if selected_data.automapper: flags.append("AI map")
	var tags: Array[String] = []
	for tag: Variant in selected_data.tags:
		tags.append(str(tag))
	var text := """[center]%s By %s[/center]

Map author: %s
Duration: %dm %ds    BPM: %d
Rating: %d%% (%d up / %d down)    Downloads: %d
Difficulties:%s
NPS: %s    Uploaded: %s
%s%s
[center]Description:[/center]
%s""" % [
		selected_data.song_name,
		selected_data.song_author_name,
		selected_data.level_author_name,
		dur_s/60,dur_s%60,
		int(selected_data.bpm),
		int(round(selected_data.score * 100.0)),
		selected_data.upvotes, selected_data.downvotes,
		selected_data.downloads,
		difficulties,
		nps_text,
		selected_data.uploaded.substr(0, 10),
		("Tags: %s\n" % ", ".join(tags)) if not tags.is_empty() else "",
		("%s\n" % ", ".join(flags)) if not flags.is_empty() else "",
		selected_data.description,
	]
	($song_data as RichTextLabel).text = text

	var preview_url := Utils.get_str(version, "previewURL", "")
	if preview_url != "":
		httppreviewdownload.cancel_request()
		httppreviewdownload.request(preview_url)

func _show_playlist_details() -> void:
	var playlist := _get_selected_playlist()
	if playlist == null: return
	goto_maps_by.visible = false
	var by := "by %s" % playlist.owner_name
	if playlist.curator_name != "":
		by += ", curated by %s" % playlist.curator_name
	var text := """[center]%s[/center]

%s
%d maps    Rating: %d%%    NPS: %.1f - %.1f
%s
[center]Description:[/center]
%s

Press Open playlist to browse and download its maps""" % [
		playlist.name,
		by,
		playlist.total_maps,
		int(round(playlist.avg_score * 100.0)),
		playlist.min_nps, playlist.max_nps,
		("Curated: %s" % playlist.curated_at.substr(0, 10)) if playlist.curated_at != "" else "",
		playlist.description,
	]
	($song_data as RichTextLabel).text = text

func _open_playlist(playlist: BeatSaverPlaylistInfo) -> void:
	if playlist == null or playlist.id < 0: return
	_run_new_request(_make_request(REQ_PLAYLIST_MAPS, str(playlist.id), "Playlist: %s" % playlist.name))

# ---------------------------------------------------------------------------
# downloads

func _on_download_button_up() -> void:
	OS.request_permissions()
	if item_selected == -1: return
	if _is_playlist_list(prev_request):
		_open_playlist(_get_selected_playlist())
		return
	_queue_download(_get_selected_song())
	download_next()

func _on_downloadAll_pressed() -> void:
	OS.request_permissions()
	var queued := 0
	for song in song_data:
		if _queue_download(song):
			queued += 1
	if queued == 0 and song_data.size() > 0:
		label.text = "All maps already queued"
	download_next()

# add a song to the download queue; false if it is already queued or has no download
func _queue_download(song: BeatSaverSongInfo) -> bool:
	if song == null: return false
	var version_info := song.get_version()
	if Utils.get_str(version_info, "downloadURL", "") == "":
		return false
	for entry: Variant in downloading:
		if entry[0] == song.name:
			return false
	downloading.append([song.name, version_info])
	return true

var _download_in_flight := false

func download_next() -> void:
	if downloading.size() > 0 and not _download_in_flight:
		var error := httpdownload.request(downloading[0][1]['downloadURL'])
		if error != OK:
			label.text = "Download error %d" % error
			downloading.remove_at(0)
			download_next()
			return
		_download_in_flight = true
		label.text = "Downloading: %s - %d left" % [str(downloading[0][0]),downloading.size()-1]
		label.visible = true

func _on_HTTPRequest_download_completed(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_download_in_flight = false
	if downloading.is_empty():
		return
	if body.slice(0, 10) == "<!DOCTYPE html>".to_utf8_buffer().slice(0, 10):
		result = -1
	if result == 0:
		var has_error := false
		var tempdir := Constants.APPDATA_PATH+"temp"
		var error := DirAccess.make_dir_recursive_absolute(tempdir)
		if error != OK:
			vr.log_error(
				"_on_HTTPRequest_download_completed - " +
				"Failed to create temp directory '%s'" % tempdir)
			has_error = true

		# sanitize path separators from song directory name
		var song_dir_name: String = downloading[0][0].replace('/','').replace('\\','')

		var zippath := Constants.APPDATA_PATH+"temp/%s.zip"%song_dir_name
		if not has_error:
			var file := FileAccess.open(zippath,FileAccess.WRITE)
			if file:
				file.store_buffer(body)
				file.close()
			else:
				vr.log_file_error(FileAccess.get_open_error(), zippath, "BeatSaverPanel.gd at line 261")
				has_error = true

		var song_out_dir := Constants.APPDATA_PATH+("Songs/%s/"%song_dir_name)
		if not has_error:
			error = DirAccess.make_dir_recursive_absolute(song_out_dir)
			if error != OK:
				vr.log_error(
					"_on_HTTPRequest_download_completed - " +
					"Failed to create song output dir '%s'" % song_out_dir)
				has_error = true

		if not has_error:
			Utils.unzip(zippath,song_out_dir)

		DirAccess.remove_absolute(zippath)

		downloading.remove_at(0)

		if not downloading.size() > 0:
			main_menu_ref._on_LoadPlaylists_Button_pressed()
			label.text = "All downloaded"
	else:
		label.text = "Download error "+str(result)
		if result == -1:
			label.text += "\nInvalid URL or server is down"
		vr.log_info("download error "+str(result))
		downloading.remove_at(0)

	_refresh_canvas()
	download_next()

func _on_preview_download_completed(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == 0 and main_menu_ref != null:
		# request preview to be played by the main menu node
		main_menu_ref.play_preview(
			body, # song data buffer
			0,    # start previous at time 0
			-1,   # play preview song for entire duration
			'mp3')# bsaver has all it's previews in mp3 format for now

# ---------------------------------------------------------------------------
# text search

func _on_search_button_up() -> void:
	keyboard._show()
	keyboard._text_edit.grab_focus()

func _text_input_enter(text: String) -> void:
	keyboard._hide()
	search_word = text.strip_edges()
	if search_word == "":
		return
	if _is_playlist_list(prev_request):
		# searching while browsing playlists searches playlists
		_run_new_request(_make_request(REQ_PLAYLIST_SEARCH, search_word, "Playlists: %s" % search_word))
	else:
		sort_index = SORT_ORDERS.find("Relevance")
		_run_new_request(_make_request(REQ_TEXT_SEARCH, search_word, "Search: %s" % search_word))

func _text_input_cancel() -> void:
	keyboard._hide()

# ---------------------------------------------------------------------------
# covers

var _current_cover_to_download := 0

func _update_all_covers() -> void:
	httpcoverdownload.cancel_request()
	update_next_cover()

func update_next_cover() -> void:
	while _current_cover_to_download < _cover_urls.size():
		var cover_url := _cover_urls[_current_cover_to_download]
		if cover_url == "":
			# row has no cover. skip it and move to next one
			_current_cover_to_download += 1
			continue
		if httpcoverdownload.request(cover_url) != OK:
			_current_cover_to_download += 1
			continue
		return

func _update_cover(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == 0 and _current_cover_to_download < item_list.item_count:
		var img := Image.new()
		if not img.load_jpg_from_buffer(body) == 0:
			if img.load_png_from_buffer(body) != 0:
				img = null
		if img != null and not img.is_empty():
			var img_tex := ImageTexture.create_from_image(img)
			item_list.set_item_icon(_current_cover_to_download,img_tex)
			if _current_cover_to_download == item_selected:
				($TextureRect as TextureRect).texture = img_tex
	_current_cover_to_download += 1

	_refresh_canvas()

	update_next_cover()

# ---------------------------------------------------------------------------
# navigation

func _on_gotoMapsBy_pressed() -> void:
	var selected_song := _get_selected_song()
	if selected_song == null or selected_song.uploader_id == -1: return
	var mapper := selected_song.uploader_name if selected_song.uploader_name != "" else selected_song.level_author_name
	_run_new_request(_make_request(REQ_UPLOADER, str(selected_song.uploader_id), "Maps by %s" % mapper))

# SCROLL_TO_FETCH_THRESHOLD
# Range: 0.0 to 1.0
# Description: Used to request the next page of songs from the current list
# once the user scrolls past this threshold
const SCROLL_TO_FETCH_THRESHOLD := 0.9
var _scroll_page_request_pending := false

func _on_ListV_Scroll_value_changed(new_value: float) -> void:
	var scroll_range := v_scroll.max_value - v_scroll.min_value
	if scroll_range <= 0.0:
		return
	var scroll_ratio := (new_value + v_scroll.page) / scroll_range
	if scroll_ratio > SCROLL_TO_FETCH_THRESHOLD:
		if next_page_available == -1:
			# no next page to load
			return

		# prevent back to back requests
		if _scroll_page_request_pending:
			return

		# request next page and update list
		prev_request.page += 1
		update_list(prev_request)
		_scroll_page_request_pending = true

func _on_back_pressed() -> void:
	if back_stack.is_empty():
		return

	# re-request latest entry
	prev_request = back_stack.back()
	prev_request.page = 0
	back_stack.pop_back()
	update_list(prev_request)

	back_button.visible = back_stack.size() > 0

func _on_CloseButton_pressed() -> void:
	self._hide()

var _is_first_show := true
func _on_BeatSaverPanel_visibility_changed() -> void:
	if _is_first_show:
		# populate initial list of songs with most played on BeatSaver
		prev_request = _make_request(REQ_CATEGORY, str(Category.MOST_PLAYED), CATEGORY_TITLES[Category.MOST_PLAYED])
		update_list(prev_request)
		_is_first_show = false
