class_name ProjectPanel
extends VBoxContainer

const REFRESH_INTERVAL: float = 0.25

var _font_rb: FontFile
var _font_e2r: FontFile
var _font_e2s: FontFile

# Long-Term Projects section (persistent tier)
var _lt_header: Button = null
var _lt_body: VBoxContainer = null
var _lt_expanded: bool = true
var _lt_cards: Array = []  # Array[ProjectCard]

# Strategic Projects section (personal tier)
var _sp_header: Button = null
var _sp_body: VBoxContainer = null
var _sp_expanded: bool = true
var _sp_cards: Array = []  # Array[ProjectCard]

var _refresh_accum: float = 0.0
var _last_unlocked_snapshot: Array = []
var _last_completed_snapshot: Array = []


func setup(font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_font_rb = font_rb
	_font_e2r = font_e2r
	_font_e2s = font_e2s
	add_theme_constant_override("separation", 8)
	_build()
	GameManager.project_manager.project_unlocked.connect(func(_id: String) -> void: _rebuild_cards())
	GameManager.project_manager.project_completed.connect(func(_id: String) -> void: _rebuild_cards())
	_rebuild_cards()


func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum >= REFRESH_INTERVAL:
		_refresh_accum = 0.0
		_refresh_cards()


# ── Build skeleton ─────────────────────────────────────────────────────────────


func _build() -> void:
	var dark: bool = GameSettings.is_dark_mode

	# Header: max funding rate
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	add_child(header_row)

	var max_rate_lbl := Label.new()
	var max_rate: float = GameManager.project_manager.get_max_drain_rate()
	max_rate_lbl.text = "Maximum Funding Rate: %d/tick per resource" % int(max_rate)
	max_rate_lbl.add_theme_font_override("font", _font_e2r)
	max_rate_lbl.add_theme_font_size_override("font_size", 13)
	max_rate_lbl.add_theme_color_override("font_color",
		Color(0.60, 0.60, 0.60) if dark else Color(0.40, 0.40, 0.40))
	header_row.add_child(max_rate_lbl)

	add_child(HSeparator.new())

	# Long-Term Projects section (persistent tier), expanded by default
	_lt_header = _make_section_header("Long-Term Projects", _lt_expanded)
	_lt_body = _make_section_body(_lt_expanded)
	_add_section_desc(_lt_body, "Progress on these projects carries across retirements.")
	_lt_header.pressed.connect(func() -> void:
		_lt_expanded = not _lt_expanded
		_lt_body.visible = _lt_expanded
		_lt_header.text = ("▼  " if _lt_expanded else "▶  ") + "Long-Term Projects"
	)

	# Strategic Projects section (personal tier), expanded by default
	_sp_header = _make_section_header("Strategic Projects", _sp_expanded)
	_sp_body = _make_section_body(_sp_expanded)
	_add_section_desc(_sp_body, "These projects reset when you retire. Plan accordingly.")
	_sp_header.pressed.connect(func() -> void:
		_sp_expanded = not _sp_expanded
		_sp_body.visible = _sp_expanded
		_sp_header.text = ("▼  " if _sp_expanded else "▶  ") + "Strategic Projects"
	)


func _make_section_header(title: String, start_open: bool) -> Button:
	var header := Button.new()
	header.text = ("▼  " if start_open else "▶  ") + title
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.focus_mode = Control.FOCUS_NONE
	header.add_theme_font_override("font", _font_rb)
	header.add_theme_font_size_override("font_size", 16)
	add_child(header)
	return header


func _make_section_body(start_open: bool) -> VBoxContainer:
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.visible = start_open
	add_child(body)
	return body


func _add_section_desc(body: VBoxContainer, text: String) -> void:
	var dark: bool = GameSettings.is_dark_mode
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", _font_e2r)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color",
		Color(0.55, 0.55, 0.55) if dark else Color(0.50, 0.50, 0.50))
	body.add_child(lbl)


# ── Rebuild (structural changes) ───────────────────────────────────────────────


