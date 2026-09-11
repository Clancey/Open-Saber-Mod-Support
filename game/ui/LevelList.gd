extends ScrollContainer
class_name LevelList

# Beat Saber style level list: one row per level with the cover on the left,
# the song name over the author, and the BPM on the right.
# Exposes the subset of the ItemList API the menu code relies on.

signal item_selected(index: int)

const ROW_HEIGHT := 84.0
const COVER_SIZE := 68.0

var _rows: Array[Button] = []
var _selected := -1
var _list: VBoxContainer

func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = VBoxContainer.new()
	_list.name = "Rows"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	add_child(_list)

func clear() -> void:
	for row: Button in _rows:
		row.queue_free()
	_rows.clear()
	_selected = -1

## ItemList compatibility: "Song - Author" text with an icon.
func add_item(text: String, icon: Texture2D = null) -> int:
	var parts := text.split(" - ", true, 1)
	return add_level(parts[0], parts[1] if parts.size() > 1 else "", "", icon)

func add_level(song_name: String, author: String, detail: String, icon: Texture2D) -> int:
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.toggle_mode = true
	row.focus_mode = Control.FOCUS_NONE
	row.theme_type_variation = &"LevelRow"
	var content := HBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8.0
	content.offset_right = -12.0
	content.add_theme_constant_override("separation", 14)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(content)

	var cover := TextureRect.new()
	cover.name = "Cover"
	cover.custom_minimum_size = Vector2(COVER_SIZE, COVER_SIZE)
	cover.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.texture = icon
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(cover)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(texts)
	var name_label := Label.new()
	name_label.text = song_name
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(name_label)
	var author_label := Label.new()
	author_label.text = author
	author_label.add_theme_font_size_override("font_size", 22)
	author_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	author_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	author_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(author_label)

	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.add_theme_font_size_override("font_size", 24)
	detail_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	detail_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(detail_label)

	var index := _rows.size()
	row.pressed.connect(_on_row_pressed.bind(index))
	_list.add_child(row)
	_rows.append(row)
	return index

func set_item_icon(index: int, icon: Texture2D) -> void:
	if index < 0 or index >= _rows.size():
		return
	var cover := _rows[index].find_child("Cover", true, false) as TextureRect
	if cover != null:
		cover.texture = icon

func select(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	if _selected >= 0 and _selected < _rows.size():
		_rows[_selected].button_pressed = false
	_selected = index
	_rows[index].button_pressed = true

func get_selected_items() -> PackedInt32Array:
	if _selected < 0:
		return PackedInt32Array()
	return PackedInt32Array([_selected])

func get_item_count() -> int:
	return _rows.size()

func ensure_current_is_visible() -> void:
	if _selected < 0 or _selected >= _rows.size():
		return
	ensure_control_visible(_rows[_selected])

func _on_row_pressed(index: int) -> void:
	select(index)
	item_selected.emit(index)
