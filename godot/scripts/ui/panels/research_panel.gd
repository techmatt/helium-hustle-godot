class_name ResearchPanel
extends VBoxContainer

var _font_rb: FontFile
var _font_e2r: FontFile
var _font_e2s: FontFile

var _completed_snapshot: Array = []
var _seen_events_snapshot: Array = []
var _buildings_snapshot: Dictionary = {}
var _shipments_snapshot: int = -1
var _show_completed: bool = true


func setup(font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_font_rb = font_rb
	_font_e2r = font_e2r
	_font_e2s = font_e2s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	_take_snapshot()
	_build()


func _take_snapshot() -> void:
	var st: GameState = GameManager.state
	_completed_snapshot = st.completed_research.duplicate()
	_seen_events_snapshot = st.seen_event_ids.duplicate()
	_buildings_snapshot = st.buildings_owned.duplicate()
	_shipments_snapshot = st.total_shipments_completed + GameManager.career.lifetime_shipments


func on_tick() -> void:
	var st: GameState = GameManager.state
	var shipments_now: int = st.total_shipments_completed + GameManager.career.lifetime_shipments
	if (st.completed_research != _completed_snapshot
			or st.seen_event_ids != _seen_events_snapshot
			or st.buildings_owned != _buildings_snapshot
			or shipments_now != _shipments_snapshot):
		_take_snapshot()
		for child in get_children():
			child.queue_free()
		_build()


func _build() -> void:
	var research_data: Array = GameManager.get_research_data()
	var st: GameState = GameManager.state

	var toggle_row := HBoxContainer.new()
	toggle_row.add_theme_constant_override("separation", 4)
	add_child(toggle_row)

	var toggle_cb := CheckBox.new()
	toggle_cb.button_pressed = _show_completed
	toggle_cb.focus_mode = Control.FOCUS_NONE
	toggle_cb.toggled.connect(func(pressed: bool):
		_show_completed = pressed
		for child in get_children():
			child.queue_free()
		_build()
	)
	toggle_row.add_child(toggle_cb)

	var toggle_lbl := Label.new()
	toggle_lbl.text = "Show completed research"
	toggle_lbl.add_theme_font_override("font", _font_e2r)
	toggle_lbl.add_theme_font_size_override("font_size", 15)
	toggle_row.add_child(toggle_lbl)

	if research_data.is_empty():
		var lbl := Label.new()
		lbl.text = "No research data loaded."
		add_child(lbl)
		return

	var category_order: Array = []
	var by_category: Dictionary = {}
	for item: Dictionary in research_data:
		if not _item_visible(item, st):
			continue
		var cat: String = item.get("category", "Other")
		if not by_category.has(cat):
			by_category[cat] = []
			category_order.append(cat)
		by_category[cat].append(item)

	if category_order.is_empty():
		var lbl := Label.new()
		lbl.text = "Build a Research Lab and earn science to unlock research."
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_override("font", _font_e2r)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
		add_child(lbl)
		return

	for cat: String in category_order:
		_add_category_section(cat, by_category[cat])


func _item_visible(item: Dictionary, _st: GameState) -> bool:
	return GameManager.is_research_item_visible(item.get("id", ""))


func _add_category_section(category: String, items: Array) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	add_child(section)

	var header := Button.new()
	header.text = "▼  " + category.to_upper()
	header.alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_font_override("font", _font_rb)
	header.add_theme_font_size_override("font_size", 15)
	_apply_category_header_style(header)
	section.add_child(header)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(flow)

	header.pressed.connect(func():
		flow.visible = not flow.visible
		header.text = ("▼  " if flow.visible else "▶  ") + category.to_upper()
		_apply_category_header_style(header)
	)

	var completed_ids: Array = GameManager.state.completed_research
	var uncompleted: Array = items.filter(func(i: Dictionary) -> bool: return not completed_ids.has(i.get("id", "")))
	var completed: Array = items.filter(func(i: Dictionary) -> bool: return completed_ids.has(i.get("id", "")))
	for item: Dictionary in uncompleted:
		flow.add_child(_build_card(item))
	if _show_completed:
		for item: Dictionary in completed:
			flow.add_child(_build_card(item))


func _build_card(item: Dictionary) -> PanelContainer:
	var st: GameState = GameManager.state
	var item_id: String = item.get("id", "")
	var is_completed: bool = item_id in st.completed_research
	var cost: int = int(item.get("cost", 0))
	var requires_id: String = item.get("requires", "")
	var requires_met: bool = requires_id.is_empty() or st.completed_research.has(requires_id)
	var can_afford: bool = requires_met and st.amounts.get("sci", 0.0) >= cost

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.size_flags_horizontal = Control.SIZE_FILL
	if is_completed:
		panel.modulate = Color(1, 1, 1, 0.65)

	if not GameSettings.is_dark_mode:
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.941, 0.941, 0.941) if is_completed else Color.WHITE
		card_style.corner_radius_top_left     = 4
		card_style.corner_radius_top_right    = 4
		card_style.corner_radius_bottom_left  = 4
		card_style.corner_radius_bottom_right = 4
		card_style.border_width_left   = 1
		card_style.border_width_right  = 1
		card_style.border_width_top    = 1
		card_style.border_width_bottom = 1
		card_style.border_color = Color(0.816, 0.816, 0.816)
		panel.add_theme_stylebox_override("panel", card_style)

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(header_hbox)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_override("font", _font_rb)
	name_lbl.add_theme_font_size_override("font_size", 20)
	if is_completed:
		name_lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
	header_hbox.add_child(name_lbl)

	if is_completed:
		var badge := Label.new()
		badge.text = "✓"
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_override("font", _font_e2s)
		badge.add_theme_font_size_override("font_size", 16)
		badge.add_theme_color_override("font_color", UIPalette.p("text_positive"))
		header_hbox.add_child(badge)
	else:
		var btn := Button.new()
		btn.text = "Research"
		btn.disabled = not can_afford
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_override("font", _font_e2s)
		btn.add_theme_font_size_override("font_size", 16)
		if not GameSettings.is_dark_mode and can_afford:
			var gs := StyleBoxFlat.new()
			gs.bg_color = Color(0.298, 0.686, 0.314)
			gs.corner_radius_top_left     = 4
			gs.corner_radius_top_right    = 4
			gs.corner_radius_bottom_left  = 4
			gs.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("normal", gs)
			btn.add_theme_color_override("font_color", Color.WHITE)
		elif not GameSettings.is_dark_mode:
			btn.add_theme_color_override("font_disabled_color", Color(0.10, 0.10, 0.10))
		btn.pressed.connect(func(): GameManager.purchase_research(item_id))
		header_hbox.add_child(btn)

	var desc_lbl := Label.new()
	desc_lbl.text = item.get("description", "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_override("font", _font_e2r)
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
	vbox.add_child(desc_lbl)

	if not is_completed:
		if not requires_id.is_empty() and not requires_met:
			var req_lbl := Label.new()
			var req_name: String = requires_id.replace("_", " ").capitalize()
			for rd: Dictionary in GameManager.get_research_data():
				if rd.get("id", "") == requires_id:
					req_name = rd.get("name", req_name)
					break
			req_lbl.text = "Requires: %s" % req_name
			req_lbl.add_theme_font_override("font", _font_e2r)
			req_lbl.add_theme_font_size_override("font_size", 14)
			req_lbl.add_theme_color_override("font_color", UIPalette.p("text_requires"))
			vbox.add_child(req_lbl)

		var cost_row := HBoxContainer.new()
		cost_row.add_theme_constant_override("separation", 4)
		vbox.add_child(cost_row)

		var sci_dot := ColorRect.new()
		sci_dot.color = Color(0.70, 0.50, 0.90)
		sci_dot.custom_minimum_size = Vector2(11, 11)
		sci_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cost_row.add_child(sci_dot)

		var cost_lbl := Label.new()
		cost_lbl.text = "%d science" % cost
		cost_lbl.add_theme_font_override("font", _font_e2r)
		cost_lbl.add_theme_font_size_override("font_size", 15)
		cost_lbl.add_theme_color_override("font_color", UIPalette.p("text_positive") if can_afford else UIPalette.p("text_negative"))
		cost_row.add_child(cost_lbl)

	return panel


func _apply_category_header_style(btn: Button) -> void:
	if not GameSettings.is_dark_mode:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.173, 0.243, 0.314)
		s.corner_radius_top_left     = 4
		s.corner_radius_top_right    = 4
		s.corner_radius_bottom_left  = 4
		s.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_stylebox_override("hover",  s)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_color_hover", Color.WHITE)
	else:
		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_stylebox_override("hover")
		btn.remove_theme_color_override("font_color")
		btn.remove_theme_color_override("font_color_hover")
