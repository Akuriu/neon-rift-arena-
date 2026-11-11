extends SceneTree

var failed := 0
var output := OS.get_environment("RIFLE_QA_CAPTURE_DIR")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("NEON_QA_ISOLATED") != "1":
		printerr("Ce test exige une fenêtre et un profil isolé.")
		quit(2)
		return
	var start := Time.get_ticks_usec()
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	var boot = current_scene
	await RenderingServer.frame_post_draw
	var first := Time.get_ticks_usec()
	var opening := root.get_texture().get_image()
	check(has_title(opening), "Première image rendue avec le titre du jeu")
	save(opening, "10-demarrage")
	var deadline := Time.get_ticks_msec() + 12000
	while is_instance_valid(boot) and boot.state != boot.State.REVEAL_MENU and Time.get_ticks_msec() < deadline:
		await process_frame
	var ready := Time.get_ticks_usec()
	var app = current_scene
	check(app != boot and app.screen == "menu" and app.view.is_visible_in_tree(),
		"Accueil réel prêt sous le masque de démarrage")
	if app == boot:
		quit(1)
		return
	while is_instance_valid(boot) and Time.get_ticks_msec() < deadline:
		await process_frame
	await capture("11-accueil")
	var intervals := PackedFloat64Array()
	var calls := PackedFloat64Array()
	var last := Time.get_ticks_usec()
	for index in 100:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if index >= 10:
			intervals.append((now - last) / 1000.0)
			calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		last = now
	intervals.sort()
	calls.sort()
	print("MENU first_frame_ms=", (first - start) / 1000.0, " interactive_ms=", (ready - start) / 1000.0,
		" p50=", intervals[44], " p95=", intervals[85], " p99=", intervals[89], " draws=", calls[44],
		" nodes=", get_node_count(), " engine_mib=", Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	var play := button_named(app.view, "Jouer")
	check(play != null and play.has_focus(), "Jouer reçoit le focus à l’ouverture")
	if play == null:
		quit(1)
		return
	var point := play.get_global_transform_with_canvas() * (play.size * 0.5)
	click(point, true)
	await RenderingServer.frame_post_draw
	check(play.scale.x < 1.0 and app.screen == "menu", "Compression du bouton lors d’un vrai clic fenêtré")
	save(root.get_texture().get_image(), "16-jouer-presse")
	click(point, false)
	await process_frame
	check(app.screen == "play", "Le clic ouvre Jouer pendant la transition")
	await capture("12-jouer")
	app.request_match("training", "standard", "skyline", 381)
	await RenderingServer.frame_post_draw
	var map_image := root.get_texture().get_image()
	save(map_image, "13-chargement-carte")
	check(app.map_loading != null and app.map_loading.image != null and map_image.get_pixel(870, 320).v > 0.06,
		"Le chargement de carte affiche la miniature dans une image rendue")
	deadline = Time.get_ticks_msec() + 16000
	while app.screen == "loading" and Time.get_ticks_msec() < deadline:
		await process_frame
	check(app.screen == "hud" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"Le HUD et la capture souris sont rétablis après le chargement")
	if app.screen == "hud":
		await capture("14-depot")
		app.pause()
		await capture("15-pause")
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "La pause rend le curseur")
	app.menu()
	app.open_settings("menu")
	app.settings.show_tab(5)
	await capture("17-accessibilite")
	root.size = Vector2i(1600, 720)
	await process_frame
	var extent := root.get_visible_rect().size
	app._apply_safe_insets(Rect2(Vector2(57, 0), extent - Vector2(69, 0)), extent)
	await capture("18-accessibilite-20-9")
	check(root.size == Vector2i(1600, 720) and app.canvas.get_global_rect().position.x > 57.0,
		"Fenêtre 20:9 et encoche asymétrique simulée")
	for extent_target in [Vector2i(960, 540), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = extent_target
		await process_frame
		app._safe_canvas()
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		check(frame.get_size() == extent_target, "Surface réellement rendue en " + str(extent_target))
		save(frame, "19-options-%dx%d" % [extent_target.x, extent_target.y])
	root.get_node("Sounds").stop_all()
	app.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	quit(1 if failed else 0)

func has_title(frame: Image) -> bool:
	var extent := Vector2(frame.get_size())
	for y in range(220, 350, 10):
		for x in range(72, 628, 12):
			var pixel := Vector2i(Vector2(x, y) / Vector2(1280, 720) * extent)
			if frame.get_pixelv(pixel).v > 0.8:
				return true
	return false

func button_named(parent: Node, label: String) -> Button:
	for button in parent.find_children("*", "Button", true, false):
		if button.accessibility_name == label or button.text == label:
			return button
	return null

func click(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	Input.parse_input_event(event)

func capture(name: String) -> void:
	await create_timer(0.25, true, false, true).timeout
	await RenderingServer.frame_post_draw
	save(root.get_texture().get_image(), name)

func save(frame: Image, name: String) -> void:
	if not output.is_empty():
		check(frame.save_png(output.path_join(name + ".png")) == OK, "Capture moteur " + name)

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failed += 1
