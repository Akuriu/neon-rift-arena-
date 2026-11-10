extends Control

var mark := ""
var ink := Color.WHITE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_set_transform(size * 0.5, 0.0, size / 24.0)
	match mark:
		"play":
			draw_colored_polygon(PackedVector2Array([Vector2(-5, -7), Vector2(7, 0), Vector2(-5, 7)]), ink)
		"arrow", "back":
			var sign := -1.0 if mark == "back" else 1.0
			_stroke([Vector2(-7 * sign, 0), Vector2(7 * sign, 0)])
			_stroke([Vector2(2 * sign, -5), Vector2(7 * sign, 0), Vector2(2 * sign, 5)])
		"target":
			draw_arc(Vector2.ZERO, 7.0, 0, TAU, 32, ink, 1.6, true)
			for axis in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_line(axis * 4.0, axis * 10.0, ink, 1.5, true)
		"progress":
			_stroke([Vector2(-8, 7), Vector2(-8, 3), Vector2(-4, 3), Vector2(-4, 7), Vector2(-4, -1),
				Vector2(0, -1), Vector2(0, 7), Vector2(0, -6), Vector2(5, -6), Vector2(5, 7)])
			draw_line(Vector2(-10, 7), Vector2(8, 7), ink, 1.7, true)
		"settings":
			for row in [-6, 0, 6]:
				var x: float = 3 if row == 0 else -3
				draw_line(Vector2(-8, row), Vector2(8, row), ink, 1.7, true)
				draw_rect(Rect2(x - 1.8, row - 2.0, 3.6, 4.0), ink)
		"info":
			draw_arc(Vector2.ZERO, 8.0, 0, TAU, 32, ink, 1.6, true)
			draw_circle(Vector2(0, -3.6), 1.0, ink, true, -1, true)
			draw_line(Vector2(0, -0.7), Vector2(0, 4.4), ink, 1.7, true)
		"quit":
			_stroke([Vector2(1, -8), Vector2(-8, -8), Vector2(-8, 8), Vector2(1, 8)])
			_stroke([Vector2(3, -4), Vector2(7, 0), Vector2(3, 4)])
			draw_line(Vector2(-3, 0), Vector2(7, 0), ink, 1.7, true)

func _stroke(points: Array) -> void:
	draw_polyline(PackedVector2Array(points), ink, 1.7, true)
