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
	await process_frame
	var extent := root.get_visible_rect().size
	app._apply_safe_insets(Rect2(Vector2(50, 8), extent - Vector2(50, 8)), extent)
	await process_frame
	check(app.matte.size.is_equal_approx(extent) and app.canvas.position.x >= 50.0
		and app.canvas.size.x < extent.x, "Le fond remplit l’écran quand la zone tactile respecte une encoche")
	app._safe_canvas()
	app.begin("training", "standard", "station", 71)
	layer = app.touch_panel
	await ticks(4)
	var pilot = app.session.player
	check(prefs.values.touch_compact and not layer._available("gadget") and layer._available("sprint"),
		"Le HUD simplifié affiche le sprint")
	await check_aim(pilot)
	var stick: Vector2 = layer._center("stick")
	var fire: Vector2 = layer._center("fire")
	var look := Vector2(770, 289)
	var sprint: Vector2 = layer._center("sprint")
	tap(8, sprint, true)
	tap(8, sprint, false, true)
	check(not pilot.down("sprint"), "Un toucher annulé ne bascule pas le sprint")
	tap(8, sprint, true)
	tap(8, sprint, false)
	tap(0, stick, true)
	drag(0, stick + Vector2(0, -76), Vector2(0, -76))
	await ticks(14)
	check(pilot.down("sprint") and pilot.sprinting, "Un toucher active la vraie course")
	tap(0, stick, false)
	await ticks(2)
	check(pilot.down("sprint") and not pilot.sprinting, "La bascule reste active au repos sans déplacement automatique")
	app.pause()
	check(not pilot.touch_sprint, "La pause suspend l’entrée tactile")
	app.hud()
	await process_frame
	tap(0, stick, true)
	drag(0, stick + Vector2(0, -76), Vector2(0, -76))
	await ticks(5)
	check(pilot.sprinting, "Le sprint reste actif après reprise et au prochain déplacement")
	tap(8, sprint, true)
	tap(8, sprint, false)
	await ticks(2)
	check(not pilot.down("sprint") and not pilot.sprinting, "Un deuxième toucher rend la marche même si le joystick reste poussé")
	tap(0, stick, false)
	await ticks(10)
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
	check(Input.get_vector("left", "right", "forward", "back") == Vector2.ZERO and not pilot.down("sprint"),
		"Relâchement du joystick sans déplacement ni sprint bloqué")
	former_yaw = pilot.rotation.y
	tap(2, fire, true)
	drag(2, fire + Vector2(46, 0), Vector2(46, 0))
	check(absf(pilot.rotation.y - former_yaw) > 0.02 and Input.is_action_pressed("fire"),
		"Glisser sur le tir permet de viser avec le même doigt")
	tap(2, fire, false)
	var jump: Vector2 = layer._center("jump")
	tap(7, jump, true)
	drag(7, jump + Vector2(0, 40), Vector2(0, 40))
	check(Input.is_action_pressed("crouch"), "Glisser vers le bas déclenche l’accroupissement")
	tap(7, jump, false)
	check(not Input.is_action_pressed("crouch"), "Lever le doigt relâche l’accroupissement")
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
	tap(4, ads, false)
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
	check(layer._center("stick").x > layer.size.x * 0.5 and layer._center("sprint").x > layer.size.x * 0.5,
		"Disposition gaucher miroite le joystick et le sprint")
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

func check_aim(pilot: CharacterBody3D) -> void:
	var stage = app.session
	var target = stage.units[0]
	target.set_physics_process(false)
	target.position = pilot.position + Vector3(0, 0, -4)
	pilot.head.rotation.x = asin((target.aim_point() - pilot.head.global_position).normalized().y)
	await ticks(3)
	var before := pilot.rotation
	pilot.look_input(Vector2.ZERO, Vector2.ONE, true)
	await ticks(4)
	var scale: float = pilot.touch_aim.speed_scale
	check(scale < 0.96 and scale >= 0.72 and pilot.rotation == before,
		"L’aide tactile freine près d’une cible visible sans tourner la caméra")
	var wall := StaticBody3D.new()
	var hitbox := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 2.7, 0.32)
	hitbox.shape = shape
	wall.position = pilot.position + Vector3(0, 1.1, -2)
	wall.add_child(hitbox)
	stage.add_child(wall)
	pilot.look_input(Vector2.ZERO, Vector2.ONE, true)
	await ticks(4)
	check(is_equal_approx(pilot.touch_aim.speed_scale, 1.0), "Un mur annule l’aide à la visée")
	wall.queue_free()
	pilot.head.rotation.x = 0.0
	target.set_physics_process(true)
	await ticks(3)

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
