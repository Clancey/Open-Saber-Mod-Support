extends Panel
class_name LobbyPanel

# Multiplayer lobby UI: host, join by 4-character code (letter spinners so no
# keyboard is needed), the code shown large once in a lobby, the roster with
# ready/song state and live scores, a Ready toggle and the host-only Pick Song
# and Start buttons. Talks to the MultiplayerSession autoload; the main menu
# tells it which song the host picked through set_selected_song() (broadcast
# to everyone as song_selected) and reacts to song_start_requested itself.
# A LobbyMapFetcher child checks/downloads the selected song on every peer.

signal start_pressed(song_key: String, difficulty: String)
signal closed()
## The host wants to choose the song in the level list.
signal pick_song_requested()

const ALPHABET := WebRtcSignaling.CODE_ALPHABET

var selected_song_key := ""
var selected_difficulty := ""
var selected_song_label := ""

var _code_indices: Array[int] = [0, 0, 0, 0]
var _rows: Dictionary = {}  # peer id -> row Control
var _fetcher: LobbyMapFetcher

@onready var _title := $VBox/Title as Label
@onready var _status := $VBox/Status as Label
@onready var _code_label := $VBox/CodeLabel as Label
@onready var _offline := $VBox/Offline as VBoxContainer
@onready var _host_button := $VBox/Offline/HostButton as Button
@onready var _code_entry := $VBox/Offline/JoinRow/CodeEntry as HBoxContainer
@onready var _join_button := $VBox/Offline/JoinRow/JoinButton as Button
@onready var _lobby := $VBox/Lobby as VBoxContainer
@onready var _song_label := $VBox/Lobby/SongLabel as Label
@onready var _roster := $VBox/Lobby/RosterScroll/Roster as VBoxContainer
@onready var _ready_button := $VBox/Lobby/Buttons/ReadyButton as Button
@onready var _start_button := $VBox/Lobby/Buttons/StartButton as Button
@onready var _leave_button := $VBox/Lobby/Buttons/LeaveButton as Button
@onready var _pick_button := $VBox/Lobby/Buttons/PickSongButton as Button


func _ready() -> void:
	_build_code_entry()
	_fetcher = LobbyMapFetcher.new()
	_fetcher.name = "MapFetcher"
	var parent := get_parent()
	if parent != null and parent.has_method("get_all_songs"):
		_fetcher.main_menu = parent
	_fetcher.state_changed.connect(_on_fetch_state_changed)
	_fetcher.progress.connect(_on_fetch_progress)
	_fetcher.song_ready.connect(_on_song_ready)
	_fetcher.song_unavailable.connect(_on_song_unavailable)
	add_child(_fetcher)
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_ready_button.toggled.connect(_on_ready_toggled)
	_start_button.pressed.connect(_on_start_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)
	_pick_button.pressed.connect(pick_song_requested.emit)
	MultiplayerSession.lobby_joined.connect(_on_lobby_joined)
	MultiplayerSession.lobby_left.connect(_on_lobby_left)
	MultiplayerSession.roster_changed.connect(_on_roster_changed)
	MultiplayerSession.song_selected.connect(_on_song_selected)
	# The main menu attaches click sounds to all of its children (this panel
	# included); only do it here when the panel is used on its own.
	if has_node("/root/UI_AudioEngine") and _fetcher.main_menu == null:
		UI_AudioEngine.attach_children(self)
	refresh()


## Called by the menu when the host picked a level. Online hosts broadcast it
## (song_selected then updates this panel on every peer); otherwise it only
## updates the local selection.
func set_selected_song(song_key: String, difficulty: String, display_label: String = "") -> void:
	if MultiplayerSession.is_host():
		if MultiplayerSession.select_song(song_key, difficulty):
			return
	_apply_selection(song_key, difficulty, display_label)


func get_fetcher() -> LobbyMapFetcher:
	return _fetcher


func get_entered_code() -> String:
	var code := ""
	for index: int in _code_indices:
		code += ALPHABET[index]
	return code


func show_status(text: String) -> void:
	_status.text = text


## The VR canvas that hosts this panel only re-renders on pointer input;
## ask it to redraw so roster/score changes show up without moving the laser.
func _request_canvas_redraw() -> void:
	var node: Node = get_parent()
	while node != null:
		if node.has_method("_input_update"):
			node.call("_input_update")
			return
		node = node.get_parent()


