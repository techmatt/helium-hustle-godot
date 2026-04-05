class_name LeftSidebar
extends Node

signal mode_requested(mode: String)

const RESOURCES: Array = [
	["boredom","Boredom",    Color(0.55, 0.55, 0.55)],
	["eng",    "Energy",     Color(1.00, 0.85, 0.00)],
	["proc",   "Processors", Color(0.80, 0.20, 0.80)],
	["land",   "Land",       Color(0.40, 0.70, 0.30)],
	["reg",    "Regolith",   Color(0.60, 0.42, 0.22)],
	["ice",    "Ice",        Color(0.70, 0.92, 1.00)],
	["he3",    "Helium-3",   Color(0.50, 0.50, 1.00)],
	["ti",     "Titanium",   Color(0.80, 0.80, 0.80)],
	["cir",    "Circuit Boards", Color(0.30, 0.80, 0.70)],
	["prop",   "Propellant", Color(0.40, 0.70, 0.95)],
	["cred",   "Credits",    Color(0.20, 0.85, 0.20)],
	["sci",    "Science",    Color(0.70, 0.50, 0.90)],
]

const NAV_ITEMS: Array = [
	["Buildings",   Color(0.30, 0.65, 0.90)],
	["Commands",    Color(0.90, 0.60, 0.10)],
	["Launch Pads", Color(0.95, 0.55, 0.10)],
	["Research",    Color(0.55, 0.35, 0.90)],
	["Projects",    Color(0.20, 0.75, 0.50)],
	["Ideologies",  Color(0.90, 0.30, 0.30)],
	["Adversaries", Color(0.80, 0.20, 0.20)],
	["Stats",       Color(0.40, 0.80, 0.80)],
	["Story",       Color(0.95, 0.80, 0.10)],
	["Retirement",  Color(0.60, 0.30, 0.80)],
	["Options",     Color(0.60, 0.60, 0.65)],
	["Exit",        Color(0.50, 0.15, 0.15)],
]

const HIDDEN_NAV_PANELS: Dictionary = {
	"retirement":  "Retirement",
	"projects":    "Projects",
	"ideologies":  "Ideologies",
}

# Nav buttons gated on building ownership (this run OR career lifetime).
const BUILDING_GATED_NAV_PANELS: Dictionary = {
	"launch_pad":   "Launch Pads",
	"research_lab": "Research",
}

# Mapping from nav button label to the panel_id used in newly_revealed_nav.
const NAV_LABEL_TO_ID: Dictionary = {
	"Retirement":  "retirement",
	"Projects":    "projects",
	"Ideologies":  "ideologies",
	"Launch Pads": "launch_pad",
	"Research":    "research_lab",
}

const NEW_ACCENT_COLOR: Color = Color(0.961, 0.620, 0.043)  # #F59E0B gold/amber

const SPEEDS: Array = ["||", "1x", "3x", "10x", "50x", "200x"]

const TRADEABLE_DISPLAY: Dictionary = {
	"he3":  ["Helium-3",      Color(0.50, 0.50, 1.00)],
	"ti":   ["Titanium",      Color(0.80, 0.80, 0.80)],
	"cir":  ["Circuit Boards", Color(0.30, 0.80, 0.70)],
	"prop": ["Propellant",    Color(0.40, 0.70, 0.95)],
}

const IDEOLOGY_COLORS: Dictionary = {
	"nationalist": Color(0.776, 0.157, 0.157),
	"humanist":    Color(0.180, 0.490, 0.196),
	"rationalist": Color(0.086, 0.396, 0.753),
}

var _nav_vbox: VBoxContainer
var _font_rb: FontFile
var _font_e2r: FontFile
var _font_e2s: FontFile

