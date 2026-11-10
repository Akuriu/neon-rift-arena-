extends Control

var mode := "page"
var wash: GradientTexture2D
var shade: GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	if mode == "home":
		wash = _wash(Vector2.RIGHT, [0.0, 0.29, 0.52, 0.71, 1.0],
			[0.99, 0.96, 0.63, 0.10, 0.04], Color("#181b17"))
		shade = _wash(Vector2.DOWN, [0.0, 0.18, 0.58, 0.84, 1.0],
			[0.72, 0.04, 0.0, 0.35, 0.98], Color("#141713"))
	elif mode == "tile":
		wash = _wash(Vector2.RIGHT, [0.0, 0.34, 1.0], [1.0, 0.40, 0.08], Color("#252922"))
		shade = _wash(Vector2.DOWN, [0.0, 0.65, 1.0], [0.09, 0.0, 0.51], Color("#161915"))
	else:
		var opacity := 0.90 if mode == "overlay" else 0.975
		wash = _wash(Vector2.RIGHT, [0.0, 0.62, 1.0], [opacity, opacity, opacity - 0.035], Color("#1b1e19"))

func _wash(axis: Vector2, stops: Array, values: Array, ink: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(stops)
	var colors := PackedColorArray()
	for alpha in values:
		colors.append(Color(ink, alpha))
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256 if axis.x > 0.0 else 4
	texture.height = 256 if axis.y > 0.0 else 4
	texture.fill_to = axis
	return texture

func _draw() -> void:
	if wash == null:
		return
	draw_texture_rect(wash, Rect2(Vector2.ZERO, size), false)
	if shade != null:
		draw_texture_rect(shade, Rect2(Vector2.ZERO, size), false)
