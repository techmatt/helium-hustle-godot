class_name BuildingCard
extends PanelContainer

const COLORS_DARK: Dictionary = {
	"positive":    Color(0.498, 0.749, 0.498),
	"negative":    Color(0.749, 0.498, 0.498),
	"can_afford":  Color(0.20, 0.40, 0.20, 0.35),
	"cant_afford": Color(0.40, 0.20, 0.20, 0.35),
	"desc":        Color(0.70, 0.70, 0.70),
	"count":       Color(0.75, 0.75, 0.75),
}
const COLORS_LIGHT: Dictionary = {
	"positive":    Color(0.08, 0.46, 0.08),
	"negative":    Color(0.58, 0.08, 0.08),
	"can_afford":  Color(0.50, 0.86, 0.50, 0.30),
	"cant_afford": Color(0.86, 0.50, 0.50, 0.30),
	"desc":        Color(0.26, 0.26, 0.30),
	"count":       Color(0.32, 0.32, 0.36),
}

const RESOURCE_COLORS: Dictionary = {
	"eng":     Color(1.00, 0.85, 0.00),
	"reg":     Color(0.60, 0.42, 0.22),
	"ice":     Color(0.70, 0.92, 1.00),
	"he3":     Color(0.50, 0.50, 1.00),
	"cred":    Color(0.20, 0.85, 0.20),
	"land":    Color(0.40, 0.70, 0.30),
	"boredom": Color(0.55, 0.55, 0.55),
	"proc":    Color(0.80, 0.20, 0.80),
	"ti":      Color(0.80, 0.80, 0.80),
	"prop":    Color(0.40, 0.70, 0.95),
	"sci":     Color(0.70, 0.50, 0.90),
	"cir":     Color(0.30, 0.80, 0.70),
}

const RESOURCE_NAMES: Dictionary = {
	"eng":     "Energy",
	"reg":     "Regolith",
	"ice":     "Ice",
	"he3":     "Helium-3",
	"cred":    "Credits",
	"land":    "Land",
	"boredom": "Boredom",
	"proc":    "Processors",
	"ti":      "Titanium",
	"prop":    "Propellant",
	"sci":     "Science",
	"cir":     "Circuits",
}

var _bdef: Dictionary
var _font_rajdhani_bold: FontFile
var _font_exo2_regular: FontFile
var _font_exo2_semibold: FontFile

var _count_lbl: Label
var _bg_style: StyleBoxFlat
var _cost_labels: Dictionary = {}

# Enable/disable controls — shown only when owned > 0
var _controls_hbox: HBoxContainer
var _active_minus: Button
var _active_plus: Button

# Sell controls — shown only when owned > 0
var _sell_row: HBoxContainer
var _sell1_btn: Button
var _sell_all_btn: Button
var _sell_all_pending: bool = false


func _c(key: String) -> Color:
	return COLORS_DARK[key] if GameSettings.is_dark_mode else COLORS_LIGHT[key]


