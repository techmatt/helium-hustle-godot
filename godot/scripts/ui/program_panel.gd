class_name ProgramPanel
extends Node

signal program_state_changed
signal event_row_clicked(event_id: String)

var _right_vbox: VBoxContainer
var _font_rb: FontFile
var _font_e2r: FontFile
var _font_e2s: FontFile

var _selected_program: int = 0
var _tab_buttons: Array = []
var _proc_label: Label
var _proc_minus_btn: Button
var _proc_plus_btn: Button
var _cmd_list_vbox: VBoxContainer
var _cmd_row_nodes: Array = []
var _event_panel: EventPanel = null
var _command_row_scene: PackedScene

const PROG_REFRESH_INTERVAL: float = 0.1
var _prog_refresh_accum: float = 0.0


func setup(right_vbox: VBoxContainer, font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_right_vbox = right_vbox
	_font_rb = font_rb
	_font_e2r = font_e2r
	_font_e2s = font_e2s
	_command_row_scene = load("res://scenes/ui/CommandRow.tscn")
	_build_tab_bar()
	_build_processor_row()
	_build_command_scroll()
	_build_event_panel()
	_select_program(0)


func rebuild() -> void:
	var saved := _selected_program
	for child in _right_vbox.get_children():
		child.queue_free()
	_tab_buttons.clear()
	_cmd_row_nodes.clear()
	_proc_label = null
	_proc_minus_btn = null
	_proc_plus_btn = null
	_cmd_list_vbox = null
	_event_panel = null
	_command_row_scene = load("res://scenes/ui/CommandRow.tscn")
	_build_tab_bar()
	_build_processor_row()
	_build_command_scroll()
	_build_event_panel()
	_select_program(saved)


func process_delta(delta: float) -> void:
	_prog_refresh_accum += delta
	if _prog_refresh_accum >= PROG_REFRESH_INTERVAL:
		_prog_refresh_accum = 0.0
		_refresh_command_rows()


func on_tick() -> void:
	_update_processor_row()
	_update_tab_labels()


func add_command(short_name: String) -> void:
	var prog: GameState.ProgramData = GameManager.state.programs[_selected_program]
	var entry := GameState.ProgramEntry.new()
	entry.command_shortname = short_name
	entry.repeat_count = 1
	prog.commands.append(entry)
	_update_tab_labels()
	_rebuild_command_list()


# ── Build ─────────────────────────────────────────────────────────────────────

func _build_tab_bar() -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	hbox.custom_minimum_size = Vector2(0, 38)
	_right_vbox.add_child(hbox)

	var sel_style := StyleBoxFlat.new()
	sel_style.bg_color = UIPalette.p("bg_tab_selected")
	sel_style.corner_radius_top_left     = 4
	sel_style.corner_radius_top_right    = 4
	sel_style.corner_radius_bottom_left  = 4
	sel_style.corner_radius_bottom_right = 4

	for i in range(5):
		var btn := Button.new()
		btn.text = str(i + 1)
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_override("font", _font_rb)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_stylebox_override("pressed", sel_style)
		if not GameSettings.is_dark_mode:
			btn.add_theme_color_override("font_color_pressed", Color.WHITE)
		var idx := i
		btn.pressed.connect(func(): _select_program(idx))
		hbox.add_child(btn)
		_tab_buttons.append(btn)


func _build_processor_row() -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.custom_minimum_size = Vector2(0, 34)
	_right_vbox.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = "\u2699"
	icon_lbl.add_theme_font_size_override("font_size", 16)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	_proc_label = Label.new()
	_proc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_proc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_proc_label.add_theme_font_override("font", _font_e2r)
	_proc_label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(_proc_label)

	_proc_minus_btn = Button.new()
	_proc_minus_btn.text = "\u2212"
	_proc_minus_btn.custom_minimum_size = Vector2(34, 0)
	_proc_minus_btn.focus_mode = Control.FOCUS_NONE
	_proc_minus_btn.add_theme_font_size_override("font_size", 18)
	_proc_minus_btn.pressed.connect(_on_proc_minus)
	hbox.add_child(_proc_minus_btn)

	_proc_plus_btn = Button.new()
	_proc_plus_btn.text = "+"
	_proc_plus_btn.custom_minimum_size = Vector2(34, 0)
	_proc_plus_btn.focus_mode = Control.FOCUS_NONE
	_proc_plus_btn.add_theme_font_size_override("font_size", 18)
	_proc_plus_btn.pressed.connect(_on_proc_plus)
	hbox.add_child(_proc_plus_btn)

	hbox.add_child(VSeparator.new())

	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.focus_mode = Control.FOCUS_NONE
	reset_btn.add_theme_font_override("font", _font_e2s)
	reset_btn.add_theme_font_size_override("font_size", 15)
	reset_btn.pressed.connect(_on_proc_reset)
	hbox.add_child(reset_btn)

	if not GameSettings.is_dark_mode:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.941, 0.941, 0.941)
		s.corner_radius_top_left     = 3
		s.corner_radius_top_right    = 3
		s.corner_radius_bottom_left  = 3
		s.corner_radius_bottom_right = 3
		s.border_width_left   = 1
		s.border_width_right  = 1
		s.border_width_top    = 1
		s.border_width_bottom = 1
		s.border_color = Color(0.816, 0.816, 0.816)
		for btn: Button in [_proc_minus_btn, _proc_plus_btn, reset_btn]:
			btn.add_theme_stylebox_override("normal", s)
			btn.add_theme_stylebox_override("hover",  s)


