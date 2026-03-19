class_name BuildingCard
extends PanelContainer

const COLOR_POSITIVE    := Color(0.498, 0.749, 0.498)  # #7FBF7F
const COLOR_NEGATIVE    := Color(0.749, 0.498, 0.498)  # #BF7F7F
const COLOR_CAN_AFFORD  := Color(0.20, 0.40, 0.20, 0.35)
const COLOR_CANT_AFFORD := Color(0.40, 0.20, 0.20, 0.35)

const RESOURCE_COLORS: Dictionary = {
	"eng":     Color(1.00, 0.85, 0.00),
	"reg":     Color(0.60, 0.42, 0.22),
	"ice":     Color(0.70, 0.92, 1.00),
	"he3":     Color(0.50, 0.50, 1.00),
	"cred":    Color(0.20, 0.85, 0.20),
	"land":    Color(0.40, 0.70, 0.30),
	"boredom": Color(0.55, 0.55, 0.55),
	"proc":    Color(0.80, 0.20, 0.80),
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
	_bg_style.bg_color = COLOR_CAN_AFFORD if can_afford else COLOR_CANT_AFFORD

	var scaled: Dictionary = GameManager.get_scaled_costs(_bdef.short_name)
	var st: GameState = GameManager.state
	for res: String in _cost_labels:
		var lbl: Label = _cost_labels[res]
		if res == "land":
			var land_cost: int = _bdef.land
			lbl.text = "%d" % land_cost
			var ok: bool = st.amounts.get("land", 0.0) >= float(land_cost)
			lbl.add_theme_color_override("font_color", Color.WHITE if ok else COLOR_NEGATIVE)
		else:
			var amount: float = scaled.get(res, 0.0)
			lbl.text = "%.0f" % amount
			var ok: bool = st.amounts.get(res, 0.0) >= amount
			lbl.add_theme_color_override("font_color", Color.WHITE if ok else COLOR_NEGATIVE)


# ── UI construction ────────────────────────────────────────────────────────────

func _build_ui() -> void:
	custom_minimum_size = Vector2(240, 0)
	size_flags_horizontal = Control.SIZE_FILL

	_bg_style = StyleBoxFlat.new()
	_bg_style.bg_color = COLOR_CANT_AFFORD
	_bg_style.corner_radius_top_left     = 4
	_bg_style.corner_radius_top_right    = 4
	_bg_style.corner_radius_bottom_left  = 4
	_bg_style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", _bg_style)

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
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
	name_lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(name_lbl)

	_count_lbl = Label.new()
	_count_lbl.text = "(0)"
	_count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_lbl.add_theme_font_override("font", _font_exo2_semibold)
	_count_lbl.add_theme_font_size_override("font_size", 12)
	_count_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	row.add_child(_count_lbl)

	_buy_btn = Button.new()
	_buy_btn.text = "Buy"
	_buy_btn.add_theme_font_override("font", _font_exo2_semibold)
	_buy_btn.add_theme_font_size_override("font_size", 12)
	var sn: String = _bdef.short_name
	_buy_btn.pressed.connect(func(): GameManager.buy_building(sn))
	row.add_child(_buy_btn)


func _build_description(parent: VBoxContainer) -> void:
	var lbl := Label.new()
	lbl.text = _bdef.description
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", _font_exo2_regular)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.70))
	parent.add_child(lbl)


func _build_production(parent: VBoxContainer) -> void:
	for res: String in _bdef.production:
		var lbl := Label.new()
		lbl.text = "  +%.1f %s/s" % [float(_bdef.production[res]), res]
		lbl.add_theme_font_override("font", _font_exo2_regular)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", COLOR_POSITIVE)
		parent.add_child(lbl)


func _build_upkeep(parent: VBoxContainer) -> void:
	for res: String in _bdef.upkeep:
		var lbl := Label.new()
		lbl.text = "  \u2212%.1f %s/s" % [float(_bdef.upkeep[res]), res]
		lbl.add_theme_font_override("font", _font_exo2_regular)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", COLOR_NEGATIVE)
		parent.add_child(lbl)


func _build_effects(parent: VBoxContainer) -> void:
	for effect: Dictionary in _bdef.effects:
		if effect.get("prefix", "") == "store":
			var lbl := Label.new()
			lbl.text = "  +%.0f %s storage" % [float(effect.value), effect.resource]
			lbl.add_theme_font_override("font", _font_exo2_regular)
			lbl.add_theme_font_size_override("font_size", 11)
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
	icon.custom_minimum_size = Vector2(10, 10)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = res
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_override("font", _font_exo2_regular)
	name_lbl.add_theme_font_size_override("font_size", 11)
	grid.add_child(name_lbl)

	var amt_lbl := Label.new()
	amt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amt_lbl.add_theme_font_override("font", _font_exo2_semibold)
	amt_lbl.add_theme_font_size_override("font_size", 11)
	grid.add_child(amt_lbl)

	_cost_labels[res] = amt_lbl
