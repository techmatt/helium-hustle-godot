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

const COLOR_POSITIVE := Color(0.498, 0.749, 0.498)  # #7FBF7F
const COLOR_NEGATIVE := Color(0.749, 0.498, 0.498)  # #BF7F7F
const COLOR_ZERO     := Color(0.502, 0.502, 0.502)  # #808080

@onready var _center_header: Label = $MainVBox/ContentHBox/CenterPanel/CenterMargin/CenterVBox/LblBuildingsHeader
@onready var _buildings_scroll: ScrollContainer = $MainVBox/ContentHBox/CenterPanel/CenterMargin/CenterVBox/BuildingsScroll
@onready var _programs_header: Label = $MainVBox/ContentHBox/RightPanel/RightMargin/RightVBox/LblProgramsHeader
@onready var _events_header: Label = $MainVBox/ContentHBox/RightPanel/RightMargin/RightVBox/LblEventsHeader
@onready var _status_label: Label = $MainVBox/StatusBar/StatusMargin/LblStatus

# {short_name: {val: Label, rate: Label}}
var _resource_labels: Dictionary = {}
# {short_name: {count_lbl: Label, cost_lbl: Label, buy_btn: Button}}
var _building_cards: Dictionary = {}
# cached building defs for formatting
var _buildings_data: Array = []

var _font_rajdhani_bold: FontFile
var _font_exo2_regular: FontFile
var _font_exo2_semibold: FontFile


func _ready() -> void:
	_setup_theme()
	_setup_panel_headers()
	_build_left_sidebar()
	_connect_program_slots()
	GameManager.tick_completed.connect(_on_tick)
	# Initialize center panel with Buildings mode
	_build_buildings_panel()
	_update_resource_display()


# ── Theme & typography ─────────────────────────────────────────────────────────

func _load_fonts() -> void:
	_font_rajdhani_bold = load("res://assets/fonts/Rajdhani-Bold.ttf")
	_font_exo2_regular  = load("res://assets/fonts/Exo2-Regular.ttf")
	_font_exo2_semibold = load("res://assets/fonts/Exo2-SemiBold.ttf")


func _setup_theme() -> void:
	_load_fonts()
	var new_theme := Theme.new()
	new_theme.default_font = _font_exo2_regular
	new_theme.default_font_size = 13
	self.theme = new_theme


func _setup_panel_headers() -> void:
	_center_header.add_theme_font_override("font", _font_rajdhani_bold)
	_center_header.add_theme_font_size_override("font_size", 22)
	_programs_header.add_theme_font_override("font", _font_rajdhani_bold)
	_programs_header.add_theme_font_size_override("font_size", 18)
	_events_header.add_theme_font_override("font", _font_rajdhani_bold)
	_events_header.add_theme_font_size_override("font_size", 18)


# ── Tick handler ───────────────────────────────────────────────────────────────

func _on_tick() -> void:
	_update_resource_display()
	_update_building_cards()
	_status_label.text = "System uptime: %d days" % GameManager.state.current_day


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
		grid.add_child(_make_nav_button(item[0], item[1]))


func _switch_mode(mode: String) -> void:
	print("Mode: " + mode)
	_center_header.text = mode
	for child in _buildings_scroll.get_children():
		child.queue_free()
	_building_cards.clear()
	if mode == "Buildings":
		_build_buildings_panel()
	else:
		var lbl := Label.new()
		lbl.text = mode + " — coming soon"
		_buildings_scroll.add_child(lbl)


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
	for speed: String in SPEEDS:
		var btn := Button.new()
		btn.text = speed
		btn.toggle_mode = true
		btn.button_group = grp
		if speed == "1x":
			btn.button_pressed = true
		btn.add_theme_font_override("font", _font_exo2_semibold)
		btn.add_theme_font_size_override("font_size", 13)
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


func _update_resource_display() -> void:
	var st: GameState = GameManager.state
	var deltas: Dictionary = GameManager.last_deltas
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
			lbls.rate.add_theme_color_override("font_color", COLOR_ZERO)
		elif delta > 0.0:
			lbls.rate.text = "+%.1f/s" % delta
			lbls.rate.add_theme_color_override("font_color", COLOR_POSITIVE)
		else:
			lbls.rate.text = "%.1f/s" % delta
			lbls.rate.add_theme_color_override("font_color", COLOR_NEGATIVE)


# ── Buildings panel ────────────────────────────────────────────────────────────

func _build_buildings_panel() -> void:
	for child in _buildings_scroll.get_children():
		child.queue_free()
	_building_cards.clear()
	_buildings_data = GameManager.get_buildings_data()

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	_buildings_scroll.add_child(vbox)

	for bdef in _buildings_data:
		_add_building_card(vbox, bdef)


