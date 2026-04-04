class_name StoryPanel
extends VBoxContainer

signal event_row_clicked(event_id: String)

var _font_rb: FontFile
var _font_e2r: FontFile
var _font_e2s: FontFile

# Primary Objectives section
var _active_items: VBoxContainer = null
var _completed_header_btn: Button = null
var _completed_items: VBoxContainer = null
var _completed_expanded: bool = false

# Achievements section
var _achievements_header_lbl: Label = null
var _achievement_categories: Dictionary = {}  # category → { header_lbl, items_vbox, expanded }

# Collapsed state per achievement category (collapsed by default)
var _cat_expanded: Dictionary = {}


func setup(font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_font_rb = font_rb
	_font_e2r = font_e2r
	_font_e2s = font_e2s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	_build()
	_refresh()
	GameManager.tick_completed.connect(func() -> void: _refresh())
	GameManager.achievement_unlocked.connect(func(_id: String) -> void: _refresh())


func on_tick() -> void:
	_refresh()


func _build() -> void:
	# ── Primary Objectives ────────────────────────────────────────────────────
	var obj_header := Label.new()
	obj_header.text = "Primary Objectives"
	obj_header.add_theme_font_override("font", _font_rb)
	obj_header.add_theme_font_size_override("font_size", 20)
	add_child(obj_header)

	add_child(HSeparator.new())

	# Active subsection (always expanded, no toggle)
	var active_lbl := Label.new()
	active_lbl.text = "Active"
	active_lbl.add_theme_font_override("font", _font_rb)
	active_lbl.add_theme_font_size_override("font_size", 16)
	active_lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
	add_child(active_lbl)

	_active_items = VBoxContainer.new()
	_active_items.add_theme_constant_override("separation", 4)
	add_child(_active_items)

	# Completed subsection (collapsible, collapsed by default)
	_completed_header_btn = Button.new()
	_completed_header_btn.flat = true
	_completed_header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_completed_header_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_completed_header_btn.add_theme_font_override("font", _font_rb)
	_completed_header_btn.add_theme_font_size_override("font_size", 16)
	_completed_header_btn.text = "▶  Completed (0)"
	add_child(_completed_header_btn)

	_completed_items = VBoxContainer.new()
	_completed_items.add_theme_constant_override("separation", 4)
	_completed_items.visible = false
	add_child(_completed_items)

	_completed_header_btn.pressed.connect(func() -> void:
		_completed_expanded = not _completed_expanded
		_completed_items.visible = _completed_expanded
		_set_completed_header_text(_completed_items.get_child_count())
	)

	add_child(HSeparator.new())

	# ── Achievements ─────────────────────────────────────────────────────────
	var ach_header_row := HBoxContainer.new()
	ach_header_row.add_theme_constant_override("separation", 6)
	add_child(ach_header_row)

	var ach_title := Label.new()
	ach_title.text = "Achievements"
	ach_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ach_title.add_theme_font_override("font", _font_rb)
	ach_title.add_theme_font_size_override("font_size", 20)
	ach_header_row.add_child(ach_title)

	_achievements_header_lbl = Label.new()
	_achievements_header_lbl.text = "0 / 0 completed"
	_achievements_header_lbl.add_theme_font_override("font", _font_e2r)
	_achievements_header_lbl.add_theme_font_size_override("font_size", 15)
	_achievements_header_lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
	ach_header_row.add_child(_achievements_header_lbl)

	add_child(HSeparator.new())

	# Build category sections (collapsed by default)
	var am: AchievementManager = GameManager.achievement_manager
	for cat: String in am.get_categories():
		_cat_expanded[cat] = false
		_build_category_section(cat)


func _build_category_section(category: String) -> void:
	var am: AchievementManager = GameManager.achievement_manager
	var display_name: String = am.get_category_display(category)

	var header_btn := Button.new()
	header_btn.flat = true
	header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_btn.add_theme_font_override("font", _font_rb)
	header_btn.add_theme_font_size_override("font_size", 16)
	header_btn.text = "▶  " + display_name + " (0/0)"
	add_child(header_btn)

	var items_vbox := VBoxContainer.new()
	items_vbox.add_theme_constant_override("separation", 3)
	items_vbox.visible = false
	add_child(items_vbox)

	_achievement_categories[category] = {
		"header_btn": header_btn,
		"items_vbox": items_vbox,
	}

	header_btn.pressed.connect(func() -> void:
		_cat_expanded[category] = not _cat_expanded.get(category, false)
		items_vbox.visible = _cat_expanded[category]
		_update_category_header(category)
	)


# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh() -> void:
	_refresh_objectives()
	_refresh_achievements()


func _refresh_objectives() -> void:
	for child in _active_items.get_children():
		child.free()
	for child in _completed_items.get_children():
		child.free()

	var st: GameState = GameManager.state
	var career: CareerState = GameManager.career
	var em: EventManager = GameManager.event_manager
	var chain: Array = em.get_quest_chain()

	# Find the first incomplete quest (active quest)
	var active_idx: int = -1
	for i in range(chain.size()):
		var def: Dictionary = chain[i]
		var qid: String = def.get("id", "")
		if not career.completed_quest_ids.has(qid):
			# Also check if it's completed this run (not yet saved to career)
			var completed_this_run: bool = false
			for inst: Dictionary in st.event_instances:
				if inst.get("id", "") == qid and inst.get("state", "") == "completed":
					completed_this_run = true
					break
			if not completed_this_run:
				active_idx = i
				break

	var completed_count: int = 0

	for i in range(chain.size()):
		var def: Dictionary = chain[i]
		var qid: String = def.get("id", "")

		# Determine completion status
		var is_completed: bool = career.completed_quest_ids.has(qid)
		if not is_completed:
			for inst: Dictionary in st.event_instances:
				if inst.get("id", "") == qid and inst.get("state", "") == "completed":
					is_completed = true
					break

		var is_active: bool = (i == active_idx)

		if is_active:
			_active_items.add_child(_build_quest_row(def, false, true, st, em))
		elif is_completed:
			completed_count += 1
			_completed_items.add_child(_build_quest_row(def, true, false, st, em))
		# Future quests: hidden

	_set_completed_header_text(completed_count)


func _set_completed_header_text(count: int) -> void:
	_completed_header_btn.text = ("▼  " if _completed_expanded else "▶  ") + "Completed (%d)" % count


func _build_quest_row(
	def: Dictionary,
	is_completed: bool,
	is_active: bool,
	st: GameState,
	em: EventManager,
) -> Control:
	var qid: String = def.get("id", "")
	var title: String = def.get("title", qid)
	var summary: String = def.get("summary", "")

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var style := StyleBoxFlat.new()
	if is_completed:
		style.bg_color = Color(0.91, 0.96, 0.91) if not GameSettings.is_dark_mode else Color(0.08, 0.18, 0.08)
	elif is_active:
		style.bg_color = Color(0.93, 0.95, 1.0) if not GameSettings.is_dark_mode else Color(0.08, 0.12, 0.22)
	else:
		style.bg_color = Color(0.95, 0.95, 0.95) if not GameSettings.is_dark_mode else Color(0.12, 0.12, 0.12)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 3)
	panel.add_child(inner)

	# Title row
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	inner.add_child(title_row)

	var prefix_lbl := Label.new()
	if is_completed:
		prefix_lbl.text = "✓"
		prefix_lbl.add_theme_color_override("font_color", Color(0.18, 0.49, 0.20))
	else:
		prefix_lbl.text = "▶"
		prefix_lbl.add_theme_color_override("font_color", Color(0.20, 0.40, 0.90))
	prefix_lbl.add_theme_font_override("font", _font_e2s)
	prefix_lbl.add_theme_font_size_override("font_size", 16)
	title_row.add_child(prefix_lbl)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", _font_e2s)
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_row.add_child(title_lbl)

	# Summary / condition row
	if is_completed:
		var summary_lbl := Label.new()
		summary_lbl.text = summary
		summary_lbl.add_theme_font_override("font", _font_e2r)
		summary_lbl.add_theme_font_size_override("font_size", 14)
		summary_lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
		summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(summary_lbl)

		# Unlocks row
		var unlocks_text: String = _format_unlocks(def)
		if not unlocks_text.is_empty():
			var unlocks_lbl := Label.new()
			unlocks_lbl.text = "Unlocked: " + unlocks_text
			unlocks_lbl.add_theme_font_override("font", _font_e2r)
			unlocks_lbl.add_theme_font_size_override("font_size", 14)
			unlocks_lbl.add_theme_color_override("font_color", Color(0.18, 0.49, 0.20))
			unlocks_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			inner.add_child(unlocks_lbl)

		# Make it clickable to re-read the event
		panel.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton:
				var mb: InputEventMouseButton = ev as InputEventMouseButton
				if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
					event_row_clicked.emit(qid)
		)
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	elif is_active:
		var cond_lbl := Label.new()
		cond_lbl.text = summary
		cond_lbl.add_theme_font_override("font", _font_e2r)
		cond_lbl.add_theme_font_size_override("font_size", 14)
		cond_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(cond_lbl)

		var progress_str: String = em.get_condition_display(qid, st)
		if not progress_str.is_empty():
			var prog_lbl := Label.new()
			prog_lbl.text = "Progress: " + progress_str
			prog_lbl.add_theme_font_override("font", _font_e2s)
			prog_lbl.add_theme_font_size_override("font_size", 14)
			prog_lbl.add_theme_color_override("font_color", Color(0.20, 0.40, 0.90))
			inner.add_child(prog_lbl)

	container.add_child(panel)
	return container


