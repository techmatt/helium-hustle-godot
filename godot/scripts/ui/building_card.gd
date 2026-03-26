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
var _buy_btn: Button
var _bg_style: StyleBoxFlat
# Maps resource key → amount Label (for dynamic cost coloring)
var _cost_labels: Dictionary = {}


func _c(key: String) -> Color:
	return COLORS_DARK[key] if GameSettings.is_dark_mode else COLORS_LIGHT[key]


func setup(bdef: Dictionary, font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_bdef = bdef
	_font_rajdhani_bold = font_rb
	_font_exo2_regular  = font_e2r
	_font_exo2_semibold = font_e2s
	_build_ui()


func refresh() -> void:
	var count: int = GameManager.state.buildings_owned.get(_bdef.short_name, 0)
	_count_lbl.text = "(%d)" % count

	var can_afford: bool = GameManager.can_afford_building(_bdef.short_name)
	_buy_btn.disabled = not can_afford
	if GameSettings.is_dark_mode:
		_bg_style.bg_color = _c("can_afford") if can_afford else _c("cant_afford")
	else:
		# Light mode: very subtle tint + style the Buy button
		_bg_style.bg_color = Color(0.94, 0.99, 0.94) if can_afford else Color(0.99, 0.94, 0.94)
		if can_afford:
			var s := StyleBoxFlat.new()
			s.bg_color = Color(0.298, 0.686, 0.314)  # #4CAF50
			s.corner_radius_top_left     = 4
			s.corner_radius_top_right    = 4
			s.corner_radius_bottom_left  = 4
			s.corner_radius_bottom_right = 4
			_buy_btn.add_theme_stylebox_override("normal", s)
			_buy_btn.add_theme_stylebox_override("pressed", s)
			_buy_btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			_buy_btn.remove_theme_stylebox_override("normal")
			_buy_btn.remove_theme_stylebox_override("pressed")
			_buy_btn.remove_theme_color_override("font_color")

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


# ── UI construction ────────────────────────────────────────────────────────────

func _build_ui() -> void:
	custom_minimum_size = Vector2(310, 0)
	size_flags_horizontal = Control.SIZE_FILL

	_bg_style = StyleBoxFlat.new()
	_bg_style.corner_radius_top_left     = 4
	_bg_style.corner_radius_top_right    = 4
	_bg_style.corner_radius_bottom_left  = 4
	_bg_style.corner_radius_bottom_right = 4
	if GameSettings.is_dark_mode:
		_bg_style.bg_color = _c("cant_afford")
	else:
		_bg_style.bg_color = Color.WHITE
		_bg_style.border_width_left   = 1
		_bg_style.border_width_right  = 1
		_bg_style.border_width_top    = 1
		_bg_style.border_width_bottom = 1
		_bg_style.border_color = Color(0.816, 0.816, 0.816)  # #D0D0D0
	add_theme_stylebox_override("panel", _bg_style)

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	_build_header(vbox)
	_build_description(vbox)
	_build_production(vbox)
	_build_upkeep(vbox)
	_build_effects(vbox)
	vbox.add_child(HSeparator.new())
	_build_cost_grid(vbox)


func _build_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = _bdef.name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_override("font", _font_rajdhani_bold)
	name_lbl.add_theme_font_size_override("font_size", 21)
	row.add_child(name_lbl)

	_count_lbl = Label.new()
	_count_lbl.text = "(0)"
	_count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_lbl.add_theme_font_override("font", _font_exo2_semibold)
	_count_lbl.add_theme_font_size_override("font_size", 15)
	_count_lbl.add_theme_color_override("font_color", _c("count"))
	row.add_child(_count_lbl)

	_buy_btn = Button.new()
	_buy_btn.text = "Buy"
	_buy_btn.add_theme_font_override("font", _font_exo2_semibold)
	_buy_btn.add_theme_font_size_override("font_size", 15)
	var sn: String = _bdef.short_name
	_buy_btn.pressed.connect(func(): GameManager.buy_building(sn))
	row.add_child(_buy_btn)


func _build_description(parent: VBoxContainer) -> void:
	var lbl := Label.new()
	lbl.text = _bdef.description
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", _font_exo2_regular)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", _c("desc"))
	parent.add_child(lbl)


func _build_production(parent: VBoxContainer) -> void:
	for res: String in _bdef.production:
		var lbl := Label.new()
		lbl.text = "  +%.1f %s/s" % [float(_bdef.production[res]), RESOURCE_NAMES.get(res, res)]
		lbl.add_theme_font_override("font", _font_exo2_regular)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", _c("positive"))
		parent.add_child(lbl)


func _build_upkeep(parent: VBoxContainer) -> void:
	for res: String in _bdef.upkeep:
		var lbl := Label.new()
		lbl.text = "  \u2212%.1f %s/s" % [float(_bdef.upkeep[res]), RESOURCE_NAMES.get(res, res)]
		lbl.add_theme_font_override("font", _font_exo2_regular)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", _c("negative"))
		parent.add_child(lbl)


func _build_effects(parent: VBoxContainer) -> void:
	for effect: Dictionary in _bdef.effects:
		if effect.get("prefix", "") == "store":
			var lbl := Label.new()
			lbl.text = "  +%.0f %s storage" % [float(effect.value), RESOURCE_NAMES.get(effect.resource, effect.resource)]
			lbl.add_theme_font_override("font", _font_exo2_regular)
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.50))
			parent.add_child(lbl)


func _build_cost_grid(parent: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
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
	grid.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = RESOURCE_NAMES.get(res, res)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_override("font", _font_exo2_regular)
	name_lbl.add_theme_font_size_override("font_size", 14)
	grid.add_child(name_lbl)

	var amt_lbl := Label.new()
	amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amt_lbl.add_theme_font_override("font", _font_exo2_semibold)
	amt_lbl.add_theme_font_size_override("font_size", 14)
	grid.add_child(amt_lbl)

	_cost_labels[res] = amt_lbl
