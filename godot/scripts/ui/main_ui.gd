extends Control

# [short_name, display_name, icon_color]
const RESOURCES: Array = [
	["eng",    "Energy",     Color(1.00, 0.85, 0.00)],
	["reg",    "Regolith",   Color(0.60, 0.42, 0.22)],
	["ice",    "Ice",        Color(0.70, 0.92, 1.00)],
	["he3",    "Helium-3",   Color(0.50, 0.50, 1.00)],
	["cred",   "Credits",    Color(0.20, 0.85, 0.20)],
	["sci",    "Science",    Color(0.70, 0.50, 0.90)],
	["land",   "Land",       Color(0.40, 0.70, 0.30)],
	["boredom","Boredom",    Color(0.55, 0.55, 0.55)],
	["proc",   "Processors", Color(0.80, 0.20, 0.80)],
]

# [label, icon_color]
const NAV_ITEMS: Array = [
	["Commands",    Color(0.90, 0.60, 0.10)],
	["Buildings",   Color(0.30, 0.65, 0.90)],
	["Launch Pads", Color(0.95, 0.55, 0.10)],
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
@onready var _status_bar_margin: MarginContainer = $MainVBox/StatusBar/StatusMargin

var _nav_buttons: Dictionary = {}    # label → Button
var _active_mode: String = "Buildings"

# {short_name: {val: Label, rate: Label}}
var _resource_labels: Dictionary = {}
# all active BuildingCard nodes — refreshed each tick
var _card_nodes: Array = []
var _buildings_data: Array = []
# launch pad panel nodes
var _launch_pad_cards: Array = []
var _launch_history_vbox: VBoxContainer = null
# commands panel: snapshot of buildings_owned used to detect when to rebuild
var _commands_buildings_snapshot: Dictionary = {}
# research panel: snapshots used to detect when to rebuild
var _research_completed_snapshot: Array = []
var _research_sci_snapshot: float = -1.0

var _font_rajdhani_bold: FontFile
var _font_exo2_regular: FontFile
var _font_exo2_semibold: FontFile

# ── Status bar nodes (built in code, replacing scene label) ───────────────────
var _uptime_label: Label = null
var _boredom_bar: ProgressBar = null
var _boredom_bar_lbl: Label = null
var _boredom_fill: StyleBoxFlat = null
var _boredom_rate_lbl: Label = null
var _energy_bar: ProgressBar = null
var _energy_bar_lbl: Label = null
var _energy_fill: StyleBoxFlat = null
var _energy_rate_lbl: Label = null
# 50-tick boredom rolling average
const BOREDOM_HISTORY_SIZE: int = 50
var _boredom_history: Array = []
var _prev_boredom: float = 0.0

# ── Program panel state ─────────────────────────────────────────────────────────
var _event_panel: EventPanel = null
var _event_modal: EventModal = null
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
	_setup_status_bar()
	_update_resource_display()
	_build_event_modal()
	GameManager.event_manager.event_triggered.connect(_on_event_triggered)


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


# ── Status bar ─────────────────────────────────────────────────────────────────

func _make_status_bar_bar(init_color: Color) -> Array:
	var wrapper := Control.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrapper.custom_minimum_size = Vector2(0, 20)

	var bar := ProgressBar.new()
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = init_color
	fill_style.corner_radius_top_left     = 3
	fill_style.corner_radius_top_right    = 3
	fill_style.corner_radius_bottom_left  = 3
	fill_style.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.816, 0.816, 0.816)  # #D0D0D0
	bg_style.corner_radius_top_left     = 3
	bg_style.corner_radius_top_right    = 3
	bg_style.corner_radius_bottom_left  = 3
	bg_style.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg_style)

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", _font_exo2_semibold)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))

	wrapper.add_child(bar)
	wrapper.add_child(lbl)
	return [bar, lbl, fill_style, wrapper]


