extends Control

const Palette := preload("res://ui/skin.gd")
const Catalog := preload("res://game/catalog.gd")
const Coop := preload("res://network/coop.gd")
const MODES := ["Survie · 20 vagues", "Survie · 10 vagues", "Infini"]

var net: Coop
var back: Callable
var address: LineEdit
var port: LineEdit
var code: LineEdit
var limit: SpinBox
var status: Label
var rows: Array[Label] = []
var map: OptionButton
var mode: OptionButton
var difficulty: OptionButton
var start: Button
var ready_button: Button
var disconnect: Button
var create: Button
var connect_button: Button

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	Palette.panel(self, Rect2(56, 204, 552, 356), Color("#10252d"))
	Palette.panel(self, Rect2(625, 204, 598, 356), Color("#10252d"))
	Palette.label(self, Rect2(76, 215, 506, 40), "CONNEXION DIRECTE", 23, Palette.CYAN, Palette.HEAD)
	Palette.label(self, Rect2(646, 215, 549, 40), "ÉQUIPE · JUSQU’À QUATRE PILOTES", 23, Palette.CYAN, Palette.HEAD)
	address = _line_entry(Rect2(76, 288, 344, 43), "Adresse de l’hôte", "127.0.0.1", 64)
	port = _line_entry(Rect2(436, 288, 151, 43), "Port UDP", str(net.listening_port), 5)
	code = _line_entry(Rect2(76, 366, 344, 43), "Code du salon · facultatif", "", 32)
	code.secret = true
	Palette.label(self, Rect2(436, 338, 151, 27), "Taille du salon", 13, Palette.MUTED)
	limit = SpinBox.new()
	limit.min_value = 2
	limit.max_value = 4
	limit.value = net.capacity
	limit.get_line_edit().accessibility_name = "Taille du salon"
	Palette.at(self, limit, Rect2(436, 366, 151, 43))
	create = Palette.button(self, Rect2(76, 428, 246, 47), "Héberger", _host, true)
	connect_button = Palette.button(self, Rect2(334, 428, 253, 47), "Rejoindre", _join)
	status = Palette.label(self, Rect2(76, 489, 510, 60), "", 15, Palette.AMBER, Palette.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
	for index in 4:
		rows.append(Palette.label(self, Rect2(647, 260 + index * 30, 542, 27), "", 15, Palette.TEXT, Palette.MONO))
	Palette.rule(self, Rect2(647, 389, 553, 1))
	map = _option(Rect2(647, 423, 185, 42), "Arène", Catalog.MAPS.values().map(func(spec): return spec.name))
	mode = _option(Rect2(841, 423, 184, 42), "Mode", MODES)
	difficulty = _option(Rect2(1034, 423, 165, 42), "Difficulté", Catalog.DIFFICULTIES.values().map(func(spec): return spec.name))
	map.select(Catalog.MAPS.keys().find(net.room.map))
	mode.select(Coop.MODES.find(net.room.mode))
	difficulty.select(Catalog.DIFFICULTIES.keys().find(net.room.difficulty))
	ready_button = Palette.button(self, Rect2(647, 484, 263, 49), "Je suis prêt", net.ready_up)
	start = Palette.button(self, Rect2(923, 484, 276, 49), "Lancer la partie", net.start_match, true)
	Palette.button(self, Rect2(56, 596, 231, 49), "Retour au menu", back)
	disconnect = Palette.button(self, Rect2(303, 596, 231, 49), "Fermer la connexion", _leave)
	Palette.label(self, Rect2(555, 593, 664, 54),
		"Sur le réseau local, communiquez l’adresse IP locale de l’hôte. Via Internet, l’hôte doit rendre son port UDP accessible.",
		15, Palette.MUTED, Palette.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
	refresh()
	create.grab_focus()

func _line_entry(rect: Rect2, caption: String, value: String, maximum: int) -> LineEdit:
	Palette.label(self, Rect2(rect.position - Vector2(0, 28), Vector2(rect.size.x, 27)), caption, 13, Palette.MUTED)
	var entry := LineEdit.new()
	entry.text = value
	entry.max_length = maximum
	entry.accessibility_name = caption
	entry.add_theme_stylebox_override("normal", Palette.box(Palette.BASE, Palette.LINE))
	Palette.at(self, entry, rect)
	return entry

func _option(rect: Rect2, caption: String, values: Array) -> OptionButton:
	Palette.label(self, Rect2(rect.position - Vector2(0, 28), Vector2(rect.size.x, 27)), caption, 13, Palette.MUTED)
	var option := OptionButton.new()
	option.accessibility_name = caption
	option.add_theme_font_size_override("font_size", 14)
	for value in values:
		option.add_item(value)
	option.item_selected.connect(func(_index): _configure())
	Palette.at(self, option, rect)
	return option

func _configure() -> void:
	net.configure(Catalog.MAPS.keys()[map.selected], Coop.MODES[mode.selected], Catalog.DIFFICULTIES.keys()[difficulty.selected])

func _host() -> void:
	var map_id: String = Catalog.MAPS.keys()[map.selected]
	var mode_id: String = Coop.MODES[mode.selected]
	var difficulty_id: String = Catalog.DIFFICULTIES.keys()[difficulty.selected]
	if net.host(port.text.to_int(), roundi(limit.value), code.text):
		net.configure(map_id, mode_id, difficulty_id)

func _join() -> void:
	net.join(address.text, port.text.to_int(), code.text)

func _leave() -> void:
	net.stop()
	net.status = "Connexion fermée."
	refresh()

func refresh() -> void:
	var online := net.active()
	create.disabled = online
	connect_button.disabled = online
	disconnect.disabled = not online
	address.editable = not online
	port.editable = not online
	code.editable = not online
	limit.editable = not online
	for option in [map, mode, difficulty]:
		option.disabled = online and not net.hosting
	if online:
		map.select(Catalog.MAPS.keys().find(net.room.map))
		mode.select(Coop.MODES.find(net.room.mode))
		difficulty.select(Catalog.DIFFICULTIES.keys().find(net.room.difficulty))
	var ids := net.roster.keys()
	ids.sort()
	for index in rows.size():
		if index >= ids.size():
			rows[index].text = "—  Place libre"
			rows[index].modulate = Palette.QUIET
			continue
		var id: int = ids[index]
		var pilot: Dictionary = net.roster[id]
		var label := "HÔTE" if id == 1 else ("VOUS" if id == net.local_id() else "PILOTE")
		rows[index].text = "%s   %s    ·    %s" % [label, pilot.name, "PRÊT" if pilot.ready else "EN ATTENTE"]
		rows[index].modulate = Palette.CYAN if pilot.ready else Palette.TEXT
	ready_button.disabled = not net.roster.has(net.local_id())
	ready_button.text = "Annuler prêt" if net.roster.get(net.local_id(), {}).get("ready", false) else "Je suis prêt"
	start.disabled = not net.can_start()
	status.text = net.status