var _nav_buttons: Dictionary = {}
var _nav_dots: Dictionary = {}  # button label → Panel (the notification dot)
var _resource_labels: Dictionary = {}
var _adversaries_section: Control = null
var _spec_rows: Dictionary = {}  # resource → {row: HBoxContainer, count_lbl: Label}
var _ideology_section: VBoxContainer = null
var _ideology_axis_rows: Dictionary = {}
var _ideology_prev_values: Dictionary = {"nationalist": 0.0, "humanist": 0.0, "rationalist": 0.0}
var _ideology_rate_ema: Dictionary = {"nationalist": 0.0, "humanist": 0.0, "rationalist": 0.0}


func setup(nav_vbox: VBoxContainer, font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_nav_vbox = nav_vbox
	_font_rb = font_rb
	_font_e2r = font_e2r
	_font_e2s = font_e2s
	_build()


func rebuild() -> void:
	for child in _nav_vbox.get_children():
		child.queue_free()
	_nav_buttons.clear()
	_nav_dots.clear()
	_resource_labels.clear()
	_adversaries_section = null
	_spec_rows.clear()
	_ideology_section = null
	_ideology_axis_rows = {}
	_ideology_prev_values = {"nationalist": 0.0, "humanist": 0.0, "rationalist": 0.0}
	_ideology_rate_ema = {"nationalist": 0.0, "humanist": 0.0, "rationalist": 0.0}
	_build()


func _build() -> void:
	var title := Label.new()
	title.text = "Helium Hustle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _font_rb)
	title.add_theme_font_size_override("font_size", 24)
	_nav_vbox.add_child(title)

	_nav_vbox.add_child(HSeparator.new())
	_build_nav_grid()

	_nav_vbox.add_child(HSeparator.new())
	_build_speed_section()

	_nav_vbox.add_child(HSeparator.new())
	_build_resources_section()

	_nav_vbox.add_child(HSeparator.new())
	_build_adversaries_section()
	_build_ideology_section()


# ── Nav ──────────────────────────────────────────────────────────────────────

func _build_nav_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_nav_vbox.add_child(grid)

	var unlocked_panels: Array = GameManager.state.unlocked_nav_panels
	for item: Array in NAV_ITEMS:
		var btn := _make_nav_button(item[0], item[1])
		grid.add_child(btn)
		_nav_buttons[item[0]] = btn
		for panel_id: String in HIDDEN_NAV_PANELS:
			if HIDDEN_NAV_PANELS[panel_id] == item[0]:
				btn.visible = GameSettings.show_all_cards or unlocked_panels.has(panel_id)
				break
		for bsn: String in BUILDING_GATED_NAV_PANELS:
			if BUILDING_GATED_NAV_PANELS[bsn] == item[0]:
				btn.visible = _is_building_gated_visible(bsn)
				break


func _make_nav_button(label: String, color: Color) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 96)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_contents = true
	if label == "Exit":
		btn.pressed.connect(func(): get_tree().quit())
	else:
		var nav_id: String = NAV_LABEL_TO_ID.get(label, "")
		btn.pressed.connect(func():
			mode_requested.emit(label)
			if not nav_id.is_empty():
				if GameManager.state.newly_revealed_nav.erase(nav_id):
					var dot: Panel = _nav_dots.get(label) as Panel
					if dot != null and is_instance_valid(dot):
						dot.visible = false
		)

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
	lbl.add_theme_font_override("font", _font_e2s)
	lbl.add_theme_font_size_override("font_size", 15)
	vbox.add_child(lbl)

	# Notification dot — top-right corner, shown when this nav panel is newly revealed
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = NEW_ACCENT_COLOR
	dot_style.corner_radius_top_left     = 5
	dot_style.corner_radius_top_right    = 5
	dot_style.corner_radius_bottom_left  = 5
	dot_style.corner_radius_bottom_right = 5
	var dot := Panel.new()
	dot.add_theme_stylebox_override("panel", dot_style)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.visible = false
	dot.set_anchor(SIDE_LEFT, 1.0)
	dot.set_anchor(SIDE_RIGHT, 1.0)
	dot.set_anchor(SIDE_TOP, 0.0)
	dot.set_anchor(SIDE_BOTTOM, 0.0)
	dot.set_offset(SIDE_LEFT, -13)
	dot.set_offset(SIDE_RIGHT, -3)
	dot.set_offset(SIDE_TOP, 3)
	dot.set_offset(SIDE_BOTTOM, 13)
	btn.add_child(dot)
	_nav_dots[label] = dot

	return btn


