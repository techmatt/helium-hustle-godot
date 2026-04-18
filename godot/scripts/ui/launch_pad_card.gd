class_name LaunchPadCard
extends PanelContainer

const TRADEABLE: Array = ["he3", "ti", "cir", "prop"]

const ICON_PAUSE: Texture2D = preload("res://assets/icons/pause.svg")
const ICON_PLAY: Texture2D = preload("res://assets/icons/play.svg")


const RESOURCE_COLORS: Dictionary = {
	"he3":  Color(0.50, 0.50, 1.00),
	"ti":   Color(0.80, 0.80, 0.80),
	"cir":  Color(0.30, 0.80, 0.70),
	"prop": Color(0.40, 0.70, 0.95),
}

# Payout = base_value * live_demand * cargo
const BASE_VALUES: Dictionary = {"he3": 20.0, "ti": 12.0, "cir": 30.0, "prop": 8.0}

var _pad_idx: int = 0
var _font_rb: FontFile
var _font_e2r: FontFile
var _font_e2s: FontFile

var _card_style: StyleBoxFlat
var _resource_opt: OptionButton
var _pause_btn: TextureButton
var _launch_btn: Button
var _cargo_fill: ColorRect
var _bar_content: Control
var _bar_ratio: float = 0.0
var _cargo_label: Label
var _value_label: Label
var _status_label: Label
var _updating_ui: bool = false


func _c_text_muted() -> Color:
	return Color(0.40, 0.40, 0.40) if not GameSettings.is_dark_mode else Color(0.60, 0.60, 0.60)


func setup(pad_idx: int, font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_pad_idx = pad_idx
	_font_rb  = font_rb
	_font_e2r = font_e2r
	_font_e2s = font_e2s
	_build_ui()


func _build_ui() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_card_style = StyleBoxFlat.new()
	_card_style.bg_color = Color(1.0, 1.0, 1.0) if not GameSettings.is_dark_mode else Color(0.12, 0.12, 0.16)
	_card_style.corner_radius_top_left     = 6
	_card_style.corner_radius_top_right    = 6
	_card_style.corner_radius_bottom_left  = 6
	_card_style.corner_radius_bottom_right = 6
	if not GameSettings.is_dark_mode:
		_card_style.border_width_left   = 1
		_card_style.border_width_right  = 1
		_card_style.border_width_top    = 1
		_card_style.border_width_bottom = 1
		_card_style.border_color = Color(0.78, 0.78, 0.78)
	add_theme_stylebox_override("panel", _card_style)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(vbox)

	# ── Title row ──────────────────────────────────────────────────────────────
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.text = "Launch Pad %d" % (_pad_idx + 1)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", _font_rb)
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	title_row.add_child(title_lbl)

	_resource_opt = OptionButton.new()
	_resource_opt.custom_minimum_size = Vector2(145, 0)
	_resource_opt.add_theme_font_override("font", _font_e2s)
	_resource_opt.add_theme_font_size_override("font_size", 15)
	if not GameSettings.is_dark_mode:
		var opt_style := StyleBoxFlat.new()
		opt_style.bg_color = Color.WHITE
		opt_style.border_width_left   = 1
		opt_style.border_width_right  = 1
		opt_style.border_width_top    = 1
		opt_style.border_width_bottom = 1
		opt_style.border_color = Color(0.78, 0.78, 0.78)
		opt_style.corner_radius_top_left     = 4
		opt_style.corner_radius_top_right    = 4
		opt_style.corner_radius_bottom_left  = 4
		opt_style.corner_radius_bottom_right = 4
		_resource_opt.add_theme_stylebox_override("normal", opt_style)
		_resource_opt.add_theme_stylebox_override("hover", opt_style)
		_resource_opt.add_theme_stylebox_override("pressed", opt_style)
		_resource_opt.add_theme_stylebox_override("focus", opt_style)
		var black := Color(0.10, 0.10, 0.10)
		_resource_opt.add_theme_color_override("font_color", black)
		_resource_opt.add_theme_color_override("font_hover_color", black)
		_resource_opt.add_theme_color_override("font_pressed_color", black)
		_resource_opt.add_theme_color_override("font_focus_color", black)
	_resource_opt.add_item("None")
	for res: String in TRADEABLE:
		_resource_opt.add_item(GameManager.get_resource_display_name(res))
	_resource_opt.item_selected.connect(_on_resource_selected)
	title_row.add_child(_resource_opt)

	_pause_btn = TextureButton.new()
	_pause_btn.texture_normal = ICON_PAUSE
	_pause_btn.ignore_texture_size = true
	_pause_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_pause_btn.custom_minimum_size = Vector2(32, 32)
	_pause_btn.tooltip_text = "Pause"
	_pause_btn.pressed.connect(_on_pause_pressed)
	title_row.add_child(_pause_btn)

	_launch_btn = Button.new()
	_launch_btn.text = "Launch"
	_launch_btn.custom_minimum_size = Vector2(76, 0)
	_launch_btn.add_theme_font_override("font", _font_e2s)
	_launch_btn.add_theme_font_size_override("font_size", 16)
	_launch_btn.pressed.connect(_on_launch_pressed)
	title_row.add_child(_launch_btn)

	# ── Cargo bar ──────────────────────────────────────────────────────────────
	var bar_wrap := PanelContainer.new()
	bar_wrap.custom_minimum_size = Vector2(0, 22)
	bar_wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.22, 0.22, 0.26) if GameSettings.is_dark_mode else Color(0.78, 0.78, 0.78)
	bar_bg.corner_radius_top_left     = 4
	bar_bg.corner_radius_top_right    = 4
	bar_bg.corner_radius_bottom_left  = 4
	bar_bg.corner_radius_bottom_right = 4
	bar_wrap.add_theme_stylebox_override("panel", bar_bg)
	vbox.add_child(bar_wrap)

	_bar_content = Control.new()
	_bar_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_content.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_bar_content.mouse_filter = Control.MOUSE_FILTER_PASS
	bar_wrap.add_child(_bar_content)

	_cargo_fill = ColorRect.new()
	_cargo_fill.color = RESOURCE_COLORS["he3"]
	_cargo_fill.mouse_filter = Control.MOUSE_FILTER_PASS
	_cargo_fill.visible = false
	_bar_content.add_child(_cargo_fill)
	# Recompute fill size whenever the container is resized (e.g. after layout).
	_bar_content.resized.connect(_apply_bar_fill)

	# ── Text labels ────────────────────────────────────────────────────────────
	_cargo_label = Label.new()
	_cargo_label.text = "0 / 100 units"
	_cargo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cargo_label.add_theme_font_override("font", _font_e2r)
	_cargo_label.add_theme_font_size_override("font_size", 15)
	_cargo_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_cargo_label)

	_value_label = Label.new()
	_value_label.text = ""
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.add_theme_font_override("font", _font_e2r)
	_value_label.add_theme_font_size_override("font_size", 14)
	_value_label.add_theme_color_override("font_color", _c_text_muted())
	_value_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_value_label)

	_status_label = Label.new()
	_status_label.text = "Empty — waiting for cargo"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_override("font", _font_e2r)
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", _c_text_muted())
	_status_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_status_label)


