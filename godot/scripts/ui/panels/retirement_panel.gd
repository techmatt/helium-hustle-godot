class_name RetirementCenterPanel
extends VBoxContainer

var _font_rb: FontFile
var _font_e2r: FontFile
var _font_e2s: FontFile

# ── This Run labels ───────────────────────────────────────────────────────────
var _run_section_hdr: Label = null
var _stat_credits: Array = []       # [val_lbl, record_lbl, prev_lbl]
var _stat_shipments: Array = []
var _stat_buildings: Array = []
var _stat_power: Array = []
var _run_research_val: Label = null # no career record tracked
var _run_ideology_row: HBoxContainer = null  # hidden when best rank == 0
var _run_ideology_val: Label = null
var _stat_days: Array = []

# ── Next Run Bonus labels ─────────────────────────────────────────────────────
var _bonus_credits_val: Label = null
var _bonus_credits_delta: Label = null
var _bonus_boredom_val: Label = null
var _bonus_boredom_delta: Label = null
var _bonus_power_container: VBoxContainer = null   # hidden when bp == 1.0
var _bonus_power_val: Label = null
var _bonus_power_delta: Label = null
var _bonus_ideology_container: VBoxContainer = null  # hidden when no head start
var _bonus_ideology_val: Label = null

# ── Retire button ─────────────────────────────────────────────────────────────
var _retire_btn: Button = null


func setup(font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_font_rb = font_rb
	_font_e2r = font_e2r
	_font_e2s = font_e2s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)
	_build()


func on_tick() -> void:
	if _run_section_hdr == null or not is_instance_valid(_run_section_hdr):
		return
	_refresh()


# ── Build ─────────────────────────────────────────────────────────────────────

func _build() -> void:
	_build_this_run_section()
	_build_next_run_bonuses_section()
	_build_retire_button()
	_refresh()


func _build_this_run_section() -> void:
	_run_section_hdr = _make_section_header("This Run (Day 0)")
	add_child(_run_section_hdr)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	_stat_credits   = _make_stat_row_with_record("Credits earned",          vbox)
	_stat_shipments = _make_stat_row_with_record("Shipments completed",      vbox)
	_stat_buildings = _make_stat_row_with_record("Buildings built",          vbox)
	_stat_power     = _make_stat_row_with_record("Peak energy production",   vbox)
	_run_research_val = _make_stat_row("Research completed", vbox)

	# Ideology row — hidden when no rank achieved this run
	var ideo_row := HBoxContainer.new()
	vbox.add_child(ideo_row)
	_run_ideology_row = ideo_row
	var ideo_lbl := Label.new()
	ideo_lbl.text = "Highest ideology rank"
	ideo_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ideo_lbl.add_theme_font_override("font", _font_e2r)
	ideo_lbl.add_theme_font_size_override("font_size", 16)
	ideo_row.add_child(ideo_lbl)
	_run_ideology_val = Label.new()
	_run_ideology_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_run_ideology_val.add_theme_font_override("font", _font_e2s)
	_run_ideology_val.add_theme_font_size_override("font_size", 16)
	ideo_row.add_child(_run_ideology_val)

	_stat_days = _make_stat_row_with_record("Run length", vbox)


func _build_next_run_bonuses_section() -> void:
	add_child(HSeparator.new())
	add_child(_make_section_header("Next Run Bonuses"))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Starting credits — always visible
	var cr := _make_bonus_row_with_hint(
		"Starting credits",
		"↳ increases with best career revenue",
		vbox
	)
	_bonus_credits_val   = cr[0]
	_bonus_credits_delta = cr[1]

	# Boredom resilience — always visible
	var br := _make_bonus_row_with_hint(
		"Boredom resilience",
		"↳ increases with longest run",
		vbox
	)
	_bonus_boredom_val   = br[0]
	_bonus_boredom_delta = br[1]

	# Buy Power scaling — hidden when mult == 1.0
	_bonus_power_container = VBoxContainer.new()
	_bonus_power_container.add_theme_constant_override("separation", 2)
	vbox.add_child(_bonus_power_container)
	var bp := _make_bonus_row_with_hint(
		"Buy Power scaling",
		"↳ increases with peak energy production",
		_bonus_power_container
	)
	_bonus_power_val   = bp[0]
	_bonus_power_delta = bp[1]

	# Ideology head start — hidden when all start ranks == 0
	_bonus_ideology_container = VBoxContainer.new()
	_bonus_ideology_container.add_theme_constant_override("separation", 2)
	vbox.add_child(_bonus_ideology_container)
	_bonus_ideology_val = _make_stat_row("Ideology head start", _bonus_ideology_container)
	_make_hint_label("↳ increases with highest ideology ranks", _bonus_ideology_container)


