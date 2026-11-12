extends RefCounted

const Palette := preload("res://ui/skin.gd")
const Livery := preload("res://ui/livery.gd")
const Link := preload("res://ui/design/components/navigation_link.gd")
const Tokens := preload("res://ui/design/tokens.gd")
const CARDS := [
	["gungame", "Gun Game", "Changez d’arme à chaque élimination.", "reactor", "8 PALIERS"],
	["classic", "Classique", "Chacun pour soi, équipes, capture et domination.", "district", "4 MODES"],
	["parkour", "Parkour", "Battez votre meilleur chrono.", "parkour-yard", "3 PARCOURS"],
	["survival", "Survie", "Tenez les vagues et affrontez les boss.", "cryo", "7 ARÈNES"],
	["coop", "Coop", "Rejoignez ou hébergez un salon privé.", "skyline", "2–4 JOUEURS"],
	["training", "Entraînement", "Réglez les cibles et essayez les armes.", "station", "ACCÈS LIBRE"],
]

static var previews := {}

func build(parent: Control, actions: Dictionary) -> void:
	var first := true
	for i in CARDS.size():
		var card: Array = CARDS[i]
		if not actions.has(card[0]):
			continue
		var rect := Rect2(57 + (i % 3) * 396, 211 + floori(i / 3.0) * 190, 374, 173)
		var button := Palette.button(parent, rect, "", actions[card[0]])
		button.accessibility_name = card[1]
		var crop := Control.new()
		crop.clip_contents = true
		crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Palette.at(button, crop, Rect2(158, 2, 214, 169))
		var texture := _preview(card[3])
		if texture != null:
			var picture := TextureRect.new()
			picture.texture = texture
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			crop.add_child(picture)
			picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var veil := Livery.new()
			veil.mode = "tile"
			crop.add_child(veil)
		Palette.rule(button, Rect2(20, 23, 22, 2), Tokens.ACCENT)
		Palette.label(button, Rect2(51, 14, 181, 21), card[4], 12, Tokens.FOCUS, Palette.MONO)
		Palette.label(button, Rect2(18, 43, 303, 50), card[1], 36, Tokens.TEXT, Palette.HEAD)
		Palette.label(button, Rect2(21, 106, 221, 50), card[2], 15, Tokens.TEXT, Palette.BODY,
			HORIZONTAL_ALIGNMENT_LEFT, true)
		Palette.panel(button, Rect2(314, 115, 42, 42), Color(Tokens.BACKGROUND, 0.86), Tokens.EDGE)
		Link.add_icon(button, Rect2(324, 125, 22, 22), "arrow", Tokens.ACCENT)
		if first:
			button.grab_focus()
			first = false

static func _preview(id: String) -> Texture2D:
	if not previews.has(id):
		var path := "res://assets/maps/%s.jpg" % id
		if ResourceLoader.exists(path, "Texture2D"):
			previews[id] = load(path)
	return previews.get(id)
