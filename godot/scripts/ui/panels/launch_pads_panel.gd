class_name LaunchPadsPanel
extends VBoxContainer

const DEMAND_TIERS: Array = [
	[0.85, "VERY HIGH", Color(0.10, 0.80, 0.30)],
	[0.55, "HIGH",      Color(0.18, 0.49, 0.20)],
	[0.25, "MEDIUM",    Color(0.0,  0.0,  0.0,  0.0)],
	[0.0,  "LOW",       Color(0.78, 0.16, 0.16)],
]

const TRADEABLE_DISPLAY: Dictionary = {
	"he3":  ["He-3",       Color(0.50, 0.50, 1.00)],
	"ti":   ["Titanium",   Color(0.80, 0.80, 0.80)],
	"cir":  ["Circuits",   Color(0.30, 0.80, 0.70)],
	"prop": ["Propellant", Color(0.40, 0.70, 0.95)],
}

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

var _font_rb: FontFile
var _font_e2r: FontFile
var _font_e2s: FontFile

var _launch_pad_cards: Array = []
var _launch_history_vbox: VBoxContainer = null
var _demand_body: VBoxContainer = null
var _demand_sparklines: Dictionary = {}
var _demand_value_labels: Dictionary = {}
var _demand_tier_labels: Dictionary = {}
var _demand_has_ma: bool = false
var _spec_intel_body: VBoxContainer = null
var _spec_intel_countdown_lbl: Label = null
var _spec_intel_size_lbl: Label = null
var _spec_intel_prob_labels: Dictionary = {}
var _spec_intel_bar_fill_rects: Dictionary = {}
var _spec_intel_has_sa: bool = false


