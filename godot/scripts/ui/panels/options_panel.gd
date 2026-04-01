class_name OptionsPanel
extends VBoxContainer

var _font_rb: FontFile
var _font_e2r: FontFile
var _font_e2s: FontFile


func setup(font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_font_rb = font_rb
	_font_e2r = font_e2r
	_font_e2s = font_e2s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	_build()


func _build() -> void:
	var section_lbl := Label.new()
	section_lbl.text = "Display"
	section_lbl.add_theme_font_override("font", _font_rb)
	section_lbl.add_theme_font_size_override("font_size", 20)
	add_child(section_lbl)

	add_child(HSeparator.new())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	var lbl := Label.new()
	lbl.text = "Color scheme"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", _font_e2r)
	lbl.add_theme_font_size_override("font_size", 15)
	row.add_child(lbl)

	var grp := ButtonGroup.new()

	var dark_btn := Button.new()
	dark_btn.text = "Dark"
	dark_btn.toggle_mode = true
	dark_btn.button_group = grp
	dark_btn.button_pressed = GameSettings.is_dark_mode
	dark_btn.focus_mode = Control.FOCUS_NONE
	dark_btn.add_theme_font_override("font", _font_e2s)
	dark_btn.add_theme_font_size_override("font_size", 14)
	dark_btn.toggled.connect(func(on: bool): if on: GameSettings.is_dark_mode = true)
	row.add_child(dark_btn)

	var light_btn := Button.new()
	light_btn.text = "Light"
	light_btn.toggle_mode = true
	light_btn.button_group = grp
	light_btn.button_pressed = not GameSettings.is_dark_mode
	light_btn.focus_mode = Control.FOCUS_NONE
	light_btn.add_theme_font_override("font", _font_e2s)
	light_btn.add_theme_font_size_override("font_size", 14)
	light_btn.toggled.connect(func(on: bool): if on: GameSettings.is_dark_mode = false)
	row.add_child(light_btn)

	add_child(HSeparator.new())

	var debug_lbl := Label.new()
	debug_lbl.text = "Debug"
	debug_lbl.add_theme_font_override("font", _font_rb)
	debug_lbl.add_theme_font_size_override("font_size", 20)
	add_child(debug_lbl)

	add_child(HSeparator.new())

	var debug_desc := Label.new()
	debug_desc.text = "Ensures at least 20 solar panels, 5 storage depots, 3 launch pads, and 200 land, then fills all resources to cap."
	debug_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	debug_desc.add_theme_font_override("font", _font_e2r)
	debug_desc.add_theme_font_size_override("font_size", 13)
	debug_desc.add_theme_color_override("font_color", UIPalette.p("text_muted"))
	add_child(debug_desc)

	var debug_btn := Button.new()
	debug_btn.text = "Fill Resources"
	debug_btn.focus_mode = Control.FOCUS_NONE
	debug_btn.add_theme_font_override("font", _font_e2s)
	debug_btn.add_theme_font_size_override("font_size", 14)
	if not GameSettings.is_dark_mode:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.298, 0.686, 0.314)
		s.corner_radius_top_left     = 4
		s.corner_radius_top_right    = 4
		s.corner_radius_bottom_left  = 4
		s.corner_radius_bottom_right = 4
		debug_btn.add_theme_stylebox_override("normal", s)
		debug_btn.add_theme_color_override("font_color", Color.WHITE)
	debug_btn.pressed.connect(func():
		GameManager.debug_boost()
		debug_btn.text = "✓ Done"
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(debug_btn):
				debug_btn.text = "Fill Resources"
		)
	)
	add_child(debug_btn)

	var no_boredom_row := HBoxContainer.new()
	no_boredom_row.add_theme_constant_override("separation", 10)
	add_child(no_boredom_row)

	var no_boredom_lbl := Label.new()
	no_boredom_lbl.text = "Disable boredom gain"
	no_boredom_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no_boredom_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	no_boredom_lbl.add_theme_font_override("font", _font_e2r)
	no_boredom_lbl.add_theme_font_size_override("font_size", 14)
	no_boredom_lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
	no_boredom_row.add_child(no_boredom_lbl)

	var no_boredom_btn := CheckButton.new()
	no_boredom_btn.button_pressed = GameSettings.debug_no_boredom
	no_boredom_btn.focus_mode = Control.FOCUS_NONE
	no_boredom_btn.toggled.connect(func(on: bool): GameSettings.debug_no_boredom = on)
	no_boredom_row.add_child(no_boredom_btn)

	var show_all_row := HBoxContainer.new()
	show_all_row.add_theme_constant_override("separation", 10)
	add_child(show_all_row)

	var show_all_lbl := Label.new()
	show_all_lbl.text = "Show all cards"
	show_all_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	show_all_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	show_all_lbl.add_theme_font_override("font", _font_e2r)
	show_all_lbl.add_theme_font_size_override("font_size", 14)
	show_all_lbl.add_theme_color_override("font_color", UIPalette.p("text_muted"))
	show_all_row.add_child(show_all_lbl)

	var show_all_btn := CheckButton.new()
	show_all_btn.button_pressed = GameSettings.show_all_cards
	show_all_btn.focus_mode = Control.FOCUS_NONE
	show_all_btn.toggled.connect(func(on: bool): GameSettings.show_all_cards = on)
	show_all_row.add_child(show_all_btn)

	var clear_desc := Label.new()
	clear_desc.text = "Deletes the save file and resets to a fresh Run 1. Cannot be undone."
	clear_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clear_desc.add_theme_font_override("font", _font_e2r)
	clear_desc.add_theme_font_size_override("font_size", 13)
	clear_desc.add_theme_color_override("font_color", UIPalette.p("text_muted"))
	add_child(clear_desc)

	var clear_btn := Button.new()
	clear_btn.text = "Clear Save Data"
	clear_btn.focus_mode = Control.FOCUS_NONE
	clear_btn.add_theme_font_override("font", _font_e2s)
	clear_btn.add_theme_font_size_override("font_size", 14)
	var clear_s := StyleBoxFlat.new()
	clear_s.bg_color = Color(0.70, 0.18, 0.18)
	clear_s.corner_radius_top_left     = 4
	clear_s.corner_radius_top_right    = 4
	clear_s.corner_radius_bottom_left  = 4
	clear_s.corner_radius_bottom_right = 4
	clear_btn.add_theme_stylebox_override("normal", clear_s)
	clear_btn.add_theme_stylebox_override("hover", clear_s)
	clear_btn.add_theme_color_override("font_color", Color.WHITE)
	clear_btn.pressed.connect(func():
		if clear_btn.text == "Sure?":
			GameManager._debug_clear_save()
			clear_btn.text = "Clear Save Data"
		else:
			clear_btn.text = "Sure?"
			get_tree().create_timer(3.0).timeout.connect(func():
				if is_instance_valid(clear_btn) and clear_btn.text == "Sure?":
					clear_btn.text = "Clear Save Data"
			)
	)
	add_child(clear_btn)