func _build_command_scroll() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 325)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right_vbox.add_child(scroll)

	_cmd_list_vbox = VBoxContainer.new()
	_cmd_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cmd_list_vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(_cmd_list_vbox)

	var _can_drop := func(_pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("entry_index")
	var _do_drop := func(_pos: Vector2, data: Variant) -> void:
		var prog: GameState.ProgramData = GameManager.state.programs[_selected_program]
		_on_row_move(data.entry_index, prog.commands.size())
	var _no_drag := func(_pos: Vector2) -> Variant: return null
	_cmd_list_vbox.set_drag_forwarding(_no_drag, _can_drop, _do_drop)
	scroll.set_drag_forwarding(_no_drag, _can_drop, _do_drop)


func _build_event_panel() -> void:
	_right_vbox.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right_vbox.add_child(scroll)

	var ep := load("res://scenes/ui/EventPanel.tscn").instantiate() as EventPanel
	ep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(ep)
	ep.setup(_font_rb, _font_e2r, _font_e2s)
	ep.event_row_clicked.connect(_on_event_panel_row_clicked)
	_event_panel = ep


func _on_event_panel_row_clicked(eid: String) -> void:
	event_row_clicked.emit(eid)


# ── State management ──────────────────────────────────────────────────────────

func _select_program(idx: int) -> void:
	_selected_program = idx
	for i in range(_tab_buttons.size()):
		var btn: Button = _tab_buttons[i]
		btn.button_pressed = (i == idx)
	_update_tab_labels()
	_update_processor_row()
	_rebuild_command_list()


func _update_tab_labels() -> void:
	for i in range(5):
		var btn: Button = _tab_buttons[i]
		var prog: GameState.ProgramData = GameManager.state.programs[i]
		var has_cmds: bool = not prog.commands.is_empty()
		btn.text = ("\u25cf " if has_cmds else "  ") + str(i + 1)

		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = UIPalette.p("bg_tab_has_cmds") if has_cmds else UIPalette.p("bg_tab_empty")
		normal_style.corner_radius_top_left     = 4
		normal_style.corner_radius_top_right    = 4
		normal_style.corner_radius_bottom_left  = 4
		normal_style.corner_radius_bottom_right = 4
		if not GameSettings.is_dark_mode:
			normal_style.border_width_left   = 1
			normal_style.border_width_right  = 1
			normal_style.border_width_top    = 1
			normal_style.border_width_bottom = 1
			normal_style.border_color = Color(0.816, 0.816, 0.816)
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover",  normal_style)


func _update_processor_row() -> void:
	if _proc_label == null:
		return
	var st: GameState = GameManager.state
	var prog: GameState.ProgramData = st.programs[_selected_program]
	var assigned: int = prog.processors_assigned
	var free: int = st.unassigned_processors
	_proc_label.text = "%d assigned  (%d free)" % [assigned, free]


func _rebuild_command_list() -> void:
	for child in _cmd_list_vbox.get_children():
		child.queue_free()
	_cmd_row_nodes.clear()

	var prog: GameState.ProgramData = GameManager.state.programs[_selected_program]

	if prog.commands.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No commands assigned.\nUse the Commands panel to add commands."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_override("font", _font_e2r)
		empty_lbl.add_theme_color_override("font_color", UIPalette.p("text_dim"))
		_cmd_list_vbox.add_child(empty_lbl)
		return

	var cmd_lookup: Dictionary = {}
	for cmd: Dictionary in GameManager.get_commands_data():
		cmd_lookup[cmd.short_name] = cmd

	for i in range(prog.commands.size()):
		var entry: GameState.ProgramEntry = prog.commands[i]
		var cmd_def: Dictionary = cmd_lookup.get(entry.command_shortname, {})
		var display_name: String = cmd_def.get("name", entry.command_shortname)
		var row: CommandRow = _command_row_scene.instantiate()
		row.setup(i, display_name, entry.repeat_count, _font_e2r, _font_e2s,
			cmd_def.get("costs", {}), cmd_def.get("production", {}))
		row.refresh(
			entry.current_progress,
			entry.repeat_count,
			i == prog.instruction_pointer,
			entry.failed_this_cycle,
			i > 0,
			i < prog.commands.size() - 1,
			entry.partial_failed_this_cycle,
			prog.processors_assigned,
		)
		row.repeat_delta_requested.connect(_on_row_repeat_delta)
		row.remove_requested.connect(_on_row_remove)
		row.move_requested.connect(_on_row_move)
		_cmd_list_vbox.add_child(row)
		_cmd_row_nodes.append(row)


func _refresh_command_rows() -> void:
	var prog: GameState.ProgramData = GameManager.state.programs[_selected_program]
	if prog.commands.size() != _cmd_row_nodes.size():
		_rebuild_command_list()
		return
	for i in range(_cmd_row_nodes.size()):
		var row: CommandRow = _cmd_row_nodes[i]
		var entry: GameState.ProgramEntry = prog.commands[i]
		row.refresh(
			entry.current_progress,
			entry.repeat_count,
			i == prog.instruction_pointer,
			entry.failed_this_cycle,
			i > 0,
			i < prog.commands.size() - 1,
			entry.partial_failed_this_cycle,
			prog.processors_assigned,
		)


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_proc_minus() -> void:
	var prog: GameState.ProgramData = GameManager.state.programs[_selected_program]
	if prog.processors_assigned > 0:
		prog.processors_assigned -= 1
	_update_processor_row()


func _on_proc_plus() -> void:
	var st: GameState = GameManager.state
	if st.unassigned_processors > 0:
		st.programs[_selected_program].processors_assigned += 1
	_update_processor_row()


func _on_proc_reset() -> void:
	var prog: GameState.ProgramData = GameManager.state.programs[_selected_program]
	prog.processors_assigned = 0
	prog.commands.clear()
	prog.instruction_pointer = 0
	_update_tab_labels()
	_update_processor_row()
	_rebuild_command_list()
	program_state_changed.emit()


func _on_row_repeat_delta(entry_idx: int, delta: int) -> void:
	var prog: GameState.ProgramData = GameManager.state.programs[_selected_program]
	if entry_idx >= prog.commands.size():
		return
	var entry: GameState.ProgramEntry = prog.commands[entry_idx]
	entry.repeat_count = max(1, entry.repeat_count + delta)
	if entry.current_progress >= entry.repeat_count:
		entry.current_progress = 0
		if prog.instruction_pointer == entry_idx:
			prog.instruction_pointer = (entry_idx + 1) % prog.commands.size()
	_rebuild_command_list()
	program_state_changed.emit()


func _on_row_remove(entry_idx: int) -> void:
	var prog: GameState.ProgramData = GameManager.state.programs[_selected_program]
	if entry_idx >= prog.commands.size():
		return
	var old_ip: int = prog.instruction_pointer
	prog.commands.remove_at(entry_idx)
	if prog.commands.is_empty():
		prog.instruction_pointer = 0
	elif entry_idx < old_ip:
		prog.instruction_pointer = old_ip - 1
	else:
		prog.instruction_pointer = mini(old_ip, prog.commands.size() - 1)
	_update_tab_labels()
	_rebuild_command_list()
	program_state_changed.emit()


func _on_row_move(from_idx: int, to_idx: int) -> void:
	var prog: GameState.ProgramData = GameManager.state.programs[_selected_program]
	if from_idx < 0 or from_idx >= prog.commands.size() or from_idx == to_idx:
		return
	var entry: GameState.ProgramEntry = prog.commands[from_idx]
	var old_ip: int = prog.instruction_pointer
	prog.commands.remove_at(from_idx)
	var insert_at: int = clamp(
		to_idx if to_idx <= from_idx else to_idx - 1,
		0, prog.commands.size()
	)
	prog.commands.insert(insert_at, entry)
	if old_ip == from_idx:
		prog.instruction_pointer = insert_at
	elif old_ip > from_idx and old_ip <= insert_at:
		prog.instruction_pointer -= 1
	elif old_ip < from_idx and old_ip >= insert_at:
		prog.instruction_pointer += 1
	_rebuild_command_list()
