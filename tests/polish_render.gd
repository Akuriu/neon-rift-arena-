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
	app.play_menu()
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
