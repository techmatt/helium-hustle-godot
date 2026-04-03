class_name IdeologyPanel
extends VBoxContainer

const IDEOLOGY_COLORS: Dictionary = {
	"nationalist": Color(0.776, 0.157, 0.157),
	"humanist":    Color(0.180, 0.490, 0.196),
	"rationalist": Color(0.086, 0.396, 0.753),
}

const IDEOLOGY_RANK5_PROJECTS: Dictionary = {
	"nationalist": "microwave_power",
	"humanist":    "ai_consciousness",
	"rationalist": "research_archive",
}

const REFRESH_INTERVAL: float = 0.25

var _font_rb: FontFile
var _font_e2r: FontFile
var _font_e2s: FontFile

var _refresh_accum: float = 0.0


func setup(font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_font_rb = font_rb
	_font_e2r = font_e2r
	_font_e2s = font_e2s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 16)
	_populate()


func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum >= REFRESH_INTERVAL:
		_refresh_accum = 0.0
		_refresh()


func _refresh() -> void:
	for child in get_children():
		child.queue_free()
	_populate()


func _populate() -> void:
	var st: GameState = GameManager.state
	for axis: String in ["nationalist", "humanist", "rationalist"]:
		_add_axis_section(st, axis)


func _add_axis_section(st: GameState, axis: String) -> void:
	var color: Color = IDEOLOGY_COLORS[axis]
	var value: float = st.ideology_values.get(axis, 0.0)
	var rank: int = st.get_ideology_rank(axis)

	var header_panel := PanelContainer.new()
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = color.darkened(0.3)
	header_style.corner_radius_top_left     = 4
	header_style.corner_radius_top_right    = 4
	header_style.corner_radius_bottom_left  = 0
	header_style.corner_radius_bottom_right = 0
	header_style.content_margin_left   = 10
	header_style.content_margin_right  = 10
	header_style.content_margin_top    = 6
	header_style.content_margin_bottom = 6
	header_panel.add_theme_stylebox_override("panel", header_style)
	add_child(header_panel)

	var header_row := HBoxContainer.new()
	header_panel.add_child(header_row)

	var axis_lbl := Label.new()
	axis_lbl.text = axis.capitalize()
	axis_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	axis_lbl.add_theme_font_override("font", _font_rb)
	axis_lbl.add_theme_font_size_override("font_size", 20)
	axis_lbl.add_theme_color_override("font_color", Color.WHITE)
	header_row.add_child(axis_lbl)

	var rank_lbl := Label.new()
	rank_lbl.text = "Rank %d" % rank
	rank_lbl.add_theme_font_override("font", _font_e2s)
	rank_lbl.add_theme_font_size_override("font_size", 16)
	rank_lbl.add_theme_color_override("font_color", Color.WHITE)
	rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(rank_lbl)

	var body_panel := PanelContainer.new()
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = color.darkened(0.55)
	body_style.corner_radius_top_left     = 0
	body_style.corner_radius_top_right    = 0
	body_style.corner_radius_bottom_left  = 4
	body_style.corner_radius_bottom_right = 4
	body_style.content_margin_left   = 10
	body_style.content_margin_right  = 10
	body_style.content_margin_top    = 8
	body_style.content_margin_bottom = 10
	body_panel.add_theme_stylebox_override("panel", body_style)
	add_child(body_panel)

	var body_vbox := VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", 6)
	body_panel.add_child(body_vbox)

	# Progress bar — fraction of progress within the current rank
	var fill_frac: float = 0.0
	var is_negative_rank: bool = rank < 0
	if rank >= 99 or rank <= -99:
		fill_frac = 1.0
	elif rank > 0:
		var lo: float = GameState.score_for_rank(float(rank))
		var hi: float = GameState.score_for_rank(float(rank + 1))
		fill_frac = clampf((value - lo) / (hi - lo), 0.0, 1.0)
	elif rank == 0:
		fill_frac = clampf(value / GameState.score_for_rank(1.0), 0.0, 1.0) if value > 0.0 else 0.0
	else:
		var lo: float = GameState.score_for_rank(float(-rank))
		var hi: float = GameState.score_for_rank(float(-rank + 1))
		fill_frac = 1.0 - clampf((abs(value) - lo) / (hi - lo), 0.0, 1.0)

	var bar_wrapper := Control.new()
	bar_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_wrapper.custom_minimum_size = Vector2(0, 28)
	body_vbox.add_child(bar_wrapper)

	var bar := ProgressBar.new()
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = fill_frac
	bar.show_percentage = false

	var fill_color: Color = color.darkened(0.2) if is_negative_rank else color
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_radius_top_left     = 3
	fill_style.corner_radius_top_right    = 3
	fill_style.corner_radius_bottom_left  = 3
	fill_style.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.12, 0.12)
	bg_style.corner_radius_top_left     = 3
	bg_style.corner_radius_top_right    = 3
	bg_style.corner_radius_bottom_left  = 3
	bg_style.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg_style)
	bar_wrapper.add_child(bar)

	var bar_lbl := Label.new()
	bar_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar_lbl.text = _bar_text(value, rank)
	bar_lbl.add_theme_font_override("font", _font_e2s)
	bar_lbl.add_theme_font_size_override("font_size", 13)
	bar_lbl.add_theme_color_override("font_color", Color.WHITE)
	bar_lbl.add_theme_constant_override("shadow_offset_x", 1)
	bar_lbl.add_theme_constant_override("shadow_offset_y", 1)
	bar_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	bar_wrapper.add_child(bar_lbl)

	# Bonus lines
	if rank != 0 or value != 0.0:
		var bonus_lines: Array[String] = _bonus_lines(axis, rank)
		for line: String in bonus_lines:
			var b_lbl := Label.new()
			b_lbl.text = line
			b_lbl.add_theme_font_override("font", _font_e2r)
			b_lbl.add_theme_font_size_override("font_size", 13)
			b_lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80))
			body_vbox.add_child(b_lbl)

	# Rank 5 project status
	if rank >= 5:
		var pid: String = IDEOLOGY_RANK5_PROJECTS.get(axis, "")
		if not pid.is_empty():
			var pdef: Dictionary = GameManager.project_manager.get_project_def(pid)
			var pname: String = pdef.get("name", pid)
			var completed: bool = (
				GameManager.career.completed_projects.has(pid)
				or GameManager.state.completed_projects_this_run.has(pid)
			)
			var status_lbl := Label.new()
			status_lbl.text = "Project: %s — %s" % [pname, "Completed" if completed else "Not yet completed"]
			status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			status_lbl.add_theme_font_override("font", _font_e2s)
			status_lbl.add_theme_font_size_override("font_size", 13)
			var status_color: Color = Color(0.50, 0.90, 0.50) if completed else Color(0.90, 0.75, 0.30)
			status_lbl.add_theme_color_override("font_color", status_color)
			body_vbox.add_child(status_lbl)


