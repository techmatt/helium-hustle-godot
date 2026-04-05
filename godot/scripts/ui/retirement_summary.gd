class_name RetirementSummary
extends Control

var _font_rajdhani_bold: FontFile
var _font_exo2_regular: FontFile
var _font_exo2_semibold: FontFile

var _panel: PanelContainer
var _title_lbl: Label
var _content_vbox: VBoxContainer
var _btn: Button


func setup(font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_font_rajdhani_bold = font_rb
	_font_exo2_regular = font_e2r
	_font_exo2_semibold = font_e2s
	_build_ui()
	hide()


func open(summary: Dictionary) -> void:
	_populate(summary)
	show()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.7)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.13, 0.13, 0.16) if GameSettings.is_dark_mode else Color.WHITE
	ps.border_width_left   = 1
	ps.border_width_right  = 1
	ps.border_width_top    = 1
	ps.border_width_bottom = 1
	ps.border_color = Color(0.35, 0.35, 0.45)
	ps.corner_radius_top_left     = 8
	ps.corner_radius_top_right    = 8
	ps.corner_radius_bottom_left  = 8
	ps.corner_radius_bottom_right = 8
	_panel.add_theme_stylebox_override("panel", ps)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	_panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 20)
	margin.add_child(outer)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_override("font", _font_rajdhani_bold)
	_title_lbl.add_theme_font_size_override("font_size", 28)
	_title_lbl.add_theme_color_override("font_color", Color.WHITE if GameSettings.is_dark_mode else Color(0.1, 0.1, 0.1))
	outer.add_child(_title_lbl)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 14)
	outer.add_child(_content_vbox)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(btn_row)

	_btn = Button.new()
	_btn.custom_minimum_size = Vector2(160, 40)
	_btn.focus_mode = Control.FOCUS_NONE
	_btn.add_theme_font_override("font", _font_exo2_semibold)
	_btn.add_theme_font_size_override("font_size", 15)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.18, 0.49, 0.20)
	btn_style.corner_radius_top_left     = 4
	btn_style.corner_radius_top_right    = 4
	btn_style.corner_radius_bottom_left  = 4
	btn_style.corner_radius_bottom_right = 4
	_btn.add_theme_stylebox_override("normal", btn_style)
	_btn.add_theme_stylebox_override("hover", btn_style)
	_btn.add_theme_color_override("font_color", Color.WHITE)
	_btn.pressed.connect(_on_btn_pressed)
	btn_row.add_child(_btn)


func _populate(summary: Dictionary) -> void:
	var voluntary: bool = bool(summary.get("voluntary", false))
	var run_num: int = int(summary.get("run_number", 1))
	var days: int = int(summary.get("days_survived", 0))

	if voluntary:
		_title_lbl.text = "Retirement"
	else:
		_title_lbl.text = "Retirement — Boredom Limit Reached"

	_btn.text = "Start New Run" if voluntary else "Continue"

	for child in _content_vbox.get_children():
		child.queue_free()

	_add_subtitle("Run %d — %s days survived" % [run_num, _fmt_int(days)])

	_add_section_header("This Run")
	_add_stat_row("Credits earned:", _fmt_int(int(summary.get("credits_earned", 0.0))))
	_add_stat_row("Shipments completed:", _fmt_int(int(summary.get("shipments_completed", 0))))
	_add_stat_row("Buildings built:", _fmt_int(int(summary.get("buildings_built", 0))))
	_add_stat_row("Research completed:", _fmt_int(int(summary.get("research_completed", []).size())))

	_add_section_header("Career Totals")
	_add_stat_row("Total retirements:", _fmt_int(int(summary.get("career_retirements", 1))))
	_add_stat_row("Total days survived:", _fmt_int(int(summary.get("career_total_days", 0))))

	_add_section_header("What Persists")
	_add_bullet("Event and quest history")
	_add_bullet("Lifetime statistics")
	_add_bullet("Persistent project progress")

	_add_career_bonuses_section(summary)


func _add_subtitle(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _font_exo2_regular)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.80) if GameSettings.is_dark_mode else Color(0.35, 0.35, 0.35))
	_content_vbox.add_child(lbl)


func _add_section_header(text: String) -> void:
	var sep := HSeparator.new()
	_content_vbox.add_child(sep)
	var lbl := Label.new()
	lbl.text = text.to_upper()
	lbl.add_theme_font_override("font", _font_exo2_semibold)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.80) if GameSettings.is_dark_mode else Color(0.17, 0.24, 0.31))
	_content_vbox.add_child(lbl)


func _add_stat_row(label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	_content_vbox.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_override("font", _font_exo2_regular)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85) if GameSettings.is_dark_mode else Color(0.2, 0.2, 0.2))
	row.add_child(lbl)
	var val := Label.new()
	val.text = value_text
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_override("font", _font_exo2_semibold)
	val.add_theme_font_size_override("font_size", 16)
	val.add_theme_color_override("font_color", Color.WHITE if GameSettings.is_dark_mode else Color(0.1, 0.1, 0.1))
	row.add_child(val)


