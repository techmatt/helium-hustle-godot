class_name CommandRow
extends PanelContainer

signal repeat_delta_requested(entry_index: int, delta: int)
signal remove_requested(entry_index: int)
# from_index, to_index — insert semantics: "move from_index to land before to_index"
signal move_requested(from_index: int, to_index: int)

func _bg_normal() -> Color:
	return Color(0.0, 0.0, 0.0, 0.0) if GameSettings.is_dark_mode else Color.WHITE

func _bg_active() -> Color:
	return Color(0.10, 0.30, 0.10, 0.90) if GameSettings.is_dark_mode else Color(0.50, 0.86, 0.50, 0.70)

func _bg_failed() -> Color:
	return Color(0.30, 0.10, 0.10, 0.90) if GameSettings.is_dark_mode else Color(0.86, 0.50, 0.50, 0.70)

func _bg_partial() -> Color:
	return Color(0.28, 0.22, 0.04, 0.90) if GameSettings.is_dark_mode else Color(0.86, 0.78, 0.40, 0.70)

func _fill_color_normal() -> Color:
	return _fill_color_active()

func _fill_color_active() -> Color:
	return Color(0.20, 0.75, 0.20) if GameSettings.is_dark_mode else Color(0.10, 0.72, 0.10)

func _fill_color_failed() -> Color:
	return Color(0.70, 0.20, 0.20) if GameSettings.is_dark_mode else Color(0.72, 0.12, 0.12)

func _fill_color_partial() -> Color:
	return Color(0.75, 0.62, 0.10) if GameSettings.is_dark_mode else Color(0.72, 0.58, 0.08)

func _grip_color() -> Color:
	return Color(0.50, 0.50, 0.50) if GameSettings.is_dark_mode else Color(0.45, 0.45, 0.50)

var _entry_index: int = 0
var _cmd_name: String = ""
var _repeat_count: int = 1

var _bg_style: StyleBoxFlat
var _name_lbl: Label
var _progress_bar: ProgressBar
var _fill_normal: StyleBoxFlat
var _fill_active: StyleBoxFlat
var _fill_failed: StyleBoxFlat
var _fill_partial: StyleBoxFlat
var _minus_btn: Button
var _plus_btn: Button
var _remove_btn: Button


func setup(
	entry_idx: int,
	cmd_name: String,
	repeat_count: int,
	font_r: FontFile,
	font_s: FontFile,
) -> void:
	_entry_index = entry_idx
	_cmd_name = cmd_name
	_repeat_count = repeat_count
	_build_ui(font_r, font_s)


func refresh(
	current_progress: int,
	repeat_count: int,
	is_active: bool,
	failed: bool,
	_can_up: bool,
	_can_down: bool,
	partial_failed: bool = false,
	processors: int = 1,
) -> void:
	_repeat_count = repeat_count
	_name_lbl.text = _cmd_name + " (x%d)" % repeat_count
	_progress_bar.max_value = max(repeat_count * processors, 1)
	_progress_bar.value = current_progress

	if failed:
		_bg_style.bg_color = _bg_failed()
		_progress_bar.add_theme_stylebox_override("fill", _fill_failed)
	elif partial_failed:
		_bg_style.bg_color = _bg_partial()
		_progress_bar.add_theme_stylebox_override("fill", _fill_partial)
	elif is_active:
		_bg_style.bg_color = _bg_active()
		_progress_bar.add_theme_stylebox_override("fill", _fill_active)
	else:
		_bg_style.bg_color = _bg_normal()
		_progress_bar.add_theme_stylebox_override("fill", _fill_normal)


# ── Drag-and-drop ───────────────────────────────────────────────────────────────

func _get_drag_data(_at_pos: Vector2) -> Variant:
	set_drag_preview(_make_drag_preview())
	return {"entry_index": _entry_index, "cmd_name": _cmd_name}


func _can_drop_data(_at_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("entry_index") \
		and data.entry_index != _entry_index


func _drop_data(_at_pos: Vector2, data: Variant) -> void:
	# Insert the dragged entry before this row's position
	move_requested.emit(data.entry_index, _entry_index)


func _make_drag_preview() -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.28, 0.05, 0.92) if GameSettings.is_dark_mode else Color(0.50, 0.86, 0.50, 0.92)
	style.corner_radius_top_left     = 3
	style.corner_radius_top_right    = 3
	style.corner_radius_bottom_left  = 3
	style.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = "  " + _cmd_name + " (x%d)" % _repeat_count + "  "
	lbl.add_theme_font_size_override("font_size", 13)
	panel.add_child(lbl)
	return panel


