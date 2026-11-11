extends Node

const Session := preload("res://scenes/Session.tscn")
const Arena := preload("res://game/arena.gd")
const Depot := preload("res://game/skyline.gd")
const FRAME := Vector2(1280, 720)
const Director := preload("res://game/wave_director.gd")
const Catalog := preload("res://game/catalog.gd")
const Palette := preload("res://ui/skin.gd")
const Hud := preload("res://ui/hud.gd")
const Livery := preload("res://ui/livery.gd")
const Glyph := preload("res://ui/glyph.gd")
const Options := preload("res://ui/settings.gd")
const Hub := preload("res://ui/hub.gd")
const Profile := preload("res://services/profile.gd")
const Wallet := preload("res://game/economy/field_wallet.gd")
const Coop := preload("res://network/coop.gd")
const Lobby := preload("res://ui/lobby.gd")
const Rules := preload("res://game/modes/rules.gd")
const ClassicSetup := preload("res://ui/screens/classic_setup.gd")
const GunGameResult := preload("res://ui/screens/gun_game_result.gd")
const PlayMenu := preload("res://ui/screens/play.gd")
const ParkourSetup := preload("res://ui/screens/parkour_setup.gd")
const Courses := preload("res://game/modes/parkour_routes.gd")
const TouchLayer := preload("res://ui/mobile/touch_layer.gd")
const TouchEditor := preload("res://ui/mobile/editor.gd")
const CareerView := preload("res://ui/screens/career.gd")
const Career := preload("res://services/career.gd")
const Waves := preload("res://game/waves/generator.gd")

const MODES := {
	"survival": {"name": "Survie · 20 vagues", "tag": "CAMPAGNE", "line": "4 paliers majeurs · poursuite en Infini",
		"summary": "Traversez vingt vagues et affrontez le tireur d’élite. Encaissez la victoire ou poursuivez la même partie en Infini."},
	"short": {"name": "Survie · 10 vagues", "tag": "PATROUILLE", "line": "Format court · 2 affrontements majeurs",
		"summary": "Dix vagues, des achats entre les assauts et un combat final contre le commandant."},
	"endless": {"name": "Infini", "tag": "ENDURANCE", "line": "Rythme progressif · sortie volontaire",
		"summary": "Poursuivez jusqu’à la défaite ou encaissez le bilan après une vague réussie. Les apparitions simultanées restent limitées."},
	"trial": {"name": "Défi chronométré", "tag": "CHRONO", "line": "90 secondes · 15 cibles · classement",
		"summary": "Neutralisez toutes les cibles avant la fermeture du secteur. Chaque seconde restante compte."},
	"boss_rush": {"name": "Boss Rush", "tag": "BOSS", "line": "4 boss · 3 ravitaillements",
		"summary": "Défiez successivement le chef blindé, le commandant, le démineur lourd et le tireur d’élite, chacun avec son escorte. Achetez et équipez-vous entre les combats."},
	"training": {"name": "Entraînement", "tag": "ATELIER", "line": "4 cibles mobiles · 8 armes en prêt",
		"summary": "Toutes les armes sont disponibles, même verrouillées. La console de départ réarme le pilote et réinitialise les cibles."},
	"explore": {"name": "Exploration", "tag": "VISITE", "line": "Arène libre · zéro adversaire",
		"summary": "Explorez les voies et testez vos déplacements. La carte reste libre de tout adversaire."},
	"relax": {"name": "Détente", "tag": "REPRISE", "line": "5 vagues · rythme modéré",
		"summary": "Cinq vagues avec des adversaires moins puissants et des renforts espacés. Les crédits restent dans la partie."},
}
const ICON := preload("res://assets/art/rift.svg")

var layer: CanvasLayer
var canvas: Control
var view: Control
var matte: Livery
var screen := "menu"
var session
var hud_panel: Hud
var touch_panel: TouchLayer
var backdrop: Arena
var title_cam: Camera3D
var orbit := 0.0
var exiting := false
var last_mode := "survival"
var last_difficulty := "standard"
var last_map := "reactor"
var last_seed := -1
var last_rules := {}
var classic_setup: ClassicSetup
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
var map_preview: TextureRect
var records_label: Label
var start_button: Button
var mode_buttons := {}
var seed_input: LineEdit
var field_notice := ""
var coop: Coop
var lobby: Lobby
var shop_clock: Label
var version_label := ""

func _ready() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version")
	version_label = "v" + version.trim_suffix("-alpha") + " Alpha" if version.ends_with("-alpha") else "v" + version
	layer = CanvasLayer.new()
	add_child(layer)
	canvas = Control.new()
	layer.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.theme = Palette.theme()
	get_window().size_changed.connect(_safe_canvas)
	canvas.resized.connect(_fit_menu)
	_safe_canvas.call_deferred()
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
	if not is_instance_valid(title_cam) or not Prefs.values.ui_motion:
		return
	orbit += delta
	var shift := sin(orbit * 0.11)
	title_cam.position = Vector3(12.9 + shift * 1.34, 3.31, 18.6 + shift * 0.59)
	title_cam.look_at(Vector3(-3.5, 2.82, -5.6), Vector3.UP)

func _new_screen(name: String, treatment := "page") -> void:
	if is_instance_valid(session):
		_freeze()
	if Prefs.mobile():
		Input.emulate_mouse_from_touch = true
	_drop_menu_view()
	settings = null
	lobby = null
	shop_clock = null
	screen = name
	confirmation_cancel = Callable()
	view = Control.new()
	view.name = "Screen_" + name
	matte = Livery.new()
	matte.mode = treatment
	layer.add_child(matte)
	layer.move_child(matte, 0)
	canvas.add_child(view)
	view.size = FRAME
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit_menu()
	if Prefs.values.ui_motion and not Prefs.mobile():
		view.modulate.a = 0.84
		view.create_tween().tween_property(view, "modulate:a", 1.0, 0.15)

