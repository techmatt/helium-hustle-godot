class_name ProjectCard
extends PanelContainer


var _pdef: Dictionary = {}
var _font_rb: FontFile
var _font_e2r: FontFile
var _font_e2s: FontFile

# Per-resource rate labels (resource_id → Label showing current rate)
var _rate_labels: Dictionary = {}
# Per-resource progress bars (resource_id → ProgressBar)
var _progress_bars: Dictionary = {}
# Per-resource progress labels (resource_id → Label showing "x/y")
var _progress_labels: Dictionary = {}
# Per-resource row background styles (resource_id → StyleBoxFlat) for green tinting
var _row_styles: Dictionary = {}
# Per-resource stepper containers (resource_id → HBoxContainer) for show/hide
var _stepper_containers: Dictionary = {}

# Hold-to-repeat state
var _hold_res: String = ""
var _hold_dir: float = 0.0
var _hold_timer: float = 0.0
var _hold_active: bool = false
const HOLD_DELAY: float = 0.40
const HOLD_INTERVAL: float = 0.075


func setup(pdef: Dictionary, font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_pdef = pdef
	_font_rb = font_rb
	_font_e2r = font_e2r
	_font_e2s = font_e2s
	_build()


func refresh() -> void:
	var st: GameState = GameManager.state
	var pm: ProjectManager = GameManager.project_manager
	var pid: String = _pdef.id
	var is_complete: bool = pm.is_project_complete(st, pid)
	var costs: Dictionary = _pdef.get("costs", {})
	var invested: Dictionary = st.project_invested.get(pid, {})
	var dark: bool = GameSettings.is_dark_mode

	for res: String in costs:
		var total_needed: float = float(costs[res])
		var current: float = minf(float(invested.get(res, 0.0)), total_needed)
		var frac: float = current / total_needed if total_needed > 0.0 else 1.0
		var row_done: bool = frac >= 1.0 or is_complete

		if _row_styles.has(res):
			var rs: StyleBoxFlat = _row_styles[res]
			if row_done:
				rs.bg_color = Color(0.20, 0.40, 0.20, 0.35) if dark else Color(0.50, 0.86, 0.50, 0.30)
			else:
				rs.bg_color = Color(0, 0, 0, 0)

		if _progress_bars.has(res):
			var bar: ProgressBar = _progress_bars[res]
			bar.value = frac
			# Green when complete, accent when in-progress
			var fill_style: StyleBoxFlat = StyleBoxFlat.new()
			fill_style.bg_color = Color(0.18, 0.49, 0.20) if frac >= 1.0 else Color(0.298, 0.686, 0.314)
			bar.add_theme_stylebox_override("fill", fill_style)

		if _progress_labels.has(res):
			_progress_labels[res].text = "%d/%d" % [int(current), int(total_needed)]

		if _rate_labels.has(res):
			var rate: float = pm.get_project_rate(st, pid, res)
			_rate_labels[res].text = "%d" % int(rate)

		if _stepper_containers.has(res):
			var sc: HBoxContainer = _stepper_containers[res]
			sc.visible = not row_done
			if row_done and _hold_res == res:
				_hold_res = ""
				_hold_active = false


func _build() -> void:
	var dark: bool = GameSettings.is_dark_mode
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.12, 0.12) if dark else Color.WHITE
	bg_style.border_width_left   = 1
	bg_style.border_width_right  = 1
	bg_style.border_width_top    = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.25, 0.25, 0.25) if dark else Color(0.816, 0.816, 0.816)
	bg_style.content_margin_left   = 10
	bg_style.content_margin_right  = 10
	bg_style.content_margin_top    = 8
	bg_style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", bg_style)

	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Header row: name
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	vbox.add_child(header_row)

	var name_lbl := Label.new()
	name_lbl.text = _pdef.get("name", _pdef.id)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_override("font", _font_rb)
	name_lbl.add_theme_font_size_override("font_size", 16)
	header_row.add_child(name_lbl)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = _pdef.get("description", "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_override("font", _font_e2r)
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color",
		Color(0.60, 0.60, 0.60) if dark else Color(0.40, 0.40, 0.40))
	vbox.add_child(desc_lbl)

	# Per-resource rows
	var costs: Dictionary = _pdef.get("costs", {})
	for res: String in costs:
		vbox.add_child(_build_resource_row(res, float(costs[res])))

	# Reward line
	var reward_lbl := Label.new()
	reward_lbl.text = "Reward: " + _format_reward(_pdef.get("reward", {}))
	reward_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reward_lbl.add_theme_font_override("font", _font_e2r)
	reward_lbl.add_theme_font_size_override("font_size", 14)
	reward_lbl.add_theme_color_override("font_color",
		Color(0.55, 0.55, 0.55) if dark else Color(0.45, 0.45, 0.45))
	vbox.add_child(reward_lbl)


