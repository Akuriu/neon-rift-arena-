extends SceneTree

var failed := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var prefs := root.get_node("Prefs")
	prefs.change_value("quality", 2)
	var fx = load("res://game/effects.gd").new()
	root.add_child(fx)
	for index in 149:
		var origin := Vector3(float(index % 7), 0.2, 0.0)
		fx.beam(origin, origin + Vector3.FORWARD * 3.0, Color("#d7bf8a"), 0.04, 0.3)
	check(fx.active.size() == 120 and fx.get_child_count() == 120, "Les effets simultanés respectent le pool Élevée")
	prefs.change_value("quality", 3)
	check(fx.active.size() == 64 and fx.active.all(func(id: int): return id < 64),
		"Passer en Ultra faible désactive immédiatement les emplacements hors budget")
	fx.wave(Vector3.ZERO, Color("#c4b08c"), 3.0)
	check(fx.active.size() == 64 and fx.next_slot < 64, "L’anneau réutilise un emplacement dans le budget")
	await create_timer(0.5).timeout
	check(fx.active.is_empty() and not fx.is_processing(), "Le pool retourne au repos sans traitement par image")
	prefs.change_value("quality", 2)
	prefs.change_value("particles", 0.0)
	fx.impact(Vector3.ZERO, Vector3.UP, Color.WHITE, "grove", false)
	check(fx.active.is_empty(), "La densité nulle coupe les particules d’impact")
	fx.wave(Vector3.ZERO, Color.WHITE, 2.0)
	check(fx.active.size() == 1, "Le repère de zone reste lisible avec les particules désactivées")
	fx.queue_free()
	await process_frame
	quit(1 if failed else 0)

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failed += 1