func _drop_menu_view() -> void:
	if is_instance_valid(view):
		canvas.remove_child(view)
		view.queue_free()
		view = null
	if is_instance_valid(matte):
		layer.remove_child(matte)
		matte.queue_free()
		matte = null

func _footer(copy: String) -> void:
	var line := Palette.rule(view, Rect2(57, 660, 1166, 1), Color(Palette.MUTED, 0.25))
	line.anchor_right = 1.0
	line.offset_right = -57.0
	Palette.label(view, Rect2(57, 671, 1030, 35), copy, 13, Palette.MUTED)
	var version := _right_block(172.0, 35.0, 671.0)
	Palette.label(version, Rect2(0, 0, 172, 35), version_label, 13, Palette.MUTED, Palette.MONO, HORIZONTAL_ALIGNMENT_RIGHT)

func _safe_canvas() -> void:
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if OS.has_feature("android"):
		var extent := get_window().get_visible_rect().size
		var safe := DisplayServer.get_display_safe_area()
		if safe.has_area():
			var inverse := get_window().get_final_transform().affine_inverse()
			var allowed := Rect2(Vector2.ZERO, extent).intersection(inverse * Rect2(safe))
			if allowed.has_area():
				_apply_safe_insets(allowed, extent)
	_fit_menu()

func _apply_safe_insets(allowed: Rect2, extent: Vector2) -> void:
	var x := minf(maxf(allowed.position.x, extent.x - allowed.end.x) + 4.0, extent.x * 0.24)
	var y := minf(maxf(allowed.position.y, extent.y - allowed.end.y) + 4.0, extent.y * 0.24)
	canvas.offset_left = x
	canvas.offset_right = -x
	canvas.offset_top = y
	canvas.offset_bottom = -y

func _fit_menu() -> void:
	if not is_instance_valid(view):
		return
	var factor := minf(canvas.size.x / FRAME.x, canvas.size.y / FRAME.y)
	view.scale = Vector2.ONE * factor
	view.size = Vector2(canvas.size.x / maxf(factor, 0.001), FRAME.y) if screen in ["menu", "touch_editor"] else FRAME
	view.position = (canvas.size - view.size * factor) * 0.5

func _right_block(width: float, height: float, y: float) -> Control:
	var block := Control.new()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(block)
	block.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	block.offset_left = -58.0 - width
	block.offset_right = -58.0
	block.offset_top = y
	block.offset_bottom = y + height
	return block

func _glyph(parent: Control, rect: Rect2, mark: String, ink: Color) -> void:
	var icon := Glyph.new()
	icon.mark = mark
	icon.ink = ink
	Palette.at(parent, icon, rect)

func _header(index: String, name: String, description: String) -> void:
	Palette.label(view, Rect2(57, 27, 840, 27), index, 15, Palette.AMBER, Palette.BOLD)
	Palette.label(view, Rect2(54, 61, 1140, 79), name, 57, Palette.TEXT, Palette.HEAD)
	if not description.is_empty():
		Palette.label(view, Rect2(57, 143, 1155, 36), description, 17, Palette.MUTED)
	Palette.rule(view, Rect2(57, 185, 1166, 1))

func _make_backdrop() -> void:
	if is_instance_valid(backdrop):
		return
	backdrop = Depot.new()
	backdrop.is_backdrop = true
	add_child(backdrop)
	title_cam = Camera3D.new()
	title_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	title_cam.position = Vector3(12.9, 3.31, 18.6)
	title_cam.fov = 64.0
	title_cam.far = 160.0
	add_child(title_cam)
	title_cam.look_at_from_position(title_cam.position, Vector3(-3.5, 2.82, -5.6), Vector3.UP)
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
	Sounds.set_region("skyline")
	_new_screen("menu", "home")
	var mark := TextureRect.new()
	mark.texture = ICON
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Palette.at(view, mark, Rect2(53, 29, 46, 46))
	Palette.rule(view, Rect2(107, 40, 1, 25))
	Palette.label(view, Rect2(120, 30, 282, 44), "FPS D’ARÈNE", 14, Palette.MUTED, Palette.MONO)
	var edition := _right_block(158.0, 32.0, 36.0)
	Palette.panel(edition, Rect2(0, 0, 158, 32), Color("#242823"), Color(Palette.AMBER, 0.41))
	Palette.rule(edition, Rect2(13, 13, 6, 6), Palette.AMBER)
	Palette.label(edition, Rect2(28, 0, 119, 32), "ALPHA PUBLIQUE", 12, Palette.TEXT, Palette.MONO)
	Palette.rule(view, Rect2(58, 107, 30, 2), Palette.AMBER)
	Palette.label(view, Rect2(99, 93, 297, 30), "SOLO  /  COOP", 14, Palette.AMBER, Palette.MONO)
	Palette.label(view, Rect2(52, 121, 670, 110), "RIFLE ARENA", 113, Palette.TEXT, Palette.BRAND)
	Palette.label(view, Rect2(58, 251, 520, 31), "Affrontez les bots en solo ou jouez jusqu’à quatre en coop.", 19, Palette.MUTED)
	var start := _home_link(Rect2(57, 302, 389, 70), "Jouer", "play", play_menu, true)
	_home_link(Rect2(57, 386, 389, 51), "Arsenal", "target", open_hub.bind("arsenal"))
	_home_link(Rect2(57, 448, 389, 51), "Progression", "progress", show_profile.bind("profile"))
	_home_link(Rect2(57, 510, 389, 51), "Paramètres", "settings", open_settings.bind("menu"))
	_home_link(Rect2(57, 590, 187, 46), "Crédits", "info", credits)
	_home_link(Rect2(255, 590, 191, 46), "Quitter", "quit", _quit)
	var map := _right_block(312.0, 99.0, 536.0)
	var plate := Palette.panel(map, Rect2(0, 0, 312, 99), Color(0.090, 0.104, 0.085, 0.88), Color(Palette.MUTED, 0.29))
	Palette.rule(plate, Rect2(0, 14, 3, 69), Palette.AMBER)
	Palette.label(plate, Rect2(18, 12, 206, 21), "APERÇU DE L’ARÈNE", 12, Palette.AMBER, Palette.MONO)
	Palette.label(plate, Rect2(16, 34, 235, 37), Catalog.MAPS.skyline.name, 29, Palette.TEXT, Palette.HEAD)
	Palette.label(plate, Rect2(18, 71, 210, 17), "Cour de chargement", 12, Palette.MUTED)
	Palette.rule(plate, Rect2(246, 18, 1, 62))
	_glyph(plate, Rect2(263, 35, 31, 31), "target", Palette.AMBER)
	start.grab_focus()
	_footer("Commandes tactiles" if Prefs.mobile() else "Clavier et souris")

