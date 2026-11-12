extends SceneTree

var failed := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	app.open_hub("arsenal")
	var hub
	for child in app.view.get_children():
		if child.has_method("_category"):
			hub = child
			break
	check(hub != null, "L’armurerie est accessible")
	if hub == null:
		quit(1)
		return
	var viewer = hub.viewer
	var viewport: SubViewport = viewer.viewport
	var initial: String = hub.selected
	var initial_model: Node3D = viewer.model
	var choices: Array = hub.item_buttons.keys()
	choices.erase(initial)
	hub.item_buttons[choices.front()].pressed.emit()
	check(hub.viewer == viewer and viewer.viewport == viewport and viewer.model != initial_model,
		"Changer d’équipement conserve la fenêtre 3D")
	hub.item_buttons[initial].pressed.emit()
	check(viewer.model == initial_model, "Revenir au même équipement réutilise sa géométrie")
	hub.category_buttons.Gadgets.pressed.emit()
	check(app.screen == "hub" and not viewer.visible and not viewer.is_processing(),
		"La catégorie sans aperçu suspend la présentation 3D")
	hub.category_buttons.Armes.pressed.emit()
	check(viewer.visible and hub.viewer == viewer, "Le retour à Armes restaure l’aperçu")

	app.open_lobby()
	var port := randi_range(35000, 62000)
	check(app.coop.host(port, 4), "Un salon de test peut être ouvert")
	check(app.lobby.connection.text == "Salon ouvert" and app.lobby.start.disabled,
		"Le lobby affiche l’état réel et le lancement indisponible à un pilote")
	app._back()
	check(app.screen == "play" and not app.coop.active() and app.coop.roster.is_empty(),
		"Le retour de la coop ferme le salon")
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failed += 1