func _rebuild_cards() -> void:
	var st: GameState = GameManager.state
	var pm: ProjectManager = GameManager.project_manager
	var career: CareerState = GameManager.career

	var completed: Array = st.completed_projects_this_run.duplicate()
	for pid: String in career.completed_projects:
		if not completed.has(pid):
			completed.append(pid)
	var unlocked: Array = st.enabled_projects.duplicate()

	_last_unlocked_snapshot = unlocked.duplicate()
	_last_completed_snapshot = completed.duplicate()

	# Clear existing project cards from both bodies
	for card: ProjectCard in _lt_cards:
		card.queue_free()
	_lt_cards.clear()
	for card: ProjectCard in _sp_cards:
		card.queue_free()
	_sp_cards.clear()
	_clear_cards_from_body(_lt_body)
	_clear_cards_from_body(_sp_body)

	# Group all defs by tier (only visible: unlocked or completed)
	var lt_defs: Array = []
	var sp_defs: Array = []
	for pdef: Dictionary in pm.get_all_defs():
		var pid: String = pdef.get("id", "")
		if not unlocked.has(pid) and not completed.has(pid):
			continue  # locked — skip
		if pdef.get("tier", "personal") == "persistent":
			lt_defs.append(pdef)
		else:
			sp_defs.append(pdef)

	_populate_section(_lt_body, lt_defs, unlocked, completed, _lt_cards)
	_populate_section(_sp_body, sp_defs, unlocked, completed, _sp_cards)

	# Hide sections that have no visible projects (header + body both hidden)
	var lt_has: bool = lt_defs.size() > 0
	_lt_header.visible = lt_has
	_lt_body.visible = lt_has and _lt_expanded

	var sp_has: bool = sp_defs.size() > 0
	_sp_header.visible = sp_has
	_sp_body.visible = sp_has and _sp_expanded


func _clear_cards_from_body(body: VBoxContainer) -> void:
	# Keep index 0 (the description label), free everything else
	var children: Array = body.get_children()
	for i: int in range(1, children.size()):
		children[i].queue_free()


func _populate_section(
	body: VBoxContainer,
	defs: Array,
	unlocked: Array,
	completed: Array,
	cards_out: Array,
) -> void:
	# Active/available (unlocked, not completed) → full interactive card
	for pdef: Dictionary in defs:
		var pid: String = pdef.get("id", "")
		if completed.has(pid):
			continue
		var card := ProjectCard.new()
		card.setup(pdef, _font_rb, _font_e2r, _font_e2s)
		body.add_child(card)
		cards_out.append(card)

	# Completed → compact single-line row
	for pdef: Dictionary in defs:
		var pid: String = pdef.get("id", "")
		if completed.has(pid):
			body.add_child(_build_completed_card(pdef))


func _build_completed_card(pdef: Dictionary) -> PanelContainer:
	var dark: bool = GameSettings.is_dark_mode
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.18, 0.08) if dark else Color(0.91, 0.96, 0.91)
	bg.border_width_left   = 1
	bg.border_width_right  = 1
	bg.border_width_top    = 1
	bg.border_width_bottom = 1
	bg.border_color = Color(0.15, 0.30, 0.15) if dark else Color(0.72, 0.84, 0.72)
	bg.content_margin_left   = 10
	bg.content_margin_right  = 10
	bg.content_margin_top    = 6
	bg.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", bg)

	var reward_text: String = _format_reward_short(pdef.get("reward", {}))
	var line: String = "✓ " + pdef.get("name", pdef.id)
	if not reward_text.is_empty():
		line += " — Reward: " + reward_text

	var lbl := Label.new()
	lbl.text = line
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", _font_e2r)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.18, 0.49, 0.20))
	card.add_child(lbl)

	return card


# ── Refresh (data update) ──────────────────────────────────────────────────────


func _refresh_cards() -> void:
	var st: GameState = GameManager.state
	var completed: Array = st.completed_projects_this_run
	for pid: String in GameManager.career.completed_projects:
		if not completed.has(pid):
			completed.append(pid)

	if st.enabled_projects != _last_unlocked_snapshot or completed != _last_completed_snapshot:
		_rebuild_cards()
		return

	for card: ProjectCard in _lt_cards:
		card.refresh()
	for card: ProjectCard in _sp_cards:
		card.refresh()


func _format_reward_short(reward: Dictionary) -> String:
	match reward.get("type", ""):
		"modifier":
			var key: String = reward.get("modifier_key", "")
			var val: float = float(reward.get("modifier_value", 1.0))
			var pct: int = int(roundf((val - 1.0) * 100.0))
			var sign: String = "+" if pct >= 0 else ""
			return "%s %s%d%%" % [key, sign, pct]
		"starting_buildings":
			var parts: Array = []
			for bsn: String in reward.get("buildings", {}):
				parts.append("+%d %s" % [int(reward.buildings[bsn]), bsn])
			return ", ".join(parts)
		"stub":
			return reward.get("description", "")
	return ""
