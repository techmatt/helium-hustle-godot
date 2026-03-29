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

var _font_rb: FontFile
var _font_e2r: FontFile
var _font_e2s: FontFile

# resource_id → {card: PanelContainer, net_lbl: Label, body: VBoxContainer}
var _cards: Dictionary = {}
var _flow: HFlowContainer = null
var _instant_mode: bool = false  # false = moving average, true = instantaneous


func setup(font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_font_rb = font_rb
	_font_e2r = font_e2r
	_font_e2s = font_e2s
	add_theme_constant_override("separation", 4)
	_build_mode_selector()
	_build_resources_section()


func refresh(rate_tracker: ResourceRateTracker, buildings_data: Array, state: GameState) -> void:
	for entry: Array in RESOURCE_ORDER:
		_refresh_card(entry[0], rate_tracker, buildings_data, state)


# ── Mode selector ──────────────────────────────────────────────────────────────

func _build_mode_selector() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	var lbl := Label.new()
	lbl.text = "Display:"
	lbl.add_theme_font_override("font", _font_e2r)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	var opt := OptionButton.new()
	opt.add_item("20-tick average", 0)
	opt.add_item("Instantaneous", 1)
	opt.selected = 0
	opt.add_theme_font_override("font", _font_e2r)
	opt.add_theme_font_size_override("font_size", 13)
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
	net_lbl.add_theme_font_size_override("font_size", 14)
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
	net_lbl.text = _fmt_rate(net) + "/tick"
	net_lbl.add_theme_color_override("font_color", _rate_color(net))

	# Rebuild body rows
	for child in body.get_children():
		child.queue_free()

	for entry: Dictionary in entries:
		body.add_child(_make_rate_row(entry.label, entry.avg))

	body.add_child(HSeparator.new())
	body.add_child(_make_rate_row("Net", net, true))


func _make_rate_row(label_text: String, value: float, bold: bool = false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	name_lbl.add_theme_font_override("font", _font_e2s if bold else _font_e2r)
	name_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = _fmt_rate(value)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.custom_minimum_size = Vector2(64, 0)
	val_lbl.add_theme_font_override("font", _font_e2s)
	val_lbl.add_theme_font_size_override("font_size", 14)
	val_lbl.add_theme_color_override("font_color", _rate_color(value))
	row.add_child(val_lbl)

	return row


# ── Source label helpers ───────────────────────────────────────────────────────

func _make_source_label(source_key: String, buildings_data: Array, state: GameState) -> String:
	var parts: Array = source_key.split(":")
	if parts.is_empty():
		return source_key
	match parts[0]:
		"building":
			if parts.size() < 3:
				return source_key
			var bname: String = parts[1]
			var _kind: String = parts[2]
			var count: int = state.buildings_active.get(bname, state.buildings_owned.get(bname, 0))
			var display: String = _get_building_display_name(bname, buildings_data)
			return "%d× %s" % [count, display]
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
	if value > 0.0:
		return "+%.1f" % value
	elif value < 0.0:
		return "%.1f" % value
	return "0.0"


func _rate_color(value: float) -> Color:
	if value > 0.005:
		return Color(0.180, 0.490, 0.196)   # #2E7D32
	elif value < -0.005:
		return Color(0.776, 0.157, 0.157)   # #C62828
	return Color(0.400, 0.400, 0.400)       # #666666
