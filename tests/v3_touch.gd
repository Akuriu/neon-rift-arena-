extends SceneTree

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
	var prefs = root.get_node("Prefs")
	check(prefs.values.quality == 3 and prefs.values.fps_limit == 45, "Profil mobile Ultra Léger au premier lancement")
	app.begin("training", "standard", "station", 71)
	layer = app.touch_panel
	await ticks(4)
	var pilot = app.session.player
	var stick: Vector2 = layer._center("stick")
	var fire: Vector2 = layer._center("fire")
	var look := Vector2(770, 289)
	var start: Vector3 = pilot.position
	var yaw: float = pilot.rotation.y
	tap(0, stick, true)
	drag(0, stick + Vector2(0, -76), Vector2(0, -76))
	tap(1, look, true)
	drag(1, look + Vector2(80, 0), Vector2(80, 0))
	tap(2, fire, true)
	await ticks(20)
	check(pilot.position.distance_to(start) > 0.5 and absf(pilot.rotation.y - yaw) > 0.1
		and pilot.stats.shots > 0 and layer.fingers.size() == 3, "Trois doigts bougent, visent et tirent simultanément")
	var former_yaw: float = pilot.rotation.y
	drag(2, fire + Vector2(-150, 0), Vector2(-150, 0))
	await ticks(2)
	check(is_equal_approx(pilot.rotation.y, former_yaw) and Input.is_action_pressed("fire"),
		"Le doigt de tir garde sa fonction hors du bouton")
	tap(2, fire, false, true)
	check(not Input.is_action_pressed("fire"), "Annulation système relâche le tir")
	tap(0, stick, false)
	tap(1, look, false)
	check(Input.get_vector("left", "right", "forward", "back") == Vector2.ZERO, "Relâchement du joystick sans déplacement bloqué")
	var gun = pilot.arsenal
	var active: int = gun.active
	var next: Vector2 = layer._center("next")
	tap(3, next, true)
	tap(3, next, false)
	check(gun.active != active, "Changement d’arme au toucher")
	gun.select(4)
	await ticks(32)
	var ads: Vector2 = layer._center("ads")
	tap(4, ads, true)
	await ticks(24)
	var zoom: Vector2 = layer._center("zoom")
	tap(5, zoom, true)
	tap(5, zoom, false)
	check(gun.aiming() and gun.magnification() == 4.0, "Visée et zoom du Rail au toucher")
	var pause: Vector2 = layer._center("pause")
	tap(6, pause, true)
	check(app.screen == "pause" and paused and not Input.is_action_pressed("ads") and layer.fingers.is_empty(),
		"Pause tactile libère tous les doigts")
	app.hud()
	prefs.change_value("touch_left", true)
	check(layer._center("stick").x > layer.size.x * 0.5, "Disposition gaucher miroite la zone de déplacement")
	app.open_settings("pause")
	app.settings.show_tab(4)
	app.open_touch_editor()
	var edited: Dictionary = prefs.touch_layout.duplicate(true)
	edited.fire = {"x": 0.74, "y": 0.56, "size": 1.26, "opacity": 0.61}
	prefs.set_touch_layout(edited)
	prefs.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	prefs.load_disk()
	check(app.screen == "touch_editor" and is_equal_approx(prefs.touch_layout.fire.x, 0.74)
		and is_equal_approx(prefs.touch_layout.fire.opacity, 0.61), "Disposition persistante et sauvegarde en arrière-plan")
	app.hud()
	app.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(app.screen == "pause" and paused, "Suspension pendant une partie préserve une reprise manuelle")
	app.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	app.hud()
	check(not paused and app.screen == "hud", "Reprise tactile après retour à l’application")
	app.menu()
	await process_frame
	quit(failures)

func tap(index: int, at: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
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
	for _i in count:
		await physics_frame

func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1