func refresh(pad_data: GameState.LaunchPadData, is_active: bool) -> void:
	_updating_ui = true

	# Sync dropdown (index 0 = None, 1-N = TRADEABLE)
	var res_idx: int = TRADEABLE.find(pad_data.resource_type)
	var opt_idx: int = res_idx + 1 if res_idx >= 0 else 0
	if _resource_opt.selected != opt_idx:
		_resource_opt.selected = opt_idx

	# Pause button icon, tooltip, and tint
	if pad_data.paused:
		_pause_btn.texture_normal = ICON_PLAY
		_pause_btn.tooltip_text = "Resume"
		_pause_btn.modulate = Color(0.95, 0.80, 0.15)
	else:
		_pause_btn.texture_normal = ICON_PAUSE
		_pause_btn.tooltip_text = "Pause"
		_pause_btn.modulate = Color(0.55, 0.55, 0.60) if GameSettings.is_dark_mode else Color(0.30, 0.30, 0.35)

	# Bar fill color
	_cargo_fill.color = RESOURCE_COLORS.get(pad_data.resource_type, Color.WHITE)

	# Mute card if inactive or in cooldown
	var status: int = pad_data.status
	var cargo: float = pad_data.cargo_loaded

	if not is_active:
		modulate = Color(1, 1, 1, 0.50)
	elif status == GameState.PAD_COOLDOWN:
		modulate = Color(1, 1, 1, 0.65)
	else:
		modulate = Color(1, 1, 1, 1.0)

	# Card background: yellow tint when paused or no resource selected, normal otherwise
	var dark: bool = GameSettings.is_dark_mode
	if pad_data.paused or pad_data.resource_type == "none":
		_card_style.bg_color = Color(0.24, 0.22, 0.00) if dark else Color(1.0, 0.992, 0.906)
	else:
		_card_style.bg_color = Color(0.12, 0.12, 0.16) if dark else Color(1.0, 1.0, 1.0)

	if pad_data.resource_type == "none":
		_set_bar_fill(0.0)
		_cargo_label.text = "—"
		_value_label.text = ""
		_status_label.text = "No resource selected"
		_status_label.add_theme_color_override("font_color", _c_text_muted())
		_set_launch_btn(false, "")
		_updating_ui = false
		return

	match status:
		GameState.PAD_EMPTY:
			_set_bar_fill(0.0)
			_cargo_label.text = "0 / 100 units"
			_value_label.text = ""
			_status_label.text = "Empty — waiting for cargo"
			_set_launch_btn(false, "")
		GameState.PAD_LOADING:
			_set_bar_fill(cargo / 100.0)
			_cargo_label.text = "%d / 100 units" % int(cargo)
			var demand_l: float = GameManager.state.demand.get(pad_data.resource_type, 0.5)
			_value_label.text = "Estimated value: %d credits" % int(BASE_VALUES.get(pad_data.resource_type, 0.0) * demand_l * cargo)
			_set_value_label_color(demand_l)
			_status_label.text = "Loading..."
			_set_launch_btn(false, "")
		GameState.PAD_FULL:
			_set_bar_fill(1.0)
			_cargo_label.text = "100 / 100 units"
			var demand_f: float = GameManager.state.demand.get(pad_data.resource_type, 0.5)
			_value_label.text = "Estimated value: %d credits" % int(BASE_VALUES.get(pad_data.resource_type, 0.0) * demand_f * 100.0)
			_set_value_label_color(demand_f)
			var can_launch: bool = is_active and GameManager.can_launch_pad(_pad_idx)
			_set_launch_btn(can_launch, "Need 20 propellant" if not can_launch else "")
			_status_label.text = "Full — ready to launch!" if can_launch else "Full — need 20 propellant"
			_status_label.add_theme_color_override("font_color",
				Color(0.498, 0.749, 0.498) if can_launch else Color(0.749, 0.498, 0.498))
		GameState.PAD_LAUNCHING:
			_set_bar_fill(1.0)
			_cargo_label.text = "Launching!"
			_value_label.text = ""
			_status_label.text = "Launching..."
			_set_launch_btn(false, "")
		GameState.PAD_COOLDOWN:
			_set_bar_fill(0.0)
			_cargo_label.text = "Returning... %d ticks" % pad_data.cooldown_ticks
			_value_label.text = ""
			_status_label.text = "Pad on cooldown"
			_set_launch_btn(false, "")

	_updating_ui = false


