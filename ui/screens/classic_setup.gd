extends RefCounted

const Palette := preload("res://ui/skin.gd")
const Rules := preload("res://game/modes/rules.gd")
const Catalog := preload("res://game/catalog.gd")
const MODES := ["classic", "teams", "capture", "domination"]
const COPY := {
	"gungame": "Une élimination, une nouvelle arme. La huitième remporte le match. Votre palier survit aux défaites.",
	"classic": "Chacun pour soi. Un point par neutralisation. La première limite atteinte termine le match.",
	"teams": "Deux équipes. Un point par neutralisation adverse. Les tirs alliés sont neutralisés.",
	"capture": "Tenez le point central. L’équipe qui le contrôle marque chaque seconde.",
	"domination": "Contrôlez A, B et C. Chaque zone tenue donne un point par seconde à son équipe.",
}

var root: Control
var summary: Label
var modes: OptionButton
var targets: OptionButton
var order: OptionButton
var maps: OptionButton
var detail: Label
var preview: TextureRect
var allowed := MODES.duplicate()
var gun_game := false

func build(parent: Control, selected_map: String, selected_level: String, initial: Dictionary,
	start: Callable, back: Callable, gun := false) -> void:
	root = parent
	gun_game = gun
	allowed = ["gungame"] if gun else MODES.duplicate()
	var mode: String = initial.get("mode", "classic")
	var rules := Rules.normalize(initial.get("rules", {}), mode)
	Palette.panel(root, Rect2(57, 206, 1166, 349), Palette.PANEL)
	var names: Array[String] = []
	for id in allowed:
		names.append(Rules.LABELS[id])
	modes = _choice("FORMAT", 82, 220, names, allowed.find(mode))
	names = []
	for id in Prefs.MAPS:
		names.append(Catalog.MAPS[id].name)
	maps = _choice("ARÈNE", 457, 220, names, Prefs.MAPS.find(selected_map))
	names = []
	for id in Prefs.DIFFICULTIES:
		names.append(Catalog.DIFFICULTIES[id].name)
	var levels := _choice("DIFFICULTÉ", 832, 220, names, Prefs.DIFFICULTIES.find(selected_level))
	names = []
	var max_bots := 7 if Prefs.values.quality == 3 else 12
	for count in range(max_bots + 1):
		names.append("Exploration libre" if count == 0 else "%d bots" % count)
	var bots := _choice("EFFECTIF", 82, 316, names, mini(max_bots, rules.bots))
	var duration := _choice("DURÉE", 457, 316, ["3 minutes", "5 minutes", "10 minutes", "15 minutes"], Rules.DURATIONS.find(rules.duration))
	if gun_game:
		order = _choice("ORDRE DES ARMES", 832, 316, ["Ordre classique", "Mélangé par graine"], int(rules.shuffled))
	else:
		targets = _choice("LIMITE DE SCORE", 832, 316, ["10 points", "20 points", "35 points", "60 points", "100 points"], Rules.TARGETS.find(rules.target))
	summary = Palette.label(root, Rect2(82, 414, 833, 43), "", 19, Palette.TEXT, Palette.BOLD,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	detail = Palette.label(root, Rect2(82, 465, 833, 48), "", 16, Palette.MUTED, Palette.BODY,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Palette.at(root, preview, Rect2(944, 397, 233, 131))
	if not gun_game:
		modes.item_selected.connect(func(i: int):
			targets.select(3 if allowed[i] in ["capture", "domination"] else 1)
			_refresh()
		)
	maps.item_selected.connect(func(_i: int): _refresh())
	_refresh()
	var seed := LineEdit.new()
	seed.placeholder_text = "Graine de match facultative"
	seed.max_length = 10
	if initial.has("seed"):
		seed.text = str(initial.seed)
	Palette.at(root, seed, Rect2(832, 572, 345, 51))
	Palette.button(root, Rect2(57, 572, 137, 51), "Retour", back)
	Palette.button(root, Rect2(209, 572, 279, 51), "LANCER LE MATCH    ›", func():
		var code := seed.text.strip_edges()
		var options := {"bots": bots.selected, "duration": Rules.DURATIONS[duration.selected]}
		if gun_game:
			options.shuffled = order.selected == 1
		else:
			options.target = Rules.TARGETS[targets.selected]
		start.call(allowed[modes.selected], Prefs.DIFFICULTIES[levels.selected],
			Prefs.MAPS[maps.selected], int(code) if code.is_valid_int() else -1, options)
	, true)
	modes.grab_focus()

func _choice(label: String, x: int, y: int, names: Array[String], selected: int) -> OptionButton:
	Palette.label(root, Rect2(x, y, 345, 24), label, 13, Palette.MUTED, Palette.MONO)
	var choice := OptionButton.new()
	choice.accessibility_name = label
	for title in names:
		choice.add_item(title)
	choice.select(maxi(0, selected))
	Palette.at(root, choice, Rect2(x, y + 30, 345, 45))
	return choice

func _refresh() -> void:
	summary.text = COPY[allowed[modes.selected]]
	var map_id: String = Prefs.MAPS[maps.selected]
	detail.text = Catalog.MAPS[map_id].summary
	preview.texture = load("res://assets/maps/%s.jpg" % map_id)