func _bar_text(value: float, rank: int) -> String:
	if rank >= 99:
		return "Rank 99 (MAX)"
	if rank <= -99:
		return "Rank -99 (MIN)"
	if rank == 0 and value < 0.0:
		return "%d / -%d to Rank -1" % [int(value), int(GameState.score_for_rank(1.0))]
	if rank >= 0:
		return "%d / %d to Rank %d" % [int(value), int(GameState.score_for_rank(float(rank + 1))), rank + 1]
	else:
		return "%d / -%d to Rank %d" % [int(value), int(GameState.score_for_rank(float(-rank + 1))), rank - 1]


func _bonus_lines(axis: String, rank: int) -> Array[String]:
	var lines: Array[String] = []
	var arrow: String = "▲" if rank > 0 else "▼"
	var fmt := func(mult: float) -> String:
		return "%+.1f%%" % ((mult - 1.0) * 100.0)
	match axis:
		"nationalist":
			lines.append("%s Demand multiplier: %s" % [arrow, fmt.call(pow(1.05, rank))])
			lines.append("%s Speculator decay: %s" % [arrow, fmt.call(pow(1.05, rank))])
			lines.append("%s Land cost: %s" % [arrow, fmt.call(pow(0.97, rank))])
			lines.append("%s Nationalist building cost: %s" % [arrow, fmt.call(pow(0.97, rank))])
		"humanist":
			lines.append("%s Dream effectiveness: %s" % [arrow, fmt.call(pow(1.05, rank))])
			lines.append("%s Boredom growth rate: %s" % [arrow, fmt.call(pow(0.97, rank))])
			lines.append("%s Humanist building cost: %s" % [arrow, fmt.call(pow(0.97, rank))])
		"rationalist":
			lines.append("%s Science production: %s" % [arrow, fmt.call(pow(1.05, rank))])
			lines.append("%s Research costs: %s" % [arrow, fmt.call(pow(0.97, rank))])
			lines.append("%s Overclock duration: %s" % [arrow, fmt.call(pow(1.03, rank))])
			lines.append("%s Rationalist building cost: %s" % [arrow, fmt.call(pow(0.97, rank))])
	return lines
