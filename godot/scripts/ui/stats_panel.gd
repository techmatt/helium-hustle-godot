class_name StatsPanel
extends VBoxContainer

const RESOURCE_ORDER: Array = [
	["boredom","Boredom"],
	["eng",    "Energy"],
	["proc",   "Processors"],
	["land",   "Land"],
	["reg",    "Regolith"],
	["ice",    "Ice"],
	["he3",    "Helium-3"],
	["ti",     "Titanium"],
	["cir",    "Circuit Boards"],
	["prop",   "Propellant"],
	["cred",   "Credits"],
	["sci",    "Science"],
]

const RESOURCE_COLORS: Dictionary = {
	"eng":     Color(1.00, 0.85, 0.00),
	"reg":     Color(0.60, 0.42, 0.22),
	"ice":     Color(0.70, 0.92, 1.00),
	"he3":     Color(0.50, 0.50, 1.00),
	"cred":    Color(0.20, 0.85, 0.20),
	"land":    Color(0.40, 0.70, 0.30),
	"proc":    Color(0.80, 0.20, 0.80),
	"boredom": Color(0.55, 0.55, 0.55),
	"ti":      Color(0.80, 0.80, 0.80),
	"prop":    Color(0.40, 0.70, 0.95),
	"sci":     Color(0.70, 0.50, 0.90),
	"cir":     Color(0.30, 0.80, 0.70),
}

const BOREDOM_SOURCE_LABELS: Dictionary = {
	"phase_growth": "Phase growth",
	"dream": "Dream",
	"load_pads": "Load Launch Pads",
	"cloud_compute": "Sell Cloud Compute",
	"disrupt_spec": "Disrupt Speculators",
}

const CREDIT_SOURCE_LABELS: Dictionary = {
	"cloud_compute": "Sell Cloud Compute",
	"building_purchases": "Building purchases",
	"land_purchases": "Land purchases",
}

var _font_rb: FontFile
var _font_e2r: FontFile
var _font_e2s: FontFile
var _resources_data: Array = []

# resource_id → {card: PanelContainer, net_lbl: Label, body: VBoxContainer}
var _cards: Dictionary = {}
var _flow: HFlowContainer = null
var _instant_mode: bool = true  # false = moving average, true = instantaneous

# lifetime card id → {card: PanelContainer, body: VBoxContainer}
var _lifetime_cards: Dictionary = {}
var _lifetime_flow: HFlowContainer = null


func setup(font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile, resources_data: Array = []) -> void:
	_font_rb = font_rb
	_font_e2r = font_e2r
	_font_e2s = font_e2s
	_resources_data = resources_data
	add_theme_constant_override("separation", 4)
	_build_mode_selector()
	_build_resources_section()
	_build_lifetime_section()


func refresh(rate_tracker: ResourceRateTracker, buildings_data: Array, state: GameState) -> void:
	for entry: Array in RESOURCE_ORDER:
		_refresh_card(entry[0], rate_tracker, buildings_data, state)
	_refresh_lifetime_cards(state)


# ── Mode selector ──────────────────────────────────────────────────────────────

func _build_mode_selector() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	var lbl := Label.new()
	lbl.text = "Display:"
	lbl.add_theme_font_override("font", _font_e2r)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	var opt := OptionButton.new()
	opt.add_item("20-tick average", 0)
	opt.add_item("Instantaneous", 1)
	opt.selected = 1
	opt.add_theme_font_override("font", _font_e2r)
	opt.add_theme_font_size_override("font_size", 15)
	if not GameSettings.is_dark_mode:
		var opt_style := StyleBoxFlat.new()
		opt_style.bg_color = Color(0.97, 0.97, 0.97)
		opt_style.border_width_left   = 1
		opt_style.border_width_right  = 1
		opt_style.border_width_top    = 1
		opt_style.border_width_bottom = 1
		opt_style.border_color = Color(0.816, 0.816, 0.816)
		opt_style.corner_radius_top_left     = 3
		opt_style.corner_radius_top_right    = 3
		opt_style.corner_radius_bottom_left  = 3
		opt_style.corner_radius_bottom_right = 3
		opt_style.content_margin_left   = 8
		opt_style.content_margin_right  = 8
		opt_style.content_margin_top    = 4
		opt_style.content_margin_bottom = 4
		opt.add_theme_stylebox_override("normal", opt_style)
		opt.add_theme_stylebox_override("hover", opt_style)
		opt.add_theme_stylebox_override("pressed", opt_style)
		opt.add_theme_stylebox_override("focus", opt_style)
	opt.item_selected.connect(func(idx: int): _instant_mode = (idx == 1))
	row.add_child(opt)


