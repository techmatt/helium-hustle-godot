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
	_content_vbox.add_theme_constant_override("separation", 6)
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
	var show_records: bool = run_num > 1

	if voluntary:
		_title_lbl.text = "Retirement"
	else:
		_title_lbl.text = "Retirement — Boredom Limit Reached"

	_btn.text = "Start New Run" if voluntary else "Continue"

	for child in _content_vbox.get_children():
		child.queue_free()

	_add_subtitle("Run %d — %s days survived" % [run_num, _fmt_int(days)])
	_add_spacer(8)

	# ── Merged stat section ────────────────────────────────────────────────
	_add_section_header("This Run (Day %d)" % days)

	var credits_val: int = int(summary.get("credits_earned", 0.0))
	var pre_credits: float = float(summary.get("pre_best_credits", 0.0))
	_add_stat_row_with_record(
		"Credits earned:",
		_fmt_int(credits_val),
		show_records and credits_val > pre_credits,
		_fmt_int(int(pre_credits))
	)

	var ships_val: int = int(summary.get("shipments_completed", 0))
	var pre_ships: int = int(summary.get("pre_best_shipments", 0))
	_add_stat_row_with_record(
		"Shipments completed:",
		_fmt_int(ships_val),
		show_records and ships_val > pre_ships,
		_fmt_int(pre_ships)
	)

	_add_stat_row("Buildings built:", _fmt_int(int(summary.get("buildings_built", 0))))

	var peak_power_val: float = float(summary.get("run_peak_power", 0.0))
	var pre_power: float = float(summary.get("pre_peak_power", 0.0))
	_add_stat_row_with_record(
		"Peak energy production:",
		"%.1f/day" % peak_power_val,
		show_records and peak_power_val > pre_power,
		"%.1f" % pre_power
	)

	var research_arr: Array = summary.get("research_completed", [])
	var research_total: int = GameManager.get_research_data().size()
	_add_stat_row("Research completed:", "%d / %d" % [research_arr.size(), research_total])

	var ideo_ranks: Dictionary = summary.get("ideology_ranks", {})
	var best_ideo_axis: String = ""
	var best_ideo_rank: int = 0
	for axis: String in ["nationalist", "humanist", "rationalist"]:
		var r: int = int(ideo_ranks.get(axis, 0))
		if r > best_ideo_rank:
			best_ideo_rank = r
			best_ideo_axis = axis
	if best_ideo_rank > 0:
		_add_stat_row("Highest ideology rank:", "%s %d" % [_axis_label(best_ideo_axis), best_ideo_rank])

	_add_stat_row_with_record(
		"Run length:",
		"%d days" % days,
		show_records and days > int(summary.get("pre_best_days", 0)),
		"%d days" % int(summary.get("pre_best_days", 0))
	)

	_add_spacer(6)
	_add_section_header("What Persists")
	_add_persists_line()

	_add_spacer(6)
	_add_career_bonuses_section(summary)


func _add_subtitle(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", _font_exo2_regular)
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.80) if GameSettings.is_dark_mode else Color(0.35, 0.35, 0.35))
	_content_vbox.add_child(lbl)


func _add_spacer(height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	_content_vbox.add_child(spacer)


func _add_section_header(text: String) -> void:
	var pc := PanelContainer.new()
	var hdr_style := StyleBoxFlat.new()
	hdr_style.bg_color = Color(0.20, 0.20, 0.26) if GameSettings.is_dark_mode else Color(0.86, 0.86, 0.90)
	hdr_style.content_margin_left   = 8
	hdr_style.content_margin_right  = 8
	hdr_style.content_margin_top    = 4
	hdr_style.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", hdr_style)
	var lbl := Label.new()
	lbl.text = text.to_upper()
	lbl.add_theme_font_override("font", _font_exo2_semibold)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.80) if GameSettings.is_dark_mode else Color(0.17, 0.24, 0.31))
	pc.add_child(lbl)
	_content_vbox.add_child(pc)


func _add_stat_row(label_text: String, value_text: String) -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 2)
	m.add_theme_constant_override("margin_bottom", 2)
	var row := HBoxContainer.new()
	m.add_child(row)
	_content_vbox.add_child(m)
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


func _add_stat_row_with_record(label_text: String, value_text: String, is_record: bool, prev_text: String) -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 2)
	m.add_theme_constant_override("margin_bottom", 2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	m.add_child(row)
	_content_vbox.add_child(m)

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

	if is_record:
		var rec := Label.new()
		rec.text = "▲ RECORD"
		rec.add_theme_font_override("font", _font_exo2_semibold)
		rec.add_theme_font_size_override("font_size", 13)
		rec.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))
		row.add_child(rec)

		var prev := Label.new()
		prev.text = "(prev: %s)" % prev_text
		prev.add_theme_font_override("font", _font_exo2_regular)
		prev.add_theme_font_size_override("font_size", 13)
		prev.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60) if GameSettings.is_dark_mode else Color(0.50, 0.50, 0.50))
		row.add_child(prev)


func _add_persists_line() -> void:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 2)
	m.add_theme_constant_override("margin_bottom", 2)
	var lbl := Label.new()
	lbl.text = "Events, statistics, and project progress carry over to your next run."
	lbl.add_theme_font_override("font", _font_exo2_regular)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70) if GameSettings.is_dark_mode else Color(0.40, 0.40, 0.40))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.add_child(lbl)
	_content_vbox.add_child(m)


