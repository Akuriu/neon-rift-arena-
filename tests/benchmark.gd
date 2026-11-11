extends SceneTree

func _initialize() -> void:
	call_deferred("measure")

func measure() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("NEON_QA_ISOLATED") != "1":
		printerr("Ce test exige une fenêtre et un profil isolé.")
		quit(2)
		return
	var prefs := root.get_node("Prefs")
	var audio := root.get_node("Sounds")
	var quality := 0
	var resolution := 1
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		quality = clampi(int(arguments[0]), 0, 3)
	if arguments.size() > 1:
		resolution = clampi(int(arguments[1]), 0, 3)
	prefs.change_value("fullscreen", false)
	prefs.change_value("resolution", resolution)
	prefs.change_value("vsync", false)
	prefs.change_value("quality", quality)
	Engine.max_fps = 0
	seed(7114)
	var app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	app.begin("survival", "expert", "reactor", 7114)
	var stage = app.session
	var pilot = stage.player
	pilot.damage_lock = 60.0
	stage.director.wave = 5
	stage.director.clock = 0.02
	await create_timer(8.8).timeout
	var last := Time.get_ticks_usec()
	var ms := PackedFloat64Array()
	var calls := PackedFloat64Array()
	for index in 180:
		pilot.rotation.y = sin(index * 0.025) * 0.75
		if index % 37 == 0:
			Input.action_press("fire")
		elif index % 37 == 19:
			Input.action_release("fire")
		await process_frame
		var now := Time.get_ticks_usec()
		ms.append((now - last) / 1000.0)
		last = now
		calls.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	Input.action_release("fire")
	ms.sort()
	calls.sort()
	print("BENCH preset=", quality, " resolution=", DisplayServer.window_get_size(),
		" scale=", root.scaling_3d_scale, " units=", stage.units.size(),
		" frames=", ms.size(), " median_ms=", snappedf(ms[ms.size() / 2], 0.01),
		" p95_ms=", snappedf(ms[floori(ms.size() * 0.95)], 0.01),
		" p99_ms=", snappedf(ms[floori(ms.size() * 0.99)], 0.01),
		" median_draw_calls=", calls[calls.size() / 2],
		" engine_static_mib=", snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1))
	audio.stop_all()
	app.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	await create_timer(0.30).timeout
	quit()