func _make_nav_inactive_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.941, 0.941, 0.941)
	s.corner_radius_top_left     = 4
	s.corner_radius_top_right    = 4
	s.corner_radius_bottom_left  = 4
	s.corner_radius_bottom_right = 4
	s.border_width_left   = 1
	s.border_width_right  = 1
	s.border_width_top    = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.816, 0.816, 0.816)
	return s


func update_nav_highlight(mode: String) -> void:
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = UIPalette.p("bg_nav_active")
	active_style.corner_radius_top_left     = 4
	active_style.corner_radius_top_right    = 4
	active_style.corner_radius_bottom_left  = 4
	active_style.corner_radius_bottom_right = 4
	for label: String in _nav_buttons:
		var btn: Button = _nav_buttons[label]
		if label == mode:
			btn.add_theme_stylebox_override("normal", active_style)
			if not GameSettings.is_dark_mode:
				btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			if not GameSettings.is_dark_mode:
				btn.add_theme_stylebox_override("normal", _make_nav_inactive_style())
				btn.remove_theme_color_override("font_color")
			else:
				btn.remove_theme_stylebox_override("normal")


func update_nav_visibility() -> void:
	var unlocked: Array = GameManager.state.unlocked_nav_panels
	for panel_id: String in HIDDEN_NAV_PANELS:
		var btn_label: String = HIDDEN_NAV_PANELS[panel_id]
		if _nav_buttons.has(btn_label):
			_nav_buttons[btn_label].visible = GameSettings.show_all_cards or unlocked.has(panel_id)
	for bsn: String in BUILDING_GATED_NAV_PANELS:
		var btn_label: String = BUILDING_GATED_NAV_PANELS[bsn]
		if _nav_buttons.has(btn_label):
			_nav_buttons[btn_label].visible = _is_building_gated_visible(bsn)


func update_nav_dots() -> void:
	var newly: Dictionary = GameManager.state.newly_revealed_nav
	for label: String in _nav_dots:
		var nav_id: String = NAV_LABEL_TO_ID.get(label, "")
		var dot: Panel = _nav_dots[label] as Panel
		if dot != null and is_instance_valid(dot):
			dot.visible = not nav_id.is_empty() and newly.has(nav_id)


func _is_building_gated_visible(building_short_name: String) -> bool:
	if GameSettings.show_all_cards:
		return true
	var st: GameState = GameManager.state
	return st.buildings_owned.get(building_short_name, 0) > 0


# ── Speed section ─────────────────────────────────────────────────────────────

