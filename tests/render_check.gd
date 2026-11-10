extends SceneTree

var app
var prefs
var sounds
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("NEON_QA_ISOLATED") != "1":
		printerr("Ce test exige une fenêtre et un profil isolé.")
		quit(2)
		return
	prefs = root.get_node("Prefs")
	sounds = root.get_node("Sounds")
	prefs.reset_settings()
	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(0, capture)
	app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	await sleep(0.38)
	await click(Vector2(166, 348))
	check(app.screen == "play", "Clic dans la fenêtre sur Jouer")
	await click_named("Survie")
	check(app.screen == "select", "Sélection de Survie dans le menu Jouer")
	await click(Vector2(293, 578))
	check(app.screen == "hud" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Démarrage et capture souris")
	var pilot = app.session.player
	var yaw: float = pilot.rotation.y
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(22, -11)
	motion.screen_relative = motion.relative
	Input.parse_input_event(motion)
	await sleep(0.15)
	check(absf(pilot.rotation.y - yaw) > 0.02 and absf(pilot.head.rotation.x) > 0.01, "La souris contrôle le lacet et la hauteur de visée")
	await escape()
	check(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Échap libère la souris et suspend la simulation")
	prefs.change_value("resolution", 0)
	await sleep(0.25)
	await RenderingServer.frame_post_draw
	check(DisplayServer.window_get_size() == Vector2i(960, 540) \
		and root.get_texture().get_image().get_size() == Vector2i(960, 540),
		"La fenêtre et la surface rendue passent à 960 × 540")
	prefs.change_value("fullscreen", true)
	await sleep(0.25)
	check(DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN],
		"Le mode plein écran est demandé au pilote d’affichage")
	prefs.change_value("fullscreen", false)
	prefs.change_value("resolution", 1)
	await sleep(0.25)
	check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED \
		and DisplayServer.window_get_size() == Vector2i(1280, 720), "Retour au fenêtré 1280 × 720")
	capture.clear_buffer()
	sounds.play("pulse")
	await sleep(0.11)
	var audio := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for sample in audio:
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	check(audio.size() > 0 and peak > 0.008, "Signal audio réellement mixé")
	print("AUDIO frames=", audio.size(), " peak=", peak)
	await escape()
	check(app.screen == "hud" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Reprise et nouvelle capture du curseur")
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	check(frame.get_size() == Vector2i(1280, 720) and frame.get_pixel(640, 160).v > 0.01, "Image de jeu 1280 × 720 rendue")
	var out := OS.get_environment("NEON_QA_CAPTURE")
	if not out.is_empty():
		frame.save_png(out)
	await v2_views(out.get_base_dir() if not out.is_empty() else "")
	AudioServer.remove_bus_effect(0, 0)
	sounds.stop_all()
	await sleep(0.28)
	app.queue_free()
	await process_frame
	quit(failed)

func v2_views(directory: String) -> void:
	app.menu()
	await click(Vector2(175, 342))
	await click_named("Coop")
	check(app.screen == "lobby" and app.lobby.address.is_visible_in_tree(), "Le lobby coop est accessible à la souris")
	await screenshot(directory, "lobby")
	app.menu()
	await click(Vector2(170, 414))
	check(app.screen == "hub", "L’arsenal est accessible à la souris")
	await click(Vector2(281, 648))
	check(app.screen == "hub", "La boutique est accessible depuis l’arsenal")
	app.open_hub("shop", "Armes", "wp_eclipse")
	await screenshot(directory, "arsenal")
	app.selected_map = "cryo"
	app.practice_weapon("wp_eclipse")
	await sleep(0.40)
	Input.action_press("ads")
	await sleep(0.45)
	# Software renderers can spend several frames compiling a fresh map's shaders.
	var scope_deadline := Time.get_ticks_msec() + 2500
	while app.session.player.arsenal.scope <= 0.95 and Time.get_ticks_msec() < scope_deadline:
		await process_frame
	print("SCOPE factor=", app.session.player.arsenal.scope, " software_fps=", Engine.get_frames_per_second())
	check(app.session.map_id == "cryo" and app.session.player.arsenal.scope > 0.95, "Chaufferie et lunette rendues dans la fenêtre")
	await screenshot(directory, "cryo_scope")
	Input.action_release("ads")
	app.begin("survival", "discovery", "cryo", 781)
	await sleep(0.30)
	var stage = app.session
	stage.director.open_wave()
	var limit := Time.get_ticks_msec() + 3500
	while stage.director.remaining() > 0 and Time.get_ticks_msec() < limit:
		if stage.units.is_empty() and not stage.director.pending.is_empty():
			stage._spawn(stage.director.pending[0])
		for unit in stage.units.duplicate():
			unit.take_hit(90000.0, unit.center(), Vector3.DOWN)
		await physics_frame
	check(app.screen == "upgrade" and stage.wallet.balance > 75, "Ravitaillement et monnaie visibles en 720p")
	await screenshot(directory, "intermission")
	app.menu()

func screenshot(directory: String, name: String) -> void:
	await sleep(0.28)
	await RenderingServer.frame_post_draw
	if not directory.is_empty():
		root.get_texture().get_image().save_png(directory.path_join(name + ".png"))

func click(point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		Input.parse_input_event(event)
		await sleep(0.09)

func click_named(title: String) -> void:
	var nodes: Array[Node] = [app.view]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		if node is Button and node.accessibility_name == title:
			await click(node.get_global_rect().get_center())
			return
		nodes.append_array(node.get_children())
	check(false, "Bouton accessible introuvable : " + title)

func escape() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	Input.parse_input_event(key)
	await sleep(0.08)
	key = InputEventKey.new()
	key.keycode = KEY_ESCAPE
	Input.parse_input_event(key)
	await sleep(0.1)

func sleep(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func check(ok: bool, title: String) -> void:
	print("PASS " if ok else "FAIL ", title)
	if not ok:
		failed += 1
