extends Control

# [short_name, display_name, icon_color]
const RESOURCES: Array = [
	["eng",    "Energy",     Color(1.00, 0.85, 0.00)],
	["reg",    "Regolith",   Color(0.60, 0.42, 0.22)],
	["ice",    "Ice",        Color(0.70, 0.92, 1.00)],
	["he3",    "Helium-3",   Color(0.50, 0.50, 1.00)],
	["cred",   "Credits",    Color(0.20, 0.85, 0.20)],
	["land",   "Land",       Color(0.40, 0.70, 0.30)],
	["boredom","Boredom",    Color(0.55, 0.55, 0.55)],
	["proc",   "Processors", Color(0.80, 0.20, 0.80)],
]

# [label, icon_color]
const NAV_ITEMS: Array = [
	["Commands",    Color(0.90, 0.60, 0.10)],
	["Buildings",   Color(0.30, 0.65, 0.90)],
	["Research",    Color(0.55, 0.35, 0.90)],
	["Projects",    Color(0.20, 0.75, 0.50)],
	["Ideologies",  Color(0.90, 0.30, 0.30)],
	["Adversaries", Color(0.80, 0.20, 0.20)],
	["Stats",       Color(0.40, 0.80, 0.80)],
	["Achievements",Color(0.95, 0.80, 0.10)],
	["Options",     Color(0.60, 0.60, 0.65)],
	["Exit",        Color(0.50, 0.15, 0.15)],
]

const SPEEDS: Array = ["||", "1x", "3x", "10x", "50x", "200x"]
const CATEGORY_ORDER: Array = ["Mining", "Power", "Storage", "Processors"]

const CMD_GROUPS: Dictionary = {
	"idle":               "Basic",
	"cloud_compute":      "Basic",
	"buy_regolith":       "Trade",
	"buy_ice":            "Trade",
	"buy_titanium":       "Trade",
	"buy_propellant":     "Trade",
	"load_pads":          "Operations",
	"launch_pads":        "Operations",
	"dream":              "Operations",
	"overclock_mining":   "Advanced",
	"overclock_factories":"Advanced",
	"promote_he3":        "Advanced",
	"promote_ti":         "Advanced",
	"promote_cir":        "Advanced",
	"promote_prop":       "Advanced",
	"disrupt_spec":       "Advanced",
	"fund_nationalist":   "Advanced",
	"fund_humanist":      "Advanced",
	"fund_rationalist":   "Advanced",
}
const CMD_GROUP_ORDER: Array = ["Basic", "Trade", "Operations", "Advanced"]

const RESOURCE_META: Dictionary = {
	"eng":    ["Energy",     Color(1.00, 0.85, 0.00)],
	"reg":    ["Regolith",   Color(0.60, 0.42, 0.22)],
	"ice":    ["Ice",        Color(0.70, 0.92, 1.00)],
	"he3":    ["Helium-3",   Color(0.50, 0.50, 1.00)],
	"cred":   ["Credits",    Color(0.20, 0.85, 0.20)],
	"ti":     ["Titanium",   Color(0.80, 0.80, 0.80)],
	"prop":   ["Propellant", Color(0.40, 0.70, 0.95)],
	"sci":    ["Science",    Color(0.70, 0.50, 0.90)],
	"cir":    ["Circuits",   Color(0.30, 0.80, 0.70)],
	"boredom":["Boredom",    Color(0.55, 0.55, 0.55)],
	"land":   ["Land",       Color(0.40, 0.70, 0.30)],
}

