class_name CommandsPanel
extends VBoxContainer

signal command_add_requested(short_name: String)

const CMD_GROUPS: Dictionary = {
	"idle":               "Basic",
	"cloud_compute":      "Basic",
	"buy_regolith":       "Trade",
	"buy_ice":            "Trade",
	"buy_titanium":       "Trade",
	"buy_propellant":     "Trade",
	"load_pads":          "Operations",
	"launch_pads":        "Operations",
	"dream":              "Operations",
	"overclock_mining":   "Advanced",
	"overclock_factories":"Advanced",
	"promote_he3":        "Advanced",
	"promote_ti":         "Advanced",
	"promote_cir":        "Advanced",
	"promote_prop":       "Advanced",
	"disrupt_spec":       "Advanced",
	"fund_nationalist":   "Advanced",
	"fund_humanist":      "Advanced",
	"fund_rationalist":   "Advanced",
	"buy_power":          "Advanced",
}
const CMD_GROUP_ORDER: Array = ["Basic", "Trade", "Operations", "Advanced"]

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

var _buildings_snapshot: Dictionary = {}
var _research_snapshot: Array = []
var _lifetime_cmds_snapshot: Array = []


func setup(font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_font_rb = font_rb
	_font_e2r = font_e2r
	_font_e2s = font_e2s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	_buildings_snapshot = GameManager.state.buildings_owned.duplicate()
	_research_snapshot = GameManager.state.completed_research.duplicate()
	_lifetime_cmds_snapshot = GameManager.get_lifetime_used_command_ids()
	_build()


func on_tick() -> void:
	var cur_bld: Dictionary = GameManager.state.buildings_owned.duplicate()
	var cur_res: Array = GameManager.state.completed_research.duplicate()
	var cur_cmds: Array = GameManager.get_lifetime_used_command_ids()
	if cur_bld != _buildings_snapshot or cur_res != _research_snapshot \
			or cur_cmds != _lifetime_cmds_snapshot:
		_buildings_snapshot = cur_bld
		_research_snapshot = cur_res
		_lifetime_cmds_snapshot = cur_cmds
		for child in get_children():
			child.queue_free()
		_build()


func _build() -> void:
	var cmds: Array = GameManager.get_commands_data()
	var by_group: Dictionary = {}
	for cmd: Dictionary in cmds:
		var group: String = CMD_GROUPS.get(cmd.short_name, "Other")
		if not by_group.has(group):
			by_group[group] = []
		by_group[group].append(cmd)

	var order: Array = CMD_GROUP_ORDER.duplicate()
	for g: String in by_group:
		if not order.has(g):
			order.append(g)

	for group: String in order:
		if by_group.has(group):
			_add_group_section(group, by_group[group])


func _add_group_section(group: String, cmds: Array) -> void:
	# Filter to visible commands; skip group if none are visible.
	var visible_cmds: Array = []
	for cmd: Dictionary in cmds:
		if GameManager.is_command_visible(cmd.short_name):
			visible_cmds.append(cmd)
	if visible_cmds.is_empty():
		return

	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	add_child(section)

	var header := Button.new()
	header.text = "▼  " + group.to_upper()
	header.alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_font_override("font", _font_rb)
	header.add_theme_font_size_override("font_size", 15)
	_apply_category_header_style(header)
	section.add_child(header)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(flow)

	header.pressed.connect(func():
		flow.visible = not flow.visible
		header.text = ("▼  " if flow.visible else "▶  ") + group.to_upper()
		_apply_category_header_style(header)
	)

	for cmd: Dictionary in visible_cmds:
		flow.add_child(_build_command_card(cmd))


func _build_command_card(cmd: Dictionary) -> PanelContainer:
	var req: Dictionary = cmd.get("requires", {})
	var is_locked: bool = not _is_cmd_unlocked(req)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(310, 0)
	panel.size_flags_horizontal = Control.SIZE_FILL

	if not GameSettings.is_dark_mode:
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = UIPalette.p("bg_card_locked") if is_locked else Color.WHITE
		card_style.corner_radius_top_left     = 4
		card_style.corner_radius_top_right    = 4
		card_style.corner_radius_bottom_left  = 4
		card_style.corner_radius_bottom_right = 4
		card_style.border_width_left   = 1
		card_style.border_width_right  = 1
		card_style.border_width_top    = 1
		card_style.border_width_bottom = 1
		card_style.border_color = Color(0.816, 0.816, 0.816)
		panel.add_theme_stylebox_override("panel", card_style)
	elif is_locked:
		var locked_style := StyleBoxFlat.new()
		locked_style.bg_color = UIPalette.p("bg_card_locked")
		locked_style.corner_radius_top_left     = 4
		locked_style.corner_radius_top_right    = 4
		locked_style.corner_radius_bottom_left  = 4
		locked_style.corner_radius_bottom_right = 4
		panel.add_theme_stylebox_override("panel", locked_style)

	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Header row
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(header_hbox)

	var name_lbl := Label.new()
	name_lbl.text = cmd.name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_override("font", _font_rb)
	name_lbl.add_theme_font_size_override("font_size", 21)
	if is_locked:
		name_lbl.add_theme_color_override("font_color", UIPalette.p("text_locked"))
	header_hbox.add_child(name_lbl)

	var add_btn := Button.new()
	add_btn.text = "Add"
	add_btn.focus_mode = Control.FOCUS_NONE
	add_btn.custom_minimum_size = Vector2(70, 0)
	add_btn.add_theme_font_override("font", _font_e2s)
	add_btn.add_theme_font_size_override("font_size", 15)
	add_btn.disabled = is_locked
	if not GameSettings.is_dark_mode and not is_locked:
		var gs := StyleBoxFlat.new()
		gs.bg_color = Color(0.298, 0.686, 0.314)
		gs.corner_radius_top_left     = 4
		gs.corner_radius_top_right    = 4
		gs.corner_radius_bottom_left  = 4
		gs.corner_radius_bottom_right = 4
		add_btn.add_theme_stylebox_override("normal", gs)
		add_btn.add_theme_color_override("font_color", Color.WHITE)
	var sn: String = cmd.short_name
	add_btn.pressed.connect(func():
		command_add_requested.emit(sn)
		add_btn.text = "\u2713"
		get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(add_btn):
				add_btn.text = "Add"
		)
	)
	header_hbox.add_child(add_btn)

	# Costs / Produces columns
	var costs: Dictionary = cmd.get("costs", {})
	var production: Dictionary = cmd.get("production", {})
	if not costs.is_empty() or not production.is_empty():
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 10)
		vbox.add_child(cols)

		if not costs.is_empty():
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 2)
			cols.add_child(col)
			var hdr := Label.new()
			hdr.text = "Costs:"
			hdr.add_theme_font_override("font", _font_e2r)
			hdr.add_theme_font_size_override("font_size", 14)
			hdr.add_theme_color_override("font_color", UIPalette.p("text_muted"))
			col.add_child(hdr)
			for res: String in costs:
				col.add_child(_make_resource_line(res, costs[res], UIPalette.p("text_negative")))

		if not production.is_empty():
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 2)
			cols.add_child(col)
			var hdr := Label.new()
			hdr.text = "Produces:"
			hdr.add_theme_font_override("font", _font_e2r)
			hdr.add_theme_font_size_override("font_size", 14)
			hdr.add_theme_color_override("font_color", UIPalette.p("text_muted"))
			col.add_child(hdr)
			for res: String in production:
				col.add_child(_make_resource_line(res, production[res], UIPalette.p("text_positive")))

	# Effects
	for eff: Dictionary in cmd.get("effects", []):
		var text: String = _format_effect(eff)
		if text != "":
			var lbl := Label.new()
			lbl.text = text
			lbl.add_theme_font_override("font", _font_e2r)
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(lbl)

	# AI Consciousness Act boredom surcharge
	if GameManager.state.flags.get("ai_consciousness_active", false):
		const AI_BOREDOM: Dictionary = {
			"load_pads": 0.3,
			"cloud_compute": 0.2,
			"disrupt_spec": 0.5,
		}
		var ai_extra: float = float(AI_BOREDOM.get(cmd.get("short_name", ""), 0.0))
		if ai_extra > 0.0:
			var ai_lbl := Label.new()
			ai_lbl.text = "+%.1f boredom (AI Consciousness Act)" % ai_extra
			ai_lbl.add_theme_font_override("font", _font_e2r)
			ai_lbl.add_theme_font_size_override("font_size", 14)
			ai_lbl.add_theme_color_override("font_color", UIPalette.p("text_negative"))
			ai_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vbox.add_child(ai_lbl)

	# Requires line
	if is_locked:
		var req_text: String = _format_requires(req)
		var lbl := Label.new()
		lbl.text = req_text
		lbl.add_theme_font_override("font", _font_e2r)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", UIPalette.p("text_requires"))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(lbl)

	return panel