func setup(font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_font_rb = font_rb
	_font_e2r = font_e2r
	_font_e2s = font_e2s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	_build()


func on_tick() -> void:
	var st: GameState = GameManager.state
	if st.pads.size() != _launch_pad_cards.size():
		for child in get_children():
			child.queue_free()
		_reset_state()
		_build()
		return
	_refresh_pad_cards()
	_refresh_demand_section()
	_refresh_spec_intel_section()
	_refresh_launch_history()


func _reset_state() -> void:
	_launch_pad_cards.clear()
	_launch_history_vbox = null
	_demand_body = null
	_demand_sparklines.clear()
	_demand_value_labels.clear()
	_demand_tier_labels.clear()
	_demand_has_ma = false
	_spec_intel_body = null
	_spec_intel_countdown_lbl = null
	_spec_intel_size_lbl = null
	_spec_intel_prob_labels.clear()
	_spec_intel_bar_fill_rects.clear()
	_spec_intel_has_sa = false


func _build() -> void:
	var st: GameState = GameManager.state

	_demand_body = _make_collapsible_section(self, "Earth Demand", true)
	_demand_has_ma = false
	_demand_sparklines.clear()
	_demand_value_labels.clear()
	_demand_tier_labels.clear()
	_populate_demand_section(st, st.completed_research.has("market_awareness"))

	_spec_intel_has_sa = false
	_spec_intel_prob_labels.clear()
	_spec_intel_bar_fill_rects.clear()
	_spec_intel_body = _make_collapsible_section(self, "Speculator Intelligence", true)
	_build_spec_intel_section(_spec_intel_body)

	var priority_body := _make_collapsible_section(self, "Loading Priority", false)
	_build_loading_priority_list(priority_body)

	if st.pads.is_empty():
		var no_pads_lbl := Label.new()
		no_pads_lbl.text = "No Launch Pads built. Purchase a Launch Pad from the Buildings panel to begin shipping resources to Earth."
		no_pads_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		no_pads_lbl.add_theme_font_override("font", _font_e2r)
		no_pads_lbl.add_theme_font_size_override("font_size", 16)
		no_pads_lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
		add_child(no_pads_lbl)
	else:
		for i in range(st.pads.size()):
			var card := LaunchPadCard.new()
			card.setup(i, _font_rb, _font_e2r, _font_e2s)
			add_child(card)
			_launch_pad_cards.append(card)
		_refresh_pad_cards()

	add_child(HSeparator.new())
	var history_hdr := Label.new()
	history_hdr.text = "Recent Launches"
	history_hdr.add_theme_font_override("font", _font_rb)
	history_hdr.add_theme_font_size_override("font_size", 16)
	add_child(history_hdr)

	_launch_history_vbox = VBoxContainer.new()
	_launch_history_vbox.add_theme_constant_override("separation", 4)
	add_child(_launch_history_vbox)
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
		lbl.add_theme_font_override("font", _font_e2r)
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
		_launch_history_vbox.add_child(lbl)
		return
	for record: GameState.LaunchRecord in st.launch_history:
		var lbl := Label.new()
		var src: String = record.source_type
		if not record.notification_message.is_empty():
			lbl.text = "Day %d: %s" % [record.tick, record.notification_message]
			if src == "speculator":
				lbl.add_theme_color_override("font_color", Color(0.902, 0.318, 0.0))
			else:
				lbl.add_theme_color_override("font_color", Color(0.40, 0.40, 0.40))
		else:
			var res_name: String = RESOURCE_META.get(record.resource_type, [record.resource_type.capitalize()])[0]
			lbl.text = "Day %d: %s × %d → %d credits" % [record.tick, res_name, int(record.quantity), int(record.credits_earned)]
		lbl.add_theme_font_override("font", _font_e2r)
		lbl.add_theme_font_size_override("font_size", 15)
		_launch_history_vbox.add_child(lbl)


# ── Spec intel ────────────────────────────────────────────────────────────────

func _build_spec_intel_section(body: VBoxContainer) -> void:
	var st: GameState = GameManager.state
	var has_sa: bool = st.completed_research.has("speculator_analysis")
	_spec_intel_has_sa = has_sa

	if not has_sa:
		var locked_lbl := Label.new()
		locked_lbl.text = "Requires Speculator Analysis research."
		locked_lbl.add_theme_font_override("font", _font_e2r)
		locked_lbl.add_theme_font_size_override("font_size", 15)
		locked_lbl.add_theme_color_override("font_color", UIPalette.p("text_locked"))
		body.add_child(locked_lbl)
		return

	_spec_intel_countdown_lbl = Label.new()
	_spec_intel_countdown_lbl.add_theme_font_override("font", _font_e2r)
	_spec_intel_countdown_lbl.add_theme_font_size_override("font_size", 15)
	body.add_child(_spec_intel_countdown_lbl)

	_spec_intel_size_lbl = Label.new()
	_spec_intel_size_lbl.add_theme_font_override("font", _font_e2r)
	_spec_intel_size_lbl.add_theme_font_size_override("font_size", 15)
	body.add_child(_spec_intel_size_lbl)

	var prob_hdr := Label.new()
	prob_hdr.text = "Target probabilities:"
	prob_hdr.add_theme_font_override("font", _font_e2r)
	prob_hdr.add_theme_font_size_override("font_size", 15)
	body.add_child(prob_hdr)

	var bar_wrap := PanelContainer.new()
	bar_wrap.custom_minimum_size = Vector2(0, 16)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.22, 0.22, 0.26) if GameSettings.is_dark_mode else Color(0.78, 0.78, 0.78)
	bar_bg.corner_radius_top_left     = 4
	bar_bg.corner_radius_top_right    = 4
	bar_bg.corner_radius_bottom_left  = 4
	bar_bg.corner_radius_bottom_right = 4
	bar_wrap.add_theme_stylebox_override("panel", bar_bg)
	body.add_child(bar_wrap)

	var bar_hbox := HBoxContainer.new()
	bar_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_hbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	bar_hbox.add_theme_constant_override("separation", 0)
	bar_wrap.add_child(bar_hbox)

	for res: String in GameState.TRADEABLE_RESOURCES:
		var seg := ColorRect.new()
		seg.color = TRADEABLE_DISPLAY.get(res, [res, Color.WHITE])[1]
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.size_flags_stretch_ratio = 0.25
		seg.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		bar_hbox.add_child(seg)
		_spec_intel_bar_fill_rects[res] = seg

	var prob_row := HBoxContainer.new()
	prob_row.add_theme_constant_override("separation", 8)
	body.add_child(prob_row)

	for res: String in GameState.TRADEABLE_RESOURCES:
		var display: Array = TRADEABLE_DISPLAY.get(res, [res, Color.WHITE])
		var prob_lbl := Label.new()
		prob_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prob_lbl.add_theme_font_override("font", _font_e2s)
		prob_lbl.add_theme_font_size_override("font_size", 14)
		prob_lbl.add_theme_color_override("font_color", display[1])
		prob_row.add_child(prob_lbl)
		_spec_intel_prob_labels[res] = prob_lbl

	_refresh_spec_intel_content(st)