func _setup_status_bar() -> void:
	var status_bar: PanelContainer = $MainVBox/StatusBar
	status_bar.custom_minimum_size.y = 36

	for child in _status_bar_margin.get_children():
		child.queue_free()

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 12)
	_status_bar_margin.add_child(hbox)

	# Day counter — fixed width, left-aligned
	_uptime_label = Label.new()
	_uptime_label.text = "Day 0"
	_uptime_label.add_theme_font_override("font", _font_exo2_semibold)
	_uptime_label.add_theme_font_size_override("font_size", 13)
	_uptime_label.custom_minimum_size.x = 60
	hbox.add_child(_uptime_label)

	hbox.add_child(VSeparator.new())

	# Boredom section
	var boredom_hbox := HBoxContainer.new()
	boredom_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boredom_hbox.add_theme_constant_override("separation", 6)
	hbox.add_child(boredom_hbox)

	var bd_lbl := Label.new()
	bd_lbl.text = "Boredom"
	bd_lbl.add_theme_font_override("font", _font_exo2_semibold)
	bd_lbl.add_theme_font_size_override("font_size", 13)
	boredom_hbox.add_child(bd_lbl)

	var bd := _make_status_bar_bar(Color(0.180, 0.490, 0.196))  # #2E7D32
	_boredom_bar    = bd[0]
	_boredom_bar_lbl = bd[1]
	_boredom_fill   = bd[2]
	boredom_hbox.add_child(bd[3])

	_boredom_rate_lbl = Label.new()
	_boredom_rate_lbl.text = "+0.00/tick"
	_boredom_rate_lbl.add_theme_font_override("font", _font_exo2_regular)
	_boredom_rate_lbl.add_theme_font_size_override("font_size", 12)
	_boredom_rate_lbl.custom_minimum_size.x = 90
	boredom_hbox.add_child(_boredom_rate_lbl)

	hbox.add_child(VSeparator.new())

	# Energy section
	var energy_hbox := HBoxContainer.new()
	energy_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	energy_hbox.add_theme_constant_override("separation", 6)
	hbox.add_child(energy_hbox)

	var en_lbl := Label.new()
	en_lbl.text = "Energy"
	en_lbl.add_theme_font_override("font", _font_exo2_semibold)
	en_lbl.add_theme_font_size_override("font_size", 13)
	energy_hbox.add_child(en_lbl)

	var en := _make_status_bar_bar(Color(0.082, 0.396, 0.753))  # #1565C0
	_energy_bar     = en[0]
	_energy_bar_lbl = en[1]
	_energy_fill    = en[2]
	energy_hbox.add_child(en[3])

	_energy_rate_lbl = Label.new()
	_energy_rate_lbl.text = "+0/tick"
	_energy_rate_lbl.add_theme_font_override("font", _font_exo2_regular)
	_energy_rate_lbl.add_theme_font_size_override("font_size", 12)
	_energy_rate_lbl.custom_minimum_size.x = 72
	energy_hbox.add_child(_energy_rate_lbl)


func _update_status_bar() -> void:
	if _uptime_label == null:
		return

	var st: GameState = GameManager.state

	# Day counter
	_uptime_label.text = "Day %d" % st.current_day

	# Boredom rolling average (50-tick circular buffer)
	var current_boredom: float = st.amounts.get("boredom", 0.0)
	var delta_boredom: float = current_boredom - _prev_boredom
	_prev_boredom = current_boredom
	_boredom_history.push_back(delta_boredom)
	if _boredom_history.size() > BOREDOM_HISTORY_SIZE:
		_boredom_history.pop_front()

	var boredom_rate: float = 0.0
	if not _boredom_history.is_empty():
		var total: float = 0.0
		for d: float in _boredom_history:
			total += d
		boredom_rate = total / _boredom_history.size()

	const BOREDOM_MAX: float = 100.0
	_boredom_bar.max_value = BOREDOM_MAX
	_boredom_bar.value = current_boredom
	_boredom_bar_lbl.text = "%.1f / %.0f" % [current_boredom, BOREDOM_MAX]

	# Color ramp on boredom bar fill
	var boredom_pct: float = current_boredom / BOREDOM_MAX * 100.0
	if boredom_pct < 25.0:
		_boredom_fill.bg_color = Color(0.180, 0.490, 0.196)   # #2E7D32
	elif boredom_pct < 50.0:
		_boredom_fill.bg_color = Color(0.976, 0.659, 0.145)   # #F9A825
	elif boredom_pct < 75.0:
		_boredom_fill.bg_color = Color(0.902, 0.318, 0.0)     # #E65100
	else:
		_boredom_fill.bg_color = Color(0.718, 0.110, 0.110)   # #B71C1C

	if boredom_rate <= 0.0:
		_boredom_rate_lbl.text = "%.2f/tick" % boredom_rate
		_boredom_rate_lbl.add_theme_color_override("font_color", Color(0.180, 0.490, 0.196))
	else:
		_boredom_rate_lbl.text = "+%.2f/tick" % boredom_rate
		_boredom_rate_lbl.add_theme_color_override("font_color", Color(0.776, 0.157, 0.157))

	# Energy bar
	var energy_amount: float = st.amounts.get("eng", 0.0)
	var energy_cap: float = st.caps.get("eng", 100.0)
	_energy_bar.max_value = energy_cap
	_energy_bar.value = energy_amount
	_energy_bar_lbl.text = "%d / %d" % [int(energy_amount), int(energy_cap)]

	var rates: Dictionary = _compute_theoretical_rates()
	var energy_rate: int = int(rates.get("eng", 0.0))
	if energy_rate >= 0:
		_energy_rate_lbl.text = "+%d/tick" % energy_rate
		_energy_rate_lbl.add_theme_color_override("font_color", Color(0.180, 0.490, 0.196))
	else:
		_energy_rate_lbl.text = "%d/tick" % energy_rate
		_energy_rate_lbl.add_theme_color_override("font_color", Color(0.776, 0.157, 0.157))


