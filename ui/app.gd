extends Node

const Session := preload("res://scenes/Session.tscn")
const Arena := preload("res://game/arena.gd")
const Director := preload("res://game/wave_director.gd")
const Catalog := preload("res://game/catalog.gd")
const Palette := preload("res://ui/skin.gd")
const Hud := preload("res://ui/hud.gd")
const Livery := preload("res://ui/livery.gd")
const Options := preload("res://ui/settings.gd")
const Hub := preload("res://ui/hub.gd")
const Profile := preload("res://services/profile.gd")
const Wallet := preload("res://game/economy/field_wallet.gd")
const Coop := preload("res://network/coop.gd")
const Lobby := preload("res://ui/lobby.gd")

const MODES := {
	"survival": {"name": "Survie · 20 vagues", "tag": "CAMPAGNE", "line": "4 paliers majeurs · poursuite en Infini",
		"summary": "Traversez vingt vagues et défiez le Null Architect. Encaissez la victoire ou poursuivez la même partie en Infini."},
	"short": {"name": "Survie · 10 vagues", "tag": "PATROUILLE", "line": "Format court · 2 affrontements majeurs",
		"summary": "Dix vagues, des achats entre les assauts et un combat final contre le Reactor Warden."},
	"endless": {"name": "Infini", "tag": "ENDURANCE", "line": "Rythme progressif · sortie volontaire",
		"summary": "Poursuivez jusqu’à la défaite ou encaissez le bilan après une vague réussie. Les apparitions simultanées restent limitées."},
	"trial": {"name": "Défi chronométré", "tag": "CHRONO", "line": "90 secondes · 15 robots · classement",
		"summary": "Neutralisez toutes les cibles avant la fermeture du secteur. Chaque seconde restante compte."},
	"boss_rush": {"name": "Boss Rush", "tag": "BOSS", "line": "4 boss · 3 ravitaillements",
		"summary": "Défiez successivement Apex, Warden, Colossus et Architect, chacun avec son escorte. Achetez et équipez-vous entre les combats."},
	"training": {"name": "Entraînement", "tag": "ATELIER", "line": "4 cibles mobiles · 8 armes en prêt",
		"summary": "Toutes les armes sont disponibles, même verrouillées. La console de départ réarme le pilote et réinitialise les cibles."},
}
const ICON := preload("res://assets/art/rift.svg")

var layer: CanvasLayer
var canvas: Control
var view: Control
var screen := "menu"
var session
var hud_panel: Hud
var backdrop: Arena
var title_cam: Camera3D
var orbit := 0.0
var exiting := false
var last_mode := "survival"
var last_difficulty := "standard"
var last_map := "reactor"
var selected_mode := "survival"
var selected_difficulty := "standard"
var selected_map := "reactor"
var options_origin := "menu"
var settings: Options
var confirmation_cancel: Callable
var select_title: Label
var select_line: Label
var select_copy: Label
var select_map_copy: Label
var records_label: Label
var start_button: Button
var mode_buttons := {}
var seed_input: LineEdit
var field_notice := ""
var coop: Coop
var lobby: Lobby
var shop_clock: Label

func _ready() -> void:
	layer = CanvasLayer.new()
	add_child(layer)
	canvas = Control.new()
	layer.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.theme = Palette.theme()
	coop = Coop.new()
	coop.name = "Coop"
	coop.app = self
	add_child(coop)
	coop.changed.connect(_coop_changed)
	coop.notice.connect(_coop_notice)
	coop.ended.connect(_coop_ended)
	Prefs.changed.connect(_prefs_changed)
	if DisplayServer.get_name() != "headless":
		get_window().focus_exited.connect(_focus_lost)
		get_tree().auto_accept_quit = false
		get_window().close_requested.connect(_quit)
	var arguments := OS.get_cmdline_user_args()
	if "--server" in arguments:
		_dedicated(arguments)
	else:
		menu()

func _process(delta: float) -> void:
	if screen == "upgrade" and is_instance_valid(shop_clock) and coop.in_match():
		var line := "%d / %d prêts   ·   Reprise dans %d s" % [coop.ready_count(), coop.roster.size(), ceili(coop.shop_left)]
		if shop_clock.text != line:
			shop_clock.text = line
	if not is_instance_valid(title_cam):
		return
	orbit += delta
	var angle := 0.53 + sin(orbit * 0.26) * 0.12
	title_cam.position = Vector3(sin(angle) * 16.9, 3.8 + sin(orbit * 0.32) * 0.37, cos(angle) * 16.9)
	title_cam.look_at(Vector3(-5.4, 2.58, -0.8), Vector3.UP)

func _new_screen(name: String, treatment := "page") -> void:
	if is_instance_valid(view):
		canvas.remove_child(view)
		view.queue_free()
		view = null
	settings = null
	lobby = null
	shop_clock = null
	screen = name
	confirmation_cancel = Callable()
	view = Control.new()
	view.name = "Screen_" + name
	canvas.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var matte := Livery.new()
	matte.mode = treatment
	view.add_child(matte)
	if Prefs.values.recoil:
		view.modulate.a = 0.61
		var fade := view.create_tween()
		fade.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fade.tween_property(view, "modulate:a", 1.0, 0.19)

func _footer(copy: String) -> void:
	Palette.label(view, Rect2(56, 673, 1100, 45), copy, 13, Palette.MUTED, Palette.MONO)
	Palette.label(view, Rect2(1107, 673, 116, 45), "BUILD 2.0.0", 12, Palette.CYAN, Palette.MONO, HORIZONTAL_ALIGNMENT_RIGHT)

