class_name EventModal
extends Control

var _font_rajdhani_bold: FontFile
var _font_exo2_regular: FontFile
var _font_exo2_semibold: FontFile

var _event_id: String = ""
var _prev_speed_key: String = "1x"
var _did_pause: bool = false

var _backdrop: ColorRect
var _panel: PanelContainer
var _title_lbl: Label
var _body_lbl: Label
var _checklist_container: VBoxContainer
var _buttons_hbox: HBoxContainer

signal modal_closed


func setup(font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_font_rajdhani_bold = font_rb
	_font_exo2_regular = font_e2r
	_font_exo2_semibold = font_e2s
	_build_ui()
	hide()


func open(event_id: String, pause_game: bool = true) -> void:
	_event_id = event_id
	_populate()
	show()
	_did_pause = pause_game
	_backdrop.visible = pause_game
	if pause_game:
		_prev_speed_key = GameManager.current_speed_key
		GameManager.set_speed("||")


func close() -> void:
	hide()
	if _did_pause:
		GameManager.set_speed(_prev_speed_key)
	modal_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			accept_event()
			close()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Semi-transparent backdrop
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0, 0, 0, 0.6)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)

	# Centered panel container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(480, 0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color.WHITE if not GameSettings.is_dark_mode else Color(0.13, 0.13, 0.13)
	panel_style.border_width_left   = 1
	panel_style.border_width_right  = 1
	panel_style.border_width_top    = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.816, 0.816, 0.816)
	panel_style.corner_radius_top_left     = 6
	panel_style.corner_radius_top_right    = 6
	panel_style.corner_radius_bottom_left  = 6
	panel_style.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_override("font", _font_rajdhani_bold)
	_title_lbl.add_theme_font_size_override("font_size", 24)
	if GameSettings.is_dark_mode:
		_title_lbl.add_theme_color_override("font_color", Color.WHITE)
	else:
		_title_lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	vbox.add_child(_title_lbl)

	_body_lbl = Label.new()
	_body_lbl.add_theme_font_override("font", _font_exo2_regular)
	_body_lbl.add_theme_font_size_override("font_size", 16)
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if GameSettings.is_dark_mode:
		_body_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	else:
		_body_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	vbox.add_child(_body_lbl)

	_checklist_container = VBoxContainer.new()
	_checklist_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_checklist_container)

	_buttons_hbox = HBoxContainer.new()
	_buttons_hbox.alignment = BoxContainer.ALIGNMENT_END
	_buttons_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(_buttons_hbox)


func _populate() -> void:
	var st: GameState = GameManager.state
	var em: EventManager = GameManager.event_manager
	var def: Dictionary = em.get_event_def(_event_id)
	var inst: Dictionary = _find_instance(st)

	_title_lbl.text = def.get("title", _event_id)
	_body_lbl.text = em.get_event_body(_event_id)

	# Build sub-objective checklist for all_of quests
	for child in _checklist_container.get_children():
		child.queue_free()
	var cond: Dictionary = def.get("condition", {})
	if cond.get("type", "") == "all_of":
		_build_checklist(cond.get("sub_objectives", []), st)
	_checklist_container.visible = not _checklist_container.get_children().is_empty()

	# Clear buttons
	for child in _buttons_hbox.get_children():
		child.queue_free()

	var is_completed: bool = not inst.is_empty() and inst.state == "completed"

	if is_completed:
		_add_button("Close", _on_close_pressed, true)
		return

	var choices: Array = def.get("choices", [])
	if choices.is_empty():
		_add_button("Continue", _on_continue_pressed, true)
	else:
		for choice in choices:
			var affordable: bool = _can_afford_choice(choice, st)
			_add_button(choice.get("label", "?"), func() -> void: _on_choice_pressed(choice.get("id", "")), affordable)
		_add_button("Later", _on_close_pressed, true)