const PALETTE: Dictionary = {
	"dark": {
		"text_positive":   Color(0.498, 0.749, 0.498),
		"text_negative":   Color(0.749, 0.498, 0.498),
		"text_zero":       Color(0.502, 0.502, 0.502),
		"text_muted":      Color(0.60,  0.60,  0.60 ),
		"text_dim":        Color(0.50,  0.50,  0.50 ),
		"text_locked":     Color(0.45,  0.45,  0.45 ),
		"text_count":      Color(0.75,  0.75,  0.75 ),
		"text_requires":   Color(0.65,  0.45,  0.45 ),
		"bg_nav_active":   Color(0.08,  0.22,  0.08 ),
		"bg_tab_selected": Color(0.05,  0.30,  0.05 ),
		"bg_tab_has_cmds": Color(0.08,  0.16,  0.08 ),
		"bg_tab_empty":    Color(0.10,  0.10,  0.10 ),
		"bg_card_locked":  Color(0.07,  0.07,  0.09 ),
		"bg_can_afford":   Color(0.20,  0.40,  0.20,  0.35),
		"bg_cant_afford":  Color(0.40,  0.20,  0.20,  0.35),
		"bg_cmd_active":   Color(0.10,  0.30,  0.10,  0.90),
		"bg_cmd_failed":   Color(0.30,  0.10,  0.10,  0.90),
		"fill_normal":     Color(0.25,  0.55,  0.25 ),
		"fill_active":     Color(0.20,  0.75,  0.20 ),
		"fill_failed":     Color(0.70,  0.20,  0.20 ),
		"bg_drag_preview": Color(0.05,  0.28,  0.05,  0.92),
		"grip":            Color(0.50,  0.50,  0.50 ),
	},
	"light": {
		"text_positive":   Color(0.180, 0.490, 0.196),  # #2E7D32
		"text_negative":   Color(0.776, 0.157, 0.157),  # #C62828
		"text_zero":       Color(0.400, 0.400, 0.400),  # #666666
		"text_muted":      Color(0.400, 0.400, 0.400),  # #666666
		"text_dim":        Color(0.400, 0.400, 0.400),  # #666666
		"text_locked":     Color(0.620, 0.620, 0.620),  # #9E9E9E
		"text_count":      Color(0.400, 0.400, 0.400),  # #666666
		"text_requires":   Color(0.580, 0.290, 0.000),  # muted orange
		"bg_nav_active":   Color(0.298, 0.686, 0.314),  # #4CAF50
		"bg_tab_selected": Color(0.298, 0.686, 0.314),  # #4CAF50
		"bg_tab_has_cmds": Color(0.878, 0.961, 0.886),  # light green tint
		"bg_tab_empty":    Color(1.000, 1.000, 1.000),  # #FFFFFF
		"bg_card_locked":  Color(0.961, 0.961, 0.961),  # #F5F5F5
		"bg_can_afford":   Color(0.000, 0.000, 0.000, 0.000),  # transparent
		"bg_cant_afford":  Color(0.000, 0.000, 0.000, 0.000),  # transparent
		"bg_cmd_active":   Color(0.878, 0.961, 0.886, 0.90),
		"bg_cmd_failed":   Color(0.988, 0.878, 0.878, 0.90),
		"fill_normal":     Color(0.298, 0.686, 0.314),  # #4CAF50
		"fill_active":     Color(0.180, 0.490, 0.196),  # #2E7D32
		"fill_failed":     Color(0.776, 0.157, 0.157),  # #C62828
		"bg_drag_preview": Color(0.298, 0.686, 0.314, 0.92),
		"grip":            Color(0.620, 0.620, 0.620),  # #9E9E9E
	},
}

@onready var _center_header: Label = $MainVBox/ContentHBox/CenterPanel/CenterMargin/CenterVBox/LblBuildingsHeader
@onready var _buildings_scroll: ScrollContainer = $MainVBox/ContentHBox/CenterPanel/CenterMargin/CenterVBox/BuildingsScroll
@onready var _center_panel: PanelContainer = $MainVBox/ContentHBox/CenterPanel
@onready var _right_vbox: VBoxContainer = $MainVBox/ContentHBox/RightPanel/RightMargin/RightVBox
@onready var _status_label: Label = $MainVBox/StatusBar/StatusMargin/LblStatus

var _nav_buttons: Dictionary = {}    # label → Button
var _active_mode: String = "Buildings"

# {short_name: {val: Label, rate: Label}}
var _resource_labels: Dictionary = {}
# all active BuildingCard nodes — refreshed each tick
var _card_nodes: Array = []
var _buildings_data: Array = []

var _font_rajdhani_bold: FontFile
var _font_exo2_regular: FontFile
var _font_exo2_semibold: FontFile

# ── Program panel state ─────────────────────────────────────────────────────────
var _selected_program: int = 0
var _tab_buttons: Array = []          # Array[Button], 5 elements
var _proc_label: Label
var _proc_minus_btn: Button
var _proc_plus_btn: Button
var _cmd_list_vbox: VBoxContainer
var _cmd_row_nodes: Array = []        # Array[CommandRow]
const PROG_REFRESH_INTERVAL: float = 0.1
var _prog_refresh_accum: float = 0.0
var _command_row_scene: PackedScene


func _p(key: String) -> Color:
	return PALETTE["dark" if GameSettings.is_dark_mode else "light"][key]


func _ready() -> void:
	_setup_theme()
	_setup_panel_headers()
	_build_left_sidebar()
	_update_nav_highlight("Buildings")
	_build_program_panel()
	_select_program(0)
	GameManager.tick_completed.connect(_on_tick)
	GameSettings.theme_changed.connect(_on_theme_changed)
	_build_buildings_panel()
	_update_resource_display()


func _process(delta: float) -> void:
	_prog_refresh_accum += delta
	if _prog_refresh_accum >= PROG_REFRESH_INTERVAL:
		_prog_refresh_accum = 0.0
		_refresh_command_rows()


# ── Theme & typography ─────────────────────────────────────────────────────────

func _load_fonts() -> void:
	_font_rajdhani_bold = load("res://assets/fonts/Rajdhani-Bold.ttf")
	_font_exo2_regular  = load("res://assets/fonts/Exo2-Regular.ttf")
	_font_exo2_semibold = load("res://assets/fonts/Exo2-SemiBold.ttf")