func _build_retire_button() -> void:
	add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(btn_row)

	_retire_btn = Button.new()
	_retire_btn.text = "Retire Now"
	_retire_btn.custom_minimum_size = Vector2(180, 42)
	_retire_btn.focus_mode = Control.FOCUS_NONE
	_retire_btn.add_theme_font_override("font", _font_e2s)
	_retire_btn.add_theme_font_size_override("font_size", 15)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.50, 0.14, 0.14)
	btn_style.corner_radius_top_left     = 4
	btn_style.corner_radius_top_right    = 4
	btn_style.corner_radius_bottom_left  = 4
	btn_style.corner_radius_bottom_right = 4
	_retire_btn.add_theme_stylebox_override("normal", btn_style)
	_retire_btn.add_theme_stylebox_override("hover", btn_style)
	_retire_btn.add_theme_color_override("font_color", Color.WHITE)
	_retire_btn.pressed.connect(_on_retire_btn_pressed)
	btn_row.add_child(_retire_btn)


# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh() -> void:
	var st: GameState = GameManager.state
	var career: CareerState = GameManager.career
	var run_num: int = st.run_number
	var show_records: bool = run_num > 1

	_run_section_hdr.text = "THIS RUN (DAY %d)" % st.current_day

	# ── Stat rows ─────────────────────────────────────────────────────────────
	var this_credits: float = st.cumulative_resources_earned.get("cred", 0.0)
	_set_stat_record(
		_stat_credits,
		_fmt_int(int(this_credits)),
		show_records and this_credits > career.best_run_credits,
		_fmt_int(int(career.best_run_credits))
	)

	_set_stat_record(
		_stat_shipments,
		_fmt_int(st.total_shipments_completed),
		show_records and st.total_shipments_completed > career.best_run_shipments,
		_fmt_int(career.best_run_shipments)
	)

	var total_buildings: int = 0
	for cnt: int in st.buildings_owned.values():
		total_buildings += cnt
	# No career record for buildings owned — never show badge
	_set_stat_record(_stat_buildings, _fmt_int(total_buildings), false, "")

	var run_peak: float = GameManager.get_run_peak_power()
	_set_stat_record(
		_stat_power,
		"%.1f energy/tick" % run_peak,
		show_records and run_peak > GameManager.run_start_career_peak_power,
		"%.1f energy/tick" % GameManager.run_start_career_peak_power
	)

	var research_total: int = GameManager.get_research_data().size()
	_run_research_val.text = "%d / %d" % [st.completed_research.size(), research_total]

	var best_axis: String = ""
	var best_rank: int = 0
	for axis: String in ["nationalist", "humanist", "rationalist"]:
		var r: int = st.get_ideology_rank(axis)
		if r > best_rank:
			best_rank = r
			best_axis = axis
	_run_ideology_row.visible = best_rank > 0
	if best_rank > 0:
		_run_ideology_val.text = "%s %d" % [_axis_label(best_axis), best_rank]

	_set_stat_record(
		_stat_days,
		"%d days" % st.current_day,
		show_records and st.current_day > career.best_run_days,
		"%d days" % career.best_run_days
	)

	# ── Next Run Bonuses ──────────────────────────────────────────────────────
	_refresh_bonuses(st, career)


func _set_stat_record(stat: Array, value_text: String, is_record: bool, prev_text: String) -> void:
	if stat.size() < 3:
		return
	var val_lbl: Label = stat[0]
	var record_lbl: Label = stat[1]
	var prev_lbl: Label = stat[2]
	val_lbl.text = value_text
	record_lbl.visible = is_record
	prev_lbl.visible = is_record
	if is_record:
		prev_lbl.text = "(prev: %s)" % prev_text