func setup(bdef: Dictionary, font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_bdef = bdef
	_font_rajdhani_bold = font_rb
	_font_exo2_regular  = font_e2r
	_font_exo2_semibold = font_e2s
	_build_ui()


func refresh() -> void:
	var owned: int = GameManager.state.buildings_owned.get(_bdef.short_name, 0)
	var active: int = GameManager.get_building_active(_bdef.short_name)

	if owned == 0:
		_count_lbl.text = "(0)"
	else:
		_count_lbl.text = "(%d/%d)" % [active, owned]

	_controls_hbox.visible = owned > 0 and not _bdef.get("upkeep", {}).is_empty()
	_sell_row.visible = owned > 0

	if owned > 0:
		_active_minus.disabled = (active <= 0)
		_active_plus.disabled  = (active >= owned)

	var can_afford: bool = GameManager.can_afford_building(_bdef.short_name)
	if GameSettings.is_dark_mode:
		_bg_style.bg_color = _c("can_afford") if can_afford else _c("cant_afford")
	else:
		_bg_style.bg_color = Color(0.94, 0.99, 0.94) if can_afford else Color(0.99, 0.94, 0.94)

	var scaled: Dictionary = GameManager.get_scaled_costs(_bdef.short_name)
	var st: GameState = GameManager.state
	for res: String in _cost_labels:
		var lbl: Label = _cost_labels[res]
		var ok_color: Color = Color.WHITE if GameSettings.is_dark_mode else Color(0.08, 0.08, 0.10)
		if res == "land":
			var land_cost: int = _bdef.land
			lbl.text = "%d" % land_cost
			var ok: bool = st.amounts.get("land", 0.0) >= float(land_cost)
			lbl.add_theme_color_override("font_color", ok_color if ok else _c("negative"))
		else:
			var amount: float = scaled.get(res, 0.0)
			lbl.text = "%.0f" % amount
			var ok: bool = st.amounts.get(res, 0.0) >= amount
			lbl.add_theme_color_override("font_color", ok_color if ok else _c("negative"))


# ── Input — click anywhere on card to buy ──────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_attempt_buy()


func _attempt_buy() -> void:
	var sn: String = _bdef.short_name
	if GameManager.can_afford_building(sn):
		GameManager.buy_building(sn)
		# Flash after refresh (buy_building triggers tick_completed → refresh)
		_bg_style.bg_color = Color(0.72, 0.95, 0.72) if GameSettings.is_dark_mode \
			else Color(0.82, 0.97, 0.82)
		get_tree().create_timer(0.3).timeout.connect(func():
			if is_instance_valid(self): refresh()
		)
	else:
		_bg_style.bg_color = Color(0.95, 0.72, 0.72) if GameSettings.is_dark_mode \
			else Color(0.97, 0.84, 0.84)
		get_tree().create_timer(0.3).timeout.connect(func():
			if is_instance_valid(self): refresh()
		)


# ── UI construction ────────────────────────────────────────────────────────────

func _build_ui() -> void:
	custom_minimum_size = Vector2(310, 0)
	size_flags_horizontal = Control.SIZE_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP

	_bg_style = StyleBoxFlat.new()
	_bg_style.corner_radius_top_left     = 4
	_bg_style.corner_radius_top_right    = 4
	_bg_style.corner_radius_bottom_left  = 4
	_bg_style.corner_radius_bottom_right = 4
	if GameSettings.is_dark_mode:
		_bg_style.bg_color = _c("cant_afford")
	else:
		_bg_style.bg_color = Color(0.99, 0.94, 0.94)
		_bg_style.border_width_left   = 1
		_bg_style.border_width_right  = 1
		_bg_style.border_width_top    = 1
		_bg_style.border_width_bottom = 1
		_bg_style.border_color = Color(0.816, 0.816, 0.816)
	add_theme_stylebox_override("panel", _bg_style)

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(vbox)

	_build_header(vbox)
	_build_description(vbox)
	_build_production(vbox)
	_build_upkeep(vbox)
	_build_effects(vbox)
	vbox.add_child(HSeparator.new())
	_build_cost_grid(vbox)
	_build_sell_row(vbox)


func _build_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = _bdef.name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	name_lbl.add_theme_font_override("font", _font_rajdhani_bold)
	name_lbl.add_theme_font_size_override("font_size", 21)
	row.add_child(name_lbl)

	_count_lbl = Label.new()
	_count_lbl.text = "(0)"
	_count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_count_lbl.add_theme_font_override("font", _font_exo2_semibold)
	_count_lbl.add_theme_font_size_override("font_size", 14)
	_count_lbl.add_theme_color_override("font_color", _c("count"))
	row.add_child(_count_lbl)

	# Enable/disable controls — hidden until owned > 0
	_controls_hbox = HBoxContainer.new()
	_controls_hbox.add_theme_constant_override("separation", 2)
	_controls_hbox.visible = false
	row.add_child(_controls_hbox)

	var sn: String = _bdef.short_name

	_active_minus = _make_ctrl_btn("\u2212")
	_active_minus.pressed.connect(func(): GameManager.set_building_active(sn, -1))
	_controls_hbox.add_child(_active_minus)

	_active_plus = _make_ctrl_btn("+")
	_active_plus.pressed.connect(func(): GameManager.set_building_active(sn, 1))
	_controls_hbox.add_child(_active_plus)


func _build_description(parent: VBoxContainer) -> void:
	var lbl := Label.new()
	lbl.text = _bdef.description
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	lbl.add_theme_font_override("font", _font_exo2_regular)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", _c("desc"))
	parent.add_child(lbl)


func _build_production(parent: VBoxContainer) -> void:
	for res: String in _bdef.production:
		var lbl := Label.new()
		lbl.text = "  +%.1f %s/s" % [float(_bdef.production[res]), RESOURCE_NAMES.get(res, res)]
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		lbl.add_theme_font_override("font", _font_exo2_regular)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", _c("positive"))
		parent.add_child(lbl)


func _build_upkeep(parent: VBoxContainer) -> void:
	for res: String in _bdef.upkeep:
		var lbl := Label.new()
		lbl.text = "  \u2212%.1f %s/s" % [float(_bdef.upkeep[res]), RESOURCE_NAMES.get(res, res)]
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		lbl.add_theme_font_override("font", _font_exo2_regular)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", _c("negative"))
		parent.add_child(lbl)


func _build_effects(parent: VBoxContainer) -> void:
	for effect: Dictionary in _bdef.effects:
		if effect.get("prefix", "") == "store":
			var lbl := Label.new()
			lbl.text = "  +%.0f %s storage" % [float(effect.value), RESOURCE_NAMES.get(effect.resource, effect.resource)]
			lbl.mouse_filter = Control.MOUSE_FILTER_PASS
			lbl.add_theme_font_override("font", _font_exo2_regular)
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.50))
			parent.add_child(lbl)


