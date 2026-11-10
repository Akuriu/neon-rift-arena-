extends Control

const Palette := preload("res://ui/skin.gd")

var mode := "page"
var wash: GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	if mode == "home":
		gradient.offsets = PackedFloat32Array([0.0, 0.34, 0.63, 0.84, 1.0])
		gradient.colors = PackedColorArray([Color("#171a17"), Color(0.09, 0.102, 0.088, 0.96),
			Color(0.09, 0.102, 0.088, 0.28), Color(0.09, 0.102, 0.088, 0.04), Color(0.09, 0.102, 0.088, 0.12)])
	else:
		var opacity := 0.90 if mode == "overlay" else 0.98
		gradient.offsets = PackedFloat32Array([0.0, 1.0])
		gradient.colors = PackedColorArray([Color(0.092, 0.105, 0.089, opacity), Color(0.137, 0.146, 0.120, opacity)])
	wash = GradientTexture2D.new()
	wash.gradient = gradient
	wash.width = 256
	wash.height = 4
	wash.fill_to = Vector2.RIGHT

func _draw() -> void:
	if wash == null:
		return
	draw_texture_rect(wash, Rect2(Vector2.ZERO, size), false)
	if mode == "home":
		var bottom := 62.0
		draw_rect(Rect2(0, size.y - bottom, size.x, bottom), Color(0.085, 0.095, 0.078, 0.83))