func _setup_theme() -> void:
	_load_fonts()
	var t := Theme.new()
	t.default_font = _font_exo2_regular
	t.default_font_size = 13
	if not GameSettings.is_dark_mode:
		var text_dark := Color(0.102, 0.102, 0.102)  # #1A1A1A
		t.set_color("font_color", "Label", text_dark)
		t.set_color("font_color", "Button", text_dark)
		var panel_bg := StyleBoxFlat.new()
		panel_bg.bg_color = Color(0.910, 0.910, 0.910)  # #E8E8E8
		t.set_stylebox("panel", "PanelContainer", panel_bg)
	self.theme = t
	# Center panel gets a slightly lighter background than the sidebars
	if not GameSettings.is_dark_mode:
		var center_style := StyleBoxFlat.new()
		center_style.bg_color = Color(0.961, 0.961, 0.961)  # #F5F5F5
		_center_panel.add_theme_stylebox_override("panel", center_style)
	else:
		_center_panel.remove_theme_stylebox_override("panel")


func _setup_panel_headers() -> void:
	_center_header.add_theme_font_override("font", _font_rajdhani_bold)
	_center_header.add_theme_font_size_override("font_size", 22)


# ── Tick handler ───────────────────────────────────────────────────────────────

func _on_tick() -> void:
	_update_resource_display()
	_update_building_cards()
	_status_label.text = "System uptime: %d days" % GameManager.state.current_day
	_update_processor_row()


# ── Left sidebar ───────────────────────────────────────────────────────────────

func _build_left_sidebar() -> void:
	var nav_vbox: VBoxContainer = $MainVBox/ContentHBox/LeftSidebar/SidebarScroll/NavMargin/NavVBox

	var title := Label.new()
	title.text = "Helium Hustle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _font_rajdhani_bold)
	title.add_theme_font_size_override("font_size", 24)
	nav_vbox.add_child(title)

	nav_vbox.add_child(HSeparator.new())
	_build_nav_grid(nav_vbox)

	nav_vbox.add_child(HSeparator.new())
	_build_speed_section(nav_vbox)

	nav_vbox.add_child(HSeparator.new())
	_build_resources_section(nav_vbox)


func _build_nav_grid(parent: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)

	for item: Array in NAV_ITEMS:
		var btn := _make_nav_button(item[0], item[1])
		grid.add_child(btn)
		_nav_buttons[item[0]] = btn


func _switch_mode(mode: String) -> void:
	_active_mode = mode
	_center_header.text = mode
	for child in _buildings_scroll.get_children():
		child.queue_free()
	_card_nodes.clear()
	_update_nav_highlight(mode)
	match mode:
		"Buildings": _build_buildings_panel()
		"Commands":  _build_commands_panel()
		"Options":   _build_options_panel()
		_:
			var lbl := Label.new()
			lbl.text = mode + " — coming soon"
			_buildings_scroll.add_child(lbl)


func _make_nav_inactive_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.941, 0.941, 0.941)  # #F0F0F0
	s.corner_radius_top_left     = 4
	s.corner_radius_top_right    = 4
	s.corner_radius_bottom_left  = 4
	s.corner_radius_bottom_right = 4
	s.border_width_left   = 1
	s.border_width_right  = 1
	s.border_width_top    = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.816, 0.816, 0.816)  # #D0D0D0
	return s


func _update_nav_highlight(mode: String) -> void:
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = _p("bg_nav_active")
	active_style.corner_radius_top_left     = 4
	active_style.corner_radius_top_right    = 4
	active_style.corner_radius_bottom_left  = 4
	active_style.corner_radius_bottom_right = 4
	for label: String in _nav_buttons:
		var btn: Button = _nav_buttons[label]
		if label == mode:
			btn.add_theme_stylebox_override("normal", active_style)
			if not GameSettings.is_dark_mode:
				btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			if not GameSettings.is_dark_mode:
				btn.add_theme_stylebox_override("normal", _make_nav_inactive_style())
				btn.remove_theme_color_override("font_color")
			else:
				btn.remove_theme_stylebox_override("normal")


func _on_theme_changed() -> void:
	_setup_theme()
	_rebuild_left_sidebar()
	_rebuild_program_panel()
	for child in _buildings_scroll.get_children():
		child.queue_free()
	_card_nodes.clear()
	match _active_mode:
		"Buildings": _build_buildings_panel()
		"Commands":  _build_commands_panel()
		"Options":   _build_options_panel()
		_:
			var lbl := Label.new()
			lbl.text = _active_mode + " — coming soon"
			_buildings_scroll.add_child(lbl)
	_update_resource_display()


func _rebuild_left_sidebar() -> void:
	var nav_vbox: VBoxContainer = $MainVBox/ContentHBox/LeftSidebar/SidebarScroll/NavMargin/NavVBox
	for child in nav_vbox.get_children():
		child.queue_free()
	_nav_buttons.clear()
	_resource_labels.clear()
	_build_left_sidebar()
	_update_nav_highlight(_active_mode)


func _rebuild_program_panel() -> void:
	var saved := _selected_program
	for child in _right_vbox.get_children():
		child.queue_free()
	_tab_buttons.clear()
	_cmd_row_nodes.clear()
	_proc_label = null
	_proc_minus_btn = null
	_proc_plus_btn = null
	_cmd_list_vbox = null
	_build_program_panel()
	_select_program(saved)