func _add_button(label: String, callback: Callable, enabled: bool) -> void:
	var btn := Button.new()
	btn.text = label
	btn.disabled = not enabled
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", _font_exo2_semibold)
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size = Vector2(100, 36)

	if not GameSettings.is_dark_mode:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.941, 0.941, 0.941)
		s.corner_radius_top_left     = 4
		s.corner_radius_top_right    = 4
		s.corner_radius_bottom_left  = 4
		s.corner_radius_bottom_right = 4
		s.border_width_left   = 1
		s.border_width_right  = 1
		s.border_width_top    = 1
		s.border_width_bottom = 1
		s.border_color = Color(0.816, 0.816, 0.816)
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_stylebox_override("hover", s)

	btn.pressed.connect(callback)
	_buttons_hbox.add_child(btn)


func _can_afford_choice(choice: Dictionary, st: GameState) -> bool:
	for res in choice.get("cost", {}):
		if st.amounts.get(res, 0.0) < float(choice.cost[res]):
			return false
	return true


func _on_continue_pressed() -> void:
	var st: GameState = GameManager.state
	GameManager.event_manager.acknowledge_event(_event_id, st)
	close()


func _on_choice_pressed(choice_id: String) -> void:
	GameManager.event_manager.make_choice(_event_id, choice_id, GameManager.state)
	close()


func _on_close_pressed() -> void:
	close()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close()


func _build_checklist(sub_objectives: Array, st: GameState) -> void:
	var career: CareerState = GameManager.career
	var dark: bool = GameSettings.is_dark_mode
	for sub: Dictionary in sub_objectives:
		var sub_key: String = _event_id + ":" + sub.get("id", "")
		var sub_done: bool = career.completed_sub_objectives.has(sub_key)
		var sub_cond: String = sub.get("condition", "")
		var sub_cond_data: Dictionary = sub.get("condition_data", {})

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_checklist_container.add_child(row)

		var icon_lbl := Label.new()
		icon_lbl.text = "✓" if sub_done else "○"
		icon_lbl.add_theme_font_override("font", _font_exo2_semibold)
		icon_lbl.add_theme_font_size_override("font_size", 15)
		icon_lbl.add_theme_color_override("font_color",
			(Color(0.30, 0.65, 0.30) if dark else Color(0.18, 0.49, 0.20)) if sub_done
			else (Color(0.55, 0.55, 0.55) if dark else Color(0.50, 0.50, 0.50)))
		row.add_child(icon_lbl)

		var text_lbl := Label.new()
		text_lbl.text = sub.get("label", "")
		text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_lbl.add_theme_font_override("font", _font_exo2_regular)
		text_lbl.add_theme_font_size_override("font_size", 15)
		text_lbl.add_theme_color_override("font_color",
			(Color(0.55, 0.55, 0.55) if dark else Color(0.45, 0.45, 0.45)) if sub_done
			else (Color(0.85, 0.85, 0.85) if dark else Color(0.15, 0.15, 0.15)))
		row.add_child(text_lbl)

		if not sub_done:
			var prog_text: String = ""
			match sub_cond:
				"days_survived":
					var threshold: int = int(sub_cond_data.get("threshold", 0))
					prog_text = "Day %s / %s" % [_fmt_int(st.current_day), _fmt_int(threshold)]
				"credits_earned":
					var threshold: float = float(sub_cond_data.get("threshold", 0))
					var current: float = st.cumulative_resources_earned.get("cred", 0.0)
					prog_text = "¢%s / %s" % [_fmt_int(int(current)), _fmt_int(int(threshold))]
			if not prog_text.is_empty():
				var prog_lbl := Label.new()
				prog_lbl.text = prog_text
				prog_lbl.add_theme_font_override("font", _font_exo2_regular)
				prog_lbl.add_theme_font_size_override("font_size", 14)
				prog_lbl.add_theme_color_override("font_color",
					Color(0.40, 0.60, 0.90) if dark else Color(0.20, 0.40, 0.90))
				row.add_child(prog_lbl)


func _fmt_int(n: int) -> String:
	var s := str(n)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result


func _find_instance(st: GameState) -> Dictionary:
	for inst: Dictionary in st.event_instances:
		if inst.id == _event_id:
			return inst
	return {}
