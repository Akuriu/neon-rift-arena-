extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("NEON_QA_ISOLATED") != "1":
		printerr("Ce banc exige une fenêtre et un profil isolé.")
		quit(2)
		return
	var started := Time.get_ticks_usec()
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	var initial = current_scene
	await RenderingServer.frame_post_draw
	var first := Time.get_ticks_usec()
	var ready := first
	if initial.has_signal("state_changed"):
		var deadline := Time.get_ticks_msec() + 20000
		while is_instance_valid(initial) and initial.state != initial.State.REVEAL_MENU and Time.get_ticks_msec() < deadline:
			await RenderingServer.frame_post_draw
		ready = Time.get_ticks_usec()
		if current_scene == initial:
			printerr("L’accueil n’est pas prêt.")
			quit(1)
			return
	await create_timer(0.3).timeout
	var frame_times := PackedFloat64Array()
	var drawings := PackedInt32Array()
	var triangles := PackedInt32Array()
	var mark := Time.get_ticks_usec()
	for index in 100:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if index >= 10:
			frame_times.append((now - mark) / 1000.0)
			drawings.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			triangles.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		mark = now
	frame_times.sort()
	drawings.sort()
	triangles.sort()
	print("BOOT_BENCH ", JSON.stringify({
		"first_ms": (first - started) / 1000.0, "ready_ms": (ready - started) / 1000.0,
		"p50_ms": frame_times[44], "p95_ms": frame_times[85], "p99_ms": frame_times[89],
		"draws": drawings[44], "primitives": triangles[44], "nodes": get_node_count(),
		"engine_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"peak_rss_kib": peak_rss(), "viewport": str(root.size),
	}))
	root.get_node("Sounds").stop_all()
	current_scene.queue_free()
	await create_timer(0.28).timeout
	quit()

func peak_rss() -> int:
	if OS.get_name() == "Linux":
		var status := FileAccess.open("/proc/self/status", FileAccess.READ)
		while status != null and not status.eof_reached():
			var line := status.get_line()
			if line.begins_with("VmHWM:"):
				return line.trim_prefix("VmHWM:").strip_edges().get_slice(" ", 0).to_int()
	return -1