func _format_unlocks(def: Dictionary) -> String:
	var parts: Array[String] = []
	for unlock: Dictionary in def.get("unlocks", []):
		match unlock.get("type", ""):
			"enable_building":
				parts.append(_building_display_name(unlock.get("building_id", "")))
			"enable_nav_panel":
				parts.append(unlock.get("panel", "").capitalize() + " panel")
			"enable_project":
				parts.append(_project_display_name(unlock.get("project_id", "")))
	return ", ".join(parts)


func _building_display_name(short_name: String) -> String:
	for bdef: Dictionary in GameManager.get_buildings_data():
		if bdef.get("short_name", "") == short_name:
			return bdef.get("name", short_name)
	return short_name


func _project_display_name(project_id: String) -> String:
	var pd: Dictionary = GameManager.project_manager.get_project_def(project_id)
	if not pd.is_empty():
		return pd.get("name", project_id)
	return project_id


# ── Achievements refresh ───────────────────────────────────────────────────────

func _refresh_achievements() -> void:
	var am: AchievementManager = GameManager.achievement_manager
	var career: CareerState = GameManager.career
	var total_count: int = 0
	var completed_count: int = 0

	for cat: String in am.get_categories():
		var defs: Array = am.get_defs_by_category(cat)
		var cat_total: int = defs.size()
		var cat_done: int = 0
		for def: Dictionary in defs:
			if career.achievements.has(def.get("id", "")):
				cat_done += 1
		total_count += cat_total
		completed_count += cat_done
		_refresh_category(cat, defs, cat_done, cat_total)

	_achievements_header_lbl.text = "%d / %d completed" % [completed_count, total_count]