func refresh() -> void:
	call_deferred("_request_canvas_redraw")
	var online := MultiplayerSession.is_online()
	var connecting := MultiplayerSession.state == MultiplayerSession.State.CONNECTING
	_offline.visible = not online
	_lobby.visible = online
	_host_button.disabled = connecting
	_join_button.disabled = connecting
	_code_label.visible = online
	if online:
		_code_label.text = MultiplayerSession.lobby_code
		_status.text = "HOSTING - SHARE THIS CODE" if MultiplayerSession.is_host() else "LOBBY CODE"
		_song_label.text = _song_line()
		var me := MultiplayerSession.get_player(MultiplayerSession.get_local_id())
		_ready_button.set_pressed_no_signal(bool(me.get("ready", false)))
		_ready_button.text = "READY!" if _ready_button.button_pressed else "READY"
		_ready_button.disabled = not _song_available()
		_start_button.visible = MultiplayerSession.is_host()
		_pick_button.visible = MultiplayerSession.is_host()
		_start_button.disabled = not (MultiplayerSession.all_ready() and selected_song_key != "")
		_rebuild_roster(MultiplayerSession.get_players())
	elif connecting:
		_status.text = "CONNECTING..."
	else:
		_status.text = "HOST A LOBBY OR ENTER A CODE"


# --- Song selection / download state ---------------------------------------

func _apply_selection(song_key: String, difficulty: String, display_label: String = "") -> void:
	selected_song_key = song_key
	selected_difficulty = difficulty
	selected_song_label = display_label if display_label != "" else _label_for(song_key, difficulty)
	if song_key != "":
		_fetcher.resolve(song_key)
	refresh()


static func _label_for(song_key: String, difficulty: String) -> String:
	var label := LobbySongKey.display_name(song_key)
	var parts := difficulty.split("|")
	if parts.size() > 0 and not parts[0].is_empty():
		label += " (%s)" % parts[0]
	return label


func _song_available() -> bool:
	return selected_song_key != "" and _fetcher != null and _fetcher.is_ready()


func _song_line() -> String:
	if selected_song_key == "":
		return "PICK A SONG" if MultiplayerSession.is_host() else "WAITING FOR THE HOST TO PICK A SONG"
	if _fetcher == null:
		return "SONG: %s" % selected_song_label
	match _fetcher.state:
		LobbyMapFetcher.State.READY:
			return "SONG: %s (READY)" % selected_song_label
		LobbyMapFetcher.State.DOWNLOADING:
			return "DOWNLOADING %s %d%%" % [selected_song_label, roundi(_fetcher.last_fraction * 100.0)]
		LobbyMapFetcher.State.EXTRACTING:
			return "INSTALLING %s..." % selected_song_label
		LobbyMapFetcher.State.UNAVAILABLE:
			if _fetcher.last_reason == "not_found":
				return "NOT ON BEATSAVER, ASK THE HOST TO PICK ANOTHER"
			return "DOWNLOAD FAILED, ASK THE HOST TO PICK ANOTHER"
		_:
			return "CHECKING %s..." % selected_song_label


func _on_song_selected(song_key: String, difficulty: String) -> void:
	_apply_selection(song_key, difficulty)


func _on_fetch_state_changed(_state: int, _detail: String) -> void:
	refresh()


func _on_fetch_progress(_fraction: float) -> void:
	_song_label.text = _song_line()
	call_deferred("_request_canvas_redraw")


func _on_song_ready(_song_key: String, _map: MapInfo) -> void:
	MultiplayerSession.set_has_song(true)
	refresh()


func _on_song_unavailable(_song_key: String, _reason: String) -> void:
	MultiplayerSession.set_has_song(false)
	refresh()


# --- Code entry -------------------------------------------------------------

func _build_code_entry() -> void:
	for child: Node in _code_entry.get_children():
		child.queue_free()
	for slot: int in range(4):
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		var up := Button.new()
		up.text = "+"
		up.custom_minimum_size = Vector2(64, 44)
		up.focus_mode = Control.FOCUS_NONE
		up.pressed.connect(_on_code_step.bind(slot, 1))
		column.add_child(up)
		var letter := Label.new()
		letter.name = "Letter"
		letter.text = ALPHABET[_code_indices[slot]]
		letter.custom_minimum_size = Vector2(64, 60)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		letter.add_theme_font_size_override("font_size", 52)
		column.add_child(letter)
		var down := Button.new()
		down.text = "-"
		down.custom_minimum_size = Vector2(64, 44)
		down.focus_mode = Control.FOCUS_NONE
		down.pressed.connect(_on_code_step.bind(slot, -1))
		column.add_child(down)
		_code_entry.add_child(column)


func _on_code_step(slot: int, delta: int) -> void:
	_code_indices[slot] = posmod(_code_indices[slot] + delta, ALPHABET.length())
	var column := _code_entry.get_child(slot)
	(column.get_node("Letter") as Label).text = ALPHABET[_code_indices[slot]]