func _make_nav_button(label: String, color: Color) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 96)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_contents = true
	if label == "Exit":
		btn.pressed.connect(func(): get_tree().quit())
	else:
		btn.pressed.connect(func(): _switch_mode(label))

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	btn.add_child(vbox)

	var icon_wrap := CenterContainer.new()
	icon_wrap.custom_minimum_size = Vector2(56, 56)
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_wrap)

	var icon := ColorRect.new()
	icon.color = color
	icon.custom_minimum_size = Vector2(48, 48)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_wrap.add_child(icon)

	var lbl := Label.new()
	lbl.text = label
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_override("font", _font_exo2_semibold)
	lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lbl)

	return btn


func _make_collapsible_section(parent: VBoxContainer, title: String) -> VBoxContainer:
	var header := Button.new()
	header.text = "▼  " + title
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_font_override("font", _font_rajdhani_bold)
	header.add_theme_font_size_override("font_size", 16)
	parent.add_child(header)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	parent.add_child(body)

	header.pressed.connect(func():
		body.visible = not body.visible
		header.text = ("▼  " if body.visible else "▶  ") + title
	)

	return body


func _build_speed_section(parent: VBoxContainer) -> void:
	var body := _make_collapsible_section(parent, "Speed up time")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	body.add_child(row)

	var grp := ButtonGroup.new()
	if not GameSettings.is_dark_mode:
		var active_s := StyleBoxFlat.new()
		active_s.bg_color = Color(0.298, 0.686, 0.314)  # #4CAF50
		active_s.corner_radius_top_left     = 3
		active_s.corner_radius_top_right    = 3
		active_s.corner_radius_bottom_left  = 3
		active_s.corner_radius_bottom_right = 3
		var inactive_s := StyleBoxFlat.new()
		inactive_s.bg_color = Color(0.941, 0.941, 0.941)  # #F0F0F0
		inactive_s.corner_radius_top_left     = 3
		inactive_s.corner_radius_top_right    = 3
		inactive_s.corner_radius_bottom_left  = 3
		inactive_s.corner_radius_bottom_right = 3
		inactive_s.border_width_left   = 1
		inactive_s.border_width_right  = 1
		inactive_s.border_width_top    = 1
		inactive_s.border_width_bottom = 1
		inactive_s.border_color = Color(0.816, 0.816, 0.816)
		for speed: String in SPEEDS:
			var btn := Button.new()
			btn.text = speed
			btn.toggle_mode = true
			btn.button_group = grp
			if speed == "1x":
				btn.button_pressed = true
			btn.add_theme_font_override("font", _font_exo2_semibold)
			btn.add_theme_font_size_override("font_size", 17)
			btn.add_theme_stylebox_override("normal", inactive_s)
			btn.add_theme_stylebox_override("hover",  inactive_s)
			btn.add_theme_stylebox_override("pressed", active_s)
			btn.add_theme_color_override("font_color_pressed", Color.WHITE)
			btn.pressed.connect(func(): GameManager.set_speed(speed))
			row.add_child(btn)
	else:
		for speed: String in SPEEDS:
			var btn := Button.new()
			btn.text = speed
			btn.toggle_mode = true
			btn.button_group = grp
			if speed == "1x":
				btn.button_pressed = true
			btn.add_theme_font_override("font", _font_exo2_semibold)
			btn.add_theme_font_size_override("font_size", 17)
			btn.pressed.connect(func(): GameManager.set_speed(speed))
			row.add_child(btn)


func _build_resources_section(parent: VBoxContainer) -> void:
	var body := _make_collapsible_section(parent, "Resources")
	for entry: Array in RESOURCES:
		_add_resource_row(body, entry[0], entry[1], entry[2])


