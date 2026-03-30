class_name BuyLandCard
extends PanelContainer

var _font_rb: FontFile
var _font_e2r: FontFile
var _font_e2s: FontFile

var _bg_style: StyleBoxFlat
var _usage_lbl: Label
var _cost_lbl: Label
var _buy_btn: Button


func setup(font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_font_rb = font_rb
	_font_e2r = font_e2r
	_font_e2s = font_e2s
	_build_ui()


func refresh() -> void:
	var st: GameState = GameManager.state
	var total: int = GameManager.get_total_land()
	var available: float = st.amounts.get("land", 0.0)
	var used: int = total - int(available)
	_usage_lbl.text = "%d / %d used" % [used, total]

	var cost: int = GameManager.get_land_purchase_cost()
	var per: int = GameManager.get_land_per_purchase()
	var can: bool = GameManager.can_buy_land()
	_cost_lbl.text = "+%d land for %d cr" % [per, cost]
	if can:
		_cost_lbl.remove_theme_color_override("font_color")
		_bg_style.bg_color = Color(0.20, 0.40, 0.20, 0.35) if GameSettings.is_dark_mode else Color(0.94, 0.99, 0.94)
	else:
		_cost_lbl.add_theme_color_override("font_color", Color(0.776, 0.157, 0.157))
		_bg_style.bg_color = Color(0.40, 0.20, 0.20, 0.35) if GameSettings.is_dark_mode else Color(0.99, 0.94, 0.94)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_buy_pressed()


func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_bg_style = StyleBoxFlat.new()
	_bg_style.corner_radius_top_left     = 4
	_bg_style.corner_radius_top_right    = 4
	_bg_style.corner_radius_bottom_left  = 4
	_bg_style.corner_radius_bottom_right = 4
	if GameSettings.is_dark_mode:
		_bg_style.bg_color = Color(0.13, 0.13, 0.16)
	else:
		_bg_style.bg_color = Color(1.0, 1.0, 1.0)
		_bg_style.border_width_left   = 1
		_bg_style.border_width_right  = 1
		_bg_style.border_width_top    = 1
		_bg_style.border_width_bottom = 1
		_bg_style.border_color = Color(0.816, 0.816, 0.816)
	add_theme_stylebox_override("panel", _bg_style)

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	# Left: color swatch + "Land" header + usage
	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	var swatch := ColorRect.new()
	swatch.color = Color(0.40, 0.70, 0.30)
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(swatch)

	var title_lbl := Label.new()
	title_lbl.text = "Land"
	title_lbl.add_theme_font_override("font", _font_rb)
	title_lbl.add_theme_font_size_override("font_size", 21)
	left.add_child(title_lbl)

	_usage_lbl = Label.new()
	_usage_lbl.text = "— / — used"
	_usage_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_usage_lbl.add_theme_font_override("font", _font_e2r)
	_usage_lbl.add_theme_font_size_override("font_size", 14)
	if not GameSettings.is_dark_mode:
		_usage_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	left.add_child(_usage_lbl)

	# Center: cost info
	_cost_lbl = Label.new()
	_cost_lbl.text = "+10 land for — cr"
	_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cost_lbl.add_theme_font_override("font", _font_e2r)
	_cost_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(_cost_lbl)

	# Right: buy button
	_buy_btn = Button.new()
	_buy_btn.text = "Buy Land"
	_buy_btn.focus_mode = Control.FOCUS_NONE
	_buy_btn.add_theme_font_override("font", _font_e2s)
	_buy_btn.add_theme_font_size_override("font_size", 14)
	_buy_btn.pressed.connect(_on_buy_pressed)
	if not GameSettings.is_dark_mode:
		var btn_s := StyleBoxFlat.new()
		btn_s.bg_color = Color(0.941, 0.941, 0.941)
		btn_s.corner_radius_top_left     = 3
		btn_s.corner_radius_top_right    = 3
		btn_s.corner_radius_bottom_left  = 3
		btn_s.corner_radius_bottom_right = 3
		btn_s.border_width_left   = 1
		btn_s.border_width_right  = 1
		btn_s.border_width_top    = 1
		btn_s.border_width_bottom = 1
		btn_s.border_color = Color(0.816, 0.816, 0.816)
		_buy_btn.add_theme_stylebox_override("normal", btn_s)
		_buy_btn.add_theme_stylebox_override("disabled", btn_s)
	row.add_child(_buy_btn)


func _on_buy_pressed() -> void:
	GameManager.buy_land()