func _header(index: String, name: String, description: String) -> void:
	Palette.label(view, Rect2(56, 29, 840, 33), "NEON RIFT  /  " + index, 14, Palette.CYAN, Palette.MONO)
	Palette.label(view, Rect2(53, 71, 1140, 78), name, 60, Palette.TEXT, Palette.HEAD)
	if description != "":
		Palette.label(view, Rect2(57, 151, 1155, 35), description, 17, Palette.MUTED)

func _make_backdrop() -> void:
	if is_instance_valid(backdrop):
		return
	backdrop = Arena.new()
	backdrop.is_backdrop = true
	add_child(backdrop)
	title_cam = Camera3D.new()
	title_cam.position = Vector3(8.5, 3.8, 14.6)
	title_cam.fov = 64.0
	title_cam.far = 160.0
	add_child(title_cam)
	title_cam.look_at_from_position(title_cam.position, Vector3(-5.4, 2.58, -0.8), Vector3.UP)
	title_cam.current = true

func _drop_backdrop() -> void:
	if is_instance_valid(title_cam):
		remove_child(title_cam)
		title_cam.queue_free()
		title_cam = null
	if is_instance_valid(backdrop):
		remove_child(backdrop)
		backdrop.queue_free()
		backdrop = null

func menu() -> void:
	coop.stop()
	_drop_session()
	_make_backdrop()
	_free_cursor()
	Sounds.duck = false
	Sounds.set_track("menu")
	_new_screen("menu", "home")
	var mark := TextureRect.new()
	mark.texture = ICON
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Palette.at(view, mark, Rect2(55, 37, 42, 42))
	Palette.label(view, Rect2(109, 37, 455, 43), "PROGRAMME DE CONFINEMENT  /  07", 14, Palette.CYAN, Palette.MONO)
	Palette.label(view, Rect2(46, 104, 635, 115), "NEON RIFT.", 91, Palette.TEXT, Palette.BRAND)
	Palette.rule(view, Rect2(58, 217, 41, 3), Palette.CYAN)
	Palette.label(view, Rect2(112, 197, 455, 40), "U P R I S I N G   /   2 . 0", 17, Palette.CYAN, Palette.MONO)
	Palette.label(view, Rect2(58, 253, 488, 48), "Reprenez le contrôle du réacteur.", 21, Palette.TEXT, Palette.BOLD)
	var start := Palette.button(view, Rect2(58, 322, 386, 59), "01     JOUER                                          ›", select_session, true)
	Palette.button(view, Rect2(58, 391, 187, 49), "ENTRAÎNEMENT", func(): begin("training", selected_difficulty, selected_map))
	Palette.button(view, Rect2(255, 391, 189, 49), "Coop · 2–4", open_lobby)
	Palette.button(view, Rect2(58, 450, 187, 44), "Arsenal", open_hub.bind("arsenal"))
	Palette.button(view, Rect2(255, 450, 189, 44), "Boutique", open_hub.bind("shop"))
	Palette.button(view, Rect2(58, 503, 187, 44), "Profil", show_profile.bind("profile"))
	Palette.button(view, Rect2(255, 503, 189, 44), "Contrats", show_profile.bind("contracts"))
	Palette.button(view, Rect2(58, 556, 187, 44), "Classements", show_profile.bind("records"))
	Palette.button(view, Rect2(255, 556, 189, 44), "Paramètres", open_settings.bind("menu"))
	Palette.button(view, Rect2(58, 609, 187, 44), "Crédits", credits)
	Palette.button(view, Rect2(255, 609, 189, 44), "Quitter", _quit)
	start.grab_focus()
	Palette.panel(view, Rect2(937, 514, 285, 103), Color(0.035, 0.079, 0.095, 0.88))
	Palette.rule(view, Rect2(937, 514, 44, 2), Palette.AMBER)
	Palette.label(view, Rect2(954, 523, 246, 28), "SECTEUR 07  /  VUE DIRECTE", 12, Palette.AMBER, Palette.MONO)
	Palette.label(view, Rect2(954, 549, 250, 46), "Reactor Court", 30, Palette.TEXT, Palette.HEAD)
	Palette.label(view, Rect2(943, 473, 278, 31), "NIVEAU %02d  ·  %d PIÈCES" % [
		Profile.level(Prefs.profile.data.xp), Prefs.profile.data.coins], 15, Palette.AMBER, Palette.MONO, HORIZONTAL_ALIGNMENT_RIGHT)
	_footer("CLAVIER + SOURIS  /  PROGRESSION LOCALE")

func open_lobby() -> void:
	_make_backdrop()
	_free_cursor()
	Sounds.duck = false
	Sounds.set_track("menu")
	_new_screen("lobby")
	_header("SALLE DE COMMANDE", "Opération en coop", "Survie et Infini en équipe, sur le réseau local ou via l’IP de l’hôte.")
	lobby = Lobby.new()
	lobby.net = coop
	lobby.back = menu
	view.add_child(lobby)
	_footer("PROTOCOLE 02  /  ENET · UDP  /  PARTIES PRIVÉES")

func leave_coop() -> void:
	coop.stop()
	_drop_session()
	open_lobby()

func launch_coop() -> void:
	begin(coop.room.mode, coop.room.difficulty, coop.room.map, coop.room.seed, "", true)

func _coop_changed() -> void:
	if is_instance_valid(lobby):
		lobby.refresh()
	elif screen == "upgrade" and coop.in_match():
		_upgrade()

func _coop_notice(message: String) -> void:
	if screen == "upgrade" and coop.in_match():
		field_notice = message
		_upgrade()