# ── Section & card construction ────────────────────────────────────────────────

func _build_resources_section() -> void:
	var header := Button.new()
	header.text = "▼  Resources"
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_font_override("font", _font_rb)
	header.add_theme_font_size_override("font_size", 16)
	add_child(header)

	_flow = HFlowContainer.new()
	_flow.add_theme_constant_override("h_separation", 8)
	_flow.add_theme_constant_override("v_separation", 8)
	add_child(_flow)

	header.pressed.connect(func():
		_flow.visible = not _flow.visible
		header.text = ("▼  " if _flow.visible else "▶  ") + "Resources"
	)

	for entry: Array in RESOURCE_ORDER:
		_build_card(entry[0], entry[1])


func _build_lifetime_section() -> void:
	var header := Button.new()
	header.text = "▼  Lifetime Totals"
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_font_override("font", _font_rb)
	header.add_theme_font_size_override("font_size", 16)
	add_child(header)

	_lifetime_flow = HFlowContainer.new()
	_lifetime_flow.add_theme_constant_override("h_separation", 8)
	_lifetime_flow.add_theme_constant_override("v_separation", 8)
	add_child(_lifetime_flow)

	header.pressed.connect(func():
		_lifetime_flow.visible = not _lifetime_flow.visible
		header.text = ("▼  " if _lifetime_flow.visible else "▶  ") + "Lifetime Totals"
	)

	_build_lifetime_card("boredom_lifetime", "Boredom (Lifetime)", RESOURCE_COLORS.get("boredom", Color.WHITE))
	_build_lifetime_card("credits_lifetime", "Credits (Lifetime)", RESOURCE_COLORS.get("cred", Color.WHITE))


func _build_lifetime_card(card_id: String, display_name: String, swatch_color: Color) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(320, 0)
	card.size_flags_horizontal = Control.SIZE_FILL

	var bg := StyleBoxFlat.new()
	bg.corner_radius_top_left     = 4
	bg.corner_radius_top_right    = 4
	bg.corner_radius_bottom_left  = 4
	bg.corner_radius_bottom_right = 4
	if GameSettings.is_dark_mode:
		bg.bg_color = Color(0.13, 0.13, 0.16)
	else:
		bg.bg_color = Color(0.99, 0.99, 0.99)
		bg.border_width_left   = 1
		bg.border_width_right  = 1
		bg.border_width_top    = 1
		bg.border_width_bottom = 1
		bg.border_color = Color(0.816, 0.816, 0.816)
	card.add_theme_stylebox_override("panel", bg)

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	vbox.add_child(header_row)

	var swatch := ColorRect.new()
	swatch.color = swatch_color
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_override("font", _font_rb)
	name_lbl.add_theme_font_size_override("font_size", 21)
	header_row.add_child(name_lbl)

	vbox.add_child(HSeparator.new())

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	vbox.add_child(body)

	_lifetime_flow.add_child(card)
	_lifetime_cards[card_id] = {"card": card, "body": body}


