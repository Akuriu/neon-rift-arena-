extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("NEON_QA_ISOLATED") != "1":
		printerr("Ce banc exige une fenêtre et un profil isolé.")
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	var quality := clampi(int(args[0]), 0, 3) if args.size() > 0 else 0
	var resolution := clampi(int(args[1]), 0, 3) if args.size() > 1 else 1
	var prefs := root.get_node("Prefs")
	prefs.change_value("quality", quality)
	prefs.change_value("resolution", resolution)
	prefs.change_value("vsync", false)
	prefs.change_value("ui_motion", false)
	Engine.max_fps = 0
	seed(7114)
	var app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	app.begin("teams", "expert", "reactor", 7114, "", false, {"bots": 12, "duration": 300})
	var stage = app.session
	app._freeze()
	var count := 7 if quality == 3 else 12
	for index in count:
		var spawn: Vector3 = stage.arena.spawn_points[index % stage.arena.spawn_points.size()]
		spawn.x += 1.75 * floori(float(index) / float(stage.arena.spawn_points.size()))
		stage.spawn_unit(stage.director.bot_kind(index + 1), spawn, false, -1, index + 1)
	if stage.units.size() != count:
		printerr("FAIL Le nombre de bots du banc diffère.")
		quit(1)
		return
	app.layer.visible = false
	var camera := Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(12, 4.0, 16), Vector3(0, 1.25, 0), Vector3.UP)
	camera.current = true
	for i in 22:
		await RenderingServer.frame_post_draw
	if args.size() > 2 and root.get_texture().get_image().save_png(args[2]) != OK:
		printerr("FAIL Impossible d’enregistrer la capture du banc.")
		quit(1)
		return
	var intervals := PackedFloat64Array()
	var calls := PackedInt32Array()
	var primitives := PackedInt32Array()
	var last := Time.get_ticks_usec()
	for index in 120:
		var pivot := sin(float(index) * 0.029) * 4.0
		camera.look_at(Vector3(pivot, 1.25, 0), Vector3.UP)
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		intervals.append((now - last) / 1000.0)
		last = now
		calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		primitives.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	intervals.sort()
	calls.sort()
	primitives.sort()
	print("FIXED ", JSON.stringify({
		"quality": quality, "window": str(root.size), "units": stage.units.size(), "frames": 120,
		"p50_ms": intervals[59], "p95_ms": intervals[113], "p99_ms": intervals[118], "draws": calls[59],
		"primitives": primitives[59], "engine_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC))
	}))
	root.get_node("Sounds").stop_all()
	app.queue_free()
	await create_timer(0.28, true).timeout
	quit()