func _build_resource_row(res: String, total_needed: float) -> PanelContainer:
	var dark: bool = GameSettings.is_dark_mode

	# Row wrapper with tintable background
	var wrap := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0, 0, 0, 0)
	row_style.content_margin_left   = 0
	row_style.content_margin_right  = 0
	row_style.content_margin_top    = 2
	row_style.content_margin_bottom = 2
	wrap.add_theme_stylebox_override("panel", row_style)
	_row_styles[res] = row_style

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	wrap.add_child(row)

	# Resource name label
	var res_lbl := Label.new()
	res_lbl.text = GameManager.get_resource_display_name(res)
	res_lbl.custom_minimum_size = Vector2(70, 0)
	res_lbl.add_theme_font_override("font", _font_e2r)
	res_lbl.add_theme_font_size_override("font_size", 15)
	row.add_child(res_lbl)

	# Progress bar
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 16)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.20, 0.20, 0.20) if dark else Color(0.88, 0.88, 0.88)
	bar.add_theme_stylebox_override("background", bg_style)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.298, 0.686, 0.314)
	bar.add_theme_stylebox_override("fill", fill_style)
	row.add_child(bar)
	_progress_bars[res] = bar

	# Progress text "x/y"
	var prog_lbl := Label.new()
	prog_lbl.text = "0/%d" % int(total_needed)
	prog_lbl.custom_minimum_size = Vector2(72, 0)
	prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prog_lbl.add_theme_font_override("font", _font_e2s)
	prog_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(prog_lbl)
	_progress_labels[res] = prog_lbl

	# Stepper group: − [rate] +
	var stepper_box := HBoxContainer.new()
	stepper_box.add_theme_constant_override("separation", 2)
	row.add_child(stepper_box)
	_stepper_containers[res] = stepper_box

	var minus_btn := _make_stepper_btn("−")
	minus_btn.button_down.connect(_on_stepper_down.bind(res, -1.0))
	minus_btn.button_up.connect(_on_stepper_up)
	stepper_box.add_child(minus_btn)

	var rate_lbl := Label.new()
	rate_lbl.text = "0"
	rate_lbl.custom_minimum_size = Vector2(24, 0)
	rate_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rate_lbl.add_theme_font_override("font", _font_e2s)
	rate_lbl.add_theme_font_size_override("font_size", 15)
	stepper_box.add_child(rate_lbl)
	_rate_labels[res] = rate_lbl

	var plus_btn := _make_stepper_btn("+")
	plus_btn.button_down.connect(_on_stepper_down.bind(res, 1.0))
	plus_btn.button_up.connect(_on_stepper_up)
	stepper_box.add_child(plus_btn)

	return wrap


func _process(delta: float) -> void:
	if not _hold_active:
		return
	_hold_timer -= delta
	if _hold_timer <= 0.0:
		_step_rate(_hold_res, _hold_dir)
		_hold_timer = HOLD_INTERVAL


func _on_stepper_down(res: String, dir: float) -> void:
	_step_rate(res, dir)
	_hold_res = res
	_hold_dir = dir
	_hold_timer = HOLD_DELAY
	_hold_active = true


func _on_stepper_up() -> void:
	_hold_active = false


func _step_rate(res: String, dir: float) -> void:
	var cur: float = GameManager.project_manager.get_project_rate(GameManager.state, _pdef.id, res)
	GameManager.set_project_rate(_pdef.id, res, cur + dir)


func _make_stepper_btn(symbol: String) -> Button:
	var dark: bool = GameSettings.is_dark_mode
	var btn := Button.new()
	btn.text = symbol
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(26, 22)
	btn.add_theme_font_override("font", _font_e2s)
	btn.add_theme_font_size_override("font_size", 16)
	if not dark:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.941, 0.941, 0.941)
		s.border_width_left   = 1
		s.border_width_right  = 1
		s.border_width_top    = 1
		s.border_width_bottom = 1
		s.border_color = Color(0.816, 0.816, 0.816)
		s.corner_radius_top_left     = 3
		s.corner_radius_top_right    = 3
		s.corner_radius_bottom_left  = 3
		s.corner_radius_bottom_right = 3
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_stylebox_override("hover", s)
	return btn


func _format_reward(reward: Dictionary) -> String:
	match reward.get("type", ""):
		"modifier":
			var key: String = reward.get("modifier_key", "")
			var val: float = float(reward.get("modifier_value", 1.0))
			return _modifier_description(key, val)
		"starting_buildings":
			var parts: Array = []
			for bsn: String in reward.get("buildings", {}):
				parts.append("+%d %s" % [int(reward.buildings[bsn]), bsn])
			return "Start future runs with " + ", ".join(parts)
		"stub":
			return reward.get("description", "Coming soon")
	return "Unknown"


func _modifier_description(key: String, value: float) -> String:
	var pct: int = int(roundf((value - 1.0) * 100.0))
	var sign: String = "+" if pct >= 0 else ""
	match key:
		"extractor_output_mult":    return "Excavator/Ice Extractor output %s%d%%" % [sign, pct]
		"solar_output_mult":        return "Solar Panel output %s%d%%" % [sign, pct]
		"building_upkeep_mult":     return "All building upkeep %s%d%%" % [sign, pct]
		"promote_effectiveness_mult": return "Promote effectiveness %s%d%%" % [sign, pct]
		"speculator_burst_interval_mult": return "Speculator burst interval %s%d%%" % [sign, pct]
		"land_cost_mult":           return "Land purchase cost %s%d%%" % [sign, pct]
	return "%s %s%d%%" % [key, sign, pct]