func _refresh_bonuses(st: GameState, career: CareerState) -> void:
	var this_credits: float = st.cumulative_resources_earned.get("cred", 0.0)
	var run_peak: float = GameManager.get_run_peak_power()

	# Starting credits
	var frac: float = GameManager.career_credits_bonus_fraction
	var proj_credits: int = int(floor(maxf(career.best_run_credits, this_credits) * frac))
	var cur_credits: int  = int(floor(career.best_run_credits * frac))
	var delta_credits: int = proj_credits - cur_credits
	_bonus_credits_val.text = "+%d credits" % proj_credits if proj_credits > 0 else "None yet"
	_set_delta_label(_bonus_credits_delta, delta_credits > 0, "(+%d)" % delta_credits)

	# Boredom resilience
	var proj_days: int = maxi(career.best_run_days, st.current_day)
	var proj_boredom_pct: float = (1.0 - pow(0.995, proj_days / 400.0)) * 100.0
	var cur_boredom_pct: float  = (1.0 - pow(0.995, career.best_run_days / 400.0)) * 100.0
	var delta_boredom: float = proj_boredom_pct - cur_boredom_pct
	if proj_boredom_pct < 0.05:
		_bonus_boredom_val.text = "None yet"
		_set_delta_label(_bonus_boredom_delta, false, "")
	else:
		_bonus_boredom_val.text = "-%.1f%% boredom rate" % proj_boredom_pct
		_set_delta_label(_bonus_boredom_delta, delta_boredom > 0.005, "(+%.1f%%)" % delta_boredom)

	# Buy Power scaling — hide when mult would be 1.0
	var proj_power_peak: float = maxf(career.peak_power_production, run_peak)
	var proj_bp: float = 1.0 + maxf(0.0, proj_power_peak - 100.0) * 0.01
	var cur_bp: float  = 1.0 + maxf(0.0, GameManager.run_start_career_peak_power - 100.0) * 0.01
	var delta_bp: float = proj_bp - cur_bp
	_bonus_power_container.visible = proj_bp > 1.0
	if proj_bp > 1.0:
		_bonus_power_val.text = "%.2fx output & cost" % proj_bp
		_set_delta_label(_bonus_power_delta, delta_bp > 0.005, "(+%.2fx)" % delta_bp)

	# Ideology head start — hide when all start ranks == 0
	var ideo_lines: Array[String] = []
	for axis: String in ["humanist", "nationalist", "rationalist"]:
		var proj_score: float = float(career.max_ideology_scores.get(axis, 0.0))
		var proj_cont: float = GameState.continuous_rank_for_score(proj_score)
		var proj_start_rank: int = int(floor(proj_cont * 0.2))
		var cur_score: float = float(GameManager.run_start_career_ideology_scores.get(axis, 0.0))
		var cur_cont: float = GameState.continuous_rank_for_score(cur_score)
		var cur_start_rank: int = int(floor(cur_cont * 0.2))
		if proj_start_rank >= 1:
			var delta_rank: int = proj_start_rank - cur_start_rank
			if delta_rank > 0:
				ideo_lines.append("%s rank %d  (+%d)" % [_axis_label(axis), proj_start_rank, delta_rank])
			else:
				ideo_lines.append("%s rank %d" % [_axis_label(axis), proj_start_rank])
	_bonus_ideology_container.visible = not ideo_lines.is_empty()
	if not ideo_lines.is_empty():
		_bonus_ideology_val.text = "  ".join(ideo_lines)


# ── Retire button ─────────────────────────────────────────────────────────────

func _on_retire_btn_pressed() -> void:
	var is_dark: bool = GameSettings.is_dark_mode

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.5)
	overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.13, 0.13, 0.16) if is_dark else Color.WHITE
	ps.border_width_left   = 1
	ps.border_width_right  = 1
	ps.border_width_top    = 1
	ps.border_width_bottom = 1
	ps.border_color = Color(0.35, 0.35, 0.45)
	ps.corner_radius_top_left     = 8
	ps.corner_radius_top_right    = 8
	ps.corner_radius_bottom_left  = 8
	ps.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "Retire?"
	title_lbl.add_theme_font_override("font", _font_rb)
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color.WHITE if is_dark else Color(0.1, 0.1, 0.1))
	vbox.add_child(title_lbl)

	var body_lbl := Label.new()
	body_lbl.text = "Are you sure you want to retire?\nYour current run will end."
	body_lbl.add_theme_font_override("font", _font_e2r)
	body_lbl.add_theme_font_size_override("font_size", 15)
	body_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.80) if is_dark else Color(0.35, 0.35, 0.35))
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 36)
	cancel_btn.focus_mode = Control.FOCUS_NONE
	cancel_btn.add_theme_font_override("font", _font_e2s)
	cancel_btn.add_theme_font_size_override("font_size", 14)
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.22, 0.22, 0.27) if is_dark else Color(0.85, 0.85, 0.85)
	cancel_style.corner_radius_top_left     = 4
	cancel_style.corner_radius_top_right    = 4
	cancel_style.corner_radius_bottom_left  = 4
	cancel_style.corner_radius_bottom_right = 4
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	cancel_btn.add_theme_stylebox_override("hover", cancel_style)
	cancel_btn.add_theme_color_override("font_color", Color.WHITE if is_dark else Color(0.1, 0.1, 0.1))
	btn_row.add_child(cancel_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Retire"
	confirm_btn.custom_minimum_size = Vector2(120, 36)
	confirm_btn.focus_mode = Control.FOCUS_NONE
	confirm_btn.add_theme_font_override("font", _font_e2s)
	confirm_btn.add_theme_font_size_override("font_size", 14)
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.50, 0.14, 0.14)
	confirm_style.corner_radius_top_left     = 4
	confirm_style.corner_radius_top_right    = 4
	confirm_style.corner_radius_bottom_left  = 4
	confirm_style.corner_radius_bottom_right = 4
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	confirm_btn.add_theme_stylebox_override("hover", confirm_style)
	confirm_btn.add_theme_color_override("font_color", Color.WHITE)
	btn_row.add_child(confirm_btn)

	cancel_btn.pressed.connect(func() -> void: overlay.queue_free())
	confirm_btn.pressed.connect(func() -> void:
		overlay.queue_free()
		GameManager.retire(true)
	)

	get_viewport().add_child(overlay)


