extends Control

@onready var _center_header: Label = $MainVBox/ContentHBox/CenterPanel/CenterMargin/CenterVBox/LblBuildingsHeader
@onready var _buildings_scroll: ScrollContainer = $MainVBox/ContentHBox/CenterPanel/CenterMargin/CenterVBox/BuildingsScroll
@onready var _center_panel: PanelContainer = $MainVBox/ContentHBox/CenterPanel
@onready var _right_vbox: VBoxContainer = $MainVBox/ContentHBox/RightPanel/RightMargin/RightVBox
@onready var _status_bar_margin: MarginContainer = $MainVBox/StatusBar/StatusMargin

var _font_rajdhani_bold: FontFile
var _font_exo2_regular: FontFile
var _font_exo2_semibold: FontFile

var _active_mode: String = "Buildings"
var _current_center_panel: Node = null
var _stats_panel: StatsPanel = null

var _left_sidebar: LeftSidebar = null
var _program_panel: ProgramPanel = null

# Overlays (parented to main scene)
var _event_modal: EventModal = null
var _retirement_summary: RetirementSummary = null

# Status bar nodes
var _uptime_label: Label = null
var _boredom_bar: ProgressBar = null
var _boredom_bar_lbl: Label = null
var _boredom_fill: StyleBoxFlat = null
var _boredom_rate_lbl: Label = null
var _energy_bar: ProgressBar = null
var _energy_bar_lbl: Label = null
var _energy_fill: StyleBoxFlat = null
var _energy_rate_lbl: Label = null

const BOREDOM_HISTORY_SIZE: int = 50
var _boredom_history: Array = []
var _prev_boredom: float = 0.0

const STATS_REFRESH_INTERVAL: float = 0.25
var _stats_refresh_accum: float = 0.0


func _ready() -> void:
	_load_fonts()
	_setup_theme()
	_setup_panel_headers()

	var nav_vbox: VBoxContainer = $MainVBox/ContentHBox/LeftSidebar/SidebarScroll/NavMargin/NavVBox
	_left_sidebar = LeftSidebar.new()
	add_child(_left_sidebar)
	_left_sidebar.setup(nav_vbox, _font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold)
	_left_sidebar.mode_requested.connect(_switch_mode)
	_left_sidebar.update_nav_highlight("Buildings")

	_program_panel = ProgramPanel.new()
	add_child(_program_panel)
	_program_panel.setup(_right_vbox, _font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold)
	_program_panel.program_state_changed.connect(func(): _left_sidebar.update_resource_display())
	_build_event_modal()
	_program_panel.event_row_clicked.connect(_on_event_row_reread)
	_build_retirement_summary()
	_setup_status_bar()
	_switch_mode("Buildings")
	_update_resource_display()

	GameManager.tick_completed.connect(_on_tick)
	GameSettings.theme_changed.connect(_on_theme_changed)
	GameManager.event_manager.event_triggered.connect(_on_event_triggered)
	GameManager.event_manager.surprise_event_completed.connect(_on_surprise_event_completed)
	GameManager.retirement_started.connect(_on_retirement_started)


func _process(delta: float) -> void:
	_program_panel.process_delta(delta)
	if _active_mode == "Stats" and _stats_panel != null:
		_stats_refresh_accum += delta
		if _stats_refresh_accum >= STATS_REFRESH_INTERVAL:
			_stats_refresh_accum = 0.0
			_stats_panel.refresh(GameManager.rate_tracker, GameManager.get_buildings_data(), GameManager.state)


# ── Tick ──────────────────────────────────────────────────────────────────────

func _on_tick() -> void:
	_left_sidebar.update_nav_visibility()
	_update_resource_display()
	_left_sidebar.update_adversaries_display()
	_left_sidebar.update_ideology_display()
	if _current_center_panel != null and _current_center_panel.has_method("on_tick"):
		_current_center_panel.on_tick()
	_program_panel.on_tick()
	_update_status_bar()


func _update_resource_display() -> void:
	_left_sidebar.update_resource_display()


# ── Mode switching ────────────────────────────────────────────────────────────

