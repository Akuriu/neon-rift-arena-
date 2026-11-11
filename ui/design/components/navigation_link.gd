extends RefCounted

const Palette := preload("res://ui/skin.gd")
const Glyph := preload("res://ui/glyph.gd")
const Tokens := preload("res://ui/design/tokens.gd")

static func create(parent: Control, rect: Rect2, title: String, icon: String, action: Callable, primary := false) -> Button:
	var button := Palette.button(parent, rect, "", action, primary)
	button.accessibility_name = title
	var ink := Tokens.BACKGROUND if primary else Tokens.TEXT
	var icon_size := 28.0 if primary else 21.0
	add_icon(button, Rect2(16, (rect.size.y - icon_size) * 0.5, icon_size, icon_size), icon,
		ink if primary else Tokens.ACCENT)
	var tail := 56.0 if primary else 13.0
	Palette.label(button, Rect2(50, 0, rect.size.x - 50.0 - tail, rect.size.y), title,
		31 if primary else 19, ink, Palette.HEAD if primary else Palette.BOLD)
	if primary:
		add_icon(button, Rect2(rect.size.x - 42.0, (rect.size.y - 24.0) * 0.5, 24, 24), "arrow", ink)
	return button

static func add_icon(parent: Control, rect: Rect2, mark: String, ink: Color) -> void:
	var icon := Glyph.new()
	icon.mark = mark
	icon.ink = ink
	Palette.at(parent, icon, rect)