func set_entered_code(code: String) -> void:
	var clean := code.strip_edges().to_upper()
	for slot: int in range(mini(4, clean.length())):
		var index := ALPHABET.find(clean[slot])
		if index != -1:
			_code_indices[slot] = index
	for slot: int in range(4):
		var column := _code_entry.get_child(slot)
		if column != null:
			(column.get_node("Letter") as Label).text = ALPHABET[_code_indices[slot]]


# --- Roster -----------------------------------------------------------------

func _rebuild_roster(players: Array[Dictionary]) -> void:
	var seen: Array[int] = []
	for player: Dictionary in players:
		var id := int(player["id"])
		seen.append(id)
		var row: Control = _rows.get(id)
		if row == null:
			row = _make_row()
			_roster.add_child(row)
			_rows[id] = row
		_fill_row(row, player)
	for id: int in _rows.keys():
		if not seen.has(id):
			(_rows[id] as Control).queue_free()
			_rows.erase(id)


func _make_row() -> Control:
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 56)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.focus_mode = Control.FOCUS_NONE
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.theme_type_variation = &"LevelRow"
	var content := HBoxContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 12.0
	content.offset_right = -12.0
	content.add_theme_constant_override("separation", 12)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(content)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(name_label)
	var score_label := Label.new()
	score_label.name = "Score"
	score_label.add_theme_font_size_override("font_size", 26)
	score_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content.add_child(score_label)
	var ready_label := Label.new()
	ready_label.name = "Ready"
	ready_label.custom_minimum_size = Vector2(120, 0)
	ready_label.add_theme_font_size_override("font_size", 26)
	ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content.add_child(ready_label)
	return row


func _fill_row(row: Control, player: Dictionary) -> void:
	var content := row.get_node("Content")
	var is_host := int(player["id"]) == 1
	var is_me := int(player["id"]) == MultiplayerSession.get_local_id()
	var display_name := str(player["name"])
	if is_host:
		display_name += " (HOST)"
	if is_me:
		display_name += " - YOU"
	(content.get_node("Name") as Label).text = display_name
	var score_text := ""
	if bool(player["finished"]):
		score_text = "%d  %d%%  %s" % [int(player["score"]), roundi(float(player["percent"]) * 100.0), str(player["rank"])]
	elif int(player["score"]) > 0 or int(player["combo"]) > 0:
		score_text = "%d  x%d  %d%%" % [int(player["score"]), int(player["combo"]), roundi(float(player["percent"]) * 100.0)]
	(content.get_node("Score") as Label).text = score_text
	var ready_label := content.get_node("Ready") as Label
	var has_song := bool(player.get("has_song", false))
	if bool(player["finished"]):
		ready_label.text = "DONE"
		ready_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	elif bool(player["ready"]):
		ready_label.text = "READY"
		ready_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55))
	elif selected_song_key != "" and not has_song:
		ready_label.text = "GETTING SONG" if not is_me or _fetcher.state != LobbyMapFetcher.State.UNAVAILABLE else "NO SONG"
		ready_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	elif has_song:
		ready_label.text = "HAS SONG"
		ready_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	else:
		ready_label.text = "..."
		ready_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))


# --- Buttons / session callbacks -------------------------------------------

func _on_host_pressed() -> void:
	if MultiplayerSession.host_lobby():
		refresh()


func _on_join_pressed() -> void:
	if MultiplayerSession.join_lobby(get_entered_code()):
		refresh()


func _on_ready_toggled(pressed: bool) -> void:
	MultiplayerSession.set_ready(pressed)
	refresh()


func _on_start_pressed() -> void:
	if MultiplayerSession.start_song(selected_song_key, selected_difficulty):
		start_pressed.emit(selected_song_key, selected_difficulty)


func _on_leave_pressed() -> void:
	MultiplayerSession.leave()
	closed.emit()


func _on_lobby_joined(_code: String) -> void:
	refresh()


func _on_lobby_left(reason: String) -> void:
	selected_song_key = ""
	selected_difficulty = ""
	selected_song_label = ""
	refresh()
	match reason:
		"lobby_not_found":
			_status.text = "NO LOBBY WITH THAT CODE"
		"timeout", "connect_failed":
			_status.text = "COULD NOT REACH THE SERVER"
		"host_left":
			_status.text = "THE HOST LEFT"
		"code_taken":
			_status.text = "COULD NOT CREATE A LOBBY, TRY AGAIN"
		"sealed":
			_status.text = "THE LOBBY WAS CLOSED"


func _on_roster_changed(_players: Array[Dictionary]) -> void:
	refresh()