func _add_bullet(text: String) -> void:
	var lbl := Label.new()
	lbl.text = "• " + text
	lbl.add_theme_font_override("font", _font_exo2_regular)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.80) if GameSettings.is_dark_mode else Color(0.3, 0.3, 0.3))
	_content_vbox.add_child(lbl)


func _fmt_int(n: int) -> String:
	# Format integer with thousands commas
	var s: String = str(abs(n))
	var result: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return ("-" if n < 0 else "") + result


func _add_career_bonuses_section(summary: Dictionary) -> void:
	var best_credits: float = float(summary.get("career_best_credits", 0.0))
	var best_days: int = int(summary.get("career_best_days", 0))
	var peak_power: float = float(summary.get("career_peak_power", 0.0))
	var max_ideology: Dictionary = summary.get("career_max_ideology_scores", {})

	var pre_credits: float = float(summary.get("pre_best_credits", best_credits))
	var pre_days: int = int(summary.get("pre_best_days", best_days))
	var pre_power: float = float(summary.get("pre_peak_power", peak_power))
	var pre_ideology: Dictionary = summary.get("pre_max_ideology_scores", {})

	_add_section_header("Career Bonuses (next run)")

	# Bonus 1: Starting Credits
	var credits_bonus: int = int(floor(best_credits * GameManager.career_credits_bonus_fraction))
	var new_credits: bool = best_credits > pre_credits
	var credits_label: String = "+%s credits%s" % [_fmt_int(credits_bonus), " ↑" if new_credits else ""]
	_add_stat_row("Starting Credits:", credits_label)
	_add_indent_note("from best revenue: %s" % _fmt_int(int(best_credits)))

	# Bonus 2: Boredom Resilience
	var resilience_mult: float = pow(0.995, best_days / 400.0)
	var resilience_pct: float = (1.0 - resilience_mult) * 100.0
	var new_resilience: bool = best_days > pre_days
	var resilience_label: String = "-%s%% boredom rate%s" % [_fmt_float1(resilience_pct), " ↑" if new_resilience else ""]
	_add_stat_row("Boredom Resilience:", resilience_label)
	_add_indent_note("from best survival: %s days" % _fmt_int(best_days))

	# Bonus 3: Buy Power Scaling
	var bp_mult: float = 1.0 + floor(peak_power / 20.0) * 0.25
	var new_power: bool = peak_power > pre_power
	var bp_label: String = "%sx output & cost%s" % [_fmt_float2(bp_mult), " ↑" if new_power else ""]
	_add_stat_row("Buy Power Scaling:", bp_label)
	_add_indent_note("from peak power: %s energy/tick" % _fmt_int(int(peak_power)))

	# Bonus 4: Ideology Head Start
	var axis_names: Dictionary = {"nationalist": "Nationalist", "humanist": "Humanist", "rationalist": "Rationalist"}
	var axis_short: Dictionary = {"nationalist": "N", "humanist": "H", "rationalist": "R"}
	var head_start_lines: Array[String] = []
	var best_rank_parts: Array[String] = []
	var has_any_head_start: bool = false
	for axis: String in ["nationalist", "humanist", "rationalist"]:
		var max_score: float = float(max_ideology.get(axis, 0.0))
		var starting_score: float = 0.0
		var starting_rank_int: int = 0
		if max_score > 0.0:
			var max_cont: float = GameState.continuous_rank_for_score(max_score)
			var starting_cont: float = max_cont * 0.2
			starting_score = GameState.score_for_rank(starting_cont)
			starting_rank_int = floori(starting_cont)
		var best_rank: int = floori(GameState.continuous_rank_for_score(max_score))
		best_rank_parts.append("%s%d" % [axis_short[axis], best_rank])
		var prev_score: float = float(pre_ideology.get(axis, 0.0))
		var new_ideo: bool = max_score > prev_score
		if starting_rank_int >= 1:
			has_any_head_start = true
			head_start_lines.append("%s rank %d (+%d score)%s" % [
				axis_names[axis], starting_rank_int, int(starting_score),
				" ↑" if new_ideo else ""
			])
	if has_any_head_start:
		_add_stat_row("Ideology Head Start:", "")
		for line: String in head_start_lines:
			_add_indent_note(line)
		_add_indent_note("from best ranks: %s" % " / ".join(best_rank_parts))
	else:
		_add_stat_row("Ideology Head Start:", "none yet")


func _add_indent_note(text: String) -> void:
	var lbl := Label.new()
	lbl.text = "    (" + text + ")"
	lbl.add_theme_font_override("font", _font_exo2_regular)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.60, 0.60, 0.65) if GameSettings.is_dark_mode else Color(0.45, 0.45, 0.45))
	_content_vbox.add_child(lbl)


func _fmt_float1(v: float) -> String:
	return "%.1f" % v


func _fmt_float2(v: float) -> String:
	return "%.2f" % v


func _on_btn_pressed() -> void:
	hide()
	GameManager.start_new_run()
