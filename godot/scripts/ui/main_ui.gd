extends Control

# [name, icon_color]
const RESOURCES: Array = [
	["Energy",       Color(1.00, 0.85, 0.00)],
	["Credits",      Color(0.20, 0.85, 0.20)],
	["Regolith",     Color(0.60, 0.42, 0.22)],
	["Ice",          Color(0.70, 0.92, 1.00)],
	["Helium-3",     Color(0.50, 0.50, 1.00)],
	["Land",         Color(0.40, 0.70, 0.30)],
	["Boredom",      Color(0.55, 0.55, 0.55)],
	["Processors",   Color(0.80, 0.20, 0.80)],
	["Silicon",      Color(0.72, 0.72, 0.62)],
	["Iron",         Color(0.62, 0.32, 0.22)],
	["Titanium",     Color(0.70, 0.72, 0.82)],
	["Water",        Color(0.20, 0.50, 0.90)],
	["Oxygen",       Color(0.60, 0.92, 1.00)],
	["Nitrogen",     Color(0.30, 0.30, 0.82)],
	["Carbon",       Color(0.25, 0.25, 0.25)],
	["Xenon",        Color(0.70, 0.40, 1.00)],
	["Deuterium",    Color(0.90, 0.52, 0.10)],
	["Thorium",      Color(0.10, 0.72, 0.52)],
	["Dark Matter",  Color(0.20, 0.05, 0.35)],
	["Quantum Foam", Color(0.90, 0.10, 0.90)],
	["Exotic Matter",Color(1.00, 0.30, 0.30)],
	["Void Crystals",Color(0.42, 0.00, 0.62)],
]

const NAV_LABELS: Array = [
	"Commands", "Buildings", "Research", "Projects",
	"Ideologies", "Adversaries", "Stats", "Achievements", "Options", "Exit",
]

const SPEEDS: Array = ["||", "1x", "3x", "10x", "50x", "200x"]


func _ready() -> void:
	_build_left_sidebar()
	_connect_program_slots()


# ── Left sidebar ───────────────────────────────────────────────────────────────

func _build_left_sidebar() -> void:
	var nav_vbox: VBoxContainer = $MainVBox/ContentHBox/LeftSidebar/SidebarScroll/NavVBox

	for label: String in NAV_LABELS:
		var btn := Button.new()
		btn.text = label
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): print(label))
		nav_vbox.add_child(btn)

	nav_vbox.add_child(HSeparator.new())
	_build_speed_section(nav_vbox)

	nav_vbox.add_child(HSeparator.new())
	_build_resources_section(nav_vbox)


func _make_collapsible_section(parent: VBoxContainer, title: String) -> VBoxContainer:
	var header := Button.new()
	header.text = "▼  " + title
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(header)

	var body := VBoxContainer.new()
	parent.add_child(body)

	header.pressed.connect(func():
		body.visible = not body.visible
		header.text = ("▼  " if body.visible else "▶  ") + title
	)

	return body


func _build_speed_section(parent: VBoxContainer) -> void:
	var body := _make_collapsible_section(parent, "Speed up time")

	var row := HBoxContainer.new()
	body.add_child(row)

	var grp := ButtonGroup.new()
	for speed: String in SPEEDS:
		var btn := Button.new()
		btn.text = speed
		btn.toggle_mode = true
		btn.button_group = grp
		if speed == "1x":
			btn.button_pressed = true
		btn.pressed.connect(func(): print("Speed: " + speed))
		row.add_child(btn)


func _build_resources_section(parent: VBoxContainer) -> void:
	var body := _make_collapsible_section(parent, "Resources")

	for entry: Array in RESOURCES:
		_add_resource_row(body, entry[0], entry[1])


func _add_resource_row(parent: VBoxContainer, res_name: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	# Colored icon placeholder
	var icon_wrap := CenterContainer.new()
	icon_wrap.custom_minimum_size = Vector2(22, 22)
	row.add_child(icon_wrap)

	var icon := ColorRect.new()
	icon.color = color
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_wrap.add_child(icon)

	# Name (expands to fill)
	var name_lbl := Label.new()
	name_lbl.text = res_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_lbl)

	# current / max
	var val_lbl := Label.new()
	val_lbl.text = "0 / 100"
	val_lbl.custom_minimum_size = Vector2(72, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(val_lbl)

	# rate
	var rate_lbl := Label.new()
	rate_lbl.text = "+0.0/s"
	rate_lbl.custom_minimum_size = Vector2(52, 0)
	rate_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rate_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(rate_lbl)


# ── Right panel ────────────────────────────────────────────────────────────────

func _connect_program_slots() -> void:
	var slots := $MainVBox/ContentHBox/RightPanel/RightVBox/ProgramSlots
	for btn: Button in slots.get_children():
		btn.pressed.connect(func(): print("Program slot: " + btn.text))