func _fmt_int(n: int) -> String:
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
	_add_bonus_card(
		"Starting Credits",
		"+%s credits" % _fmt_int(credits_bonus),
		"increases with best career revenue",
		Color(0.30, 0.72, 0.30),
		new_credits
	)

	# Bonus 2: Boredom Resilience
	var resilience_mult: float = pow(0.995, best_days / 400.0)
	var resilience_pct: float = (1.0 - resilience_mult) * 100.0
	var new_resilience: bool = best_days > pre_days
	_add_bonus_card(
		"Boredom Resilience",
		"-%s%% boredom rate" % _fmt_float1(resilience_pct),
		"increases with longest run",
		Color(0.55, 0.55, 0.55),
		new_resilience
	)

	# Bonus 3: Buy Power Scaling — hidden when bp == 1.0 (peak <= 100)
	var bp_mult: float = 1.0 + maxf(0.0, peak_power - 100.0) * 0.01
	if bp_mult > 1.0:
		var new_power: bool = peak_power > pre_power
		_add_bonus_card(
			"Buy Power Scaling",
			"%sx output & cost" % _fmt_float2(bp_mult),
			"increases with peak energy production",
			Color(0.88, 0.66, 0.20),
			new_power
		)

	# Bonus 4: Ideology Head Start — hidden when no head start earned
	var axis_short: Dictionary = {"nationalist": "N", "humanist": "H", "rationalist": "R"}
	var head_start_parts: Array[String] = []
	var any_new_ideo: bool = false
	var has_any_head_start: bool = false
	for axis: String in ["humanist", "nationalist", "rationalist"]:
		var max_score: float = float(max_ideology.get(axis, 0.0))
		var prev_score: float = float(pre_ideology.get(axis, 0.0))
		if max_score > prev_score:
			any_new_ideo = true
		if max_score > 0.0:
			var max_cont: float = GameState.continuous_rank_for_score(max_score)
			var start_rank: int = int(floor(max_cont * 0.2))
			if start_rank >= 1:
				has_any_head_start = true
				head_start_parts.append("%s%d" % [axis_short[axis], start_rank])

	if has_any_head_start:
		_add_bonus_card(
			"Ideology Head Start",
			" / ".join(head_start_parts),
			"increases with highest ideology ranks",
			Color(0.55, 0.35, 0.80),
			any_new_ideo
		)


func _add_bonus_card(
	bonus_name: String,
	value_text: String,
	hint_text: String,
	accent_color: Color,
	is_new: bool
) -> void:
	var card := PanelContainer.new()
	card.clip_contents = true
	var card_bg: Color
	if is_new:
		card_bg = Color(0.14, 0.22, 0.16) if GameSettings.is_dark_mode else Color(0.90, 0.97, 0.91)
	else:
		card_bg = Color(0.17, 0.17, 0.21) if GameSettings.is_dark_mode else Color(0.93, 0.93, 0.96)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = card_bg
	card_style.corner_radius_top_left     = 4
	card_style.corner_radius_top_right    = 4
	card_style.corner_radius_bottom_left  = 4
	card_style.corner_radius_bottom_right = 4
	card_style.content_margin_top    = 0
	card_style.content_margin_bottom = 0
	card_style.content_margin_left   = 0
	card_style.content_margin_right  = 0
	card.add_theme_stylebox_override("panel", card_style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	card.add_child(row)

	# Left accent bar
	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(4, 0)
	accent.color = accent_color
	accent.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(accent)

	# Content area
	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 10)
	content_margin.add_theme_constant_override("margin_right", 10)
	content_margin.add_theme_constant_override("margin_top", 7)
	content_margin.add_theme_constant_override("margin_bottom", 7)
	row.add_child(content_margin)

	var inner_row := HBoxContainer.new()
	inner_row.add_theme_constant_override("separation", 8)
	content_margin.add_child(inner_row)

	# Left column: bonus name + hint
	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 2)
	inner_row.add_child(name_col)

	var name_lbl := Label.new()
	name_lbl.text = bonus_name
	name_lbl.add_theme_font_override("font", _font_exo2_semibold)
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90) if GameSettings.is_dark_mode else Color(0.15, 0.15, 0.15))
	name_col.add_child(name_lbl)

	var hint_lbl := Label.new()
	hint_lbl.text = "↳ %s" % hint_text
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.add_theme_font_override("font", _font_exo2_regular)
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.60) if GameSettings.is_dark_mode else Color(0.45, 0.45, 0.45))
	name_col.add_child(hint_lbl)

	# Right column: value + NEW indicator
	var val_col := VBoxContainer.new()
	val_col.add_theme_constant_override("separation", 2)
	inner_row.add_child(val_col)

	var val_lbl := Label.new()
	val_lbl.text = value_text
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_override("font", _font_exo2_semibold)
	val_lbl.add_theme_font_size_override("font_size", 17)
	val_lbl.add_theme_color_override("font_color", Color.WHITE if GameSettings.is_dark_mode else Color(0.08, 0.08, 0.08))
	val_col.add_child(val_lbl)

	if is_new:
		var new_lbl := Label.new()
		new_lbl.text = "▲ NEW"
		new_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		new_lbl.add_theme_font_override("font", _font_exo2_semibold)
		new_lbl.add_theme_font_size_override("font_size", 13)
		new_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 0.45))
		val_col.add_child(new_lbl)

	_content_vbox.add_child(card)


func _axis_label(axis: String) -> String:
	match axis:
		"nationalist": return "Nationalist"
		"humanist": return "Humanist"
		"rationalist": return "Rationalist"
	return axis.capitalize()


func _fmt_float1(v: float) -> String:
	return "%.1f" % v


func _fmt_float2(v: float) -> String:
	return "%.2f" % v


func _on_btn_pressed() -> void:
	hide()
	GameManager.start_new_run()
