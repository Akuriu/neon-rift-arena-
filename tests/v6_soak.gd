extends SceneTree

const INPUTS := ["forward", "right", "fire"]
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("NEON_QA_ISOLATED") != "1":
		quit(2)
		return
	var seconds := 1200
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seconds="):
			seconds = clampi(argument.trim_prefix("--seconds=").to_int(), 10, 1800)
	var prefs := root.get_node("Prefs")
	var app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	var start := Time.get_ticks_msec()
	var deadline := start + seconds * 1000
	var segments := 0
	var low := -1
	var high := 0
	var duration := clampf(seconds / 14.0, 2.0, 84.0)
	while Time.get_ticks_msec() < deadline:
		var map: String = prefs.MAPS[segments % prefs.MAPS.size()]
		app.begin("teams", "standard", map, 400 + segments, "", false,
			{"bots": 8, "duration": 300, "target": 100})
		var stage = app.session
		stage.classic.open_wave()
		var end := mini(deadline, Time.get_ticks_msec() + int(duration * 1000.0))
		var step := 0
		while app.screen == "hud" and Time.get_ticks_msec() < end:
			if step % 12 == 5:
				_release()
				app.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
				check(app.screen == "pause" and paused, "Suspension tactile pendant le combat", false)
				app.open_settings("pause")
				app.settings.show_tab(4)
				await process_frame
				app.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
				app.hud()
				check(app.screen == "hud" and not paused and stage.player.steering().is_zero_approx(),
					"Reprise sans entrée bloquée", false)
			Input.action_press(INPUTS[step % INPUTS.size()])
			await create_timer(0.37, true, false, true).timeout
			_release()
			step += 1
		_release()
		check(stage.player.position.is_finite() and stage.projectile_bin.get_child_count() <= 80,
			"Partie valide, projectiles recyclés", false)
		app.menu()
		await process_frame
		await process_frame
		var used := int(Performance.get_monitor(Performance.MEMORY_STATIC))
		print("SOAK map=", map, " elapsed_s=", (Time.get_ticks_msec() - start) / 1000,
			" steps=", step, " engine_static_bytes=", used)
		if segments >= 7:
			low = used if low < 0 else mini(low, used)
			high = maxi(high, used)
		segments += 1
	check(Time.get_ticks_msec() >= deadline and segments >= 2, "Endurance solo headless en temps réel")
	if low >= 0:
		check(high - low < 16 * 1048576, "Mémoire moteur bornée après chargement des sept cartes")
	root.get_node("Sounds").stop_all()
	app.queue_free()
	await process_frame
	quit(failures)

func _release() -> void:
	for action in INPUTS:
		Input.action_release(action)

func check(ok: bool, message: String, print_success := true) -> void:
	if not ok:
		failures += 1
		print("FAIL ", message)
	elif print_success:
		print("PASS ", message)