# ── Tick handler ───────────────────────────────────────────────────────────────

func _on_tick() -> void:
	_update_resource_display()
	_update_building_cards()
	if _active_mode == "Launch Pads":
		_refresh_launch_pads_panel()
	elif _active_mode == "Commands":
		var cur: Dictionary = GameManager.state.buildings_owned.duplicate()
		if cur != _commands_buildings_snapshot:
			_commands_buildings_snapshot = cur
			for child in _buildings_scroll.get_children():
				child.queue_free()
			_build_commands_panel()
	elif _active_mode == "Research":
		var st: GameState = GameManager.state
		if st.completed_research != _research_completed_snapshot or st.cumulative_science_earned != _research_sci_snapshot:
			_research_completed_snapshot = st.completed_research.duplicate()
			_research_sci_snapshot = st.cumulative_science_earned
			for child in _buildings_scroll.get_children():
				child.queue_free()
			_build_research_panel()
	_update_status_bar()
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
	_launch_pad_cards.clear()
	_launch_history_vbox = null
	_update_nav_highlight(mode)
	match mode:
		"Buildings":   _build_buildings_panel()
		"Commands":
			_commands_buildings_snapshot = GameManager.state.buildings_owned.duplicate()
			_build_commands_panel()
		"Launch Pads": _build_launch_pads_panel()
		"Research":
			_research_completed_snapshot = GameManager.state.completed_research.duplicate()
			_research_sci_snapshot = GameManager.state.cumulative_science_earned
			_build_research_panel()
		"Options":     _build_options_panel()
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
	_launch_pad_cards.clear()
	_launch_history_vbox = null
	_boredom_bar = null
	_boredom_bar_lbl = null
	_boredom_fill = null
	_boredom_rate_lbl = null
	_energy_bar = null
	_energy_bar_lbl = null
	_energy_fill = null
	_energy_rate_lbl = null
	_uptime_label = null
	_setup_status_bar()
	match _active_mode:
		"Buildings":   _build_buildings_panel()
		"Commands":
			_commands_buildings_snapshot = GameManager.state.buildings_owned.duplicate()
			_build_commands_panel()
		"Launch Pads": _build_launch_pads_panel()
		"Research":
			_research_completed_snapshot = GameManager.state.completed_research.duplicate()
			_research_sci_snapshot = GameManager.state.cumulative_science_earned
			_build_research_panel()
		"Options":     _build_options_panel()
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
	_event_panel = null
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


func _make_collapsible_section(parent: VBoxContainer, title: String, start_open: bool = true) -> VBoxContainer:
	var header := Button.new()
	header.text = ("▼  " if start_open else "▶  ") + title
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_font_override("font", _font_rajdhani_bold)
	header.add_theme_font_size_override("font_size", 16)
	parent.add_child(header)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	body.visible = start_open
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
	# Return actual deltas from the most recent tick — reflects real building
	# starvation/cap behaviour without duplicating simulation logic.
	return GameManager.last_deltas


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


func _is_cmd_unlocked(req: Dictionary) -> bool:
	match req.get("type", "none"):
		"none":     return true
		"building": return GameManager.state.buildings_owned.get(req.get("value", ""), 0) > 0
		"research": return req.get("value", "") in GameManager.state.completed_research
	return false


func _build_command_card(cmd: Dictionary) -> PanelContainer:
	var req: Dictionary = cmd.get("requires", {})
	var is_locked: bool = not _is_cmd_unlocked(req)

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
			var rid: String = req.get("value", "")
			for item: Dictionary in GameManager.get_research_data():
				if item.get("id", "") == rid:
					return "Requires: " + item.get("name", rid) + " research"
			return "Requires: " + rid + " research"
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


