extends RefCounted

const Palette := preload("res://ui/skin.gd")
const Livery := preload("res://ui/livery.gd")
const CARDS := [
	["gungame", "Gun Game", "Huit armes. Une élimination,\nun nouveau palier.", "reactor", "01 / PROGRESSION"],
	["classic", "Classique", "Chacun pour soi, équipes,\ncapture et domination.", "district", "02 / COMPÉTITION"],
	["parkour", "Parkour", "Trois parcours à chronométrer.\nSaut, sprint et précision.", "grove", "03 / MOUVEMENT"],
	["survival", "Survie", "Vagues, boss et ravitaillement.\nSept arènes à maîtriser.", "cryo", "04 / ENDURANCE"],
	["coop", "Coop", "Un salon privé de 2 à 4.\nSurvivez en équipe.", "skyline", "05 / ÉQUIPE"],
	["training", "Entraînement", "Essayez les huit armes\nsur des cibles réglables.", "station", "06 / STAND DE TIR"],
]

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
		Palette.at(button, crop, Rect2(176, 3, 194, 166))
		var picture := TextureRect.new()
		picture.texture = load("res://assets/maps/%s.jpg" % card[3])
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crop.add_child(picture)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var veil := Livery.new()
		veil.mode = "tile"
		crop.add_child(veil)
		Palette.label(button, Rect2(19, 14, 338, 22), card[4], 12, Palette.AMBER, Palette.MONO)
		Palette.label(button, Rect2(17, 46, 340, 49), card[1], 34, Palette.TEXT, Palette.HEAD)
		Palette.label(button, Rect2(19, 104, 336, 53), card[2], 16, Palette.MUTED)
		if first:
			button.grab_focus()
			first = false