func _set_value_label_color(demand: float) -> void:
	if demand >= 0.85:
		_value_label.add_theme_color_override("font_color", Color(0.10, 0.80, 0.30))
	elif demand >= 0.55:
		_value_label.add_theme_color_override("font_color", Color(0.12, 0.40, 0.14))
	elif demand >= 0.25:
		_value_label.remove_theme_color_override("font_color")
	else:
		_value_label.add_theme_color_override("font_color", Color(0.78, 0.16, 0.16))


func _set_bar_fill(ratio: float) -> void:
	_bar_ratio = clampf(ratio, 0.0, 1.0)
	_apply_bar_fill()


func _apply_bar_fill() -> void:
	_cargo_fill.visible = _bar_ratio > 0.0
	_cargo_fill.position = Vector2.ZERO
	_cargo_fill.size = Vector2(_bar_content.size.x * _bar_ratio, _bar_content.size.y)


func _set_launch_btn(enabled: bool, _hint: String) -> void:
	_launch_btn.disabled = not enabled
	if not GameSettings.is_dark_mode:
		var s := StyleBoxFlat.new()
		s.corner_radius_top_left     = 4
		s.corner_radius_top_right    = 4
		s.corner_radius_bottom_left  = 4
		s.corner_radius_bottom_right = 4
		var black := Color(0.10, 0.10, 0.10)
		if enabled:
			s.bg_color = Color(0.298, 0.686, 0.314)
			_launch_btn.add_theme_stylebox_override("normal", s)
			_launch_btn.remove_theme_stylebox_override("disabled")
			_launch_btn.add_theme_color_override("font_color", Color.WHITE)
			_launch_btn.remove_theme_color_override("font_disabled_color")
		else:
			s.bg_color = Color(0.85, 0.85, 0.85)
			_launch_btn.add_theme_stylebox_override("disabled", s)
			_launch_btn.remove_theme_stylebox_override("normal")
			_launch_btn.add_theme_color_override("font_disabled_color", black)
			_launch_btn.remove_theme_color_override("font_color")


func _on_resource_selected(index: int) -> void:
	if _updating_ui:
		return
	if index == 0:
		GameManager.set_pad_resource(_pad_idx, "none")
	elif index - 1 < TRADEABLE.size():
		GameManager.set_pad_resource(_pad_idx, TRADEABLE[index - 1])


func _on_pause_pressed() -> void:
	var pad_data: GameState.LaunchPadData = GameManager.state.pads[_pad_idx]
	GameManager.set_pad_paused(_pad_idx, not pad_data.paused)


func _on_launch_pressed() -> void:
	GameManager.launch_pad_manual(_pad_idx)
