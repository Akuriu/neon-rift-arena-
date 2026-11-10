extends Control

const Palette := preload("res://ui/skin.gd")
var mode := "page"
var wash: GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Art.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var base: Color = Art.palette().page
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	if mode == "home":
		gradient.offsets = PackedFloat32Array([0.0, 0.32, 0.53, 0.82, 1.0])
		gradient.colors = PackedColorArray([Color(base.darkened(0.36), 0.99), Color(base, 0.98),
			Color(base, 0.72), Color(base, 0.08), Color(base, 0.36)])
	else:
		var alpha := 0.82 if mode == "overlay" else 0.97
		gradient.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
		gradient.colors = PackedColorArray([Color(base, alpha), Color(base.lightened(0.05), alpha - 0.07),
			Color(base.darkened(0.24), alpha)])
	wash = GradientTexture2D.new()
	wash.gradient = gradient
	wash.width = 384
	wash.height = 8
	wash.fill_to = Vector2.RIGHT
	queue_redraw()

func _draw() -> void:
	if wash == null:
		return
	var ink: Color = Art.palette().ui
	draw_texture_rect(wash, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(0, 0, size.x, 4), Color(ink, 0.36))
	draw_rect(Rect2(0, size.y - 47, size.x, 47), Color(0.02, 0.042, 0.056, 0.93))
	draw_line(Vector2(0, size.y - 47), Vector2(size.x, size.y - 47), Color(ink, 0.18), 1)
	if mode == "home":
		var anchor := Vector2(size.x - 61, 69)
		draw_line(anchor, anchor + Vector2(-102, 0), Color(ink, 0.66), 2, true)
		draw_line(anchor, anchor + Vector2(0, 62), Color(ink, 0.66), 2, true)
		for i in 11:
			var y := 178.0 + i * 14.0
			draw_line(Vector2(size.x - 65, y), Vector2(size.x - (81 if i % 5 == 0 else 74), y),
				Color(ink, 0.40), 1, true)
	else:
		for i in 11:
			var x := size.x - 67.0 - i * 10.0
			draw_line(Vector2(x, 36), Vector2(x - 10, 52), Color(ink, 0.20 + i * 0.009), 2, true)
