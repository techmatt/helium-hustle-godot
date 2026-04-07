class_name UIPalette

const PALETTE: Dictionary = {
	"dark": {
		"text_positive":   Color(0.498, 0.749, 0.498),
		"text_negative":   Color(0.749, 0.498, 0.498),
		"text_zero":       Color(0.502, 0.502, 0.502),
		"text_muted":      Color(0.60,  0.60,  0.60 ),
		"text_dim":        Color(0.50,  0.50,  0.50 ),
		"text_locked":     Color(0.45,  0.45,  0.45 ),
		"text_count":      Color(0.75,  0.75,  0.75 ),
		"text_requires":   Color(0.65,  0.45,  0.45 ),
		"bg_nav_active":   Color(0.08,  0.22,  0.08 ),
		"bg_tab_selected": Color(0.05,  0.30,  0.05 ),
		"bg_tab_has_cmds": Color(0.08,  0.16,  0.08 ),
		"bg_tab_empty":    Color(0.10,  0.10,  0.10 ),
		"bg_card_locked":  Color(0.07,  0.07,  0.09 ),
		"bg_can_afford":   Color(0.20,  0.40,  0.20,  0.35),
		"bg_cant_afford":  Color(0.40,  0.20,  0.20,  0.35),
		"bg_cmd_active":   Color(0.10,  0.30,  0.10,  0.90),
		"bg_cmd_failed":   Color(0.30,  0.10,  0.10,  0.90),
		"fill_normal":     Color(0.25,  0.55,  0.25 ),
		"fill_active":     Color(0.20,  0.75,  0.20 ),
		"fill_failed":     Color(0.70,  0.20,  0.20 ),
		"bg_drag_preview": Color(0.05,  0.28,  0.05,  0.92),
		"grip":            Color(0.50,  0.50,  0.50 ),
	},
	"light": {
		"text_positive":   Color(0.12, 0.40, 0.14),
		"text_negative":   Color(0.776, 0.157, 0.157),
		"text_zero":       Color(0.400, 0.400, 0.400),
		"text_muted":      Color(0.400, 0.400, 0.400),
		"text_dim":        Color(0.400, 0.400, 0.400),
		"text_locked":     Color(0.620, 0.620, 0.620),
		"text_count":      Color(0.400, 0.400, 0.400),
		"text_requires":   Color(0.580, 0.290, 0.000),
		"bg_nav_active":   Color(0.298, 0.686, 0.314),
		"bg_tab_selected": Color(0.298, 0.686, 0.314),
		"bg_tab_has_cmds": Color(0.878, 0.961, 0.886),
		"bg_tab_empty":    Color(1.000, 1.000, 1.000),
		"bg_card_locked":  Color(0.961, 0.961, 0.961),
		"bg_can_afford":   Color(0.000, 0.000, 0.000, 0.000),
		"bg_cant_afford":  Color(0.000, 0.000, 0.000, 0.000),
		"bg_cmd_active":   Color(0.878, 0.961, 0.886, 0.90),
		"bg_cmd_failed":   Color(0.988, 0.878, 0.878, 0.90),
		"fill_normal":     Color(0.298, 0.686, 0.314),
		"fill_active":     Color(0.12, 0.40, 0.14),
		"fill_failed":     Color(0.776, 0.157, 0.157),
		"bg_drag_preview": Color(0.298, 0.686, 0.314, 0.92),
		"grip":            Color(0.620, 0.620, 0.620),
	},
}

static func p(key: String) -> Color:
	return PALETTE["dark" if GameSettings.is_dark_mode else "light"][key]


static func launch_entry_color(entry_type: String) -> Color:
	match entry_type:
		"player_launch":
			return Color(0.25, 0.75, 0.25)
		"rival_flood", "speculator_surge":
			return Color(0.9, 0.35, 0.2)
		_:
			return p("text_muted")