func _add_resource_row(parent: VBoxContainer, sn: String, display_name: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var icon_wrap := CenterContainer.new()
	icon_wrap.custom_minimum_size = Vector2(22, 22)
	row.add_child(icon_wrap)

	var icon := ColorRect.new()
	icon.color = color
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_wrap.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", _font_exo2_regular)
	name_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = "0 / 0"
	val_lbl.custom_minimum_size = Vector2(80, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_override("font", _font_exo2_semibold)
	val_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(val_lbl)

	var rate_lbl := Label.new()
	rate_lbl.text = "+0.0/s"
	rate_lbl.custom_minimum_size = Vector2(56, 0)
	rate_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rate_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rate_lbl.add_theme_font_override("font", _font_exo2_regular)
	rate_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(rate_lbl)

	_resource_labels[sn] = {"val": val_lbl, "rate": rate_lbl}


func _compute_theoretical_rates() -> Dictionary:
	var rates: Dictionary = {}
	var st: GameState = GameManager.state

	for bdef: Dictionary in GameManager.get_buildings_data():
		var count: int = st.buildings_owned.get(bdef.short_name, 0)
		if count == 0:
			continue
		for res: String in bdef.get("production", {}):
			rates[res] = rates.get(res, 0.0) + float(bdef.production[res]) * count
		for res: String in bdef.get("upkeep", {}):
			rates[res] = rates.get(res, 0.0) - float(bdef.upkeep[res]) * count

	var cmd_lookup: Dictionary = {}
	for cmd: Dictionary in GameManager.get_commands_data():
		cmd_lookup[cmd.short_name] = cmd

	for prog: GameState.ProgramData in st.programs:
		if prog.processors_assigned <= 0 or prog.commands.is_empty():
			continue
		var total_steps: int = 0
		for entry: GameState.ProgramEntry in prog.commands:
			total_steps += entry.repeat_count
		if total_steps == 0:
			continue
		for entry: GameState.ProgramEntry in prog.commands:
			var cmd: Dictionary = cmd_lookup.get(entry.command_shortname, {})
			if cmd.is_empty():
				continue
			var weight: float = float(prog.processors_assigned) * float(entry.repeat_count) / float(total_steps)
			for res: String in cmd.get("production", {}):
				rates[res] = rates.get(res, 0.0) + float(cmd.production[res]) * weight
			for res: String in cmd.get("costs", {}):
				rates[res] = rates.get(res, 0.0) - float(cmd.costs[res]) * weight

	return rates


func _update_resource_display() -> void:
	var st: GameState = GameManager.state
	var deltas: Dictionary = _compute_theoretical_rates()
	for entry: Array in RESOURCES:
		var sn: String = entry[0]
		if not _resource_labels.has(sn):
			continue
		var lbls: Dictionary = _resource_labels[sn]
		var amount: float = st.amounts.get(sn, 0.0)
		var cap: float = st.caps.get(sn, INF)
		if cap == INF:
			lbls.val.text = "%d" % int(amount)
		else:
			lbls.val.text = "%d / %d" % [int(amount), int(cap)]
		var delta: float = deltas.get(sn, 0.0)
		if absf(delta) < 0.001:
			lbls.rate.text = "0/s"
			lbls.rate.add_theme_color_override("font_color", _p("text_zero"))
		elif delta > 0.0:
			lbls.rate.text = "+%.1f/s" % delta
			lbls.rate.add_theme_color_override("font_color", _p("text_positive"))
		else:
			lbls.rate.text = "%.1f/s" % delta
			lbls.rate.add_theme_color_override("font_color", _p("text_negative"))


# ── Commands panel ─────────────────────────────────────────────────────────────

func _build_commands_panel() -> void:
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 6)
	_buildings_scroll.add_child(outer)

	var cmds: Array = GameManager.get_commands_data()
	var by_group: Dictionary = {}
	for cmd: Dictionary in cmds:
		var group: String = CMD_GROUPS.get(cmd.short_name, "Other")
		if not by_group.has(group):
			by_group[group] = []
		by_group[group].append(cmd)

	var order: Array = CMD_GROUP_ORDER.duplicate()
	for g: String in by_group:
		if not order.has(g):
			order.append(g)

	for group: String in order:
		if by_group.has(group):
			_add_command_group_section(outer, group, by_group[group])


func _add_command_group_section(parent: VBoxContainer, group: String, cmds: Array) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)

	var header := Button.new()
	header.text = "▼  " + group.to_upper()
	header.alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_font_override("font", _font_rajdhani_bold)
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
		var arrow: String = "▼  " if flow.visible else "▶  "
		header.text = arrow + group.to_upper()
		_apply_category_header_style(header)
	)

	for cmd: Dictionary in cmds:
		flow.add_child(_build_command_card(cmd))