func _refresh_spec_intel_section() -> void:
	if _spec_intel_body == null or not is_instance_valid(_spec_intel_body):
		return
	var st: GameState = GameManager.state
	var has_sa: bool = st.completed_research.has("speculator_analysis")
	if has_sa != _spec_intel_has_sa:
		for child in _spec_intel_body.get_children():
			child.queue_free()
		_spec_intel_countdown_lbl = null
		_spec_intel_size_lbl = null
		_spec_intel_prob_labels.clear()
		_spec_intel_bar_fill_rects.clear()
		_build_spec_intel_section(_spec_intel_body)
		return
	if not has_sa:
		return
	_refresh_spec_intel_content(st)


func _refresh_spec_intel_content(st: GameState) -> void:
	var days_remaining: int = maxi(0, st.speculator_next_burst_tick - st.current_day)
	if _spec_intel_countdown_lbl != null and is_instance_valid(_spec_intel_countdown_lbl):
		_spec_intel_countdown_lbl.text = "Next speculator burst in %d days" % days_remaining

	if _spec_intel_size_lbl != null and is_instance_valid(_spec_intel_size_lbl):
		var ds: DemandSystem = GameManager.sim.demand_system
		var size_min: int = int(ds.get_config("speculator_burst_size_min"))
		var size_max: int = int(ds.get_config("speculator_burst_size_max"))
		var growth: float = ds.get_config("speculator_burst_growth")
		var scale: float = pow(growth, float(st.speculator_burst_number))
		_spec_intel_size_lbl.text = "Estimated burst size: %d–%d speculators" % [int(size_min * scale), int(size_max * scale)]

	var total: float = 0.0
	for res: String in GameState.TRADEABLE_RESOURCES:
		total += st.speculator_target_scores.get(res, 0.0)
	for res: String in GameState.TRADEABLE_RESOURCES:
		var score: float = st.speculator_target_scores.get(res, 0.0)
		var pct: int = int(round(score / total * 100.0)) if total > 0.0 else 25
		if _spec_intel_prob_labels.has(res):
			var display: Array = TRADEABLE_DISPLAY.get(res, [res, Color.WHITE])
			(_spec_intel_prob_labels[res] as Label).text = "%s: %d%%" % [display[0], pct]
		if _spec_intel_bar_fill_rects.has(res):
			var ratio: float = score / total if total > 0.0 else 0.25
			(_spec_intel_bar_fill_rects[res] as ColorRect).size_flags_stretch_ratio = ratio


# ── Demand section ────────────────────────────────────────────────────────────

func _demand_tier(value: float) -> Array:
	for tier: Array in DEMAND_TIERS:
		if value >= float(tier[0]):
			return tier
	return DEMAND_TIERS[DEMAND_TIERS.size() - 1]