func _build_speed_section() -> void:
	var body := _make_collapsible_section(_nav_vbox, "Speed up time")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	body.add_child(row)

	var grp := ButtonGroup.new()
	if not GameSettings.is_dark_mode:
		var active_s := StyleBoxFlat.new()
		active_s.bg_color = Color(0.298, 0.686, 0.314)
		active_s.corner_radius_top_left     = 3
		active_s.corner_radius_top_right    = 3
		active_s.corner_radius_bottom_left  = 3
		active_s.corner_radius_bottom_right = 3
		var inactive_s := StyleBoxFlat.new()
		inactive_s.bg_color = Color(0.941, 0.941, 0.941)
		inactive_s.corner_radius_top_left     = 3
		inactive_s.corner_radius_top_right    = 3
		inactive_s.corner_radius_bottom_left  = 3
		inactive_s.corner_radius_bottom_right = 3
		inactive_s.border_width_left   = 1
		inactive_s.border_width_right  = 1
		inactive_s.border_width_top    = 1
		inactive_s.border_width_bottom = 1
		inactive_s.border_color = Color(0.816, 0.816, 0.816)
		for speed: String in SPEEDS:
			var btn := Button.new()
			btn.text = speed
			btn.toggle_mode = true
			btn.button_group = grp
			if speed == GameManager.current_speed_key:
				btn.button_pressed = true
			btn.add_theme_font_override("font", _font_e2s)
			btn.add_theme_font_size_override("font_size", 17)
			btn.add_theme_stylebox_override("normal", inactive_s)
			btn.add_theme_stylebox_override("hover",  inactive_s)
			btn.add_theme_stylebox_override("pressed", active_s)
			btn.add_theme_color_override("font_color_pressed", Color.WHITE)
			btn.pressed.connect(func(): GameManager.set_speed(speed))
			row.add_child(btn)
	else:
		for speed: String in SPEEDS:
			var btn := Button.new()
			btn.text = speed
			btn.toggle_mode = true
			btn.button_group = grp
			if speed == GameManager.current_speed_key:
				btn.button_pressed = true
			btn.add_theme_font_override("font", _font_e2s)
			btn.add_theme_font_size_override("font_size", 17)
			btn.pressed.connect(func(): GameManager.set_speed(speed))
			row.add_child(btn)


# ── Resources section ─────────────────────────────────────────────────────────

func _build_resources_section() -> void:
	var body := _make_collapsible_section(_nav_vbox, "Resources")
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
	name_lbl.add_theme_font_override("font", _font_e2r)
	name_lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = "0 / 0"
	val_lbl.custom_minimum_size = Vector2(80, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_override("font", _font_e2s)
	val_lbl.add_theme_font_size_override("font_size", 16)
	row.add_child(val_lbl)

	var rate_lbl: Label = null
	if sn != "proc" and sn != "land":
		rate_lbl = Label.new()
		rate_lbl.text = "0/day"
		rate_lbl.custom_minimum_size = Vector2(72, 0)
		rate_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rate_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rate_lbl.add_theme_font_override("font", _font_e2r)
		rate_lbl.add_theme_font_size_override("font_size", 15)
		row.add_child(rate_lbl)

	_resource_labels[sn] = {"val": val_lbl, "rate": rate_lbl, "row": row}


func update_resource_display() -> void:
	var st: GameState = GameManager.state
	var rt: ResourceRateTracker = GameManager.rate_tracker
	var visible_resources: Array[String] = GameManager.get_visible_resources()
	for entry: Array in RESOURCES:
		var sn: String = entry[0]
		if not _resource_labels.has(sn):
			continue
		var labels: Dictionary = _resource_labels[sn]
		var row_node: HBoxContainer = labels.get("row")
		if row_node != null and is_instance_valid(row_node):
			row_node.visible = visible_resources.has(sn)
		if not visible_resources.has(sn):
			continue
		var val_lbl: Label = labels.val

		if sn == "proc":
			var assigned: int = 0
			for p: GameState.ProgramData in st.programs:
				assigned += p.processors_assigned
			val_lbl.text = "%d / %d" % [assigned, st.total_processors]
			val_lbl.remove_theme_color_override("font_color")
			continue

		var amount: float = st.amounts.get(sn, 0.0)
		var cap: float = st.caps.get(sn, INF)
		if cap == INF:
			val_lbl.text = "%d" % int(amount)
			val_lbl.remove_theme_color_override("font_color")
		else:
			val_lbl.text = "%d / %d" % [int(amount), int(cap)]
			if amount >= cap:
				val_lbl.add_theme_color_override("font_color", Color(0.180, 0.490, 0.196))
			elif amount <= 0.0:
				val_lbl.add_theme_color_override("font_color", Color(0.776, 0.157, 0.157))
			else:
				val_lbl.remove_theme_color_override("font_color")

		var rate_lbl: Label = labels.get("rate", null)
		if rate_lbl != null:
			var net: float = rt.get_net_instant(sn)
			rate_lbl.text = fmt_sidebar_rate(net)
			if net > 0.005:
				rate_lbl.add_theme_color_override("font_color", Color(0.180, 0.490, 0.196))
			elif net < -0.005:
				rate_lbl.add_theme_color_override("font_color", Color(0.776, 0.157, 0.157))
			else:
				rate_lbl.add_theme_color_override("font_color", Color(0.400, 0.400, 0.400))


# ── Adversaries section ───────────────────────────────────────────────────────

func _build_adversaries_section() -> void:
	# Wrap header+body in a container so the entire section can be hidden
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 0)
	_nav_vbox.add_child(wrapper)
	_adversaries_section = wrapper
	wrapper.visible = false  # hidden until at least one resource has ever had speculators

	var body := _make_collapsible_section(wrapper, "Adversaries")
	_spec_rows.clear()

	for res: String in GameState.TRADEABLE_RESOURCES:
		var display: Array = TRADEABLE_DISPLAY.get(res, [res.capitalize(), Color(0.90, 0.60, 0.10)])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.visible = false
		body.add_child(row)

		var icon_wrap := CenterContainer.new()
		icon_wrap.custom_minimum_size = Vector2(22, 22)
		row.add_child(icon_wrap)
		var icon := ColorRect.new()
		icon.color = display[1]
		icon.custom_minimum_size = Vector2(14, 14)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_wrap.add_child(icon)

		var name_lbl := Label.new()
		name_lbl.text = "Speculators (%s)" % str(display[0])
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_override("font", _font_e2r)
		name_lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(name_lbl)

		var count_lbl := Label.new()
		count_lbl.text = "0"
		count_lbl.custom_minimum_size = Vector2(40, 0)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_lbl.add_theme_font_override("font", _font_e2s)
		count_lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(count_lbl)

		_spec_rows[res] = {"row": row, "count_lbl": count_lbl}


