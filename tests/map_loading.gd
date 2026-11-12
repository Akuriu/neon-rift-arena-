extends SceneTree

const Catalog := preload("res://game/catalog.gd")

var failed := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check_batch_budget()
	var app = load("res://scenes/App.tscn").instantiate()
	app.staged_loading = true
	root.add_child(app)
	app.play_menu()
	app.request_match("training", "standard", "cryo", 2718)
	var pending = app.map_loading
	check(app.screen == "loading" and app.session == null and pending.image != null,
		"La miniature de la vraie carte est affichée avant construction")
	app.request_match("gungame", "standard", "station", 2719)
	check(app.map_loading == pending and app.match_request.map == "cryo", "Un double lancement ne crée aucune seconde demande")
	app._back()
	check(app.screen == "play" and app.view.visible and app.map_loading == null, "Retour annule le chargement et restaure Jouer")
	await process_frame
	check(app.session == null, "La requête annulée ne démarre pas en différé")

	app.request_match("training", "standard", "cryo", 2718)
	check(await wait_for(app, "hud"), "La nouvelle demande construit et révèle la partie")
	if not is_instance_valid(app.session):
		quit(1)
		return
	var stage: Node = app.session
	check(app.session.map_id == "cryo" and app.session.mode == "training" \
		and app.session.run_seed == 2718 and app.hud_panel.visible, "La demande, la graine et le HUD correspondent")
	app.pause()
	check(paused and not stage.can_process(), "La pause suspend la simulation après le chargement progressif")
	app._restart()
	check(app.screen == "loading" and not app.hud_panel.visible, "Le redémarrage masque le HUD de l’ancienne partie")
	check(await wait_for(app, "hud") and app.session != stage, "Le redémarrage attache une nouvelle session")
	await process_frame
	check(not is_instance_valid(stage) and app.get_children().filter(func(node: Node): return node.name.begins_with("Session")).size() == 1,
		"Un seul nœud de session subsiste")

	app.request_match("parkour", "standard", "skyline", 2720, "", {"route": "yard"})
	app.menu()
	await process_frame
	check(app.screen == "menu" and app.session == null and app.hud_panel == null \
		and app.map_loading == null and not paused, "Le retour menu révoque la demande et libère l’ancienne session")
	for map_id in Catalog.MAPS:
		app.request_match("explore", "discovery", map_id, 2324)
		if await wait_for(app, "hud"):
			check(app.session.arena.pending_surface_count() == 0 and app.session.arena.collision.get_child_count() > 0
				and app.session.player.can_process(), "Décor, collisions et entrée prêts · " + map_id)
		else:
			check(false, "Chargement de " + map_id)
		app.menu()
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)

func check_batch_budget() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var fabric := load("res://game/fabric.gd")
	var batches = fabric.Batch.new()
	for x in [0.0, 14.0, 28.0]:
		batches.put(fabric.cube(Vector3.ONE), fabric.paint(Color.WHITE), Vector3(x, 0, 0))
	batches.commit(parent, true, Time.get_ticks_usec())
	check(parent.get_child_count() == 1 and batches.groups.size() == 2, "Le budget suspend le lot après une surface")
	batches.commit(parent)
	check(parent.get_child_count() == 3 and batches.groups.is_empty(), "La reprise ajoute les surfaces restantes une seule fois")
	parent.queue_free()

func wait_for(app, screen: String) -> bool:
	var deadline := Time.get_ticks_msec() + 12000
	while app.screen != screen and Time.get_ticks_msec() < deadline:
		await process_frame
	return app.screen == screen

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failed += 1