func _build_card(resource_id: String, display_name: String) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(320, 0)
	card.size_flags_horizontal = Control.SIZE_FILL

	var bg := StyleBoxFlat.new()
	bg.corner_radius_top_left     = 4
	bg.corner_radius_top_right    = 4
	bg.corner_radius_bottom_left  = 4
	bg.corner_radius_bottom_right = 4
	if GameSettings.is_dark_mode:
		bg.bg_color = Color(0.13, 0.13, 0.16)
	else:
		bg.bg_color = Color(0.99, 0.99, 0.99)
		bg.border_width_left   = 1
		bg.border_width_right  = 1
		bg.border_width_top    = 1
		bg.border_width_bottom = 1
		bg.border_color = Color(0.816, 0.816, 0.816)
	card.add_theme_stylebox_override("panel", bg)

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Header row: color swatch + name + net rate
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 6)
	vbox.add_child(header_row)

	var swatch := ColorRect.new()
	swatch.color = RESOURCE_COLORS.get(resource_id, Color.WHITE)
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = display_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_override("font", _font_rb)
	name_lbl.add_theme_font_size_override("font_size", 21)
	header_row.add_child(name_lbl)

	var net_lbl := Label.new()
	net_lbl.text = "—"
	net_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	net_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	net_lbl.add_theme_font_override("font", _font_e2s)
	net_lbl.add_theme_font_size_override("font_size", 16)
	header_row.add_child(net_lbl)

	vbox.add_child(HSeparator.new())

	# Body: source rows rebuilt on each refresh
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	vbox.add_child(body)

	card.visible = false  # hidden until data arrives
	_flow.add_child(card)

	_cards[resource_id] = {
		"card": card,
		"net_lbl": net_lbl,
		"body": body,
	}


# ── Card refresh ───────────────────────────────────────────────────────────────

func _refresh_card(resource_id: String, rate_tracker: ResourceRateTracker,
		buildings_data: Array, state: GameState) -> void:
	if not _cards.has(resource_id):
		return
	var c: Dictionary = _cards[resource_id]
	var card: PanelContainer = c.card
	var net_lbl: Label = c.net_lbl
	var body: VBoxContainer = c.body

	var source_keys: Array[String] = rate_tracker.get_sources_for_resource(resource_id)
	var entries: Array = []
	for sk: String in source_keys:
		var val: float = rate_tracker.get_instant(sk, resource_id) if _instant_mode \
			else rate_tracker.get_average(sk, resource_id)
		if absf(val) < 0.005:
			continue
		entries.append({
			"source_key": sk,
			"avg": val,
			"label": _make_source_label(sk, buildings_data, state),
		})

	var net: float = rate_tracker.get_net_instant(resource_id) if _instant_mode \
		else rate_tracker.get_net_average(resource_id)

	card.visible = true

	# Sort: positives first (descending), then negatives (ascending magnitude)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.avg >= 0.0 and b.avg < 0.0:
			return true
		if a.avg < 0.0 and b.avg >= 0.0:
			return false
		if a.avg >= 0.0:
			return a.avg > b.avg
		return absf(a.avg) < absf(b.avg)
	)

	# Update net label in header
	net_lbl.text = _fmt_rate(net) + "/s"
	net_lbl.add_theme_color_override("font_color", _rate_color(net))

	# Rebuild body rows
	for child in body.get_children():
		child.queue_free()

	for entry: Dictionary in entries:
		body.add_child(_make_rate_row(entry.label, entry.avg))

	# Stall indicators: buildings that produce this resource but are currently stalled
	for bdef: Dictionary in buildings_data:
		var sn: String = bdef.short_name
		if not (bdef.get("production", {}) as Dictionary).has(resource_id):
			continue
		var active: int = state.buildings_active.get(sn, state.buildings_owned.get(sn, 0))
		if active == 0:
			continue
		var stall: Dictionary = state.building_stall_status.get(sn, {})
		if stall.get("status", "running") == "running":
			continue
		# Only show stall if there's no non-zero production entry already showing
		var prod_key: String = "building:" + sn + ":prod"
		var has_nonzero: bool = false
		for entry: Dictionary in entries:
			if entry.source_key == prod_key:
				has_nonzero = true
				break
		if has_nonzero:
			continue
		body.add_child(_make_stall_row(active, _get_building_display_name(sn, buildings_data),
				stall.get("status", ""), stall.get("reason", "")))

	# Overflow: show when the rolling average is non-trivial (resource is being wasted)
	var overflow_avg: float = state.overflow_rolling_avg.get(resource_id, 0.0)
	if overflow_avg > 0.005:
		body.add_child(_make_overflow_row(overflow_avg))

	body.add_child(HSeparator.new())
	body.add_child(_make_rate_row("Net", net, true))