# ── UI helpers ────────────────────────────────────────────────────────────────

func _make_section_header(title: String) -> Label:
	var lbl := Label.new()
	lbl.text = title.to_upper()
	lbl.add_theme_font_override("font", _font_e2s)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
	return lbl


# Returns a value Label added to an HBoxContainer row inside parent.
func _make_stat_row(label_text: String, parent: Control) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_override("font", _font_e2r)
	lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(lbl)
	var val := Label.new()
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_override("font", _font_e2s)
	val.add_theme_font_size_override("font_size", 16)
	row.add_child(val)
	return val


# Returns [val_lbl, record_lbl, prev_lbl].
# record_lbl shows "▲ RECORD" in green; prev_lbl shows "(prev: X)" in muted.
# Both are hidden until _set_stat_record sets is_record = true.
func _make_stat_row_with_record(label_text: String, parent: VBoxContainer) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_override("font", _font_e2r)
	lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(lbl)

	var val := Label.new()
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_override("font", _font_e2s)
	val.add_theme_font_size_override("font_size", 16)
	row.add_child(val)

	var record_lbl := Label.new()
	record_lbl.text = "▲ RECORD"
	record_lbl.add_theme_font_override("font", _font_e2s)
	record_lbl.add_theme_font_size_override("font_size", 14)
	record_lbl.add_theme_color_override("font_color", UIPalette.p("text_positive"))
	record_lbl.visible = false
	row.add_child(record_lbl)

	var prev_lbl := Label.new()
	prev_lbl.add_theme_font_override("font", _font_e2r)
	prev_lbl.add_theme_font_size_override("font_size", 14)
	prev_lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
	prev_lbl.visible = false
	row.add_child(prev_lbl)

	return [val, record_lbl, prev_lbl]


# Returns [val_lbl, delta_lbl]. Adds the bonus row + hint label to parent.
func _make_bonus_row_with_hint(label_text: String, hint_text: String, parent: Control) -> Array:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_override("font", _font_e2r)
	lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(lbl)

	var val := Label.new()
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_override("font", _font_e2s)
	val.add_theme_font_size_override("font_size", 16)
	row.add_child(val)

	var delta := Label.new()
	delta.add_theme_font_override("font", _font_e2r)
	delta.add_theme_font_size_override("font_size", 15)
	delta.add_theme_color_override("font_color", UIPalette.p("text_positive"))
	delta.visible = false
	row.add_child(delta)

	_make_hint_label(hint_text, parent)

	return [val, delta]


func _make_hint_label(hint_text: String, parent: Control) -> void:
	var hint := Label.new()
	hint.text = hint_text
	hint.add_theme_font_override("font", _font_e2r)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", UIPalette.p("text_muted"))
	parent.add_child(hint)


func _set_delta_label(delta: Label, show: bool, text: String) -> void:
	delta.visible = show
	if show:
		delta.text = "  " + text


# ── Format helpers ────────────────────────────────────────────────────────────

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


func _axis_label(axis: String) -> String:
	match axis:
		"nationalist": return "Nationalist"
		"humanist":    return "Humanist"
		"rationalist": return "Rationalist"
	return axis.capitalize()
