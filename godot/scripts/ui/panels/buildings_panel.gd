class_name BuildingsPanel
extends VBoxContainer

const CATEGORY_ORDER: Array = ["Core", "Storage", "Extraction", "Processing", "Trade", "Science"]

var _font_rb: FontFile
var _font_e2r: FontFile
var _font_e2s: FontFile

var _card_nodes: Array = []
var _buy_land_card: BuyLandCard = null
var _visibility_snapshot: Array = []


func setup(font_rb: FontFile, font_e2r: FontFile, font_e2s: FontFile) -> void:
	_font_rb = font_rb
	_font_e2r = font_e2r
	_font_e2s = font_e2s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	_visibility_snapshot = _get_visible_building_ids()
	_build()


func on_tick() -> void:
	var cur_vis: Array = _get_visible_building_ids()
	if cur_vis != _visibility_snapshot:
		_visibility_snapshot = cur_vis
		for child in get_children():
			child.queue_free()
		_card_nodes.clear()
		_buy_land_card = null
		_build()
		return
	if _buy_land_card != null:
		_buy_land_card.refresh()
	for card: BuildingCard in _card_nodes:
		card.refresh()


func _get_visible_building_ids() -> Array:
	var result: Array = []
	for bdef: Dictionary in GameManager.get_buildings_data():
		if GameManager.is_building_visible(bdef.short_name):
			result.append(bdef.short_name)
	return result


func _build() -> void:
	_card_nodes.clear()
	_buy_land_card = null
	var buildings_data: Array = GameManager.get_buildings_data()

	var land_card := BuyLandCard.new()
	land_card.setup(_font_rb, _font_e2r, _font_e2s)
	add_child(land_card)
	_buy_land_card = land_card
	_buy_land_card.refresh()

	var by_category: Dictionary = {}
	for bdef: Dictionary in buildings_data:
		var cat: String = bdef.get("category", "Other")
		if not by_category.has(cat):
			by_category[cat] = []
		by_category[cat].append(bdef)

	var order: Array = CATEGORY_ORDER.duplicate()
	for cat: String in by_category:
		if not order.has(cat):
			order.append(cat)

	for cat: String in order:
		if by_category.has(cat):
			_add_category_section(cat, by_category[cat])


func _add_category_section(category: String, buildings: Array) -> void:
	# Filter to only visible buildings; skip category if none are visible.
	var visible_buildings: Array = []
	for bdef: Dictionary in buildings:
		if GameManager.is_building_visible(bdef.short_name):
			visible_buildings.append(bdef)
	if visible_buildings.is_empty():
		return

	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	add_child(section)

	var header := Button.new()
	header.text = "▼  " + category.to_upper()
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
		var arrow: String = "▼  " if flow.visible else "▶  "
		header.text = arrow + category.to_upper()
		_apply_category_header_style(header)
	)

	for bdef: Dictionary in visible_buildings:
		var card := BuildingCard.new()
		card.setup(bdef, _font_rb, _font_e2r, _font_e2s)
		card.refresh()
		flow.add_child(card)
		_card_nodes.append(card)


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