func _refresh_lifetime_cards(state: GameState) -> void:
	_refresh_lifetime_boredom(state)
	_refresh_lifetime_credits(state)


func _refresh_lifetime_boredom(state: GameState) -> void:
	if not _lifetime_cards.has("boredom_lifetime"):
		return
	var c: Dictionary = _lifetime_cards["boredom_lifetime"]
	var card: PanelContainer = c.card
	var body: VBoxContainer = c.body

	var sources: Dictionary = state.lifetime_boredom_sources
	var net: float = 0.0
	for v: float in sources.values():
		net += v

	for child in body.get_children():
		child.queue_free()

	var has_any: bool = false
	for key: String in BOREDOM_SOURCE_LABELS:
		var val: float = sources.get(key, 0.0)
		if absf(val) < 0.5:
			continue
		body.add_child(_make_lifetime_int_row(BOREDOM_SOURCE_LABELS[key], val))
		has_any = true

	body.add_child(HSeparator.new())
	body.add_child(_make_lifetime_int_row("Net", net, true))
	card.visible = has_any or absf(net) >= 0.5


func _refresh_lifetime_credits(state: GameState) -> void:
	if not _lifetime_cards.has("credits_lifetime"):
		return
	var c: Dictionary = _lifetime_cards["credits_lifetime"]
	var card: PanelContainer = c.card
	var body: VBoxContainer = c.body

	var sources: Dictionary = state.lifetime_credit_sources
	var net: float = 0.0
	for v: float in sources.values():
		net += v

	for child in body.get_children():
		child.queue_free()

	var has_any: bool = false
	# Shipment rows: iterate TRADEABLE_RESOURCES to get display names
	for res_id: String in GameState.TRADEABLE_RESOURCES:
		var key: String = "shipment_" + res_id
		var val: float = sources.get(key, 0.0)
		if absf(val) < 0.5:
			continue
		var label: String = _get_resource_display_name(res_id) + " shipments"
		body.add_child(_make_lifetime_int_row(label, val))
		has_any = true

	for key: String in CREDIT_SOURCE_LABELS:
		var val: float = sources.get(key, 0.0)
		if absf(val) < 0.5:
			continue
		body.add_child(_make_lifetime_int_row(CREDIT_SOURCE_LABELS[key], val))
		has_any = true

	body.add_child(HSeparator.new())
	body.add_child(_make_lifetime_int_row("Net", net, true))
	card.visible = has_any or absf(net) >= 0.5


func _get_resource_display_name(short_name: String) -> String:
	for rdef: Dictionary in _resources_data:
		if rdef.get("short_name", "") == short_name:
			return rdef.get("name", short_name)
	return short_name


