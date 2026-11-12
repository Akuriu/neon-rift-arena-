extends SceneTree

var failed := 0
var actions := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var prefs := root.get_node("Prefs")
	var app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	var skin = load("res://ui/skin.gd")
	var button = skin.button(app.view, Rect2(800, 305, 190, 56), "Essai", func(): actions += 1)
	button.button_down.emit()
	var compress: Tween = button.motion
	check(button.scale.x < 1.0, "Le retour visuel commence pendant le signal de pression")
	check(button._has_point(button.pivot_offset + (Vector2(0.2, 0.2) - button.pivot_offset) / button.scale),
		"La zone de clic logique reste stable quand le bouton se comprime")
	button.button_up.emit()
	check(not compress.is_valid() and button.motion.is_running(), "Le relâchement remplace le tween de pression")
	button.pressed.emit()
	check(actions == 1, "L’action s’exécute avant la fin du retour visuel")
	button.button_down.emit()
	button.button_up.emit()
	await frames(32)
	check(button.scale.is_equal_approx(Vector2.ONE), "Le retour élastique rejoint exactement l’échelle de repos")
	button.button_down.emit()
	button.hide()
	button.pressed.emit()
	check(actions == 1 and button.motion == null and button.scale == Vector2.ONE,
		"Un bouton masqué libère son tween et son action")

	var obsolete: Control = app.view
	app.play_menu()
	var page: Tween = app.router.animation
	var offset: Vector2 = app.screen_surface.position
	app._back()
	check(not page.is_valid() and app.router.animation.is_running() and app.screen_surface.position == offset,
		"Le retour interrompt le panneau sans déplacer brusquement la surface")
	check(not obsolete.is_inside_tree() and app.screen_surface.get_child_count() == 1 and app.router.history == ["menu"],
		"Une seule vue reçoit les entrées et l’historique revient à l’accueil")
	app.open_settings("menu")
	var settings = app.settings
	settings.show_tab(1)
	var indicator: Tween = settings.tab_motion
	settings.show_tab(5)
	check(not indicator.is_valid() and settings.active == 5, "Les onglets changent immédiatement et retargetent l’indicateur")
	prefs.change_value("ui_motion", false)
	check(app.router.animation == null and app.screen_surface.position == Vector2.ZERO and settings.tab_motion == null,
		"Le mouvement réduit termine les animations en cours")
	check(prefs.save_disk(), "La préférence de mouvement est enregistrée")
	prefs.load_disk()
	check(not prefs.values.ui_motion, "Le mouvement réduit reste actif après relecture")

	settings.show_tab(3)
	settings._start_binding("jump")
	settings.show_tab(0)
	check(settings.active == 3 and settings.capture_overlay.mouse_filter == Control.MOUSE_FILTER_STOP,
		"La modale de touche intercepte les clics et garde l’onglet actif")
	settings._cancel_binding()
	check(settings.capture_overlay == null and settings.button_by_action.jump.has_focus(),
		"La fermeture de la modale restaure le focus")
	app.queue_free()
	await frames(2)
	check(get_processed_tweens().is_empty(), "Aucun tween actif après destruction de l’interface")
	quit(1 if failed else 0)

func frames(count: int) -> void:
	for _index in count:
		await process_frame

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failed += 1