func _home_link(rect: Rect2, title: String, icon: String, action: Callable, primary := false) -> Button:
	var button := Palette.button(view, rect, "", action, primary)
	button.accessibility_name = title
	var ink := Palette.BASE if primary else Palette.TEXT
	if not primary:
		button.add_theme_stylebox_override("normal", Palette.box(Color("#252922"), Palette.LINE, 4))
	var icon_size := 29.0 if primary else 22.0
	_glyph(button, Rect2(16.0, (rect.size.y - icon_size) * 0.5, icon_size, icon_size),
		icon, ink if primary else Palette.AMBER)
	Palette.label(button, Rect2(52, 0, rect.size.x - 90, rect.size.y), title,
		31 if primary else 19, ink, Palette.HEAD if primary else Palette.BOLD)
	if rect.size.x > 200.0:
		_glyph(button, Rect2(rect.size.x - 41.0, (rect.size.y - 23.0) * 0.5, 23, 23),
			"arrow", ink if primary else Palette.QUIET)
	return button

func play_menu() -> void:
	_new_screen("play")
	_header("RIFLE ARENA / JOUER", "Choisir un mode", "Choisissez une partie solo, un entraînement ou un salon coop.")
	PlayMenu.new().build(view, {"gungame": open_classic.bind("gungame"), "classic": open_classic,
		"parkour": open_parkour,
		"survival": select_session, "coop": open_lobby,
		"training": func(): begin("training", selected_difficulty, selected_map)})
	_home_link(Rect2(57, 593, 166, 53), "Retour", "back", menu)
	_footer("Parties locales et salons privés")

func _play_card(rect: Rect2, title: String, description: String, map_id: String, index: String,
		action: Callable, featured := false) -> void:
	var button := Palette.button(view, rect, "", action)
	button.accessibility_name = title
	var picture := TextureRect.new()
	picture.texture = load("res://assets/maps/%s.jpg" % map_id)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var crop := Control.new()
	crop.clip_contents = true
	crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Palette.at(button, crop, Rect2(270, 5, 299, 158))
	crop.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := Livery.new()
	veil.mode = "tile"
	crop.add_child(veil)
	Palette.label(button, Rect2(22, 15, 275, 24), index, 13, Palette.AMBER, Palette.MONO)
	Palette.label(button, Rect2(20, 48, 339, 47), title, 35, Palette.TEXT, Palette.HEAD)
	Palette.label(button, Rect2(22, 99, 248, 50), description, 16, Palette.MUTED)
	Palette.panel(button, Rect2(517, 111, 39, 39), Color("#252922"), Color(Palette.MUTED, 0.32))
	_glyph(button, Rect2(524, 118, 25, 25), "arrow", Palette.AMBER)
	if featured:
		button.grab_focus()

func open_lobby() -> void:
	_make_backdrop()
	_free_cursor()
	Sounds.duck = false
	Sounds.set_track("menu")
	_new_screen("lobby")
	_header("Jouer", "Coop", "Jouez en équipe sur le réseau local ou via l’adresse de l’hôte.")
	lobby = Lobby.new()
	lobby.net = coop
	lobby.back = play_menu
	view.add_child(lobby)
	_footer("2 à 4 joueurs")

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

func open_classic(variant := "classic") -> void:
	var initial := {}
	if Rules.LABELS.has(last_mode) and (last_mode == "gungame") == (variant == "gungame"):
		initial = {"mode": last_mode, "rules": last_rules, "seed": last_seed}
	elif variant == "gungame":
		initial = {"mode": "gungame", "rules": {"duration": 180}}
	_drop_session()
	_make_backdrop()
	_free_cursor()
	_new_screen("classic")
	_header("Jouer", "Gun Game" if variant == "gungame" else "Match contre les bots",
		"Huit armes en prêt, huit éliminations pour gagner." if variant == "gungame" else "Choisissez une carte, un format et le nombre de bots.")
	classic_setup = ClassicSetup.new()
	classic_setup.build(view, last_map if not initial.is_empty() else selected_map,
		last_difficulty if not initial.is_empty() else selected_difficulty, initial, _start_classic, play_menu, variant == "gungame")
	_footer("SCORE LOCAL   /   LES RÈGLES DU MATCH DÉFINISSENT LE CLASSEMENT")

func _start_classic(mode: String, difficulty: String, map_id: String, seed: int, rules: Dictionary) -> void:
	begin(mode, difficulty, map_id, seed, "", false, rules)

func open_parkour() -> void:
	_drop_session()
	_make_backdrop()
	_free_cursor()
	_new_screen("parkour")
	_header("Mouvement", "Parkour", "Traversez les portiques dans l’ordre. Une chute ou un retour au checkpoint ajoute deux secondes.")
	ParkourSetup.new().build(view, func(route: String, ghost: bool):
		begin("parkour", "standard", "skyline", -1, "", false, {"route": route, "ghost": ghost}))
	Palette.button(view, Rect2(57, 581, 166, 53), "Retour", play_menu)
	_footer("CHRONOMÈTRES PERSONNELS / Départ au premier portique / Pause disponible")