func update_adversaries_display() -> void:
	if _adversaries_section == null or not is_instance_valid(_adversaries_section):
		return
	var st: GameState = GameManager.state
	var any_seen: bool = false
	for res: String in GameState.TRADEABLE_RESOURCES:
		var ever_seen: bool = st.speculators_ever_seen.get(res, false)
		if ever_seen:
			any_seen = true
		var entry: Dictionary = _spec_rows.get(res, {})
		var row_node = entry.get("row")
		var count_lbl: Label = entry.get("count_lbl")
		if row_node != null and is_instance_valid(row_node):
			row_node.visible = ever_seen
		if count_lbl != null and is_instance_valid(count_lbl):
			count_lbl.text = "%d" % int(st.speculators.get(res, 0.0))
	_adversaries_section.visible = any_seen


# ── Ideology section (sidebar) ────────────────────────────────────────────────

func _build_ideology_section() -> void:
	var wrapper := VBoxContainer.new()
	wrapper.add_theme_constant_override("separation", 0)
	_nav_vbox.add_child(wrapper)
	_ideology_section = wrapper

	wrapper.add_child(HSeparator.new())

	var body := _make_collapsible_section(wrapper, "Ideology")
	body.add_theme_constant_override("separation", 4)

	_ideology_axis_rows = {}
	for axis: String in ["nationalist", "humanist", "rationalist"]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		body.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = axis.capitalize()
		name_lbl.custom_minimum_size = Vector2(88, 0)
		name_lbl.add_theme_font_override("font", _font_e2s)
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", IDEOLOGY_COLORS[axis])
		row.add_child(name_lbl)

		var rank_lbl := Label.new()
		rank_lbl.text = "Rank 0"
		rank_lbl.custom_minimum_size = Vector2(52, 0)
		rank_lbl.add_theme_font_override("font", _font_e2s)
		rank_lbl.add_theme_font_size_override("font_size", 15)
		row.add_child(rank_lbl)

		var rate_lbl := Label.new()
		rate_lbl.text = ""
		rate_lbl.custom_minimum_size = Vector2(52, 0)
		rate_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rate_lbl.add_theme_font_override("font", _font_e2r)
		rate_lbl.add_theme_font_size_override("font_size", 14)
		rate_lbl.add_theme_color_override("font_color", Color(0.400, 0.400, 0.400))
		row.add_child(rate_lbl)

		var prog_lbl := Label.new()
		prog_lbl.text = "0 / 70"
		prog_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prog_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		prog_lbl.add_theme_font_override("font", _font_e2r)
		prog_lbl.add_theme_font_size_override("font_size", 14)
		prog_lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
		row.add_child(prog_lbl)

		_ideology_axis_rows[axis] = {"rank_lbl": rank_lbl, "rate_lbl": rate_lbl, "prog_lbl": prog_lbl}

	_ideology_section.visible = GameSettings.show_all_cards or GameManager.state.unlocked_nav_panels.has("ideologies")


