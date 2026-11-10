extends SceneTree

const Layout := preload("res://ui/mobile/layout.gd")
var app
var layer
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("NEON_QA_ISOLATED") != "1" or "--touch" not in OS.get_cmdline_user_args():
		quit(2)
		return
	app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	app.begin("training", "standard", "skyline", 930)
	layer = app.touch_panel
	await ticks(5)
	var clean := true
	for sequence in range(300):
		var stick: Vector2 = point("stick")
		tap(0, stick, true)
		drag(0, stick - Vector2(0, layer._radius("stick") * 0.8), Vector2(0, -24))
		tap(1, point("fire"), true)
		var look: Vector2 = layer.get_global_transform_with_canvas() * (layer.size * Vector2(0.48, 0.44))
		tap(2, look, true)
		drag(2, look + Vector2(8, -2), Vector2(8, -2))
		tap(3, point("jump"), true)
		tap(3, point("jump"), false, sequence % 3 == 0)
		tap(4, point("sprint"), true)
		tap(4, point("sprint"), false)
		tap(4, point("sprint"), true)
		tap(4, point("sprint"), false)
		await physics_frame
		tap(0, stick, false, sequence % 4 == 0)
		tap(1, point("fire"), false, sequence % 5 == 0)
		tap(2, look, false, sequence % 6 == 0)
		await ticks(2)
		clean = clean and layer.fingers.is_empty() and not Input.is_action_pressed("fire")
		clean = clean and app.session.player.touch_move.is_zero_approx() and not app.session.player.touch_sprint
		if sequence % 30 == 29:
			app.session.player.arsenal.reset_supply()
	check(clean, "Trois cents séquences multitouch avec annulations ne laissent aucune entrée bloquée")
	check(app.session.player.rotation.is_finite() and app.session.shots > 0, "Les vraies entrées tactiles déplacent, visent et tirent")
	app.begin("gungame", "standard", "district", 931, "", false, {"bots": 0})
	layer = app.touch_panel
	await ticks(3)
	check(not layer._available("next") and layer._available("fire") and layer._available("sprint"),
		"Le Gun Game masque le changement d’arme inutile")
	app.begin("parkour", "standard", "skyline", 932, "", false, {"route": "yard"})
	layer = app.touch_panel
	await ticks(3)
	var available := []
	for id in Layout.CONTROLS:
		if layer._available(id):
			available.append(id)
	check(available.size() == 5 and "stick" in available and "jump" in available and "sprint" in available
		and "pause" in available and "interact" in available, "Le Parkour conserve exactement cinq commandes utiles")
	tap(0, point("sprint"), true)
	tap(0, point("sprint"), false)
	await ticks(2)
	check(app.session.player.touch_sprint and layer.sprint_latched, "Un clic active le sprint continu en Parkour")
	tap(0, point("sprint"), true)
	tap(0, point("sprint"), false)
	await ticks(2)
	check(not app.session.player.touch_sprint and not layer.sprint_latched, "Le second clic coupe le sprint continu")
	app.open_hub("arsenal", "Armes", "wp_prism")
	await ticks(3)
	check(not app.touch_panel.visible and not app.hud_panel.visible and app.session.player.input_blocked,
		"Ouvrir un menu masque le combat et libère les commandes tactiles")
	var viewer = app.view.find_child("WeaponPreview", true, false)
	var center: Vector2 = viewer.get_global_rect().get_center()
	var heading: float = viewer.heading
	tap(0, center, true)
	drag(0, center + Vector2(34, 11), Vector2(34, 11))
	tap(0, center + Vector2(34, 11), false)
	check(viewer.heading != heading and viewer.elevation > 0, "Le glissement tactile fait réellement pivoter le modèle d’armurerie")
	tap(0, center - Vector2(35, 0), true)
	tap(1, center + Vector2(35, 0), true)
	drag(1, center + Vector2(74, 0), Vector2(39, 0))
	tap(0, center - Vector2(35, 0), false)
	tap(1, center + Vector2(74, 0), false)
	check(viewer.zoom > 1.2 and viewer.zoom <= 1.6 and viewer.fingers.is_empty(),
		"Le pincement zoome l’aperçu et libère les deux pointeurs")
	app.menu()
	root.get_node("Sounds").stop_all()
	await process_frame
	quit(failures)

func point(id: String) -> Vector2:
	return layer.get_global_transform_with_canvas() * layer._center(id)

func tap(index: int, at: Vector2, down: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = down
	event.canceled = canceled
	root.push_input(event, true)

func drag(index: int, at: Vector2, offset: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.relative = offset
	event.screen_relative = offset
	root.push_input(event, true)

func ticks(count: int) -> void:
	for frame in count:
		await physics_frame

func check(value: bool, caption: String) -> void:
	print("PASS " if value else "FAIL ", caption)
	if not value:
		failures += 1