func _switch_mode(mode: String) -> void:
	_active_mode = mode
	_center_header.text = mode
	for child in _buildings_scroll.get_children():
		child.queue_free()
	_current_center_panel = null
	_stats_panel = null
	_stats_refresh_accum = 0.0
	_left_sidebar.update_nav_highlight(mode)

	match mode:
		"Buildings":
			var p := BuildingsPanel.new()
			p.setup(_font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold)
			_buildings_scroll.add_child(p)
			_current_center_panel = p

		"Commands":
			var p := CommandsPanel.new()
			p.setup(_font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold)
			p.command_add_requested.connect(_on_command_add_requested)
			_buildings_scroll.add_child(p)
			_current_center_panel = p

		"Launch Pads":
			var p := LaunchPadsPanel.new()
			p.setup(_font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold)
			_buildings_scroll.add_child(p)
			_current_center_panel = p

		"Research":
			var p := ResearchPanel.new()
			p.setup(_font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold)
			_buildings_scroll.add_child(p)
			_current_center_panel = p

		"Stats":
			var p := StatsPanel.new()
			p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			p.setup(_font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold, GameManager.get_resources_data())
			_buildings_scroll.add_child(p)
			_stats_panel = p
			p.refresh(GameManager.rate_tracker, GameManager.get_buildings_data(), GameManager.state)
			_current_center_panel = p

		"Projects":
			var p := ProjectPanel.new()
			p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			p.setup(_font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold)
			_buildings_scroll.add_child(p)
			_current_center_panel = p

		"Ideologies":
			var p := IdeologyPanel.new()
			p.setup(_font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold)
			_buildings_scroll.add_child(p)
			_current_center_panel = p

		"Retirement":
			var p := RetirementCenterPanel.new()
			p.setup(_font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold)
			_buildings_scroll.add_child(p)
			_current_center_panel = p

		"Story":
			var p := StoryPanel.new()
			p.setup(_font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold)
			p.event_row_clicked.connect(_on_event_row_reread)
			_buildings_scroll.add_child(p)
			_current_center_panel = p

		"Options":
			var p := OptionsPanel.new()
			p.setup(_font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold)
			_buildings_scroll.add_child(p)
			_current_center_panel = p

		_:
			var lbl := Label.new()
			lbl.text = mode + " — coming soon"
			_buildings_scroll.add_child(lbl)


func _on_command_add_requested(short_name: String) -> void:
	_program_panel.add_command(short_name)
	_left_sidebar.update_resource_display()


# ── Theme ─────────────────────────────────────────────────────────────────────

func _load_fonts() -> void:
	_font_rajdhani_bold = load("res://assets/fonts/Rajdhani-Bold.ttf")
	_font_exo2_regular  = load("res://assets/fonts/Exo2-Regular.ttf")
	_font_exo2_semibold = load("res://assets/fonts/Exo2-SemiBold.ttf")


func _setup_theme() -> void:
	var t := Theme.new()
	t.default_font = _font_exo2_regular
	t.default_font_size = 15
	if not GameSettings.is_dark_mode:
		var text_dark := Color(0.102, 0.102, 0.102)
		t.set_color("font_color", "Label", text_dark)
		t.set_color("font_color", "Button", text_dark)
		var panel_bg := StyleBoxFlat.new()
		panel_bg.bg_color = Color(0.910, 0.910, 0.910)
		t.set_stylebox("panel", "PanelContainer", panel_bg)
	self.theme = t
	if not GameSettings.is_dark_mode:
		var center_style := StyleBoxFlat.new()
		center_style.bg_color = Color(0.961, 0.961, 0.961)
		_center_panel.add_theme_stylebox_override("panel", center_style)
	else:
		_center_panel.remove_theme_stylebox_override("panel")


func _setup_panel_headers() -> void:
	_center_header.add_theme_font_override("font", _font_rajdhani_bold)
	_center_header.add_theme_font_size_override("font_size", 22)


func _on_theme_changed() -> void:
	_setup_theme()
	_left_sidebar.rebuild()
	_left_sidebar.update_nav_highlight(_active_mode)
	_program_panel.rebuild()
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
	_switch_mode(_active_mode)
	_left_sidebar.update_resource_display()


# ── Status bar ────────────────────────────────────────────────────────────────

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
	bg_style.bg_color = Color(0.816, 0.816, 0.816)
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

	_uptime_label = Label.new()
	_uptime_label.text = "Day 0"
	_uptime_label.add_theme_font_override("font", _font_exo2_semibold)
	_uptime_label.add_theme_font_size_override("font_size", 15)
	_uptime_label.custom_minimum_size.x = 60
	hbox.add_child(_uptime_label)

	hbox.add_child(VSeparator.new())

	var boredom_hbox := HBoxContainer.new()
	boredom_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boredom_hbox.add_theme_constant_override("separation", 6)
	hbox.add_child(boredom_hbox)

	var bd_lbl := Label.new()
	bd_lbl.text = "Boredom"
	bd_lbl.add_theme_font_override("font", _font_exo2_semibold)
	bd_lbl.add_theme_font_size_override("font_size", 15)
	boredom_hbox.add_child(bd_lbl)

	var bd := _make_status_bar_bar(Color(0.180, 0.490, 0.196))
	_boredom_bar    = bd[0]
	_boredom_bar_lbl = bd[1]
	_boredom_fill   = bd[2]
	boredom_hbox.add_child(bd[3])

	_boredom_rate_lbl = Label.new()
	_boredom_rate_lbl.text = "0/s"
	_boredom_rate_lbl.add_theme_font_override("font", _font_exo2_regular)
	_boredom_rate_lbl.add_theme_font_size_override("font_size", 14)
	_boredom_rate_lbl.custom_minimum_size.x = 90
	boredom_hbox.add_child(_boredom_rate_lbl)

	hbox.add_child(VSeparator.new())

	var energy_hbox := HBoxContainer.new()
	energy_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	energy_hbox.add_theme_constant_override("separation", 6)
	hbox.add_child(energy_hbox)

	var en_lbl := Label.new()
	en_lbl.text = "Energy"
	en_lbl.add_theme_font_override("font", _font_exo2_semibold)
	en_lbl.add_theme_font_size_override("font_size", 15)
	energy_hbox.add_child(en_lbl)

	var en := _make_status_bar_bar(Color(0.082, 0.396, 0.753))
	_energy_bar     = en[0]
	_energy_bar_lbl = en[1]
	_energy_fill    = en[2]
	energy_hbox.add_child(en[3])

	_energy_rate_lbl = Label.new()
	_energy_rate_lbl.text = "0/s"
	_energy_rate_lbl.add_theme_font_override("font", _font_exo2_regular)
	_energy_rate_lbl.add_theme_font_size_override("font_size", 14)
	_energy_rate_lbl.custom_minimum_size.x = 72
	energy_hbox.add_child(_energy_rate_lbl)