func update_ideology_display() -> void:
	if _ideology_section == null or not is_instance_valid(_ideology_section):
		return
	var st: GameState = GameManager.state
	var unlocked: bool = GameSettings.show_all_cards or st.unlocked_nav_panels.has("ideologies")
	_ideology_section.visible = unlocked
	if not unlocked:
		return
	for axis: String in ["nationalist", "humanist", "rationalist"]:
		if not _ideology_axis_rows.has(axis):
			continue
		var refs: Dictionary = _ideology_axis_rows[axis]
		var rank_lbl: Label = refs.get("rank_lbl")
		var rate_lbl: Label = refs.get("rate_lbl")
		var prog_lbl: Label = refs.get("prog_lbl")
		if rank_lbl == null or not is_instance_valid(rank_lbl):
			continue
		var value: float = st.ideology_values.get(axis, 0.0)
		var rank: int = st.get_ideology_rank(axis)
		rank_lbl.text = "Rank %d" % rank
		prog_lbl.text = _ideology_progress_text(value, rank)
		var delta_val: float = value - _ideology_prev_values.get(axis, value)
		_ideology_prev_values[axis] = value
		_ideology_rate_ema[axis] = _ideology_rate_ema.get(axis, 0.0) * 0.96 + delta_val * 0.04
		if rate_lbl != null and is_instance_valid(rate_lbl):
			var rate: float = _ideology_rate_ema[axis]
			rate_lbl.text = fmt_sidebar_rate(rate)
			if rate > 0.005:
				rate_lbl.add_theme_color_override("font_color", Color(0.180, 0.490, 0.196))
			elif rate < -0.005:
				rate_lbl.add_theme_color_override("font_color", Color(0.776, 0.157, 0.157))
			else:
				rate_lbl.add_theme_color_override("font_color", Color(0.400, 0.400, 0.400))


func _ideology_progress_text(value: float, rank: int) -> String:
	if rank >= 99:
		return "MAX"
	if rank <= -99:
		return "MIN"
	if rank == 0 and value < 0.0:
		return "%d / -%d" % [int(value), int(GameState.score_for_rank(1.0))]
	if rank >= 0:
		return "%d / %d" % [int(value), int(GameState.score_for_rank(float(rank + 1)))]
	else:
		return "%d / -%d" % [int(value), int(GameState.score_for_rank(float(-rank + 1)))]


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


func fmt_sidebar_rate(value: float) -> String:
	if absf(value) < 0.005:
		return "0/day"
	var whole: bool = absf(value - roundf(value)) < 0.05
	if value > 0.0:
		return ("+%d/day" if whole else "+%.1f/day") % value
	return ("%d/day" if whole else "%.1f/day") % value