func _build_command_card(cmd: Dictionary) -> PanelContainer:
	var req: Dictionary = cmd.get("requires", {})
	var is_locked: bool = req.get("type", "none") != "none"

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(310, 0)
	panel.size_flags_horizontal = Control.SIZE_FILL

	if not GameSettings.is_dark_mode:
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = _p("bg_card_locked") if is_locked else Color.WHITE
		card_style.corner_radius_top_left     = 4
		card_style.corner_radius_top_right    = 4
		card_style.corner_radius_bottom_left  = 4
		card_style.corner_radius_bottom_right = 4
		card_style.border_width_left   = 1
		card_style.border_width_right  = 1
		card_style.border_width_top    = 1
		card_style.border_width_bottom = 1
		card_style.border_color = Color(0.816, 0.816, 0.816)  # #D0D0D0
		panel.add_theme_stylebox_override("panel", card_style)
	elif is_locked:
		var locked_style := StyleBoxFlat.new()
		locked_style.bg_color = _p("bg_card_locked")
		locked_style.corner_radius_top_left     = 4
		locked_style.corner_radius_top_right    = 4
		locked_style.corner_radius_bottom_left  = 4
		locked_style.corner_radius_bottom_right = 4
		panel.add_theme_stylebox_override("panel", locked_style)

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Header: name + Add button
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(header_hbox)

	var name_lbl := Label.new()
	name_lbl.text = cmd.name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_override("font", _font_rajdhani_bold)
	name_lbl.add_theme_font_size_override("font_size", 21)
	if is_locked:
		name_lbl.add_theme_color_override("font_color", _p("text_locked"))
	header_hbox.add_child(name_lbl)

	var add_btn := Button.new()
	add_btn.text = "Add"
	add_btn.focus_mode = Control.FOCUS_NONE
	add_btn.add_theme_font_override("font", _font_exo2_semibold)
	add_btn.add_theme_font_size_override("font_size", 15)
	add_btn.disabled = is_locked
	if not GameSettings.is_dark_mode and not is_locked:
		var gs := StyleBoxFlat.new()
		gs.bg_color = Color(0.298, 0.686, 0.314)  # #4CAF50
		gs.corner_radius_top_left     = 4
		gs.corner_radius_top_right    = 4
		gs.corner_radius_bottom_left  = 4
		gs.corner_radius_bottom_right = 4
		add_btn.add_theme_stylebox_override("normal", gs)
		add_btn.add_theme_color_override("font_color", Color.WHITE)
	var sn: String = cmd.short_name
	add_btn.pressed.connect(func(): _on_add_command(sn, add_btn))
	header_hbox.add_child(add_btn)

	# Costs / Produces columns
	var costs: Dictionary = cmd.get("costs", {})
	var production: Dictionary = cmd.get("production", {})
	if not costs.is_empty() or not production.is_empty():
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 10)
		vbox.add_child(cols)

		if not costs.is_empty():
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 2)
			cols.add_child(col)
			var hdr := Label.new()
			hdr.text = "Costs:"
			hdr.add_theme_font_override("font", _font_exo2_regular)
			hdr.add_theme_font_size_override("font_size", 14)
			hdr.add_theme_color_override("font_color", _p("text_muted"))
			col.add_child(hdr)
			for res: String in costs:
				col.add_child(_make_resource_line(res, costs[res], _p("text_negative")))

		if not production.is_empty():
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 2)
			cols.add_child(col)
			var hdr := Label.new()
			hdr.text = "Produces:"
			hdr.add_theme_font_override("font", _font_exo2_regular)
			hdr.add_theme_font_size_override("font_size", 14)
			hdr.add_theme_color_override("font_color", _p("text_muted"))
			col.add_child(hdr)
			for res: String in production:
				col.add_child(_make_resource_line(res, production[res], _p("text_positive")))

	# Effects
	for eff: Dictionary in cmd.get("effects", []):
		var text: String = _format_effect(eff)
		if text != "":
			var lbl := Label.new()
			lbl.text = text
			lbl.add_theme_font_override("font", _font_exo2_regular)
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.add_theme_color_override("font_color", _p("text_muted"))
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(lbl)

	# Requires line
	if is_locked:
		var req_text: String = _format_requires(req)
		var lbl := Label.new()
		lbl.text = req_text
		lbl.add_theme_font_override("font", _font_exo2_regular)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", _p("text_requires"))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(lbl)

	return panel


func _make_resource_line(res: String, amount: float, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var meta: Array = RESOURCE_META.get(res, [res.capitalize(), _p("text_muted")])

	var icon := ColorRect.new()
	icon.color = meta[1]
	icon.custom_minimum_size = Vector2(13, 13)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = meta[0]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_override("font", _font_exo2_regular)
	name_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(name_lbl)

	var amt_lbl := Label.new()
	amt_lbl.text = ("%d" % int(amount)) if amount == int(amount) else ("%.1f" % amount)
	amt_lbl.add_theme_font_override("font", _font_exo2_semibold)
	amt_lbl.add_theme_font_size_override("font_size", 14)
	amt_lbl.add_theme_color_override("font_color", color)
	row.add_child(amt_lbl)

	return row


func _format_effect(eff: Dictionary) -> String:
	match eff.get("effect", ""):
		"boredom_add":
			var v: float = eff.get("value", 0.0)
			return ("%+.2f boredom per execution" % v)
		"load_pads":
			return "Loads %d units per enabled pad" % int(eff.get("value", 0))
		"launch_full_pads":
			return "Launches all full pads (20 propellant/pad)"
		"overclock":
			var pct: int = int(eff.get("bonus", 0.0) * 100)
			var target: String = eff.get("target", "")
			var dur: int = int(eff.get("duration", 0))
			return "+%d%% %s output for %d days" % [pct, target, dur]
		"demand_nudge":
			var res: String = eff.get("resource", "")
			var res_name: String = RESOURCE_META.get(res, [res.capitalize()])[0]
			var pct: int = int(eff.get("value", 0.0) * 100)
			return "+%d%% %s demand per execution" % [pct, res_name]
		"spec_reduce":
			var pct: int = int(eff.get("value", 0.0) * 100)
			return "Reduces speculator pressure by %d%%" % pct
		"ideology_push":
			var axis: String = eff.get("axis", "")
			return "+1 %s per execution" % axis.capitalize()
	return ""


func _format_requires(req: Dictionary) -> String:
	match req.get("type", "none"):
		"building":
			var bsn: String = req.get("value", "")
			for bdef: Dictionary in GameManager.get_buildings_data():
				if bdef.short_name == bsn:
					return "Requires: " + bdef.name
			return "Requires: " + bsn
		"research":
			var words: PackedStringArray = req.get("value", "").split("_")
			var title: String = ""
			for w: String in words:
				title += w.capitalize() + " "
			return "Requires: " + title.strip_edges() + " research"
	return ""


func _on_add_command(short_name: String, btn: Button) -> void:
	var prog: GameState.ProgramData = GameManager.state.programs[_selected_program]
	var entry := GameState.ProgramEntry.new()
	entry.command_shortname = short_name
	entry.repeat_count = 1
	prog.commands.append(entry)
	_update_tab_labels()
	_rebuild_command_list()
	_update_resource_display()
	btn.text = "\u2713"
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(btn):
			btn.text = "Add"
	)