func _add_building_card(parent: VBoxContainer, bdef: Dictionary) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	card.add_child(margin)

	var cvbox := VBoxContainer.new()
	cvbox.add_theme_constant_override("separation", 4)
	margin.add_child(cvbox)

	# Header row: name (expands) | owned count | buy button
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	cvbox.add_child(header_row)

	var name_lbl := Label.new()
	name_lbl.text = bdef.name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_override("font", _font_rajdhani_bold)
	name_lbl.add_theme_font_size_override("font_size", 17)
	header_row.add_child(name_lbl)

	var count_lbl := Label.new()
	count_lbl.text = "x%d" % GameManager.state.buildings_owned.get(bdef.short_name, 0)
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_override("font", _font_exo2_semibold)
	count_lbl.add_theme_font_size_override("font_size", 14)
	header_row.add_child(count_lbl)

	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.disabled = not GameManager.can_afford_building(bdef.short_name)
	buy_btn.add_theme_font_override("font", _font_exo2_semibold)
	buy_btn.add_theme_font_size_override("font_size", 14)
	var sn: String = bdef.short_name
	buy_btn.pressed.connect(func(): GameManager.buy_building(sn))
	header_row.add_child(buy_btn)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = bdef.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_override("font", _font_exo2_regular)
	desc_lbl.add_theme_font_size_override("font_size", 13)
	cvbox.add_child(desc_lbl)

	# Production (green) and upkeep (red) as separate labeled lines
	var prod_text := _format_prod(bdef)
	if prod_text != "":
		var prod_lbl := Label.new()
		prod_lbl.text = prod_text
		prod_lbl.add_theme_font_override("font", _font_exo2_semibold)
		prod_lbl.add_theme_font_size_override("font_size", 13)
		prod_lbl.add_theme_color_override("font_color", COLOR_POSITIVE)
		cvbox.add_child(prod_lbl)

	var upkeep_text := _format_upkeep(bdef)
	if upkeep_text != "":
		var upkeep_lbl := Label.new()
		upkeep_lbl.text = upkeep_text
		upkeep_lbl.add_theme_font_override("font", _font_exo2_semibold)
		upkeep_lbl.add_theme_font_size_override("font_size", 13)
		upkeep_lbl.add_theme_color_override("font_color", COLOR_NEGATIVE)
		cvbox.add_child(upkeep_lbl)

	# Cost (updated each tick)
	var cost_lbl := Label.new()
	cost_lbl.text = _format_costs(bdef.short_name, bdef.land)
	cost_lbl.add_theme_font_override("font", _font_exo2_regular)
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cvbox.add_child(cost_lbl)

	_building_cards[bdef.short_name] = {
		"count_lbl": count_lbl,
		"cost_lbl": cost_lbl,
		"buy_btn": buy_btn,
	}


func _update_building_cards() -> void:
	for sn in _building_cards:
		var refs: Dictionary = _building_cards[sn]
		refs.count_lbl.text = "x%d" % GameManager.state.buildings_owned.get(sn, 0)
		refs.buy_btn.disabled = not GameManager.can_afford_building(sn)
		var bdef: Variant = _get_bdef(sn)
		if bdef != null:
			refs.cost_lbl.text = _format_costs(sn, bdef.land)


func _format_prod(bdef: Dictionary) -> String:
	var parts: Array = []
	for res in bdef.production:
		parts.append("+%.1f %s" % [float(bdef.production[res]), res])
	return "  ".join(parts)


func _format_upkeep(bdef: Dictionary) -> String:
	var parts: Array = []
	for res in bdef.upkeep:
		parts.append("-%.1f %s" % [float(bdef.upkeep[res]), res])
	return "  ".join(parts)


func _format_costs(short_name: String, land_cost: int) -> String:
	var scaled: Dictionary = GameManager.get_scaled_costs(short_name)
	var parts: Array = []
	for res in scaled:
		parts.append("%.0f %s" % [scaled[res], res])
	parts.append("%d land" % land_cost)
	return "Cost: " + "  +  ".join(parts)


func _get_bdef(short_name: String) -> Variant:
	for bdef in _buildings_data:
		if bdef.short_name == short_name:
			return bdef
	return null


# ── Right panel ────────────────────────────────────────────────────────────────

func _connect_program_slots() -> void:
	var slots := $MainVBox/ContentHBox/RightPanel/RightMargin/RightVBox/ProgramSlots
	for btn: Button in slots.get_children():
		btn.add_theme_font_override("font", _font_exo2_semibold)
		btn.pressed.connect(func(): print("Program slot: " + btn.text))