func _mode_name(mode: String) -> String:
	if mode == "parkour":
		return "Parkour"
	if mode == "coop":
		return "Coop"
	return Rules.LABELS[mode] if Rules.LABELS.has(mode) else MODES[mode].name

func select_session() -> void:
	_new_screen("select")
	_header("Jouer", "Survie et défis", "Choisissez le mode, la carte et la difficulté.")
	mode_buttons.clear()
	var index := 0
	for kind in MODES:
		var mode := MODES[kind] as Dictionary
		var rect := Rect2(57, 194 + index * 44, 438, 42)
		var card := Palette.button(view, rect, "", _choose_mode.bind(kind))
		card.accessibility_name = mode.name
		mode_buttons[kind] = card
		Palette.label(card, Rect2(13, 0, 390, 23), mode.name, 20, Palette.TEXT, Palette.HEAD)
		Palette.label(card, Rect2(14, 21, 392, 20), mode.line, 12, Palette.MUTED)
		index += 1
	Palette.panel(view, Rect2(526, 213, 699, 405), Color("#272b24"))
	select_title = Palette.label(view, Rect2(551, 226, 387, 44), "", 33, Palette.TEXT, Palette.HEAD)
	select_line = Palette.label(view, Rect2(552, 275, 387, 24), "", 13, Palette.CYAN, Palette.MONO)
	select_copy = Palette.label(view, Rect2(552, 302, 376, 64), "", 15, Palette.MUTED,
		Palette.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
	map_preview = TextureRect.new()
	map_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Palette.at(view, map_preview, Rect2(949, 226, 251, 141))
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
		Palette.panel(view, Rect2(881, 421, 319, 48), Color("#34382e"))
		Palette.label(view, Rect2(894, 423, 291, 43), Catalog.MAPS[selected_map].name, 18, Palette.TEXT, Palette.BOLD)
	select_map_copy = Palette.label(view, Rect2(552, 479, 638, 51), "", 14, Palette.MUTED,
		Palette.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
	records_label = Palette.label(view, Rect2(552, 537, 642, 65), "", 13, Palette.CYAN,
		Palette.MONO, HORIZONTAL_ALIGNMENT_LEFT, true)
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "Graine facultative"
	seed_input.max_length = 10
	Palette.at(view, seed_input, Rect2(57, 612, 438, 43))
	Palette.button(view, Rect2(57, 553, 133, 54), "Retour", play_menu)
	start_button = Palette.button(view, Rect2(205, 553, 290, 54), "DÉMARRER    ›", _start_selected, true)
	Palette.button(view, Rect2(881, 623, 319, 44), "Match contre les bots", open_classic)
	_refresh_selection()
	mode_buttons[selected_mode].grab_focus()
	_footer(_short_controls())

func _choose_mode(mode: String) -> void:
	selected_mode = mode
	_refresh_selection()

func _refresh_selection() -> void:
	for kind in mode_buttons:
		var control: Button = mode_buttons[kind]
		control.add_theme_stylebox_override("normal", Palette.box(Color("#3d3e32") if kind == selected_mode else Palette.PANEL,
			Palette.CYAN if kind == selected_mode else Palette.LINE, 6))
	var spec: Dictionary = MODES[selected_mode]
	select_title.text = spec.name
	select_line.text = spec.line.to_upper()
	select_copy.text = spec.summary
	select_map_copy.text = Catalog.MAPS[selected_map].summary
	map_preview.texture = load("res://assets/maps/%s.jpg" % selected_map)
	if selected_mode == "training":
		records_label.text = "SESSION D’ENTRAÎNEMENT   /   Neutralisations dans le journal du pilote"
		return
	if selected_mode in ["explore", "relax"]:
		records_label.text = "SESSION LIBRE   /   Sans classement ni récompense permanente"
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

func begin(mode: String, difficulty: String, map_id := "reactor", run_seed := -1, test_weapon := "", online := false, rules: Dictionary = {}) -> void:
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
	session.match_rules = rules
	if online:
		session.net = coop
	field_notice = ""
	add_child(session)
	last_seed = session.run_seed
	last_rules = session.director.options.duplicate() if mode == "parkour" else (session.classic.options.duplicate() if is_instance_valid(session.classic) else {})
	session.director.changed.connect(_session_changed)
	session.director.campaign_complete.connect(_milestone)
	session.director.finished.connect(_result.bind(session), CONNECT_DEFERRED)
	if online:
		coop.attach(session)
		if coop.dedicated:
			screen = "server"
			return
	Sounds.duck = false
	Sounds.set_region(last_map)
	Sounds.set_track("menu" if mode == "explore" else "combat")
	hud()

func _drop_session() -> void:
	if is_instance_valid(touch_panel):
		canvas.remove_child(touch_panel)
		touch_panel.queue_free()
		touch_panel = null
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
	_drop_menu_view()
	if not is_instance_valid(hud_panel):
		hud_panel = Hud.new()
		hud_panel.session = session
		canvas.add_child(hud_panel)
	hud_panel.show()
	if Prefs.mobile():
		Input.emulate_mouse_from_touch = false
		if not is_instance_valid(touch_panel):
			touch_panel = TouchLayer.new()
			touch_panel.stage = session
			touch_panel.pilot = session.player
			touch_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			touch_panel.pause_requested.connect(pause)
			canvas.add_child(touch_panel)
		touch_panel.show()
	elif DisplayServer.get_name() != "headless":
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
	if is_instance_valid(touch_panel):
		touch_panel.release_all()
		touch_panel.hide()

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
		var bought: int = session.wallet.bought(offer, director.wave)
		Palette.label(view, Rect2(546, row, 187, 38), offer.name, 15, Palette.TEXT, Palette.HEAD)
		Palette.label(view, Rect2(734, row, 326, 38), "%s  ·  %d/%d" % [offer.detail, bought, offer.limit], 13, Palette.MUTED)
		var buy := Palette.button(view, Rect2(1063, row, 144, 36), "Épuisé" if bought >= offer.limit else "%d CR" % price, _buy_field.bind(offer.id))
		buy.accessibility_name = "Acheter " + offer.name
		buy.disabled = session.wallet.balance < price or bought >= offer.limit
	var forecast: Dictionary = director.preview_wave(director.wave + 1)
	var summary := "PROCHAINE VAGUE  /  " + String(forecast.theme)
	if Waves.MODIFIERS.has(forecast.get("mutation")):
		summary += "  ·  " + Waves.MODIFIERS[forecast.mutation]
	if session.relay_state == 2:
		summary += "   /   Relais +48 CR"
	Palette.label(view, Rect2(58, 568, 935, 32), summary if field_notice.is_empty() else field_notice, 15, Palette.AMBER)
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
	if not coop.in_match() and director.cleared % 5 == 0:
		var challenge := Palette.button(view, Rect2(590, 610, 315, 47), "Renforts rapides · +60 CR", advance.bind(true))
		challenge.tooltip_text = "Accélère les renforts et leurs attaques pour une vague. Bonus à la réussite."
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

func advance(risk := false) -> void:
	if screen == "upgrade" and session.director.phase == Director.Phase.UPGRADE:
		if coop.in_match():
			coop.ready_up()
			return
		session.ready_next_wave(risk)
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
	_header("En partie", "Pause",
		"L’opération continue pour votre équipe." if coop.in_match() else (Courses.ROUTES[session.director.route].name if last_mode == "parkour" else "%s    /    %s" % [_mode_name(last_mode), Catalog.MAPS[last_map].name]))
	var resume := Palette.button(view, Rect2(57, 229, 440, 58), "Reprendre", hud, true)
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
	Palette.panel(view, Rect2(534, 229, 690, 303), Color("#272b24"))
	Palette.label(view, Rect2(559, 242, 620, 56), "Partie en cours", 31, Palette.CYAN, Palette.HEAD)
	Palette.rule(view, Rect2(560, 307, 634, 1))
	Palette.label(view, Rect2(560, 321, 634, 61), "Checkpoint %d / %d" % [session.director.next, session.director.checkpoints.size()] if last_mode == "parkour" else "Santé %d    ·    Protection %d" % [
		ceili(session.player.health), ceili(session.player.shield)], 17, Palette.TEXT, Palette.MONO)
	Palette.label(view, Rect2(560, 384, 634, 67), "Pénalités   +%.1f s" % session.director.penalty if last_mode == "parkour" else "Arme   %s" % session.player.arsenal.spec().name, 17, Palette.TEXT, Palette.MONO)
	Palette.label(view, Rect2(560, 451, 634, 54), "Durée   %s" % Palette.clock(session.director.elapsed), 17, Palette.MUTED, Palette.MONO)
	if Prefs.mobile():
		var accuracy := roundi(100.0 * session.hits / maxi(1, session.shots))
		Palette.label(view, Rect2(560, 505, 634, 24), "%d neutralisations  ·  %d %% de précision" % [
			session.director.kills, accuracy], 15, Palette.MUTED)
	if last_mode == "training":
		Palette.button(view, Rect2(534, 551, 344, 53), "Configurer les cibles", open_training)
	resume.grab_focus()
	_footer("Échap pour reprendre" if not Prefs.mobile() else "")

func open_training() -> void:
	_new_screen("training_setup", "overlay")
	_header("STAND", "Réglages d’entraînement", "Les distances utilisent les lignes de tir dégagées de l’arène.")
	var options: Dictionary = session.training_options
	var kinds := ["fixed", "moving", "air"]
	var distances := [0, 8, 16, 24]
	var times := [0, 30, 60, 90]
	var targets := _training_option("CIBLES", 57, ["Fixes", "Mobiles", "Aériennes"], kinds.find(options.targets))
	var distance := _training_option("DISTANCE", 453, ["Placement d’origine", "8 mètres", "16 mètres", "24 mètres"], distances.find(options.distance))
	var timer := _training_option("CHRONOMÈTRE", 849, ["Libre", "30 secondes", "60 secondes", "90 secondes"], times.find(options.time))
	Palette.button(view, Rect2(57, 413, 147, 54), "Retour", _show_pause)
	Palette.button(view, Rect2(220, 413, 326, 54), "LANCER L’EXERCICE", func():
		session.configure_training(kinds[targets.selected], distances[distance.selected], times[timer.selected])
		hud()
	, true).grab_focus()
	_footer("STAND LIBRE  /  LES HUIT ARMES SONT DISPONIBLES")

func _training_option(title: String, x: int, labels: Array[String], selected: int) -> OptionButton:
	Palette.label(view, Rect2(x, 237, 373, 42), title, 15, Palette.CYAN, Palette.MONO)
	var result := OptionButton.new()
	for label in labels:
		result.add_item(label)
	result.select(maxi(0, selected))
	Palette.at(view, result, Rect2(x, 287, 374, 57))
	return result

func confirm(title: String, copy: String, accept: Callable, cancel: Callable) -> void:
	_new_screen("confirm", "overlay")
	confirmation_cancel = cancel
	Palette.panel(view, Rect2(315, 211, 650, 296), Color("#282b24"), Palette.AMBER)
	Palette.label(view, Rect2(345, 234, 588, 43), "VALIDATION DE L’OPÉRATION", 14, Palette.AMBER, Palette.MONO)
	Palette.label(view, Rect2(343, 279, 595, 56), title, 38, Palette.TEXT, Palette.HEAD)
	Palette.label(view, Rect2(346, 343, 565, 52), copy, 16, Palette.MUTED, Palette.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
	var stay := Palette.button(view, Rect2(346, 431, 269, 48), "Annuler", cancel)
	Palette.button(view, Rect2(632, 431, 301, 48), "Confirmer", accept, true)
	stay.grab_focus()
	_footer("ÉCHAP  /  ANNULER")

func _restart() -> void:
	if last_mode == "parkour" and is_instance_valid(session):
		session.director.restart()
		hud()
		return
	begin(last_mode, last_difficulty, last_map, last_seed if Rules.LABELS.has(last_mode) else -1, "", false, last_rules)

func open_settings(origin: String) -> void:
	options_origin = origin
	_new_screen("settings", "overlay" if origin == "pause" else "page")
	settings = Options.new()
	settings.close = _close_settings
	settings.edit_touch = open_touch_editor
	view.add_child(settings)

func open_touch_editor() -> void:
	_new_screen("touch_editor")
	_header("TACTILE", "Disposition des commandes", "Déplacez un bouton dans l’aperçu ou ajustez sa taille et son opacité.")
	var editor := TouchEditor.new()
	editor.back = func(): open_settings(options_origin)
	view.add_child(editor)

func _close_settings() -> void:
	if options_origin == "pause":
		_show_pause()
	else:
		menu()

func controls() -> void:
	_new_screen("controls", "overlay")
	_header("Pause", "Commandes", "Commandes tactiles" if Prefs.mobile() else "Les touches affichées suivent votre profil clavier.")
	var lines := [
		["Se déplacer", _movement_keys()],
		["Tirer et viser à la lunette", "Clic gauche  /  Clic droit"],
		["Sauter et sprinter", "%s  /  %s" % [_key("jump"), _key("sprint")]],
		["S’accroupir et glisser", "%s  /  %s pendant le sprint" % [_key("crouch"), _key("crouch")]],
		["Équipement et recharge", "%s %s %s %s ou molette  /  %s" % [_key("slot_1"), _key("slot_2"), _key("slot_3"), _key("slot_4"), _key("reload")]],
		["Interagir et afficher le journal", "%s  /  %s" % [_key("interact"), _key("stats")]],
		["Activer le gadget et inspecter l’arme", "%s  /  %s" % [_key("gadget"), _key("inspect")]],
	]
	if Prefs.mobile():
		lines = [
			["Se déplacer", "Joystick. Le bouton Sprint active ou coupe la course."],
			["Orienter la caméra", "Glisser dans la moitié droite ou sur le bouton de tir."],
			["Tirer et viser", "Garder le bouton de tir enfoncé. Toucher l’icône de visée pour basculer."],
			["Sauter et glisser", "Toucher la flèche pour sauter. Glisser vers le bas pour s’accroupir."],
			["Recharger et changer d’arme", "Toucher les munitions pour recharger, les flèches pour changer."],
			["Utiliser le gadget", "Glisser la flèche de saut vers le côté."],
		]
	Palette.panel(view, Rect2(57, 207, 1166, 335), Color("#272b24"))
	for i in lines.size():
		var y := 217 + i * 44
		Palette.label(view, Rect2(75, y, 461, 40), lines[i][0], 17, Palette.TEXT, Palette.BOLD)
		Palette.label(view, Rect2(538, y, 658, 40), lines[i][1], 15, Palette.CYAN, Palette.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
		if i < lines.size() - 1:
			Palette.rule(view, Rect2(75, y + 41, 1128, 1))
	Palette.button(view, Rect2(57, 571, 247, 54), "Retour à la pause", _show_pause, true).grab_focus()
	_footer("" if Prefs.mobile() else "Échap pour revenir")

func _result(victory: bool, owner: Node3D) -> void:
	if not is_instance_valid(owner) or owner != session or coop.dedicated:
		return
	if last_mode == "parkour":
		_parkour_result()
		return
	_freeze()
	var online := coop.in_match()
	var record_mode := "coop" if online else last_mode
	var report: Dictionary = session.result_override if not session.result_override.is_empty() else session.result_data(victory)
	var elapsed: float = session.director.elapsed
	var accuracy := roundi(100.0 * report.hits / maxi(1, report.shots))
	var reward: Dictionary = session.credited_result
	if reward.is_empty() or not reward.ok:
		reward = Prefs.complete_run(session.run_id, record_mode, last_difficulty, last_map, report)
		session.credited_result = reward
	var best: bool = reward.get("best", false)
	var leaderboard := Prefs.leaderboard(record_mode, last_difficulty, last_map, report.get("rules", ""))
	var top: int = 0 if leaderboard.is_empty() else leaderboard[0].score
	var subtitle := "%s   /   %s   /   %s" % [_mode_name(last_mode), Catalog.MAPS[last_map].name, Catalog.DIFFICULTIES[last_difficulty].name]
	_new_screen("result", "overlay")
	var name := "Extraction validée" if session.director.withdrawn else ("Secteur sécurisé" if victory else ("Temps écoulé" if last_mode == "trial" and elapsed >= Director.TRIAL_TIME else "Signal perdu"))
	if report.has("outcome"):
		name = String(report.outcome).capitalize()
	_header("VICTOIRE" if victory else "OPÉRATION TERMINÉE", name, subtitle)
	Sounds.play("win" if victory else "loss")
	if last_mode == "gungame":
		GunGameResult.new().build(view, session.director, top, best, accuracy)
	else:
		_operation_result_stats(report, top, best, victory, accuracy)
	var reward_label := "+%d PIÈCES   +%d XP   ·   NIVEAU %d" % [
		reward.get("coins", 0), reward.get("xp", 0), Profile.level(Prefs.profile.data.xp)] if reward.ok else String(reward.get("message", "Profil indisponible"))
	if reward.ok and reward.has("message"):
		reward_label = reward.message
	elif not reward.get("badges", []).is_empty():
		reward_label += "   ·   SUCCÈS  " + String(reward.badges[0]).to_upper()
	Palette.label(view, Rect2(59, 500, 1163, 43), reward_label, 16, Palette.AMBER, Palette.MONO)
	if not reward.ok:
		Palette.button(view, Rect2(642, 552, 280, 57), "Réessayer la sauvegarde", _result.bind(victory, owner))
	if online:
		Palette.button(view, Rect2(57, 552, 305, 57), "Retour à la coop", leave_coop, true).grab_focus()
	else:
		Palette.button(view, Rect2(57, 552, 305, 57), "REJOUER     ›", _restart, true).grab_focus()
		if Rules.LABELS.has(last_mode) and reward.ok:
			Palette.button(view, Rect2(642, 552, 280, 57), "Modifier les règles", open_classic.bind(last_mode))
	Palette.button(view, Rect2(377, 552, 246, 57), "Retour au menu", menu)
	_footer("RAPPORT D’OPÉRATION   /   CLASSEMENT PAR MODE, DIFFICULTÉ ET ARÈNE")

func _operation_result_stats(report: Dictionary, top: int, best: bool, victory: bool, accuracy: int) -> void:
	var wave: int = session.director.cleared
	var score: int = session.director.score
	var kills: int = session.director.kills
	var elapsed: float = session.director.elapsed
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
	elif report.has("outcome"):
		rows = [["NEUTRALISÉS", str(kills)], ["DÉFAITES", str(report.deaths)],
			["SCORE ADVERSE", str(report.rival)], ["PRÉCISION", "%d %%" % accuracy],
			["DURÉE", Palette.clock(elapsed)]]
	for i in rows.size():
		var width := 1166.0 / rows.size()
		var x := 57.0 + i * width
		Palette.panel(view, Rect2(x, 394, width - 9.0, 99), Color("#10242b"))
		Palette.label(view, Rect2(x + 13.0, 402, width - 29, 33), rows[i][0], 12, Palette.MUTED, Palette.MONO)
		Palette.label(view, Rect2(x + 13.0, 435, width - 29, 46), rows[i][1], 26, Palette.TEXT, Palette.MONO)

func _parkour_result() -> void:
	_freeze()
	var report: Dictionary = session.director.report()
	var reward: Dictionary = session.credited_result
	if reward.is_empty() or not reward.ok:
		reward = Prefs.complete_parkour(session.run_id, report)
		session.credited_result = reward
	var course: Dictionary = Courses.ROUTES[report.route]
	var best: int = Prefs.profile.data.career.parkour.get(report.route, 0)
	var medal := Courses.medal(report.route, report.milliseconds) if report.valid else ""
	var subtitle: String = course.name if medal.is_empty() else "%s  ·  Médaille %s" % [course.name, medal.to_lower()]
	_new_screen("result", "overlay")
	_header("PARKOUR", "Nouveau record" if reward.get("best", false) else "Parcours terminé", subtitle)
	Palette.panel(view, Rect2(57, 215, 1166, 159), Palette.PANEL)
	Palette.label(view, Rect2(80, 232, 700, 30), "TEMPS TOTAL", 14, Palette.MUTED, Palette.MONO)
	Palette.label(view, Rect2(74, 273, 709, 86), Courses.clock(report.milliseconds), 63, Palette.TEXT, Palette.MONO)
	Palette.label(view, Rect2(803, 238, 389, 31), "RECORD PERSONNEL", 14, Palette.MUTED, Palette.MONO, HORIZONTAL_ALIGNMENT_RIGHT)
	Palette.label(view, Rect2(803, 281, 389, 55), Courses.clock(best) if best > 0 else "—", 33, Palette.AMBER, Palette.MONO, HORIZONTAL_ALIGNMENT_RIGHT)
	var rows := [["COURSE", Courses.clock(report.elapsed_ms)], ["RETOURS", str(report.retries)],
		["PÉNALITÉS", "+%.1f s" % (report.penalty_ms / 1000.0)], ["CHECKPOINTS", "%d / %d" % [report.checkpoints, course.points.size()]]]
	for i in rows.size():
		var x := 57 + i * 296
		Palette.panel(view, Rect2(x, 392, 278, 94), Palette.PANEL)
		Palette.label(view, Rect2(x + 17, 400, 245, 31), rows[i][0], 13, Palette.MUTED, Palette.MONO)
		Palette.label(view, Rect2(x + 17, 437, 245, 39), rows[i][1], 26, Palette.TEXT, Palette.MONO)
	Palette.label(view, Rect2(59, 503, 1157, 37), reward.get("message", ""), 17, Palette.AMBER)
	Palette.button(view, Rect2(57, 564, 305, 57), "Rejouer le parcours", _restart, true).grab_focus()
	Palette.button(view, Rect2(377, 564, 305, 57), "Changer de parcours", open_parkour)
	Palette.button(view, Rect2(697, 564, 246, 57), "Retour au menu", menu)
	if not reward.ok:
		Palette.button(view, Rect2(958, 564, 265, 57), "Réessayer la sauvegarde", _parkour_result)
	_footer("Les pénalités sont comprises dans le record. Aucun gain de pièces en Parkour.")

func credits() -> void:
	_new_screen("credits")
	_header("DOSSIER DE VOL", "Crédits", "Rifle Arena · " + version_label)
	Palette.panel(view, Rect2(57, 225, 1167, 298), Color("#272b24"))
	var credit := [
		["DÉVELOPPEMENT", "Conçu et réalisé avec Codex"],
		["MOTEUR", "Godot Engine 4.6.3 · GDScript · Compatibility · licence MIT"],
		["DÉCORS ET AUDIO", "Arènes, armes, personnages, textures et sons créés pour le jeu"],
		["TYPOGRAPHIE", "Open Sans et DejaVu Sans Mono · licences incluses"],
	]
	for i in credit.size():
		var y := 244 + i * 64
		Palette.label(view, Rect2(76, y, 365, 50), credit[i][0], 14, Palette.CYAN, Palette.MONO)
		Palette.label(view, Rect2(451, y, 729, 50), credit[i][1], 17, Palette.TEXT)
	Palette.button(view, Rect2(57, 556, 234, 56), "Retour au menu", menu, true).grab_focus()
	_footer("")

func _short_controls() -> String:
	if Prefs.mobile():
		return "Joystick pour avancer  ·  Glisser à droite pour viser"
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and Prefs.mobile():
		_focus_lost()
		Sounds.suspend(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED and Prefs.mobile():
		Sounds.suspend(false)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and Prefs.mobile():
		_back()

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
	_drop_menu_view()
	Sounds.stop_all()
	await get_tree().create_timer(0.14, true, false, true).timeout
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_ESCAPE:
		return
	_back()
	get_viewport().set_input_as_handled()

func _back() -> void:
	match screen:
		"hud": pause()
		"pause": hud()
		"upgrade": _leave_intermission()
		"select", "classic", "parkour", "lobby": play_menu()
		"play", "result", "credits", "hub", "profile", "career": menu()
		"touch_editor": open_settings(options_origin)
		"controls", "training_setup": _show_pause()
		"settings":
			if is_instance_valid(settings):
				settings._back()
		"confirm":
			if confirmation_cancel.is_valid():
				confirmation_cancel.call()

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
	Palette.panel(view, Rect2(57, 207, 1166, 361), Color("#282b24"))
	if page == "contracts":
		var row := 0
		for id in Profile.CONTRACTS:
			var entry: Dictionary = Profile.CONTRACTS[id]
			var y := 221 + row * 82
			var value: int = data.contracts.progress[id]
			Palette.label(view, Rect2(78, y, 680, 35), entry.name, 25, Palette.TEXT, Palette.HEAD)
			Palette.label(view, Rect2(78, y + 35, 690, 30), "%d / %d  ·  %d pièces + %d XP" % [
				value, entry.goal, entry.coins, entry.xp], 14, Palette.CYAN, Palette.MONO)
			var claim := Palette.button(view, Rect2(900, y + 14, 287, 45),
				"Encaissé" if data.contracts.claimed[id] else "Encaisser", _claim.bind(id))
			claim.disabled = data.contracts.claimed[id] or value < entry.goal
			row += 1
		var weekly: Dictionary = data.career.weekly
		var challenge := Career.challenge(weekly.period)
		Palette.label(view, Rect2(78, 467, 693, 37), challenge[0], 25, Palette.TEXT, Palette.HEAD)
		Palette.label(view, Rect2(78, 502, 690, 30), "%d / %d · 70 pièces + 150 XP" % [weekly.value, challenge[2]],
			14, Palette.AMBER, Palette.MONO)
		var claim := Palette.button(view, Rect2(900, 481, 287, 45),
			"Encaissé" if weekly.claimed else "Encaisser la semaine", _claim_week)
		claim.disabled = weekly.claimed or weekly.value < challenge[2]
	elif page == "records":
		var entries := []
		for key in Prefs.records:
			var parts: PackedStringArray = key.split("|")
			var rows: Array = Prefs.records[key]
			if rows.is_empty():
				continue
			var label := "%s  ·  %s  ·  %s" % [_mode_name(parts[0]), Catalog.MAPS[parts[2]].name, Catalog.DIFFICULTIES[parts[1]].name]
			if parts.size() == 4:
				var options := parts[3].split("-")
				label += "  ·  %s bots / %d min / %s pts" % [options[0], int(options[1]) / 60, options[2]]
			entries.append({"label": label, "score": int(rows[0].score), "wave": int(rows[0].wave)})
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
			"%d parties   ·   %d victoires   ·   %d neutralisations" % [stats.runs, stats.wins, stats.kills],
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
		var level := Profile.level(data.xp)
		Palette.label(view, Rect2(725, 389, 440, 46), "%d XP AVANT LE NIVEAU %d" % [level * level * 80 - data.xp, level + 1]
			if level < 500 else "NIVEAU MAXIMUM", 16, Palette.AMBER, Palette.MONO)
	Palette.label(view, Rect2(57, 574, 1166, 30), notice, 15, Palette.AMBER)
	Palette.button(view, Rect2(57, 615, 136, 43), "Retour", menu, true).grab_focus()
	Palette.button(view, Rect2(208, 615, 183, 43), "Profil", show_profile.bind("profile"))
	Palette.button(view, Rect2(405, 615, 183, 43), "Contrats", show_profile.bind("contracts"))
	Palette.button(view, Rect2(602, 615, 183, 43), "Classements", show_profile.bind("records"))
	Palette.button(view, Rect2(799, 615, 183, 43), "Carrière", show_career)
	_footer("PROFIL LOCAL   /   " + data.contracts.date)

func _claim(id: String) -> void:
	var result := Prefs.profile_action(Prefs.profile.claim.bind(id))
	show_profile("contracts", result.message)

func _claim_week() -> void:
	var result := Prefs.profile_action(Prefs.profile.claim_weekly)
	show_profile("contracts", result.message)

func show_career(page := "history") -> void:
	_new_screen("career")
	var titles := {"history": "Journal des parties", "ledger": "Transactions", "badges": "Succès locaux", "stats": "Statistiques"}
	_header("CARRIÈRE", titles[page], "Progression hors ligne et suivi des dernières opérations.")
	var panel := CareerView.new()
	panel.app = self
	panel.page = page
	view.add_child(panel)
	_footer("CARRIÈRE DU PILOTE   /   %s" % Prefs.profile.data.name)

func replay_report(run: Dictionary) -> void:
	if run.mode == "coop":
		open_lobby()
		return
	var rules := {}
	if Rules.valid_key(run.rules):
		var fields := String(run.rules).split("-")
		rules = {"bots": int(fields[0]), "duration": int(fields[1]), "target": int(fields[2])}
	begin(run.mode, run.difficulty, run.map, run.seed, "", false, rules)

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