# ── Launch Pads panel ──────────────────────────────────────────────────────────

func _build_launch_pads_panel() -> void:
	_launch_pad_cards.clear()
	_launch_history_vbox = null

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 10)
	_buildings_scroll.add_child(outer)

	# Earth Demand placeholder (collapsed by default)
	var demand_body := _make_collapsible_section(outer, "Earth Demand", false)
	var demand_lbl := Label.new()
	demand_lbl.text = "Demand tracking coming soon. All resources currently at baseline demand (0.5×)."
	demand_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	demand_lbl.add_theme_font_override("font", _font_exo2_regular)
	demand_lbl.add_theme_font_size_override("font_size", 13)
	demand_lbl.add_theme_color_override("font_color", _p("text_muted"))
	demand_body.add_child(demand_lbl)
	var demand_ph := PanelContainer.new()
	demand_ph.custom_minimum_size = Vector2(0, 60)
	var demand_ph_style := StyleBoxFlat.new()
	demand_ph_style.bg_color = Color(0.12, 0.12, 0.18) if GameSettings.is_dark_mode else Color(0.88, 0.88, 0.92)
	demand_ph.add_theme_stylebox_override("panel", demand_ph_style)
	var demand_ph_lbl := Label.new()
	demand_ph_lbl.text = "[ Demand graph placeholder ]"
	demand_ph_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	demand_ph_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	demand_ph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	demand_ph_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	demand_ph_lbl.add_theme_color_override("font_color", _p("text_dim"))
	demand_ph_lbl.add_theme_font_size_override("font_size", 12)
	demand_ph.add_child(demand_ph_lbl)
	demand_body.add_child(demand_ph)

	# Loading Priority (collapsed by default)
	var priority_body := _make_collapsible_section(outer, "Loading Priority", false)
	_build_loading_priority_list(priority_body)

	# Pad cards or empty message
	var st: GameState = GameManager.state
	if st.pads.is_empty():
		var no_pads_lbl := Label.new()
		no_pads_lbl.text = "No Launch Pads built. Purchase a Launch Pad from the Buildings panel to begin shipping resources to Earth."
		no_pads_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		no_pads_lbl.add_theme_font_override("font", _font_exo2_regular)
		no_pads_lbl.add_theme_font_size_override("font_size", 14)
		no_pads_lbl.add_theme_color_override("font_color", _p("text_muted"))
		outer.add_child(no_pads_lbl)
	else:
		for i in range(st.pads.size()):
			var card := LaunchPadCard.new()
			card.setup(i, _font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold)
			outer.add_child(card)
			_launch_pad_cards.append(card)
		_refresh_pad_cards()

	# Recent Launches
	outer.add_child(HSeparator.new())
	var history_hdr := Label.new()
	history_hdr.text = "Recent Launches"
	history_hdr.add_theme_font_override("font", _font_rajdhani_bold)
	history_hdr.add_theme_font_size_override("font_size", 16)
	outer.add_child(history_hdr)

	_launch_history_vbox = VBoxContainer.new()
	_launch_history_vbox.add_theme_constant_override("separation", 4)
	outer.add_child(_launch_history_vbox)
	_refresh_launch_history()


func _refresh_launch_pads_panel() -> void:
	var st: GameState = GameManager.state
	# If pad count changed, rebuild entirely
	if st.pads.size() != _launch_pad_cards.size():
		for child in _buildings_scroll.get_children():
			child.queue_free()
		_launch_pad_cards.clear()
		_launch_history_vbox = null
		_build_launch_pads_panel()
		return
	_refresh_pad_cards()
	_refresh_launch_history()


func _refresh_pad_cards() -> void:
	var st: GameState = GameManager.state
	var active_count: int = st.buildings_active.get("launch_pad", st.buildings_owned.get("launch_pad", 0))
	for i in range(_launch_pad_cards.size()):
		if i >= st.pads.size():
			break
		_launch_pad_cards[i].refresh(st.pads[i], i < active_count)


