class_name EventPanel
extends VBoxContainer

const REFRESH_INTERVAL: float = 0.1
const COLOR_HEADER_BG: Color = Color(0.173, 0.243, 0.314)  # #2C3E50

var _font_rajdhani_bold: FontFile
var _font_exo2_regular: FontFile
var _font_exo2_semibold: FontFile

# Persistent section nodes — created once, never freed
var _story_container: VBoxContainer
var _story_header: Button
var _story_items: VBoxContainer

var _ongoing_container: VBoxContainer
var _ongoing_header: Button
var _ongoing_items: VBoxContainer

var _completed_container: VBoxContainer
var _completed_header: Button
var _completed_items: VBoxContainer

var _story_expanded: bool = true
var _ongoing_expanded: bool = false
var _completed_expanded: bool = false

var _refresh_accum: float = 0.0

signal event_row_clicked(event_id: String)


func setup(font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_font_rajdhani_bold = font_rb
	_font_exo2_regular = font_e2r
	_font_exo2_semibold = font_e2s
	add_theme_constant_override("separation", 4)
	_build_structure()
	GameManager.event_manager.event_triggered.connect(func(_id: String) -> void: _rebuild_items())
	GameManager.event_manager.event_completed.connect(func(_id: String) -> void: _rebuild_items())
	_rebuild_items()


func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum >= REFRESH_INTERVAL:
		_refresh_accum = 0.0
		_rebuild_items()


# ── Build persistent skeleton (called once) ───────────────────────────────────

func _build_structure() -> void:
	_story_container = _make_section_container()
	add_child(_story_container)
	_story_header = _make_header_btn("story")
	_story_container.add_child(_story_header)
	_story_items = _make_items_vbox()
	_story_items.visible = _story_expanded
	_story_container.add_child(_story_items)

	_ongoing_container = _make_section_container()
	add_child(_ongoing_container)
	_ongoing_header = _make_header_btn("ongoing")
	_ongoing_container.add_child(_ongoing_header)
	_ongoing_items = _make_items_vbox()
	_ongoing_items.visible = _ongoing_expanded
	_ongoing_container.add_child(_ongoing_items)

	_completed_container = _make_section_container()
	add_child(_completed_container)
	_completed_header = _make_header_btn("completed")
	_completed_container.add_child(_completed_header)
	_completed_items = _make_items_vbox()
	_completed_items.visible = _completed_expanded
	_completed_container.add_child(_completed_items)


func _make_section_container() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	return v


func _make_items_vbox() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	return v


func _make_header_btn(section_key: String) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_override("font", _font_rajdhani_bold)
	btn.add_theme_font_size_override("font_size", 15)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_HEADER_BG
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.pressed.connect(func() -> void: _on_header_pressed(section_key))
	return btn


# ── Header toggle — visibility only, no rebuild ───────────────────────────────

func _on_header_pressed(section_key: String) -> void:
	match section_key:
		"story":
			_story_expanded = not _story_expanded
			_story_items.visible = _story_expanded
			_set_header_text(_story_header, "Story", _story_items.get_child_count(), _story_expanded)
		"ongoing":
			_ongoing_expanded = not _ongoing_expanded
			_ongoing_items.visible = _ongoing_expanded
			_set_header_text(_ongoing_header, "Ongoing", _ongoing_items.get_child_count(), _ongoing_expanded)
		"completed":
			_completed_expanded = not _completed_expanded
			_completed_items.visible = _completed_expanded
			_set_header_text(_completed_header, "Completed", _completed_items.get_child_count(), _completed_expanded)


# ── Item rebuild — only touches rows inside items vboxes ──────────────────────

func _rebuild_items() -> void:
	var st: GameState = GameManager.state
	var em: EventManager = GameManager.event_manager
	var story: Array = em.get_active_events("story", st)
	var ongoing: Array = em.get_active_events("ongoing", st)
	var completed: Array = em.get_completed_events(st)

	_fill_items(_story_container, _story_header, _story_items,
		"Story", story, false, _story_expanded, st, em)
	_fill_items(_ongoing_container, _ongoing_header, _ongoing_items,
		"Ongoing", ongoing, false, _ongoing_expanded, st, em)
	_fill_items(_completed_container, _completed_header, _completed_items,
		"Completed", completed, true, _completed_expanded, st, em)


func _fill_items(
	container: VBoxContainer,
	header: Button,
	items: VBoxContainer,
	title: String,
	instances: Array,
	is_completed: bool,
	expanded: bool,
	st: GameState,
	em: EventManager,
) -> void:
	container.visible = not instances.is_empty()
	_set_header_text(header, title, instances.size(), expanded)
	for child in items.get_children():
		child.free()
	for inst in instances:
		items.add_child(_build_event_row(inst, is_completed, st, em))


func _set_header_text(btn: Button, title: String, count: int, expanded: bool) -> void:
	btn.text = ("▼ " if expanded else "▶ ") + "%s (%d)" % [title, count]


# ── Event row ─────────────────────────────────────────────────────────────────

func _build_event_row(inst: Dictionary, is_completed: bool, st: GameState, em: EventManager) -> Button:
	var event_id: String = inst.id
	var def: Dictionary = em.get_event_def(event_id)

	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", _font_exo2_regular)
	btn.add_theme_font_size_override("font_size", 13)

	var summary: String = def.get("summary", event_id)
	var progress_str: String = em.get_condition_display(event_id, st)
	if not progress_str.is_empty() and not is_completed:
		summary += "  (" + progress_str + ")"
	btn.text = summary

	var dark: bool = GameSettings.is_dark_mode
	var bg_color: Color
	var text_color: Color
	if is_completed:
		bg_color = Color(0.12, 0.12, 0.12) if dark else Color(0.94, 0.94, 0.94)
		text_color = Color(0.40, 0.40, 0.40)
	elif inst.state == "active" and em.is_event_first_time(event_id, st):
		bg_color = Color(0.18, 0.18, 0.18) if dark else Color.WHITE
		text_color = Color.WHITE if dark else Color(0.1, 0.1, 0.1)
	elif inst.state == "active":
		bg_color = Color(0.12, 0.22, 0.12) if dark else Color(0.910, 0.957, 0.910)
		text_color = Color.WHITE if dark else Color(0.1, 0.1, 0.1)
	else:
		bg_color = Color(0.14, 0.14, 0.14) if dark else Color(0.97, 0.97, 0.97)
		text_color = Color.WHITE if dark else Color(0.1, 0.1, 0.1)

	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)

	btn.pressed.connect(func() -> void: event_row_clicked.emit(event_id))
	return btn
