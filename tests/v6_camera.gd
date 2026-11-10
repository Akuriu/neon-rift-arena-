extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("NEON_QA_ISOLATED") != "1":
		quit(2)
		return
	var prefs := root.get_node("Prefs")
	prefs.change_value("head_bob", true)
	var app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	app.begin("explore", "standard", "skyline", 19)
	var pilot = app.session.player
	var camera = pilot.presentation
	var gun = pilot.arsenal
	var expected_fov: float = prefs.values.fov
	for _frame in 8:
		await physics_frame
	Input.action_press("forward")
	Input.action_press("sprint")
	var delta_peak := 0.0
	var width_peak := expected_fov
	var phase_peak := 0.0
	var moving := 0
	for frame in 45:
		var previous_fov: float = camera.fov
		var previous_phase: float = pilot.rendered_step_phase()
		if frame == 18:
			Input.action_release("sprint")
		if frame == 30:
			Input.action_release("forward")
		await process_frame
		width_peak = maxf(width_peak, camera.fov)
		delta_peak = maxf(delta_peak, absf(camera.fov - previous_fov))
		var phase: float = angle_difference(previous_phase, pilot.rendered_step_phase())
		phase_peak = maxf(phase_peak, absf(phase))
		moving += int(absf(phase) > 0.005)
	var returning: float = absf(camera.fov - expected_fov)
	check(width_peak > expected_fov + 1.0 and delta_peak < 1.45 and returning < 0.7,
		"FOV de sprint amorti avec retour propre")
	check(moving > 5 and phase_peak < 1.7 and camera.position.is_finite(),
		"Pas interpolés et position de caméra finie")
	var fov: float = camera.fov
	pilot.look_input(Vector2(33, 12))
	await process_frame
	await process_frame
	check(camera.global_basis.z.is_equal_approx(pilot.head.global_basis.z)
		and is_finite(fov) and gun.view.position.is_finite(), "Réponse de visée sans retard de direction")
	print("CAMERA frame_dt=", camera.get_process_delta_time(), " step_peak_rad=", phase_peak, " fov_delta=", delta_peak)
	root.get_node("Sounds").stop_all()
	app.queue_free()
	await process_frame
	quit(failures)

func check(ok: bool, description: String) -> void:
	print("PASS " if ok else "FAIL ", description)
	if not ok:
		failures += 1