func _refresh_launch_history() -> void:
	if _launch_history_vbox == null or not is_instance_valid(_launch_history_vbox):
		return
	for child in _launch_history_vbox.get_children():
		child.queue_free()
	var st: GameState = GameManager.state
	if st.launch_history.is_empty():
		var lbl := Label.new()
		lbl.text = "No launches yet."
		lbl.add_theme_font_override("font", _font_exo2_regular)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", _p("text_muted"))
		_launch_history_vbox.add_child(lbl)
		return
	for record: GameState.LaunchRecord in st.launch_history:
		var res_name: String = RESOURCE_META.get(record.resource_type, [record.resource_type.capitalize()])[0]
		var lbl := Label.new()
		lbl.text = "Day %d: %s × %d → %d credits" % [record.tick, res_name, int(record.quantity), int(record.credits_earned)]
		lbl.add_theme_font_override("font", _font_exo2_regular)
		lbl.add_theme_font_size_override("font_size", 13)
		_launch_history_vbox.add_child(lbl)


func _build_loading_priority_list(parent: VBoxContainer) -> void:
	var st: GameState = GameManager.state
	parent.add_theme_constant_override("separation", 4)
	for i in range(st.loading_priority.size()):
		var res: String = st.loading_priority[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		parent.add_child(row)

		var idx: int = i  # capture for lambdas

		# Stacked ▲/▼ arrows on the left
		var arrow_vbox := VBoxContainer.new()
		arrow_vbox.add_theme_constant_override("separation", 0)
		arrow_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(arrow_vbox)

		var up_btn := Button.new()
		up_btn.text = "▲"
		up_btn.flat = true
		up_btn.custom_minimum_size = Vector2(22, 14)
		up_btn.add_theme_font_size_override("font_size", 9)
		up_btn.pressed.connect(func():
			if idx == 0:
				return
			var prio: Array = GameManager.state.loading_priority.duplicate()
			var tmp: String = prio[idx]
			prio[idx] = prio[idx - 1]
			prio[idx - 1] = tmp
			GameManager.set_loading_priority(prio)
			for child in parent.get_children():
				child.queue_free()
			_build_loading_priority_list(parent)
		)
		arrow_vbox.add_child(up_btn)

		var down_btn := Button.new()
		down_btn.text = "▼"
		down_btn.flat = true
		down_btn.custom_minimum_size = Vector2(22, 14)
		down_btn.add_theme_font_size_override("font_size", 9)
		down_btn.pressed.connect(func():
			if idx == GameManager.state.loading_priority.size() - 1:
				return
			var prio: Array = GameManager.state.loading_priority.duplicate()
			var tmp: String = prio[idx]
			prio[idx] = prio[idx + 1]
			prio[idx + 1] = tmp
			GameManager.set_loading_priority(prio)
			for child in parent.get_children():
				child.queue_free()
			_build_loading_priority_list(parent)
		)
		arrow_vbox.add_child(down_btn)

		var icon := ColorRect.new()
		icon.color = RESOURCE_META.get(res, [res, Color.WHITE])[1]
		icon.custom_minimum_size = Vector2(14, 14)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)

		var name_lbl := Label.new()
		name_lbl.text = RESOURCE_META.get(res, [res.capitalize()])[0]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_override("font", _font_exo2_regular)
		name_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(name_lbl)


# ── Research panel ─────────────────────────────────────────────────────────────

func _build_research_panel() -> void:
	var research_data: Array = GameManager.get_research_data()
	var st: GameState = GameManager.state

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 6)
	_buildings_scroll.add_child(outer)

	if research_data.is_empty():
		var lbl := Label.new()
		lbl.text = "No research data loaded."
		outer.add_child(lbl)
		return

	# Group by category preserving JSON order
	var category_order: Array = []
	var by_category: Dictionary = {}
	var category_min_cost: Dictionary = {}
	for item: Dictionary in research_data:
		var cat: String = item.get("category", "Other")
		if not by_category.has(cat):
			by_category[cat] = []
			category_min_cost[cat] = INF
			category_order.append(cat)
		by_category[cat].append(item)
		category_min_cost[cat] = minf(category_min_cost[cat], float(item.get("cost", 0)))

	var has_visible: bool = false
	for cat: String in category_order:
		var threshold: float = category_min_cost[cat] * 0.5
		if st.cumulative_science_earned < threshold:
			continue
		has_visible = true
		_add_research_category_section(outer, cat, by_category[cat])

	if not has_visible:
		var lbl := Label.new()
		lbl.text = "Build a Research Lab and earn science to unlock research categories."
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_override("font", _font_exo2_regular)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", _p("text_muted"))
		outer.add_child(lbl)


func _add_research_category_section(parent: VBoxContainer, category: String, items: Array) -> void:
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
		header.text = ("▼  " if flow.visible else "▶  ") + category.to_upper()
		_apply_category_header_style(header)
	)

	for item: Dictionary in items:
		flow.add_child(_build_research_card(item))


