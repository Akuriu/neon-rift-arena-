extends SceneTree

const MAPS := ["reactor", "skyline", "cryo", "bastion", "district", "grove", "station"]

var failed := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = load("res://scenes/App.tscn").instantiate()
	app.staged_loading = true
	root.add_child(app)
	var baseline_nodes := get_node_count()
	var minimum := -1
	var maximum := 0
	for index in 21:
		var id: String = MAPS[index % MAPS.size()]
		var mode: String = ["training", "gungame", "explore"][index % 3]
		app.play_menu()
		app.request_match(mode, "discovery", id, 2244 + index, "", {"bots": 0})
		var deadline := Time.get_ticks_msec() + 10000
		while app.screen == "loading" and Time.get_ticks_msec() < deadline:
			await process_frame
		if app.screen != "hud" or not is_instance_valid(app.session):
			check(false, "La session %d se charge" % (index + 1))
			break
		var stage: Node = app.session
		app.pause()
		check(app.screen == "pause" and paused and not app.hud_panel.visible,
			"Session %02d · pause et HUD masqué" % (index + 1))
		app.hud()
		check(app.screen == "hud" and not paused and app.session == stage, "Reprise sur la même session")
		app.menu()
		await process_frame
		await process_frame
		check(app.session == null and app.hud_panel == null and app.map_loading == null and not is_instance_valid(stage),
			"Retour libère session, HUD et masque")
		if index >= 7:
			var used := int(Performance.get_monitor(Performance.MEMORY_STATIC))
			minimum = used if minimum < 0 else mini(minimum, used)
			maximum = maxi(maximum, used)
	check(get_node_count() <= baseline_nodes + 4, "Le nombre de nœuds revient à celui de l’accueil")
	check(minimum >= 0 and maximum - minimum < 8 * 1048576, "Mémoire bornée après échauffement des sept cartes")
	print("CYCLES nodes_initial=", baseline_nodes, " nodes_final=", get_node_count(),
		" heap_min=", minimum, " heap_max=", maximum)
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failed += 1
