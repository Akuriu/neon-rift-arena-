extends RefCounted

const Palette := preload("res://ui/skin.gd")
const Tokens := preload("res://ui/design/tokens.gd")
const Link := preload("res://ui/design/components/navigation_link.gd")
const Mark := preload("res://assets/art/rift.svg")

static func build(view: Control, actions: Dictionary, map_name: String) -> void:
	var mark := TextureRect.new()
	mark.texture = Mark
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Palette.at(view, mark, Rect2(55, 32, 45, 45))
	Palette.rule(view, Rect2(113, 43, 1, 23), Color(Tokens.ACCENT, 0.48))
	Palette.label(view, Rect2(128, 37, 305, 34), "Solo · Coop privée", 15, Tokens.MUTED, Palette.MONO)

	Palette.rule(view, Rect2(58, 113, 46, 3), Tokens.ACCENT)
	Palette.label(view, Rect2(51, 122, 686, 117), "RIFLE ARENA", 113, Tokens.TEXT, Palette.BRAND)
	Palette.label(view, Rect2(58, 244, 500, 33), "Affrontez les bots ou jouez en équipe jusqu’à quatre.", 18, Tokens.MUTED)
	var start := Link.create(view, Rect2(57, 301, 421, 73), "Jouer", "play", actions.play, true)
	Link.create(view, Rect2(57, 390, 200, 58), "Arsenal", "target", actions.arsenal)
	Link.create(view, Rect2(270, 390, 208, 58), "Progression", "progress", actions.profile)
	Link.create(view, Rect2(57, 461, 200, 58), "Paramètres", "settings", actions.settings)
	Link.create(view, Rect2(270, 461, 208, 58), "Crédits", "info", actions.credits)
	Link.create(view, Rect2(57, 539, 200, 49), "Quitter", "quit", actions.quit)

	var location := Control.new()
	location.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(location)
	location.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	location.offset_left = -378
	location.offset_right = -57
	location.offset_top = 532
	location.offset_bottom = 624
	var card := Palette.panel(location, Rect2(0, 0, 321, 92), Color(Tokens.BACKGROUND, 0.93), Color(Tokens.ACCENT, 0.42))
	Palette.rule(card, Rect2(18, 15, 22, 2), Tokens.ACCENT)
	Palette.label(card, Rect2(18, 21, 248, 42), map_name, 31, Tokens.TEXT, Palette.HEAD)
	Palette.label(card, Rect2(19, 63, 240, 16), "Cour de chargement", 13, Tokens.MUTED)
	Link.add_icon(card, Rect2(266, 29, 31, 31), "target", Tokens.ACCENT)
	start.grab_focus()