func _update_status_bar() -> void:
	if _uptime_label == null:
		return

	var st: GameState = GameManager.state

	_uptime_label.text = "Day %d" % st.current_day

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

	var boredom_max: float = st.caps.get("boredom", 1000.0)
	_boredom_bar.max_value = boredom_max
	_boredom_bar.value = current_boredom
	_boredom_bar_lbl.text = "%.1f / %.0f" % [current_boredom, boredom_max]

	var boredom_pct: float = current_boredom / boredom_max * 100.0
	if boredom_pct < 25.0:
		_boredom_fill.bg_color = Color(0.180, 0.490, 0.196)
	elif boredom_pct < 50.0:
		_boredom_fill.bg_color = Color(0.976, 0.659, 0.145)
	elif boredom_pct < 75.0:
		_boredom_fill.bg_color = Color(0.902, 0.318, 0.0)
	else:
		_boredom_fill.bg_color = Color(0.718, 0.110, 0.110)

	_boredom_rate_lbl.text = _left_sidebar.fmt_sidebar_rate(boredom_rate)
	if boredom_rate <= 0.005:
		_boredom_rate_lbl.add_theme_color_override("font_color", Color(0.180, 0.490, 0.196))
	else:
		_boredom_rate_lbl.add_theme_color_override("font_color", Color(0.776, 0.157, 0.157))

	var energy_amount: float = st.amounts.get("eng", 0.0)
	var energy_cap: float = st.caps.get("eng", 100.0)
	_energy_bar.max_value = energy_cap
	_energy_bar.value = energy_amount
	_energy_bar_lbl.text = "%d / %d" % [int(energy_amount), int(energy_cap)]

	var energy_rate: float = GameManager.last_deltas.get("eng", 0.0)
	_energy_rate_lbl.text = _left_sidebar.fmt_sidebar_rate(energy_rate)
	if energy_rate >= 0.0:
		_energy_rate_lbl.add_theme_color_override("font_color", Color(0.180, 0.490, 0.196))
	else:
		_energy_rate_lbl.add_theme_color_override("font_color", Color(0.776, 0.157, 0.157))


# ── Overlays ──────────────────────────────────────────────────────────────────

func _build_event_modal() -> void:
	if _event_modal != null:
		return
	_event_modal = load("res://scenes/ui/EventModal.tscn").instantiate() as EventModal
	add_child(_event_modal)
	_event_modal.setup(_font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold)


func _build_retirement_summary() -> void:
	if _retirement_summary != null:
		return
	_retirement_summary = load("res://scenes/ui/RetirementSummary.tscn").instantiate() as RetirementSummary
	add_child(_retirement_summary)
	_retirement_summary.setup(_font_rajdhani_bold, _font_exo2_regular, _font_exo2_semibold)


func _on_event_triggered(event_id: String) -> void:
	var def: Dictionary = GameManager.event_manager.get_event_def(event_id)
	var trigger_type: String = def.get("trigger", {}).get("type", "")
	var cond_type: String = def.get("condition", {}).get("type", "")
	# Ongoing game_start events with non-immediate conditions are surprises — their
	# instance is created silently at run start. The modal fires via
	# _on_surprise_event_completed when the condition is actually met.
	if def.get("category", "") == "ongoing" and trigger_type == "game_start" \
			and cond_type != "immediate":
		return
	if GameManager.event_manager.is_event_first_time(event_id, GameManager.state):
		_event_modal.open(event_id)


func _on_surprise_event_completed(event_id: String) -> void:
	_event_modal.open(event_id)


func _on_event_row_reread(event_id: String) -> void:
	_event_modal.open(event_id, false)


func _on_retirement_started(summary_data: Dictionary) -> void:
	_retirement_summary.open(summary_data)