func _coop_ended(_message: String) -> void:
	_drop_session()
	if screen != "lobby":
		open_lobby()

func _dedicated(arguments: PackedStringArray) -> void:
	var port := Coop.PORT
	var map := "reactor"
	var mode := "survival"
	var difficulty := "standard"
	var code := ""
	for argument in arguments:
		if argument.begins_with("--port="):
			port = argument.get_slice("=", 1).to_int()
		elif argument.begins_with("--map="):
			map = argument.get_slice("=", 1)
		elif argument.begins_with("--mode="):
			mode = argument.get_slice("=", 1)
		elif argument.begins_with("--difficulty="):
			difficulty = argument.get_slice("=", 1)
		elif argument.begins_with("--code="):
			code = argument.substr(7)
	if coop.host(port, 4, code, true):
		coop.configure(map, mode, difficulty)
		screen = "server"
		print("COOP dedicated UDP ", port, " · ", coop.room)
	else:
		printerr(coop.status)
		get_tree().quit(2)

func select_session() -> void:
	_new_screen("select")
	_header("SÉLECTION", "Protocoles de combat", "Choisissez une opération et la difficulté du secteur.")
	mode_buttons.clear()
	var index := 0
	for kind in MODES:
		var protocol := MODES[kind] as Dictionary
		var rect := Rect2(57, 197 + index * 55, 438, 50)
		var card := Palette.button(view, rect, "", _choose_mode.bind(kind))
		card.accessibility_name = protocol.name
		mode_buttons[kind] = card
		Palette.label(card, Rect2(13, 1, 390, 26), protocol.name, 22, Palette.TEXT, Palette.HEAD)
		Palette.label(card, Rect2(14, 25, 392, 23), protocol.line, 13, Palette.MUTED)
		index += 1
	Palette.panel(view, Rect2(526, 213, 699, 405), Color("#10252d"))
	select_title = Palette.label(view, Rect2(551, 226, 638, 44), "", 33, Palette.TEXT, Palette.HEAD)
	select_line = Palette.label(view, Rect2(552, 275, 638, 24), "", 13, Palette.CYAN, Palette.MONO)
	select_copy = Palette.label(view, Rect2(552, 302, 642, 64), "", 16, Palette.MUTED,
		Palette.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
	Palette.rule(view, Rect2(551, 375, 650, 1))
	Palette.label(view, Rect2(552, 386, 294, 30), "DIFFICULTÉ", 13, Palette.MUTED, Palette.MONO)
	Palette.label(view, Rect2(881, 386, 289, 30), "ARÈNE", 13, Palette.MUTED, Palette.MONO)
	var levels := OptionButton.new()
	for key in Prefs.DIFFICULTIES:
		levels.add_item(Catalog.DIFFICULTIES[key].name)
	levels.select(Prefs.DIFFICULTIES.find(selected_difficulty))
	levels.item_selected.connect(func(which: int):
		selected_difficulty = Prefs.DIFFICULTIES[which]
		_refresh_selection()
	)
	Palette.at(view, levels, Rect2(552, 421, 300, 48))
	if Prefs.MAPS.size() > 1:
		var maps := OptionButton.new()
		for key in Prefs.MAPS:
			maps.add_item(Catalog.MAPS[key].name)
		maps.select(Prefs.MAPS.find(selected_map))
		maps.item_selected.connect(func(which: int):
			selected_map = Prefs.MAPS[which]
			_refresh_selection()
		)
		Palette.at(view, maps, Rect2(881, 421, 319, 48))
	else:
		Palette.panel(view, Rect2(881, 421, 319, 48), Color("#172f36"))
		Palette.label(view, Rect2(894, 423, 291, 43), Catalog.MAPS[selected_map].name, 18, Palette.TEXT, Palette.BOLD)
	select_map_copy = Palette.label(view, Rect2(552, 479, 638, 51), "", 14, Palette.MUTED,
		Palette.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
	records_label = Palette.label(view, Rect2(552, 537, 642, 65), "", 13, Palette.CYAN,
		Palette.MONO, HORIZONTAL_ALIGNMENT_LEFT, true)
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "Graine facultative"
	seed_input.max_length = 10
	Palette.at(view, seed_input, Rect2(57, 612, 438, 43))
	Palette.button(view, Rect2(57, 553, 133, 54), "Retour", menu)
	start_button = Palette.button(view, Rect2(205, 553, 290, 54), "DÉMARRER    ›", _start_selected, true)
	_refresh_selection()
	mode_buttons[selected_mode].grab_focus()
	_footer(_short_controls())

func _choose_mode(mode: String) -> void:
	selected_mode = mode
	_refresh_selection()

func _refresh_selection() -> void:
	for kind in mode_buttons:
		var control: Button = mode_buttons[kind]
		control.add_theme_stylebox_override("normal", Palette.box(Color("#1d3539") if kind == selected_mode else Palette.PANEL,
			Palette.CYAN if kind == selected_mode else Palette.LINE, 6))
	var spec: Dictionary = MODES[selected_mode]
	select_title.text = spec.name
	select_line.text = spec.line.to_upper()
	select_copy.text = spec.summary
	select_map_copy.text = Catalog.MAPS[selected_map].summary
	if selected_mode == "training":
		records_label.text = "SESSION D’ENTRAÎNEMENT   /   Neutralisations dans le journal du pilote"
		return
	var best := Prefs.leaderboard(selected_mode, selected_difficulty, selected_map)
	if best.is_empty():
		records_label.text = "CLASSEMENT LOCAL   /   Première opération"
		return
	var entries: Array[String] = []
	for i in mini(5, best.size()):
		entries.append("#%d   %06d" % [i + 1, best[i].score])
	records_label.text = "CLASSEMENT LOCAL\n" + "    ".join(entries)

func _start_selected() -> void:
	var value := seed_input.text.strip_edges() if is_instance_valid(seed_input) else ""
	begin(selected_mode, selected_difficulty, selected_map, int(value) if value.is_valid_int() else -1)

func begin(mode: String, difficulty: String, map_id := "reactor", run_seed := -1, test_weapon := "", online := false) -> void:
	if not online:
		coop.stop()
	_drop_session()
	_drop_backdrop()
	last_mode = mode
	last_difficulty = difficulty
	last_map = map_id
	session = Session.instantiate()
	session.mode = mode
	session.difficulty = difficulty
	session.map_id = map_id
	session.run_seed = run_seed
	session.test_weapon = test_weapon
	if online:
		session.net = coop
	field_notice = ""
	add_child(session)
	session.director.changed.connect(_session_changed)
	session.director.campaign_complete.connect(_milestone)
	session.director.finished.connect(_result.bind(session), CONNECT_DEFERRED)
	if online:
		coop.attach(session)
		if coop.dedicated:
			screen = "server"
			return
	Sounds.duck = false
	Sounds.set_track("combat")
	hud()

func _drop_session() -> void:
	if is_instance_valid(hud_panel):
		canvas.remove_child(hud_panel)
		hud_panel.queue_free()
		hud_panel = null
	if is_instance_valid(session):
		if coop.stage == session:
			coop.stage = null
		remove_child(session)
		session.queue_free()
		session = null
	get_tree().paused = false

func hud() -> void:
	if not is_instance_valid(session):
		return
	get_tree().paused = false
	session.player.input_blocked = false
	screen = "hud"
	Sounds.duck = false
	if is_instance_valid(view):
		canvas.remove_child(view)
		view.queue_free()
		view = null
	if not is_instance_valid(hud_panel):
		hud_panel = Hud.new()
		hud_panel.session = session
		canvas.add_child(hud_panel)
	hud_panel.show()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _freeze() -> void:
	get_tree().paused = not coop.in_match()
	Sounds.duck = true
	_free_cursor()
	if is_instance_valid(session):
		session.player.input_blocked = true
		session.player.arsenal.cancel_trigger()
	if is_instance_valid(hud_panel):
		hud_panel.hide()

func _free_cursor() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _session_changed() -> void:
	if coop.dedicated:
		return
	if session.director.phase == Director.Phase.UPGRADE and (screen == "hud" or (coop.in_match() and screen != "upgrade")):
		field_notice = ""
		_upgrade()
	elif coop.in_match() and session.director.phase in [Director.Phase.PREP, Director.Phase.ACTIVE] \
			and screen in ["upgrade", "milestone"]:
		hud()

func _upgrade() -> void:
	_freeze()
	_new_screen("upgrade", "overlay")
	var director = session.director
	_header("RAVITAILLEMENT", "Vague %d neutralisée" % director.cleared,
		"Installez un module et préparez la vague %d. Le combat reprendra quand vous serez prêt." % (director.wave + 1))
	Palette.panel(view, Rect2(55, 203, 455, 354), Color("#122731"))
	Palette.panel(view, Rect2(529, 203, 696, 354), Color("#122731"))
	Palette.label(view, Rect2(72, 214, 422, 39), "MODULE GRATUIT", 20, Palette.CYAN, Palette.HEAD)
	Palette.label(view, Rect2(547, 213, 652, 39), "%d CR  ·  BOUTIQUE DE TERRAIN" % session.wallet.balance,
		23, Palette.AMBER, Palette.HEAD)
	var chosen := 0
	for option in session.choices():
		var spec: Dictionary = Catalog.UPGRADES[option]
		var y := 265 + chosen * 88
		var card := Palette.button(view, Rect2(72, y, 421, 74), "", pick.bind(option))
		card.accessibility_name = spec.name
		card.disabled = session.module_selected
		Palette.label(card, Rect2(13, 5, 388, 32), spec.name, 21, spec.tint, Palette.HEAD)
		Palette.label(card, Rect2(13, 38, 389, 30), spec.effect, 13, Palette.TEXT)
		chosen += 1
	for i in Wallet.OFFERS.size():
		var offer: Dictionary = Wallet.OFFERS[i]
		var row := 257 + i * 40
		var price: int = session.wallet.price(offer)
		Palette.label(view, Rect2(546, row, 187, 38), offer.name, 15, Palette.TEXT, Palette.HEAD)
		Palette.label(view, Rect2(734, row, 326, 38), offer.detail, 13, Palette.MUTED)
		var buy := Palette.button(view, Rect2(1063, row, 144, 36), "%d CR" % price, _buy_field.bind(offer.id))
		buy.accessibility_name = "Acheter " + offer.name
		buy.disabled = session.wallet.balance < price
	Palette.label(view, Rect2(58, 568, 935, 32), field_notice, 15, Palette.AMBER)
	Palette.button(view, Rect2(1025, 568, 183, 37), "Quitter la partie", _leave_intermission)
	var ready := Palette.button(view, Rect2(58, 610, 265, 47), "Prêt · lancer la vague", advance, true)
	if coop.in_match():
		ready.disabled = coop.roster.get(coop.local_id(), {}).get("ready", false)
		ready.text = "En attente de l’équipe" if ready.disabled else "Prêt pour la suite"
		shop_clock = Palette.label(view, Rect2(612, 610, 608, 47), "", 15, Palette.CYAN, Palette.MONO, HORIZONTAL_ALIGNMENT_RIGHT)
	if not ready.disabled:
		ready.grab_focus()
	if director.total_waves == 0 and (not coop.in_match() or coop.hosting):
		Palette.button(view, Rect2(336, 610, 234, 47), "Encaisser le bilan", bank_run)
	_footer("VAGUE %d  /  GRAINE %d" % [director.cleared, session.run_seed])

func pick(index: int) -> void:
	if screen != "upgrade" or session.module_selected or not session.choices().has(index):
		return
	if coop.in_match():
		coop.field_action("module", "", index)
		return
	session.choose_upgrade(index)
	field_notice = "%s installé" % Catalog.UPGRADES[index].name
	_upgrade()

func _buy_field(id: String) -> void:
	if screen != "upgrade":
		return
	if coop.in_match():
		coop.field_action("buy", id, -1)
		return
	var receipt: Dictionary = session.buy_offer(id)
	field_notice = receipt.message
	_upgrade()

func advance() -> void:
	if screen == "upgrade" and session.director.phase == Director.Phase.UPGRADE:
		if coop.in_match():
			coop.ready_up()
			return
		session.ready_next_wave()
		hud()

func bank_run() -> void:
	if is_instance_valid(session) and (not coop.in_match() or coop.hosting):
		session.director.bank()

func _leave_intermission() -> void:
	var copy := "La partie s’arrêtera pour tous les pilotes." if coop.in_match() and coop.hosting else "Les crédits de cette opération seront perdus."
	confirm("Quitter l’opération ?", copy, menu, func():
		if session.director.phase == Director.Phase.UPGRADE:
			_upgrade()
		else:
			hud())

func _milestone() -> void:
	if coop.dedicated:
		session.director.continue_endless.call_deferred()
		return
	_freeze()
	_new_screen("milestone", "overlay")
	_header("CAMPAGNE TERMINÉE", "Secteur sous contrôle", "Vingt vagues sécurisées. Choisissez la suite de cette opération.")
	Palette.panel(view, Rect2(56, 238, 1168, 251), Color("#102c35"), Palette.CYAN)
	Palette.label(view, Rect2(82, 254, 1110, 72), "VICTOIRE  ·  %d POINTS" % session.director.score, 44, Palette.TEXT, Palette.HEAD)
	Palette.label(view, Rect2(86, 341, 1057, 67), "Poursuivre conserve votre équipement, vos crédits et la graine de partie.",
		18, Palette.MUTED)
	if not coop.in_match() or coop.hosting:
		Palette.button(view, Rect2(57, 544, 345, 57), "Continuer en Infini", func():
			session.director.continue_endless()
			_upgrade(), true).grab_focus()
		Palette.button(view, Rect2(420, 544, 410, 57), "Encaisser et afficher le bilan", bank_run)
	else:
		Palette.label(view, Rect2(57, 542, 1075, 50), "L’hôte choisit de poursuivre ou d’encaisser le bilan.", 19, Palette.CYAN)
	_footer("GRAINE  %d  /  VAGUE 20" % session.run_seed)

func pause() -> void:
	if screen != "hud":
		return
	_freeze()
	_show_pause()

func _show_pause() -> void:
	_new_screen("pause", "overlay")
	_header("PAUSE", "Menu du pilote" if coop.in_match() else "Opération suspendue",
		"L’opération continue pour votre équipe." if coop.in_match() else "%s    /    %s" % [MODES[last_mode].name, Catalog.MAPS[last_map].name])
	var resume := Palette.button(view, Rect2(57, 229, 440, 58), "REPRENDRE     ›", hud, true)
	Palette.button(view, Rect2(57, 298, 440, 51), "Paramètres", func(): open_settings("pause"))
	Palette.button(view, Rect2(57, 359, 440, 51), "Commandes", controls)
	if not coop.in_match():
		Palette.button(view, Rect2(57, 420, 440, 51), "Recommencer", func():
			confirm("Recommencer l’opération ?", "Votre progression dans la partie en cours sera effacée.", _restart, _show_pause))
	if not coop.in_match() and session.director.total_waves == 0 and session.director.cleared > 0:
		Palette.button(view, Rect2(57, 542, 440, 51), "Encaisser le bilan", bank_run)
	Palette.button(view, Rect2(57, 481, 440, 51), "Quitter la partie" if coop.in_match() else "Retour au menu", func():
		var copy := "Fermer le salon déconnectera tous les pilotes." if coop.in_match() and coop.hosting else "Votre progression dans la partie en cours sera effacée."
		confirm("Retourner au menu ?", copy, menu, _show_pause))
	Palette.panel(view, Rect2(534, 229, 690, 303), Color("#10252d"))
	Palette.label(view, Rect2(559, 242, 620, 56), "ÉTAT DU PILOTE", 31, Palette.CYAN, Palette.HEAD)
	Palette.rule(view, Rect2(560, 307, 634, 1))
	Palette.label(view, Rect2(560, 321, 634, 61), "INTÉGRITÉ  %03d    /    BOUCLIER  %03d" % [
		ceili(session.player.health), ceili(session.player.shield)], 17, Palette.TEXT, Palette.MONO)
	Palette.label(view, Rect2(560, 384, 634, 67), "ÉQUIPEMENT   %s" % session.player.arsenal.spec().name.to_upper(), 17, Palette.TEXT, Palette.MONO)
	Palette.label(view, Rect2(560, 451, 634, 54), "TEMPS DE COMBAT   %s" % Palette.clock(session.director.elapsed), 17, Palette.MUTED, Palette.MONO)
	resume.grab_focus()
	_footer("ÉCHAP  /  REPRENDRE")

func confirm(title: String, copy: String, accept: Callable, cancel: Callable) -> void:
	_new_screen("confirm", "overlay")
	confirmation_cancel = cancel
	Palette.panel(view, Rect2(315, 211, 650, 296), Color("#10232c"), Palette.AMBER)
	Palette.label(view, Rect2(345, 234, 588, 43), "VALIDATION DE L’OPÉRATION", 14, Palette.AMBER, Palette.MONO)
	Palette.label(view, Rect2(343, 279, 595, 56), title, 38, Palette.TEXT, Palette.HEAD)
	Palette.label(view, Rect2(346, 343, 565, 52), copy, 16, Palette.MUTED, Palette.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
	var stay := Palette.button(view, Rect2(346, 431, 269, 48), "Annuler", cancel)
	Palette.button(view, Rect2(632, 431, 301, 48), "Confirmer", accept, true)
	stay.grab_focus()
	_footer("ÉCHAP  /  ANNULER")

func _restart() -> void:
	begin(last_mode, last_difficulty, last_map)

func open_settings(origin: String) -> void:
	options_origin = origin
	_new_screen("settings", "overlay" if origin == "pause" else "page")
	settings = Options.new()
	settings.close = _close_settings
	view.add_child(settings)
	_footer("ÉCHAP  /  RETOUR    •    TAB  /  PARCOURIR LES RÉGLAGES")

func _close_settings() -> void:
	if options_origin == "pause":
		_show_pause()
	else:
		menu()

func controls() -> void:
	_new_screen("controls", "overlay")
	_header("COMMANDES", "Prendre les commandes", "Les touches affichées suivent votre profil clavier.")
	var lines := [
		["Se déplacer", _movement_keys()],
		["Tirer et viser à la lunette", "Clic gauche  /  Clic droit"],
		["Sauter et sprinter", "%s  /  %s" % [_key("jump"), _key("sprint")]],
		["S’accroupir et glisser", "%s  /  %s pendant le sprint" % [_key("crouch"), _key("crouch")]],
		["Équipement et recharge", "%s %s %s %s ou molette  /  %s" % [_key("slot_1"), _key("slot_2"), _key("slot_3"), _key("slot_4"), _key("reload")]],
		["Interagir et afficher le journal", "%s  /  %s" % [_key("interact"), _key("stats")]],
		["Activer le gadget et inspecter l’arme", "%s  /  %s" % [_key("gadget"), _key("inspect")]],
	]
	Palette.panel(view, Rect2(57, 207, 1166, 335), Color("#10252d"))
	for i in lines.size():
		var y := 217 + i * 44
		Palette.label(view, Rect2(75, y, 567, 40), lines[i][0], 17, Palette.TEXT, Palette.BOLD)
		Palette.label(view, Rect2(645, y, 555, 40), lines[i][1], 16, Palette.CYAN, Palette.MONO)
		if i < lines.size() - 1:
			Palette.rule(view, Rect2(75, y + 41, 1128, 1))
	Palette.button(view, Rect2(57, 571, 247, 54), "Retour à la pause", _show_pause, true).grab_focus()
	_footer("ÉCHAP  /  RETOUR")

func _result(victory: bool, owner: Node3D) -> void:
	if not is_instance_valid(owner) or owner != session or coop.dedicated:
		return
	_freeze()
	var online := coop.in_match()
	var record_mode := "coop" if online else last_mode
	var report: Dictionary = session.result_override if not session.result_override.is_empty() else session.result_data(victory)
	var wave: int = session.director.cleared
	var score: int = session.director.score
	var kills: int = session.director.kills
	var elapsed: float = session.director.elapsed
	var accuracy := roundi(100.0 * report.hits / maxi(1, report.shots))
	var reward: Dictionary = session.credited_result
	if reward.is_empty() or not reward.ok:
		reward = Prefs.complete_run(session.run_id, record_mode, last_difficulty, last_map, report)
		session.credited_result = reward
	var best: bool = reward.get("best", false)
	var leaderboard := Prefs.leaderboard(record_mode, last_difficulty, last_map)
	var top: int = 0 if leaderboard.is_empty() else leaderboard[0].score
	var subtitle := "%s   /   %s   /   %s" % [MODES[last_mode].name, Catalog.MAPS[last_map].name, Catalog.DIFFICULTIES[last_difficulty].name]
	_new_screen("result", "overlay")
	var name := "Extraction validée" if session.director.withdrawn else ("Secteur sécurisé" if victory else ("Temps écoulé" if last_mode == "trial" and elapsed >= Director.TRIAL_TIME else "Signal perdu"))
	_header("VICTOIRE" if victory else "OPÉRATION TERMINÉE", name, subtitle)
	Sounds.play("win" if victory else "loss")
	Palette.panel(view, Rect2(57, 215, 1166, 161), Color("#112a32"), Palette.CYAN if victory else Palette.LINE)
	Palette.label(view, Rect2(79, 227, 513, 30), "SCORE FINAL", 14, Palette.MUTED, Palette.MONO)
	Palette.label(view, Rect2(75, 256, 668, 101), "%06d" % score, 68, Palette.TEXT, Palette.MONO)
	Palette.label(view, Rect2(737, 238, 449, 33), "NOUVEAU RECORD" if best else "RECORD LOCAL", 14,
		Palette.AMBER if best else Palette.MUTED, Palette.MONO, HORIZONTAL_ALIGNMENT_RIGHT)
	Palette.label(view, Rect2(733, 275, 456, 55), "%06d" % top, 36, Palette.AMBER, Palette.MONO, HORIZONTAL_ALIGNMENT_RIGHT)
	var rows := [
		["VAGUES", "%d / %d" % [wave, session.director.total_waves] if session.director.total_waves > 0 else str(wave)],
		["NEUTRALISÉS", "%d" % kills if last_mode != "trial" else "%d / %d" % [kills, session.director.trial_goal]],
		["PRÉCISION", "%d %%" % accuracy],
		["DURÉE", Palette.clock(elapsed)],
		["MEILLEURE SÉRIE", "×%d" % session.director.highest_combo],
	]
	if last_mode == "trial":
		rows.remove_at(0)
	for i in rows.size():
		var width := 1166.0 / rows.size()
		var x := 57.0 + i * width
		Palette.panel(view, Rect2(x, 394, width - 9.0, 99), Color("#10242b"))
		Palette.label(view, Rect2(x + 13.0, 402, width - 29, 33), rows[i][0], 12, Palette.MUTED, Palette.MONO)
		Palette.label(view, Rect2(x + 13.0, 435, width - 29, 46), rows[i][1], 26, Palette.TEXT, Palette.MONO)
	var reward_label := "+%d PIÈCES   +%d XP   ·   NIVEAU %d" % [
		reward.get("coins", 0), reward.get("xp", 0), Profile.level(Prefs.profile.data.xp)] if reward.ok else String(reward.get("message", "Profil indisponible"))
	Palette.label(view, Rect2(59, 500, 1163, 43), reward_label, 16, Palette.AMBER, Palette.MONO)
	if not reward.ok:
		Palette.button(view, Rect2(642, 552, 280, 57), "Réessayer la sauvegarde", _result.bind(victory, owner))
	if online:
		Palette.button(view, Rect2(57, 552, 305, 57), "Retour à la coop", leave_coop, true).grab_focus()
	else:
		Palette.button(view, Rect2(57, 552, 305, 57), "REJOUER     ›", _restart, true).grab_focus()
	Palette.button(view, Rect2(377, 552, 246, 57), "Retour au menu", menu)
	_footer("RAPPORT D’OPÉRATION   /   CLASSEMENT PAR MODE, DIFFICULTÉ ET ARÈNE")

func credits() -> void:
	_new_screen("credits")
	_header("DOSSIER DE VOL", "Crédits", "NEON RIFT — ARENA  /  Version 2.0")
	Palette.panel(view, Rect2(57, 225, 1167, 298), Color("#10252d"))
	var credit := [
		["DÉVELOPPEMENT", "Conçu et réalisé avec Codex"],
		["MOTEUR", "Godot Engine 4.6.3 · GDScript · Compatibility · licence MIT"],
		["DIRECTION ARTISTIQUE ET AUDIO", "Arène, robots, équipements et sons originaux, générés pour le projet"],
		["TYPOGRAPHIE", "Open Sans et DejaVu Sans Mono · licences incluses"],
	]
	for i in credit.size():
		var y := 244 + i * 64
		Palette.label(view, Rect2(76, y, 365, 50), credit[i][0], 14, Palette.CYAN, Palette.MONO)
		Palette.label(view, Rect2(451, y, 729, 50), credit[i][1], 17, Palette.TEXT)
	Palette.button(view, Rect2(57, 556, 234, 56), "Retour au menu", menu, true).grab_focus()
	_footer("RCT 07   /   FIN DU DOSSIER")

func _short_controls() -> String:
	return "%s  /  SOURIS  /  ESPACE  /  MOLETTE  /  %s RECHARGE" % [_movement_keys(), _key("reload")]

func _movement_keys() -> String:
	return " ".join([_key("forward"), _key("left"), _key("back"), _key("right")])

func _key(action: String) -> String:
	return OS.get_keycode_string(Prefs.keys[action])

func _prefs_changed(key: String) -> void:
	if key in ["quality", "all"]:
		if is_instance_valid(session):
			session.arena.apply_quality()
		if is_instance_valid(backdrop):
			backdrop.apply_quality()

func _focus_lost() -> void:
	if screen == "hud":
		pause()

func _quit() -> void:
	if exiting:
		return
	exiting = true
	if Prefs.dirty:
		Prefs.save_disk()
	_free_cursor()
	coop.stop()
	_drop_session()
	_drop_backdrop()
	if is_instance_valid(view):
		canvas.remove_child(view)
		view.queue_free()
		view = null
	Sounds.stop_all()
	await get_tree().create_timer(0.14, true, false, true).timeout
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	match screen:
		"hud": pause()
		"pause": hud()
		"upgrade": _leave_intermission()
		"select", "result", "credits", "hub", "profile", "lobby": menu()
		"controls": _show_pause()
		"settings":
			if is_instance_valid(settings):
				settings._back()
		"confirm":
			if confirmation_cancel.is_valid():
				confirmation_cancel.call()
	get_viewport().set_input_as_handled()

func open_hub(page: String, group := "Armes", id := "", notice := "") -> void:
	_new_screen("hub")
	_header("HANGAR", "Arsenal du pilote" if page == "arsenal" else "Boutique du pilote",
		"Composez votre équipement. Les armes peuvent être essayées au stand avant l’achat.")
	var panel := Hub.new()
	panel.app = self
	panel.page = page
	panel.category = group
	panel.selected = id
	panel.notice = notice
	view.add_child(panel)
	_footer("PIÈCES DU PILOTE  /  ACHATS LOCAUX")

func practice_weapon(id: String) -> void:
	begin("training", selected_difficulty, selected_map, -1, id)

func show_profile(page := "profile", notice := "") -> void:
	Prefs.profile.refresh_contracts()
	_new_screen("profile")
	var data: Dictionary = Prefs.profile.data
	var title: String = "Contrats locaux" if page == "contracts" else ("Classements locaux" if page == "records" else data.name)
	_header("DOSSIER PILOTE", title, "NIVEAU %02d   ·   %d XP   ·   %d PIÈCES" % [Profile.level(data.xp), data.xp, data.coins])
	Palette.panel(view, Rect2(57, 207, 1166, 361), Color("#142730"))
	if page == "contracts":
		var row := 0
		for id in Profile.CONTRACTS:
			var entry: Dictionary = Profile.CONTRACTS[id]
			var y := 231 + row * 98
			var value: int = data.contracts.progress[id]
			Palette.label(view, Rect2(78, y, 680, 35), entry.name, 25, Palette.TEXT, Palette.HEAD)
			Palette.label(view, Rect2(78, y + 35, 690, 30), "%d / %d  ·  %d pièces + %d XP" % [
				value, entry.goal, entry.coins, entry.xp], 14, Palette.CYAN, Palette.MONO)
			var claim := Palette.button(view, Rect2(900, y + 14, 287, 45),
				"Encaissé" if data.contracts.claimed[id] else "Encaisser", _claim.bind(id))
			claim.disabled = data.contracts.claimed[id] or value < entry.goal
			row += 1
	elif page == "records":
		var entries := []
		for mode in Prefs.MODES:
			for map_id in Prefs.MAPS:
				for difficulty in Prefs.DIFFICULTIES:
					var rows := Prefs.leaderboard(mode, difficulty, map_id)
					if not rows.is_empty():
						entries.append({"label": "%s  ·  %s  ·  %s" % ["Coop" if mode == "coop" else MODES[mode].name, Catalog.MAPS[map_id].name,
							Catalog.DIFFICULTIES[difficulty].name], "score": int(rows[0].score), "wave": int(rows[0].wave)})
		entries.sort_custom(func(a: Dictionary, b: Dictionary): return a.score > b.score)
		var scroll := ScrollContainer.new()
		Palette.at(view, scroll, Rect2(79, 228, 1118, 310))
		var rows := VBoxContainer.new()
		rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(rows)
		if entries.is_empty():
			rows.add_child(Label.new())
			rows.get_child(0).text = "Vos scores apparaîtront ici après une opération."
		for record in entries:
			var label := Label.new()
			label.text = "%07d pts   ·   %s%s" % [record.score, record.label, "  ·  Vague %d" % record.wave if record.wave > 0 else ""]
			label.custom_minimum_size.y = 37
			rows.add_child(label)
	else:
		var stats: Dictionary = data.stats
		var lines := [
			"%d opérations   /   %d victoires   /   %d robots" % [stats.runs, stats.wins, stats.kills],
			"Record personnel  ·  vague %d   /   %d boss neutralisés" % [stats.best_wave, stats.bosses],
			"Précision  ·  %d %%   /   %d tirs   /   %d CR dépensés" % [
				roundi(100.0 * stats.hits / maxi(1, stats.shots)), stats.shots, stats.spent],
		]
		for i in lines.size():
			Palette.label(view, Rect2(81, 230 + i * 48, 1107, 38), lines[i], 19, Palette.TEXT)
		var name := LineEdit.new()
		name.text = data.name
		name.max_length = 18
		Palette.at(view, name, Rect2(82, 389, 310, 46))
		Palette.button(view, Rect2(410, 389, 248, 46), "Enregistrer le nom", _rename_pilot.bind(name))
		Palette.button(view, Rect2(82, 473, 300, 46), "Réinitialiser la progression", _confirm_reset)
	Palette.label(view, Rect2(57, 574, 1166, 30), notice, 15, Palette.AMBER)
	Palette.button(view, Rect2(57, 615, 136, 43), "Retour", menu, true).grab_focus()
	Palette.button(view, Rect2(208, 615, 183, 43), "Profil", show_profile.bind("profile"))
	Palette.button(view, Rect2(405, 615, 183, 43), "Contrats", show_profile.bind("contracts"))
	Palette.button(view, Rect2(602, 615, 183, 43), "Classements", show_profile.bind("records"))
	_footer("PROFIL LOCAL   /   " + data.contracts.date)

func _claim(id: String) -> void:
	var result := Prefs.profile_action(Prefs.profile.claim.bind(id))
	show_profile("contracts", result.message)

func _rename_pilot(input: LineEdit) -> void:
	var result := Prefs.profile_action(func():
		Prefs.profile.data.name = Profile.safe_name(input.text)
		return {"ok": true, "message": "Nom de pilote enregistré."})
	show_profile("profile", result.message)

func _confirm_reset() -> void:
	confirm("Réinitialiser la progression ?", "Les déblocages, pièces, contrats et niveaux seront remis à zéro.",
		func(): confirm("Confirmer la remise à zéro ?", "Une copie du profil actuel sera conservée.",
			func():
				var receipt := Prefs.reset_progression()
				show_profile("profile", receipt.message),
			show_profile.bind("profile")), show_profile.bind("profile"))

func buy_from_hub(page: String, group: String, id: String) -> void:
	var receipt := Prefs.profile_action(Prefs.profile.buy.bind(id))
	if receipt.ok:
		Sounds.play("upgrade")
	open_hub(page, group, id, receipt.message)