# ── Build ───────────────────────────────────────────────────────────────────────

func _build_ui(font_r: FontFile, font_s: FontFile) -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_bg_style = StyleBoxFlat.new()
	_bg_style.bg_color = _bg_normal()
	_bg_style.corner_radius_top_left     = 3
	_bg_style.corner_radius_top_right    = 3
	_bg_style.corner_radius_bottom_left  = 3
	_bg_style.corner_radius_bottom_right = 3
	if not GameSettings.is_dark_mode:
		_bg_style.border_width_left   = 1
		_bg_style.border_width_right  = 1
		_bg_style.border_width_top    = 1
		_bg_style.border_width_bottom = 1
		_bg_style.border_color = Color(0.816, 0.816, 0.816)  # #D0D0D0
	add_theme_stylebox_override("panel", _bg_style)

	_fill_normal  = _make_fill(_fill_color_normal())
	_fill_active  = _make_fill(_fill_color_active())
	_fill_failed  = _make_fill(_fill_color_failed())
	_fill_partial = _make_fill(_fill_color_partial())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   5)
	margin.add_theme_constant_override("margin_right",  5)
	margin.add_theme_constant_override("margin_top",    4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	margin.add_child(hbox)

	# Drag handle — MOUSE_FILTER_PASS so drags from here propagate to CommandRow
	var grip := Label.new()
	grip.text = "\u22ee\u22ee"  # ⋮⋮
	grip.add_theme_font_size_override("font_size", 11)
	grip.add_theme_color_override("font_color", _grip_color())
	grip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grip.custom_minimum_size = Vector2(14, 0)
	grip.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(grip)

	# Command name label — MOUSE_FILTER_PASS so drag initiates from here
	_name_lbl = Label.new()
	_name_lbl.text = _cmd_name + " (x%d)" % _repeat_count
	_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_lbl.clip_contents = true
	_name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	if font_r:
		_name_lbl.add_theme_font_override("font", font_r)
	_name_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(_name_lbl)

	# Progress bar
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(68, 14)
	_progress_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress_bar.max_value = max(_repeat_count, 1)
	_progress_bar.value = 0
	_progress_bar.show_percentage = false
	_progress_bar.add_theme_stylebox_override("fill", _fill_normal)
	if not GameSettings.is_dark_mode:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.78, 0.78, 0.78)  # medium gray track
		_progress_bar.add_theme_stylebox_override("background", bg)
	hbox.add_child(_progress_bar)

	# −  +  × buttons
	_minus_btn = _make_icon_btn("\u2212", font_s)
	_minus_btn.pressed.connect(func(): repeat_delta_requested.emit(_entry_index, -1))
	hbox.add_child(_minus_btn)

	_plus_btn = _make_icon_btn("+", font_s)
	_plus_btn.pressed.connect(func(): repeat_delta_requested.emit(_entry_index, 1))
	hbox.add_child(_plus_btn)

	_remove_btn = _make_icon_btn("\u00d7", font_s)
	_remove_btn.pressed.connect(func(): remove_requested.emit(_entry_index))
	hbox.add_child(_remove_btn)


func _make_icon_btn(txt: String, font_s: FontFile) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(28, 28)
	btn.focus_mode = Control.FOCUS_NONE
	if font_s:
		btn.add_theme_font_override("font", font_s)
	btn.add_theme_font_size_override("font_size", 19)
	if not GameSettings.is_dark_mode:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.941, 0.941, 0.941)  # #F0F0F0
		s.corner_radius_top_left     = 3
		s.corner_radius_top_right    = 3
		s.corner_radius_bottom_left  = 3
		s.corner_radius_bottom_right = 3
		s.border_width_left   = 1
		s.border_width_right  = 1
		s.border_width_top    = 1
		s.border_width_bottom = 1
		s.border_color = Color(0.816, 0.816, 0.816)  # #D0D0D0
		s.content_margin_left   = 2
		s.content_margin_right  = 2
		s.content_margin_top    = 2
		s.content_margin_bottom = 2
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_stylebox_override("hover",  s)
	return btn


func _make_fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	return s
