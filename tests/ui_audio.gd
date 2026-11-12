extends SceneTree

var failed := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("NEON_QA_ISOLATED") != "1":
		printerr("Ce test exige une fenêtre et un profil isolé.")
		quit(2)
		return
	var sounds := root.get_node("Sounds")
	var prefs := root.get_node("Prefs")
	var capture := AudioEffectCapture.new()
	var bus := AudioServer.get_bus_index("Interface")
	AudioServer.add_bus_effect(bus, capture)
	sounds.play_ui("ui_confirm")
	await create_timer(0.18).timeout
	var samples := capture.get_buffer(capture.get_frames_available())
	var peak := level(samples)
	print("MIX interface_frames=", samples.size(), " peak=", peak)
	check(samples.size() > 0 and peak > 0.006 and peak < 0.95, "Signal d’interface mixé sans saturation")
	var cursor: int = sounds.ui_cursor
	prefs.change_value("audio_ui", false)
	sounds.play_ui("ui_select")
	check(sounds.ui_cursor == cursor, "Le réglage coupe le bus d’interaction indépendamment")

	sounds.set_track("menu")
	sounds.set_region("skyline")
	var deadline := Time.get_ticks_msec() + 5000
	while (sounds.music_name != "menu" or sounds.region != "wind") and Time.get_ticks_msec() < deadline:
		await process_frame
	check(sounds.music_name == "menu" and sounds.region == "wind", "La musique et le vent démarrent après chargement")
	if sounds.music_name != "menu" or sounds.region != "wind":
		quit(1)
		return
	await create_timer(0.41).timeout
	var wind: AudioStreamPlayer = sounds.ambience[sounds.selected_region]
	sounds.set_region("grove")
	deadline = Time.get_ticks_msec() + 5000
	while sounds.region != "canopy" and Time.get_ticks_msec() < deadline:
		await process_frame
	check(sounds.region == "canopy" and wind.playing, "La nouvelle ambiance démarre pendant le fondu sortant")
	await create_timer(0.8).timeout
	check(not wind.playing and sounds.ambience[sounds.selected_region].playing, "Le fondu arrête la piste sortante")
	sounds.suspend(true)
	check(sounds.music[sounds.selected].stream_paused and sounds.ambience[sounds.selected_region].stream_paused,
		"La suspension gèle musique et ambiance")
	sounds.suspend(false)
	check(not sounds.music[sounds.selected].stream_paused and not sounds.ambience[sounds.selected_region].stream_paused,
		"La reprise réactive les lecteurs")
	var master := AudioEffectCapture.new()
	AudioServer.add_bus_effect(0, master)
	sounds.stop_all()
	await create_timer(0.17).timeout
	master.clear_buffer()
	await create_timer(0.18).timeout
	var silence := master.get_buffer(master.get_frames_available())
	check(silence.size() > 0 and level(silence) < 0.0005, "La sortie est silencieuse après stop_all")
	AudioServer.remove_bus_effect(0, 0)
	AudioServer.remove_bus_effect(bus, 0)
	quit(1 if failed else 0)

func level(samples: PackedVector2Array) -> float:
	var peak := 0.0
	for pair in samples:
		peak = maxf(peak, maxf(absf(pair.x), absf(pair.y)))
	return peak

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failed += 1
