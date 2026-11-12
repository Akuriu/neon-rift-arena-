extends RefCounted

const Palette := preload("res://ui/skin.gd")
const Tokens := preload("res://ui/design/tokens.gd")

static func build(parent: Control, area: Rect2, entries: Array) -> void:
	var gap := 10.0
	var width := (area.size.x - gap * (entries.size() - 1)) / entries.size()
	for index in entries.size():
		var entry: Array = entries[index]
		var position := area.position + Vector2(index * (width + gap), 0)
		var card := Palette.panel(parent, Rect2(position, Vector2(width, area.size.y)), Tokens.SURFACE)
		var label := Palette.label(card, Rect2(16, 9, width - 32, 24), entry[0], 14, Tokens.MUTED, Palette.BOLD)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var value: String = entry[1]
		Palette.label(card, Rect2(16, 34, width - 32, area.size.y - 42), value,
			24 if value.length() > 8 else 30, Tokens.TEXT, Palette.MONO)