func _populate_demand_section(st: GameState, has_ma: bool) -> void:
	_demand_has_ma = has_ma
	_demand_sparklines.clear()
	_demand_value_labels.clear()
	_demand_tier_labels.clear()
	if _demand_body == null or not is_instance_valid(_demand_body):
		return

	var resources: Array = GameState.TRADEABLE_RESOURCES
	var idx := 0
	while idx < resources.size():
		var pair_row := HBoxContainer.new()
		pair_row.add_theme_constant_override("separation", 8)
		_demand_body.add_child(pair_row)

		for slot in range(2):
			if idx + slot >= resources.size():
				var spacer := Control.new()
				spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				pair_row.add_child(spacer)
				continue

			var res: String = resources[idx + slot]
			var display: Array = TRADEABLE_DISPLAY.get(res, [res, Color.WHITE])
			var demand_val: float = st.demand.get(res, 0.5)

			var block := HBoxContainer.new()
			block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			block.add_theme_constant_override("separation", 6)
			pair_row.add_child(block)

			var swatch := ColorRect.new()
			swatch.color = display[1]
			swatch.custom_minimum_size = Vector2(12, 12)
			swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			block.add_child(swatch)

			var name_lbl := Label.new()
			name_lbl.text = display[0]
			name_lbl.add_theme_font_override("font", _font_e2r)
			name_lbl.add_theme_font_size_override("font_size", 15)
			if has_ma:
				name_lbl.custom_minimum_size = Vector2(66, 0)
			else:
				name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			block.add_child(name_lbl)

			if has_ma:
				var sparkline := DemandSparkline.new()
				sparkline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				sparkline.custom_minimum_size = Vector2(0, 104)
				sparkline.set_data(st.demand_history.get(res, [demand_val]), display[1])
				block.add_child(sparkline)
				_demand_sparklines[res] = sparkline

				var val_lbl := Label.new()
				val_lbl.text = "%.2f" % demand_val
				val_lbl.custom_minimum_size = Vector2(36, 0)
				val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				val_lbl.add_theme_font_override("font", _font_e2s)
				val_lbl.add_theme_font_size_override("font_size", 15)
				var tier_arr: Array = _demand_tier(demand_val)
				if tier_arr[2] != Color(0, 0, 0, 0):
					val_lbl.add_theme_color_override("font_color", tier_arr[2])
				if st.speculator_target == res and st.speculator_count > 0.0:
					val_lbl.add_theme_color_override("font_color", Color(0.90, 0.55, 0.10))
				block.add_child(val_lbl)
				_demand_value_labels[res] = val_lbl
			else:
				var tier_arr: Array = _demand_tier(demand_val)
				var tier_lbl := Label.new()
				tier_lbl.text = tier_arr[1]
				tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				tier_lbl.add_theme_font_override("font", _font_e2s)
				tier_lbl.add_theme_font_size_override("font_size", 15)
				if tier_arr[2] != Color(0, 0, 0, 0):
					tier_lbl.add_theme_color_override("font_color", tier_arr[2])
				block.add_child(tier_lbl)
				_demand_tier_labels[res] = tier_lbl

		idx += 2


func _refresh_demand_section() -> void:
	if _demand_body == null or not is_instance_valid(_demand_body):
		return
	var st: GameState = GameManager.state
	var has_ma: bool = st.completed_research.has("market_awareness")
	if has_ma != _demand_has_ma:
		for child in _demand_body.get_children():
			child.queue_free()
		_populate_demand_section(st, has_ma)
		return
	for res: String in GameState.TRADEABLE_RESOURCES:
		var demand_val: float = st.demand.get(res, 0.5)
		var tier_arr: Array = _demand_tier(demand_val)
		if has_ma:
			if _demand_sparklines.has(res):
				(_demand_sparklines[res] as DemandSparkline).set_data(st.demand_history.get(res, []), TRADEABLE_DISPLAY.get(res, [res, Color.WHITE])[1])
			if _demand_value_labels.has(res):
				var val_lbl: Label = _demand_value_labels[res]
				val_lbl.text = "%.2f" % demand_val
				if st.speculator_target == res and st.speculator_count > 0.0:
					val_lbl.add_theme_color_override("font_color", Color(0.90, 0.55, 0.10))
				elif tier_arr[2] != Color(0, 0, 0, 0):
					val_lbl.add_theme_color_override("font_color", tier_arr[2])
				else:
					val_lbl.remove_theme_color_override("font_color")
		else:
			if _demand_tier_labels.has(res):
				var tier_lbl: Label = _demand_tier_labels[res]
				tier_lbl.text = tier_arr[1]
				if tier_arr[2] != Color(0, 0, 0, 0):
					tier_lbl.add_theme_color_override("font_color", tier_arr[2])
				else:
					tier_lbl.remove_theme_color_override("font_color")


# ── Loading priority ──────────────────────────────────────────────────────────

func _build_loading_priority_list(parent: VBoxContainer) -> void:
	var st: GameState = GameManager.state
	parent.add_theme_constant_override("separation", 4)
	for i in range(st.loading_priority.size()):
		var res: String = st.loading_priority[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		parent.add_child(row)

		var idx: int = i

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
		name_lbl.add_theme_font_override("font", _font_e2r)
		name_lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(name_lbl)


# ── Shared helpers ────────────────────────────────────────────────────────────

func _make_collapsible_section(parent: VBoxContainer, title: String, start_open: bool = true) -> VBoxContainer:
	var header := Button.new()
	header.text = ("▼  " if start_open else "▶  ") + title
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_font_override("font", _font_rb)
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