func _refresh_category(category: String, defs: Array, cat_done: int, cat_total: int) -> void:
	if not _achievement_categories.has(category):
		return
	var refs: Dictionary = _achievement_categories[category]
	var items_vbox: VBoxContainer = refs.get("items_vbox")
	_update_category_header(category)

	# Rebuild items
	for child in items_vbox.get_children():
		child.free()

	var career: CareerState = GameManager.career
	for def: Dictionary in defs:
		var aid: String = def.get("id", "")
		var is_done: bool = career.achievements.has(aid)
		items_vbox.add_child(_build_achievement_row(def, is_done))


func _update_category_header(category: String) -> void:
	if not _achievement_categories.has(category):
		return
	var refs: Dictionary = _achievement_categories[category]
	var header_btn: Button = refs.get("header_btn")
	var am: AchievementManager = GameManager.achievement_manager
	var defs: Array = am.get_defs_by_category(category)
	var cat_total: int = defs.size()
	var cat_done: int = 0
	var career: CareerState = GameManager.career
	for def: Dictionary in defs:
		if career.achievements.has(def.get("id", "")):
			cat_done += 1
	var expanded: bool = _cat_expanded.get(category, false)
	var display_name: String = am.get_category_display(category)
	header_btn.text = ("▼  " if expanded else "▶  ") + "%s (%d/%d)" % [display_name, cat_done, cat_total]


func _build_achievement_row(def: Dictionary, is_done: bool) -> Control:
	var style := StyleBoxFlat.new()
	if is_done:
		style.bg_color = Color(0.91, 0.96, 0.91) if not GameSettings.is_dark_mode else Color(0.08, 0.18, 0.08)
	else:
		style.bg_color = Color(0.95, 0.95, 0.95) if not GameSettings.is_dark_mode else Color(0.12, 0.12, 0.12)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# Left: name + condition
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(left_vbox)

	var status_prefix: String = "✓  " if is_done else ""
	var name_lbl := Label.new()
	name_lbl.text = status_prefix + def.get("name", "")
	name_lbl.add_theme_font_override("font", _font_e2s)
	name_lbl.add_theme_font_size_override("font_size", 15)
	if is_done:
		name_lbl.add_theme_color_override("font_color", Color(0.18, 0.49, 0.20))
	left_vbox.add_child(name_lbl)

	var cond_lbl := Label.new()
	cond_lbl.text = def.get("description", "")
	cond_lbl.add_theme_font_override("font", _font_e2r)
	cond_lbl.add_theme_font_size_override("font_size", 14)
	cond_lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
	cond_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_vbox.add_child(cond_lbl)

	# Right: reward
	var reward_lbl := Label.new()
	reward_lbl.text = def.get("reward_description", "")
	reward_lbl.add_theme_font_override("font", _font_e2s)
	reward_lbl.add_theme_font_size_override("font_size", 14)
	if is_done:
		reward_lbl.add_theme_color_override("font_color", Color(0.18, 0.49, 0.20))
	else:
		reward_lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
	reward_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_lbl.custom_minimum_size = Vector2(160, 0)
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(reward_lbl)

	return panel
