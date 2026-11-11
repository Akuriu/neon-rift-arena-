extends Control

const Tokens := preload("res://ui/design/tokens.gd")

var fraction := -1.0
var elapsed := 0.0
var active := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	update(-1.0, true)

func update(value: float, loading: bool) -> void:
	fraction = value
	active = loading
	set_process(active and fraction < 0.0 and Prefs.values.ui_motion)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed = fmod(elapsed + delta, 1.25)
	queue_redraw()

func _draw() -> void:
	if fraction >= 0.0:
		draw_rect(Rect2(0.0, 0.0, size.x, size.y), Tokens.EDGE)
		draw_rect(Rect2(0.0, 0.0, size.x * fraction, size.y), Tokens.ACCENT)
	elif active:
		for i in 3:
			var emphasis := 0.4 + 0.6 * pow(maxf(0.0, cos(TAU * (elapsed / 1.25 - i * 0.19))), 2.0)
			draw_rect(Rect2(i * 15.0, 0.0, 8.0, size.y), Color(Tokens.ACCENT, emphasis))
