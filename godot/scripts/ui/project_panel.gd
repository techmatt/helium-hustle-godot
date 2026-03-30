class_name ProjectPanel
extends VBoxContainer

const REFRESH_INTERVAL: float = 0.25

var _font_rb: FontFile
var _font_e2r: FontFile
var _font_e2s: FontFile

var _active_cards: Array = []    # Array[ProjectCard]
var _completed_vbox: VBoxContainer = null
var _active_vbox: VBoxContainer = null
var _empty_lbl: Label = null

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

	# Active section (collapsible, expanded by default)
	_active_vbox = _make_collapsible_section("Active", true)

	_empty_lbl = Label.new()
	_empty_lbl.text = "No projects available yet."
	_empty_lbl.add_theme_font_override("font", _font_e2r)
	_empty_lbl.add_theme_font_size_override("font_size", 13)
	_empty_lbl.add_theme_color_override("font_color",
		Color(0.50, 0.50, 0.50) if dark else Color(0.55, 0.55, 0.55))
	_active_vbox.add_child(_empty_lbl)

	# Completed section (collapsible, collapsed by default)
	_completed_vbox = _make_collapsible_section("Completed", false)


func _make_collapsible_section(title: String, start_open: bool) -> VBoxContainer:
	var dark: bool = GameSettings.is_dark_mode
	var header := Button.new()
	header.text = ("▼  " if start_open else "▶  ") + title
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.focus_mode = Control.FOCUS_NONE
	header.add_theme_font_override("font", _font_rb)
	header.add_theme_font_size_override("font_size", 16)
	add_child(header)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.visible = start_open
	add_child(body)

	header.pressed.connect(func() -> void:
		body.visible = not body.visible
		header.text = ("▼  " if body.visible else "▶  ") + title
	)
	return body


# ── Rebuild (structural changes) ───────────────────────────────────────────────


func _rebuild_cards() -> void:
	var st: GameState = GameManager.state
	var pm: ProjectManager = GameManager.project_manager

	var unlocked: Array = st.enabled_projects.duplicate()
	var completed: Array = st.completed_projects_this_run.duplicate()
	# Include career-completed persistent projects
	for pid: String in GameManager.career.completed_projects:
		if not completed.has(pid):
			completed.append(pid)

	_last_unlocked_snapshot = unlocked.duplicate()
	_last_completed_snapshot = completed.duplicate()

	# Clear active cards
	for card: ProjectCard in _active_cards:
		card.queue_free()
	_active_cards.clear()

	# Clear completed cards
	for child in _completed_vbox.get_children():
		child.queue_free()

	# Build active cards (unlocked, not completed)
	var active_project_ids: Array = []
	for pid: String in unlocked:
		if not completed.has(pid):
			active_project_ids.append(pid)

	_empty_lbl.visible = active_project_ids.is_empty()

	for pid: String in active_project_ids:
		var pdef: Dictionary = pm.get_project_def(pid)
		if pdef.is_empty():
			continue
		var card := ProjectCard.new()
		card.setup(pdef, _font_rb, _font_e2r, _font_e2s)
		_active_vbox.add_child(card)
		_active_cards.append(card)

	# Build completed cards
	for pid: String in completed:
		var pdef: Dictionary = pm.get_project_def(pid)
		if pdef.is_empty():
			continue
		_completed_vbox.add_child(_build_completed_card(pdef))


func _build_completed_card(pdef: Dictionary) -> PanelContainer:
	var dark: bool = GameSettings.is_dark_mode
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.10, 0.10) if dark else Color(0.94, 0.94, 0.94)
	bg.border_width_left   = 1
	bg.border_width_right  = 1
	bg.border_width_top    = 1
	bg.border_width_bottom = 1
	bg.border_color = Color(0.22, 0.22, 0.22) if dark else Color(0.816, 0.816, 0.816)
	bg.content_margin_left   = 10
	bg.content_margin_right  = 10
	bg.content_margin_top    = 6
	bg.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)

	var check_lbl := Label.new()
	check_lbl.text = "✓ " + pdef.get("name", pdef.id)
	check_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check_lbl.add_theme_font_override("font", _font_rb)
	check_lbl.add_theme_font_size_override("font_size", 15)
	check_lbl.add_theme_color_override("font_color",
		Color(0.45, 0.45, 0.45) if dark else Color(0.40, 0.40, 0.40))
	row.add_child(check_lbl)

	var tier: String = pdef.get("tier", "personal")
	var tier_lbl := Label.new()
	tier_lbl.text = "Persistent" if tier == "persistent" else "Personal"
	tier_lbl.add_theme_font_override("font", _font_e2s)
	tier_lbl.add_theme_font_size_override("font_size", 12)
	tier_lbl.add_theme_color_override("font_color",
		Color(0.35, 0.55, 0.80) if dark else Color(0.25, 0.40, 0.65))
	row.add_child(tier_lbl)

	var reward_text := _format_reward_short(pdef.get("reward", {}))
	if not reward_text.is_empty():
		var reward_lbl := Label.new()
		reward_lbl.text = "Reward: " + reward_text
		reward_lbl.add_theme_font_override("font", _font_e2r)
		reward_lbl.add_theme_font_size_override("font_size", 12)
		reward_lbl.add_theme_color_override("font_color",
			Color(0.40, 0.40, 0.40) if dark else Color(0.45, 0.45, 0.45))
		vbox.add_child(reward_lbl)

	return card


# ── Refresh (data update) ──────────────────────────────────────────────────────


func _refresh_cards() -> void:
	var st: GameState = GameManager.state
	# Detect structural change (new unlock or completion)
	var unlocked: Array = st.enabled_projects
	var completed: Array = st.completed_projects_this_run
	for pid: String in GameManager.career.completed_projects:
		if not completed.has(pid):
			completed.append(pid)

	if unlocked != _last_unlocked_snapshot or completed != _last_completed_snapshot:
		_rebuild_cards()
		return

	for card: ProjectCard in _active_cards:
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
