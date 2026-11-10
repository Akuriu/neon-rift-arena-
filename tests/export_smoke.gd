extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(ProjectSettings.get_setting("application/config/version") == "3.0.0", "Version exportée 3.0.0")
	var app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	check(app.screen == "menu" and app.coop != null, "Scène d’entrée et gestionnaire coop dans le paquet")
	app.open_lobby()
	check(app.screen == "lobby" and app.lobby.address.text == "127.0.0.1", "Interface coop dans le paquet")
	app.menu()
	app.open_hub("shop", "Armes", "wp_eclipse")
	check(app.screen == "hub", "Boutique et aperçu dans le paquet")
	app.begin("training", "discovery", "cryo", 733, "wp_eclipse")
	for frame in 20:
		await physics_frame
	var stage = app.session
	check(stage.map_id == "cryo" and stage.units.size() == 4, "Cryo Foundry et cibles chargées")
	check(stage.player.arsenal.spec().id == "wp_eclipse", "Eclipse Rail équipé")
	Input.action_press("ads")
	Input.action_press("fire")
	for frame in 60:
		await physics_frame
	check(stage.shots > 0 and stage.player.arsenal.scope > 0.95, "Le paquet tire et ouvre sa lunette")
	Input.action_release("ads")
	Input.action_release("fire")
	check(root.get_node("Sounds").bank.size() == 45, "45 échantillons audio chargés depuis le paquet")
	app.begin("domination", "discovery", "station", 882, "", false, {"bots": 4})
	for frame in 185:
		await physics_frame
	check(app.session.classic.zones.size() == 3 and app.session.units.size() == 4,
		"Domination, bots et carte Transit Hall chargés depuis le paquet")
	if failures == 0:
		await app._quit()
	else:
		root.get_node("Sounds").stop_all()
		app.queue_free()
		await process_frame
		quit(failures)

func check(value: bool, caption: String) -> void:
	print("PASS " if value else "FAIL ", caption)
	if not value:
		failures += 1