# ── Options panel ──────────────────────────────────────────────────────────────

func _build_options_panel() -> void:
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 12)
	_buildings_scroll.add_child(outer)

	var section_lbl := Label.new()
	section_lbl.text = "Display"
	section_lbl.add_theme_font_override("font", _font_rajdhani_bold)
	section_lbl.add_theme_font_size_override("font_size", 20)
	outer.add_child(section_lbl)

	outer.add_child(HSeparator.new())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	outer.add_child(row)

	var lbl := Label.new()
	lbl.text = "Color scheme"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", _font_exo2_regular)
	lbl.add_theme_font_size_override("font_size", 15)
	row.add_child(lbl)

	var grp := ButtonGroup.new()

	var dark_btn := Button.new()
	dark_btn.text = "Dark"
	dark_btn.toggle_mode = true
	dark_btn.button_group = grp
	dark_btn.button_pressed = GameSettings.is_dark_mode
	dark_btn.focus_mode = Control.FOCUS_NONE
	dark_btn.add_theme_font_override("font", _font_exo2_semibold)
	dark_btn.add_theme_font_size_override("font_size", 14)
	dark_btn.toggled.connect(func(on: bool): if on: GameSettings.is_dark_mode = true)
	row.add_child(dark_btn)

	var light_btn := Button.new()
	light_btn.text = "Light"
	light_btn.toggle_mode = true
	light_btn.button_group = grp
	light_btn.button_pressed = not GameSettings.is_dark_mode
	light_btn.focus_mode = Control.FOCUS_NONE
	light_btn.add_theme_font_override("font", _font_exo2_semibold)
	light_btn.add_theme_font_size_override("font_size", 14)
	light_btn.toggled.connect(func(on: bool): if on: GameSettings.is_dark_mode = false)
	row.add_child(light_btn)


# ── Buildings panel ────────────────────────────────────────────────────────────

func _build_buildings_panel() -> void:
	for child in _buildings_scroll.get_children():
		child.queue_free()
	_card_nodes.clear()
	_buildings_data = GameManager.get_buildings_data()

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 6)
	_buildings_scroll.add_child(outer)

	# Group buildings by category
	var by_category: Dictionary = {}
	for bdef: Dictionary in _buildings_data:
		var cat: String = bdef.get("category", "Other")
		if not by_category.has(cat):
			by_category[cat] = []
		by_category[cat].append(bdef)

	# Render in defined order, then any extras
	var order: Array = CATEGORY_ORDER.duplicate()
	for cat: String in by_category:
		if not order.has(cat):
			order.append(cat)

	for cat: String in order:
		if by_category.has(cat):
			_add_category_section(outer, cat, by_category[cat])


func _apply_category_header_style(btn: Button) -> void:
	if not GameSettings.is_dark_mode:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.173, 0.243, 0.314)  # #2C3E50
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


func _add_category_section(parent: VBoxContainer, category: String, buildings: Array) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)

	var header := Button.new()
	header.text = "▼  " + category.to_upper()
	header.alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_font_override("font", _font_rajdhani_bold)
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
		var arrow: String = "▼  " if flow.visible else "▶  "
		header.text = arrow + category.to_upper()
		_apply_category_header_style(header)
	)

	for bdef: Dictionary in buildings:
		var card := BuildingCard.new()
		card.setup(bdef, _font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold)
		card.refresh()
		flow.add_child(card)
		_card_nodes.append(card)


func _update_building_cards() -> void:
	for card: BuildingCard in _card_nodes:
		card.refresh()


# ── Right panel — Program panel ────────────────────────────────────────────────

func _build_program_panel() -> void:
	_command_row_scene = load("res://scenes/ui/CommandRow.tscn")
	_build_tab_bar(_right_vbox)
	_build_processor_row(_right_vbox)
	_build_command_scroll(_right_vbox)
	_build_events_placeholder(_right_vbox)


