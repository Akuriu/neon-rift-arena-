extends Control

const Palette := preload("res://ui/skin.gd")
var mode := "page"
var wash: GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	if mode == "home":
		gradient.offsets = PackedFloat32Array([0.0, 0.32, 0.53, 0.82, 1.0])
		gradient.colors = PackedColorArray([Color(0.02, 0.04, 0.058, 0.98), Color(0.02, 0.04, 0.058, 0.95),
			Color(0.02, 0.04, 0.058, 0.42), Color(0.02, 0.04, 0.058, 0.04), Color(0.02, 0.04, 0.058, 0.30)])
	else:
		var alpha := 0.82 if mode == "overlay" else 0.97
		gradient.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
		gradient.colors = PackedColorArray([Color(0.033, 0.069, 0.088, alpha), Color(0.045, 0.087, 0.109, alpha - 0.07),
			Color(0.019, 0.039, 0.064, alpha)])
	wash = GradientTexture2D.new()
	wash.gradient = gradient
	wash.width = 384
	wash.height = 8
	wash.fill_to = Vector2.RIGHT

func _draw() -> void:
	if wash == null:
		return
	draw_texture_rect(wash, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(0, 0, size.x, 4), Color(Palette.CYAN, 0.36))
	draw_rect(Rect2(0, size.y - 47, size.x, 47), Color(0.02, 0.042, 0.056, 0.93))
	draw_line(Vector2(0, size.y - 47), Vector2(size.x, size.y - 47), Color(Palette.CYAN, 0.18), 1)
	if mode == "home":
		var anchor := Vector2(size.x - 61, 69)
		draw_line(anchor, anchor + Vector2(-102, 0), Color(Palette.CYAN, 0.66), 2, true)
		draw_line(anchor, anchor + Vector2(0, 62), Color(Palette.CYAN, 0.66), 2, true)
		for i in 11:
			var y := 178.0 + i * 14.0
			draw_line(Vector2(size.x - 65, y), Vector2(size.x - (81 if i % 5 == 0 else 74), y),
				Color(Palette.CYAN, 0.40), 1, true)
	else:
		for i in 11:
			var x := size.x - 67.0 - i * 10.0
			draw_line(Vector2(x, 36), Vector2(x - 10, 52), Color(Palette.CYAN, 0.20 + i * 0.009), 2, true)