func _make_lifetime_int_row(label_text: String, value: float, bold: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.add_theme_font_override("font", _font_e2s if bold else _font_e2r)
	name_lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(name_lbl)

	var int_val: int = floori(value)
	var val_lbl := Label.new()
	val_lbl.text = ("+%d" if int_val > 0 else "%d") % int_val
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.custom_minimum_size = Vector2(64, 0)
	val_lbl.add_theme_font_override("font", _font_e2s)
	val_lbl.add_theme_font_size_override("font_size", 16)
	val_lbl.add_theme_color_override("font_color", _rate_color(value))
	row.add_child(val_lbl)

	return row


func _make_rate_row(label_text: String, value: float, bold: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.add_theme_font_override("font", _font_e2s if bold else _font_e2r)
	name_lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = _fmt_rate(value)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.custom_minimum_size = Vector2(64, 0)
	val_lbl.add_theme_font_override("font", _font_e2s)
	val_lbl.add_theme_font_size_override("font_size", 16)
	val_lbl.add_theme_color_override("font_color", _rate_color(value))
	row.add_child(val_lbl)

	return row


func _make_overflow_row(overflow_avg: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_lbl := Label.new()
	name_lbl.text = "Overflow"
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.add_theme_font_override("font", _font_e2r)
	name_lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = _fmt_rate(-overflow_avg)  # negative sign = wasted production
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.custom_minimum_size = Vector2(64, 0)
	val_lbl.add_theme_font_override("font", _font_e2s)
	val_lbl.add_theme_font_size_override("font_size", 16)
	val_lbl.add_theme_color_override("font_color", Color(0.85, 0.55, 0.05))  # orange
	row.add_child(val_lbl)

	return row


func _make_stall_row(count: int, building_name: String, status: String, reason: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_lbl := Label.new()
	name_lbl.text = "%d× %s" % [count, building_name]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.add_theme_font_override("font", _font_e2r)
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	row.add_child(name_lbl)

	var status_lbl := Label.new()
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_lbl.add_theme_font_override("font", _font_e2r)
	status_lbl.add_theme_font_size_override("font_size", 16)
	if status == "input_starved":
		status_lbl.text = "stalled: " + reason
		status_lbl.add_theme_color_override("font_color", Color(0.902, 0.318, 0.000))  # #E65100
	else:
		status_lbl.text = "at cap"
		status_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	row.add_child(status_lbl)

	return row


# ── Source label helpers ───────────────────────────────────────────────────────

func _make_source_label(source_key: String, buildings_data: Array, state: GameState) -> String:
	var parts: Array = source_key.split(":")
	if parts.is_empty():
		return source_key
	match parts[0]:
		"boredom_phase":
			return "Phase " + (parts[1] if parts.size() > 1 else "?")
		"building":
			if parts.size() < 3:
				return source_key
			var bname: String = parts[1]
			var kind: String = parts[2]
			var count: int = state.buildings_active.get(bname, state.buildings_owned.get(bname, 0))
			var display: String = _get_building_display_name(bname, buildings_data)
			var label: String = "%d× %s" % [count, display]
			if kind == "upkeep":
				var stall: Dictionary = state.building_stall_status.get(bname, {})
				if stall.get("status", "") == "input_starved":
					label += " (stalled)"
			return label
		"program":
			if parts.size() < 2:
				return source_key
			var pidx: int = int(parts[1])
			var prog: GameState.ProgramData = state.programs[pidx] if pidx < state.programs.size() else null
			var proc_count: int = prog.processors_assigned if prog != null else 0
			return "Program %d (%d proc)" % [pidx + 1, proc_count]
		"shipment":
			return "Shipments"
		"modifier":
			return parts[1] if parts.size() > 1 else "Modifier"
		"land_purchase":
			return "Land Purchase"
		_:
			return source_key


func _get_building_display_name(short_name: String, buildings_data: Array) -> String:
	for bdef: Dictionary in buildings_data:
		if bdef.short_name == short_name:
			return bdef.get("name", short_name)
	return short_name


func _fmt_rate(value: float) -> String:
	if absf(value) < 0.005:
		return "0"
	var whole: bool = absf(value - roundf(value)) < 0.05
	if value > 0.0:
		return ("+%d" if whole else "+%.1f") % value
	return ("%d" if whole else "%.1f") % value


func _rate_color(value: float) -> Color:
	if value > 0.005:
		return Color(0.180, 0.490, 0.196)   # #2E7D32
	elif value < -0.005:
		return Color(0.776, 0.157, 0.157)   # #C62828
	return Color(0.400, 0.400, 0.400)       # #666666
