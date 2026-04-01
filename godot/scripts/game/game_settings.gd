extends Node

signal theme_changed

var is_dark_mode: bool = false:
	set(v):
		is_dark_mode = v
		theme_changed.emit()

var debug_no_boredom: bool = false
var show_all_cards: bool = false