func _build_cost_grid(parent: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 2)
	parent.add_child(grid)

	for res: String in _bdef.costs:
		_add_cost_row(grid, res)
	_add_cost_row(grid, "land")


func _add_cost_row(grid: GridContainer, res: String) -> void:
	var icon := ColorRect.new()
	icon.color = RESOURCE_COLORS.get(res, Color.WHITE)
	icon.custom_minimum_size = Vector2(13, 13)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = RESOURCE_NAMES.get(res, res)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	name_lbl.add_theme_font_override("font", _font_exo2_regular)
	name_lbl.add_theme_font_size_override("font_size", 14)
	grid.add_child(name_lbl)

	var amt_lbl := Label.new()
	amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amt_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	amt_lbl.add_theme_font_override("font", _font_exo2_semibold)
	amt_lbl.add_theme_font_size_override("font_size", 14)
	grid.add_child(amt_lbl)

	_cost_labels[res] = amt_lbl


func _build_sell_row(parent: VBoxContainer) -> void:
	_sell_row = HBoxContainer.new()
	_sell_row.add_theme_constant_override("separation", 4)
	_sell_row.visible = false
	parent.add_child(_sell_row)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_PASS
	_sell_row.add_child(spacer)

	var sn: String = _bdef.short_name

	_sell1_btn = _make_sell_btn("Sell 1")
	_sell1_btn.pressed.connect(func(): GameManager.sell_building(sn, 1))
	_sell_row.add_child(_sell1_btn)

	_sell_all_btn = _make_sell_btn("Sell All")
	_sell_all_btn.pressed.connect(_on_sell_all_pressed)
	_sell_row.add_child(_sell_all_btn)


func _on_sell_all_pressed() -> void:
	if not _sell_all_pending:
		_sell_all_pending = true
		_sell_all_btn.text = "Sure?"
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_instance_valid(self) and _sell_all_pending:
				_sell_all_pending = false
				_sell_all_btn.text = "Sell All"
		)
	else:
		_sell_all_pending = false
		_sell_all_btn.text = "Sell All"
		GameManager.sell_building(_bdef.short_name, 999)


# ── Button helpers ─────────────────────────────────────────────────────────────

func _make_ctrl_btn(txt: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(26, 26)
	btn.focus_mode = Control.FOCUS_NONE
	if _font_exo2_semibold:
		btn.add_theme_font_override("font", _font_exo2_semibold)
	btn.add_theme_font_size_override("font_size", 16)
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
		s.content_margin_left   = 2
		s.content_margin_right  = 2
		s.content_margin_top    = 2
		s.content_margin_bottom = 2
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_stylebox_override("hover",  s)
	return btn


func _make_sell_btn(txt: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", _font_exo2_regular)
	btn.add_theme_font_size_override("font_size", 11)
	if not GameSettings.is_dark_mode:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.98, 0.96, 0.96)
		s.corner_radius_top_left     = 3
		s.corner_radius_top_right    = 3
		s.corner_radius_bottom_left  = 3
		s.corner_radius_bottom_right = 3
		s.border_width_left   = 1
		s.border_width_right  = 1
		s.border_width_top    = 1
		s.border_width_bottom = 1
		s.border_color = Color(0.75, 0.55, 0.55)
		s.content_margin_left   = 4
		s.content_margin_right  = 4
		s.content_margin_top    = 2
		s.content_margin_bottom = 2
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_stylebox_override("hover",  s)
		btn.add_theme_color_override("font_color", Color(0.55, 0.18, 0.18))
	return btn
