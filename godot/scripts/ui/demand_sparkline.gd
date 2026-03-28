class_name DemandSparkline
extends Control

var _history: Array = []
var _color: Color = Color.WHITE


func set_data(history: Array, color: Color) -> void:
	_history = history
	_color = color
	queue_redraw()


func _draw() -> void:
	# Background — dark navy so the line range is easy to read against any UI color
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.07, 0.13, 1.0))

	var n: int = _history.size()
	if n < 2:
		# Draw a horizontal midline when there's no data
		var mid_y: float = size.y * 0.5
		draw_line(Vector2(0, mid_y), Vector2(size.x, mid_y), Color(_color, 0.3), 1.0)
		return

	var w: float = size.x
	var h: float = size.y

	# Dim mid-line guide
	draw_line(Vector2(0, h * 0.5), Vector2(w, h * 0.5), Color(0.5, 0.5, 0.5, 0.25), 1.0)

	# Build polyline from demand history (demand 0–1, Y inverted)
	var points := PackedVector2Array()
	points.resize(n)
	for i in range(n):
		var x: float = (float(i) / float(n - 1)) * w
		var y: float = h - clampf(float(_history[i]), 0.0, 1.0) * h
		points[i] = Vector2(x, y)
	draw_polyline(points, _color, 1.5, true)