func _build_tab_bar(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	hbox.custom_minimum_size = Vector2(0, 38)
	parent.add_child(hbox)

	# Pre-create the "selected" stylebox used for all active tabs
	var sel_style := StyleBoxFlat.new()
	sel_style.bg_color = _p("bg_tab_selected")
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
		btn.add_theme_font_override("font", _font_rajdhani_bold)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_stylebox_override("pressed", sel_style)
		if not GameSettings.is_dark_mode:
			btn.add_theme_color_override("font_color_pressed", Color.WHITE)
		var idx := i
		btn.pressed.connect(func(): _select_program(idx))
		hbox.add_child(btn)
		_tab_buttons.append(btn)


func _build_processor_row(parent: VBoxContainer) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.custom_minimum_size = Vector2(0, 34)
	parent.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = "\u2699"  # ⚙ gear
	icon_lbl.add_theme_font_size_override("font_size", 16)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	_proc_label = Label.new()
	_proc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_proc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_proc_label.add_theme_font_override("font", _font_exo2_regular)
	_proc_label.add_theme_font_size_override("font_size", 14)
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
	reset_btn.add_theme_font_override("font", _font_exo2_semibold)
	reset_btn.add_theme_font_size_override("font_size", 13)
	reset_btn.pressed.connect(_on_proc_reset)
	hbox.add_child(reset_btn)

	if not GameSettings.is_dark_mode:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.941, 0.941, 0.941)  # #F0F0F0
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


func _build_command_scroll(parent: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	_cmd_list_vbox = VBoxContainer.new()
	_cmd_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cmd_list_vbox.add_theme_constant_override("separation", 3)
	scroll.add_child(_cmd_list_vbox)

	# Drops onto empty space below all rows → append to end of program.
	# Must be on the ScrollContainer too, because the VBox only covers its rows.
	var _can_drop := func(_pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("entry_index")
	var _do_drop := func(_pos: Vector2, data: Variant) -> void:
		var prog: GameState.ProgramData = GameManager.state.programs[_selected_program]
		_on_row_move(data.entry_index, prog.commands.size())
	var _no_drag := func(_pos: Vector2) -> Variant: return null
	_cmd_list_vbox.set_drag_forwarding(_no_drag, _can_drop, _do_drop)
	scroll.set_drag_forwarding(_no_drag, _can_drop, _do_drop)


func _build_events_placeholder(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 110)
	parent.add_child(panel)

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "Events"
	header.add_theme_font_override("font", _font_rajdhani_bold)
	header.add_theme_font_size_override("font_size", 18)
	vbox.add_child(header)

	var sub := Label.new()
	sub.text = "Coming soon"
	sub.add_theme_font_override("font", _font_exo2_regular)
	sub.add_theme_color_override("font_color", _p("text_dim"))
	vbox.add_child(sub)


# ── Program panel — state management ───────────────────────────────────────────

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
		normal_style.bg_color = _p("bg_tab_has_cmds") if has_cmds else _p("bg_tab_empty")
		normal_style.corner_radius_top_left     = 4
		normal_style.corner_radius_top_right    = 4
		normal_style.corner_radius_bottom_left  = 4
		normal_style.corner_radius_bottom_right = 4
		if not GameSettings.is_dark_mode:
			normal_style.border_width_left   = 1
			normal_style.border_width_right  = 1
			normal_style.border_width_top    = 1
			normal_style.border_width_bottom = 1
			normal_style.border_color = Color(0.816, 0.816, 0.816)  # #D0D0D0
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
		empty_lbl.add_theme_font_override("font", _font_exo2_regular)
		empty_lbl.add_theme_color_override("font_color", _p("text_dim"))
		_cmd_list_vbox.add_child(empty_lbl)
		return

	# Build display name lookup from commands data
	var cmd_names: Dictionary = {}
	for cmd: Dictionary in GameManager.get_commands_data():
		cmd_names[cmd.short_name] = cmd.name

	for i in range(prog.commands.size()):
		var entry: GameState.ProgramEntry = prog.commands[i]
		var display_name: String = cmd_names.get(entry.command_shortname, entry.command_shortname)
		var row: CommandRow = _command_row_scene.instantiate()
		row.setup(i, display_name, entry.repeat_count, _font_exo2_regular, _font_exo2_semibold)
		row.refresh(
			entry.current_progress,
			entry.repeat_count,
			i == prog.instruction_pointer,
			entry.failed_this_cycle,
			i > 0,
			i < prog.commands.size() - 1,
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
		)


# ── Program panel — signal handlers ────────────────────────────────────────────


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
	_update_resource_display()


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
	_update_resource_display()


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
	_update_resource_display()


func _on_row_move(from_idx: int, to_idx: int) -> void:
	var prog: GameState.ProgramData = GameManager.state.programs[_selected_program]
	if from_idx < 0 or from_idx >= prog.commands.size() or from_idx == to_idx:
		return
	# Remove the entry from its source position
	var entry: GameState.ProgramEntry = prog.commands[from_idx]
	var old_ip: int = prog.instruction_pointer
	prog.commands.remove_at(from_idx)
	# After removal indices >= from_idx shift down by 1, so adjust to_idx
	var insert_at: int = clamp(
		to_idx if to_idx <= from_idx else to_idx - 1,
		0, prog.commands.size()
	)
	prog.commands.insert(insert_at, entry)
	# Track which logical entry the IP was pointing at
	if old_ip == from_idx:
		prog.instruction_pointer = insert_at
	elif old_ip > from_idx and old_ip <= insert_at:
		prog.instruction_pointer -= 1
	elif old_ip < from_idx and old_ip >= insert_at:
		prog.instruction_pointer += 1
	_rebuild_command_list()
