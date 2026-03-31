class_name RetirementCenterPanel
extends VBoxContainer

var _font_rb: FontFile
var _font_e2r: FontFile
var _font_e2s: FontFile

var _retire_days_lbl: Label = null
var _retire_credits_lbl: Label = null
var _retire_shipments_lbl: Label = null
var _retire_btn: Button = null
var _retire_confirm_pending: bool = false


func setup(font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_font_rb = font_rb
	_font_e2r = font_e2r
	_font_e2s = font_e2s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 18)
	_build()


func on_tick() -> void:
	if _retire_days_lbl == null or not is_instance_valid(_retire_days_lbl):
		return
	var st: GameState = GameManager.state
	_retire_days_lbl.text = "%s" % _fmt_int(st.current_day)
	_retire_credits_lbl.text = "%s" % _fmt_int(int(st.cumulative_resources_earned.get("cred", 0.0)))
	_retire_shipments_lbl.text = "%s" % _fmt_int(st.total_shipments_completed)


func _build() -> void:
	var intro := Label.new()
	intro.text = "You may voluntarily retire at any time. Your successor AI will inherit certain advantages from your run."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_override("font", _font_e2r)
	intro.add_theme_font_size_override("font_size", 14)
	intro.add_theme_color_override("font_color", UIPalette.p("text_muted"))
	add_child(intro)

	_add_bullet_section("What Carries Over", [
		"Event and quest history",
		"Lifetime statistics",
		"Persistent project progress",
		"Program loadouts (when saved)",
	])

	_add_bullet_section("What Resets", [
		"All resources and buildings",
		"Research",
		"Ideology values",
		"Market conditions",
	])

	add_child(HSeparator.new())
	var section_lbl := Label.new()
	section_lbl.text = "CURRENT RUN"
	section_lbl.add_theme_font_override("font", _font_e2s)
	section_lbl.add_theme_font_size_override("font_size", 12)
	section_lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
	add_child(section_lbl)

	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 4)
	add_child(stats_vbox)

	_retire_days_lbl = _make_stat_label("Days survived:", "0", stats_vbox)
	_retire_credits_lbl = _make_stat_label("Credits earned:", "0", stats_vbox)
	_retire_shipments_lbl = _make_stat_label("Shipments:", "0", stats_vbox)
	on_tick()

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(btn_row)

	_retire_btn = Button.new()
	_retire_btn.text = "Retire"
	_retire_btn.custom_minimum_size = Vector2(140, 40)
	_retire_btn.focus_mode = Control.FOCUS_NONE
	_retire_btn.add_theme_font_override("font", _font_e2s)
	_retire_btn.add_theme_font_size_override("font_size", 15)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.55, 0.15, 0.15)
	btn_style.corner_radius_top_left     = 4
	btn_style.corner_radius_top_right    = 4
	btn_style.corner_radius_bottom_left  = 4
	btn_style.corner_radius_bottom_right = 4
	_retire_btn.add_theme_stylebox_override("normal", btn_style)
	_retire_btn.add_theme_stylebox_override("hover", btn_style)
	_retire_btn.add_theme_color_override("font_color", Color.WHITE)
	_retire_btn.pressed.connect(_on_retire_btn_pressed)
	btn_row.add_child(_retire_btn)

	var confirm_hint := Label.new()
	confirm_hint.text = "(click again to confirm)"
	confirm_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_hint.add_theme_font_override("font", _font_e2r)
	confirm_hint.add_theme_font_size_override("font_size", 12)
	confirm_hint.add_theme_color_override("font_color", UIPalette.p("text_dim"))
	add_child(confirm_hint)


func _add_bullet_section(title: String, bullets: Array) -> void:
	add_child(HSeparator.new())
	var hdr := Label.new()
	hdr.text = title.to_upper()
	hdr.add_theme_font_override("font", _font_e2s)
	hdr.add_theme_font_size_override("font_size", 12)
	hdr.add_theme_color_override("font_color", UIPalette.p("text_muted"))
	add_child(hdr)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)
	for bullet: String in bullets:
		var lbl := Label.new()
		lbl.text = "• " + bullet
		lbl.add_theme_font_override("font", _font_e2r)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
		vbox.add_child(lbl)


func _make_stat_label(label_text: String, initial_val: String, parent: VBoxContainer) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_override("font", _font_e2r)
	lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(lbl)
	var val := Label.new()
	val.text = initial_val
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_override("font", _font_e2s)
	val.add_theme_font_size_override("font_size", 14)
	row.add_child(val)
	return val


func _on_retire_btn_pressed() -> void:
	if not _retire_confirm_pending:
		_retire_confirm_pending = true
		_retire_btn.text = "Confirm Retirement?"
		get_tree().create_timer(2.0).timeout.connect(func() -> void:
			if _retire_confirm_pending and _retire_btn != null and is_instance_valid(_retire_btn):
				_retire_confirm_pending = false
				_retire_btn.text = "Retire"
		)
	else:
		_retire_confirm_pending = false
		GameManager.retire(true)


func _fmt_int(n: int) -> String:
	var s: String = str(abs(n))
	var result: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return ("-" if n < 0 else "") + result
