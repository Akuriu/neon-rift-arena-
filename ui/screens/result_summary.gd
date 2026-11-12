extends RefCounted

const Palette := preload("res://ui/skin.gd")
const Tokens := preload("res://ui/design/tokens.gd")
const Metrics := preload("res://ui/design/components/metric_row.gd")

static func build(view: Control, image: Texture2D, score_label: String, score: String,
		record: String, metrics: Array, accent: Color) -> void:
	var hero := Palette.panel(view, Rect2(57, 207, 454, 172), Tokens.RAISED)
	Palette.rule(hero, Rect2(1, 21, 3, 125), accent)
	Palette.label(hero, Rect2(23, 14, 410, 31), score_label, 15, accent, Palette.BOLD)
	Palette.label(hero, Rect2(19, 43, 419, 77), score, 59, Tokens.TEXT, Palette.MONO)
	Palette.label(hero, Rect2(23, 120, 408, 35), record, 16, Tokens.MUTED, Palette.BODY)

	var crop := Palette.panel(view, Rect2(525, 207, 698, 172), Tokens.SURFACE)
	crop.clip_contents = true
	var photograph := TextureRect.new()
	photograph.texture = image
	photograph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photograph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photograph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Palette.at(crop, photograph, Rect2(1, 1, 696, 170))
	Palette.rule(crop, Rect2(1, 1, 64, 3), accent)
	Metrics.build(view, Rect2(57, 393, 1166, 100), metrics)
