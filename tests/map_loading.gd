extends SceneTree

var failed := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
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
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)

func wait_for(app, screen: String) -> bool:
	var deadline := Time.get_ticks_msec() + 12000
	while app.screen != screen and Time.get_ticks_msec() < deadline:
		await process_frame
	return app.screen == screen

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failed += 1