func _build_research_card(item: Dictionary) -> PanelContainer:
	var is_completed: bool = item.get("id", "") in GameManager.state.completed_research
	var cost: int = int(item.get("cost", 0))
	var can_afford: bool = GameManager.state.amounts.get("sci", 0.0) >= cost

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

	# Header row: name + badge/button
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(header_hbox)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_override("font", _font_rajdhani_bold)
	name_lbl.add_theme_font_size_override("font_size", 20)
	if is_completed:
		name_lbl.add_theme_color_override("font_color", _p("text_muted"))
	header_hbox.add_child(name_lbl)

	if is_completed:
		var badge := Label.new()
		badge.text = "✓"
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_override("font", _font_exo2_semibold)
		badge.add_theme_font_size_override("font_size", 16)
		badge.add_theme_color_override("font_color", _p("text_positive"))
		header_hbox.add_child(badge)
	else:
		var btn := Button.new()
		btn.text = "Research"
		btn.disabled = not can_afford
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_override("font", _font_exo2_semibold)
		btn.add_theme_font_size_override("font_size", 14)
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
		var item_id: String = item.get("id", "")
		btn.pressed.connect(func(): _on_research_purchased(item_id))
		header_hbox.add_child(btn)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = item.get("description", "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_override("font", _font_exo2_regular)
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", _p("text_muted"))
	vbox.add_child(desc_lbl)

	# Cost line (only when not completed)
	if not is_completed:
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
		cost_lbl.add_theme_font_override("font", _font_exo2_regular)
		cost_lbl.add_theme_font_size_override("font_size", 13)
		cost_lbl.add_theme_color_override("font_color", _p("text_positive") if can_afford else _p("text_negative"))
		cost_row.add_child(cost_lbl)

	return panel


func _on_research_purchased(item_id: String) -> void:
	GameManager.purchase_research(item_id)


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

	outer.add_child(HSeparator.new())

	var debug_lbl := Label.new()
	debug_lbl.text = "Debug"
	debug_lbl.add_theme_font_override("font", _font_rajdhani_bold)
	debug_lbl.add_theme_font_size_override("font_size", 20)
	outer.add_child(debug_lbl)

	outer.add_child(HSeparator.new())

	var debug_desc := Label.new()
	debug_desc.text = "Ensures at least 20 solar panels, 5 storage depots, 3 launch pads, and 200 land, then fills all resources to cap."
	debug_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_desc.add_theme_font_override("font", _font_exo2_regular)
	debug_desc.add_theme_font_size_override("font_size", 13)
	debug_desc.add_theme_color_override("font_color", _p("text_muted"))
	outer.add_child(debug_desc)

	var debug_btn := Button.new()
	debug_btn.text = "Fill Resources"
	debug_btn.focus_mode = Control.FOCUS_NONE
	debug_btn.add_theme_font_override("font", _font_exo2_semibold)
	debug_btn.add_theme_font_size_override("font_size", 14)
	if not GameSettings.is_dark_mode:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.298, 0.686, 0.314)
		s.corner_radius_top_left     = 4
		s.corner_radius_top_right    = 4
		s.corner_radius_bottom_left  = 4
		s.corner_radius_bottom_right = 4
		debug_btn.add_theme_stylebox_override("normal", s)
		debug_btn.add_theme_color_override("font_color", Color.WHITE)
	debug_btn.pressed.connect(func():
		GameManager.debug_boost()
		debug_btn.text = "✓ Done"
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(debug_btn):
				debug_btn.text = "Fill Resources"
		)
	)
	outer.add_child(debug_btn)


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
	_build_event_panel(_right_vbox)


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
	scroll.custom_minimum_size = Vector2(0, 325)
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


func _build_event_panel(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var ep := load("res://scenes/ui/EventPanel.tscn").instantiate() as EventPanel
	ep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(ep)
	ep.setup(_font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold)
	ep.event_row_clicked.connect(func(eid: String) -> void: _event_modal.open(eid))
	_event_panel = ep


func _build_event_modal() -> void:
	if _event_modal != null:
		return
	_event_modal = load("res://scenes/ui/EventModal.tscn").instantiate() as EventModal
	add_child(_event_modal)
	_event_modal.setup(_font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold)


func _on_event_triggered(event_id: String) -> void:
	if GameManager.event_manager.is_event_first_time(event_id, GameManager.state):
		_event_modal.open(event_id)


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