func _is_cmd_unlocked(req: Dictionary) -> bool:
	match req.get("type", "none"):
		"none":           return true
		"building":       return GameManager.state.buildings_owned.get(req.get("value", ""), 0) > 0
		"building_owned": return GameManager.state.buildings_owned.get(req.get("value", ""), 0) > 0
		"research":       return req.get("value", "") in GameManager.state.completed_research
	return false


func _make_resource_line(res: String, amount: float, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var meta: Array = RESOURCE_META.get(res, [res.capitalize(), UIPalette.p("text_muted")])

	var icon := ColorRect.new()
	icon.color = meta[1]
	icon.custom_minimum_size = Vector2(13, 13)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = meta[0]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_override("font", _font_e2r)
	name_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(name_lbl)

	var amt_lbl := Label.new()
	amt_lbl.text = ("%d" % int(amount)) if amount == int(amount) else ("%.1f" % amount)
	amt_lbl.add_theme_font_override("font", _font_e2s)
	amt_lbl.add_theme_font_size_override("font_size", 14)
	amt_lbl.add_theme_color_override("font_color", color)
	row.add_child(amt_lbl)

	return row


func _format_effect(eff: Dictionary) -> String:
	match eff.get("effect", ""):
		"boredom_add":
			var v: float = eff.get("value", 0.0)
			return ("%+.2f boredom per execution" % v)
		"load_pads":
			return "Loads %d units per enabled pad" % int(eff.get("value", 0))
		"launch_full_pads":
			return "Launches all full pads (20 propellant/pad)"
		"overclock":
			var pct: int = int(eff.get("bonus", 0.0) * 100)
			var target: String = eff.get("target", "")
			var dur: int = int(eff.get("duration", 0))
			return "+%d%% %s output for %d days" % [pct, target, dur]
		"demand_nudge":
			var res: String = eff.get("resource", "")
			var res_name: String = RESOURCE_META.get(res, [res.capitalize()])[0]
			var pct: int = int(eff.get("value", 0.0) * 100)
			return "+%d%% %s demand per execution" % [pct, res_name]
		"spec_reduce":
			var pct: int = int(eff.get("value", 0.0) * 100)
			return "Reduces speculator pressure by %d%%" % pct
		"ideology_push":
			var axis: String = eff.get("axis", "")
			return "+1 %s per execution" % axis.capitalize()
	return ""


func _format_requires(req: Dictionary) -> String:
	match req.get("type", "none"):
		"building", "building_owned":
			var bsn: String = req.get("value", "")
			for bdef: Dictionary in GameManager.get_buildings_data():
				if bdef.short_name == bsn:
					return "Requires: " + bdef.name
			return "Requires: " + bsn
		"research":
			var rid: String = req.get("value", "")
			for item: Dictionary in GameManager.get_research_data():
				if item.get("id", "") == rid:
					return "Requires: " + item.get("name", rid) + " research"
			return "Requires: " + rid + " research"
	return ""


func _apply_category_header_style(btn: Button) -> void:
	if not GameSettings.is_dark_mode:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.173, 0.243, 0.314)
		s.corner_radius_top_left     = 4
		s.corner_radius_top_right    = 4
		s.corner_radius_bottom_left  = 4
		s.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_stylebox_override("hover",  s)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_color_hover", Color.WHITE)
	else:
		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_stylebox_override("hover")
		btn.remove_theme_color_override("font_color")
		btn.remove_theme_color_override("font_color_hover")
