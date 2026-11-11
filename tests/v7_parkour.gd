extends SceneTree

const Courses := preload("res://game/modes/parkour_routes.gd")
const Replay := preload("res://game/modes/parkour_ghost.gd")
var app
var prefs
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("NEON_QA_ISOLATED") != "1":
		quit(2)
		return
	app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	prefs = root.get_node("Prefs")
	app.open_parkour()
	check(app.screen == "parkour", "Sélection de trois parcours accessible")
	app.begin("parkour", "standard", "skyline", 800, "", false, {"route": "yard"})
	var stage = app.session
	var run_state = stage.director
	await ticks(90)
	check(not run_state.started and run_state.elapsed == 0 and stage.units.is_empty(),
		"Le chrono attend le franchissement réel du départ sans bots")
	Input.action_press("fire")
	Input.action_press("gadget")
	await ticks(10)
	Input.action_release("fire")
	Input.action_release("gadget")
	check(stage.shots == 0 and stage.player.gadget_left == 0.0, "Le Parkour désactive armes et gadget de combat")
	run_state.finish(true)
	check(run_state.phase == 1 and not run_state.report().valid, "Une arrivée partielle ne termine pas le parcours")
	stage.player.position = Courses.ROUTES.yard.points[3]
	await ticks(8)
	check(run_state.next == 0 and not run_state.eligible, "Un checkpoint futur et une téléportation sont refusés")
	var arena_id: int = stage.arena.get_instance_id()
	app._restart()
	await ticks(5)
	check(stage.arena.get_instance_id() == arena_id and run_state.eligible and not run_state.started,
		"Recommencer réinitialise le chrono sans reconstruire la carte")
	var initial: Dictionary = prefs.profile.data.duplicate(true)
	for route in Courses.IDS:
		app.begin("parkour", "standard", "skyline", 801, "", false, {"route": route})
		stage = app.session
		run_state = stage.director
		await ticks(4)
		var finished: bool = await drive(stage, route, route == "yard")
		check(finished and run_state.next == run_state.checkpoints.size(), "Parcours %s terminé avec les collisions, les déplacements et les sauts réels" % route)
		check(run_state.eligible and run_state.report().valid, "Les déplacements physiques %s restent valides pour un record" % route)
		await ticks(5)
		check(app.screen == "result" and prefs.profile.data.career.parkour.has(route), "Bilan et record personnel du parcours " + route)
		var old: Dictionary = prefs.profile.data.career.parkour.duplicate()
		var progress: Dictionary = prefs.profile.data.career.parkour_progress[route].duplicate(true)
		check(progress.finishes == 1 and progress.clean_finishes == int(run_state.retries == 0)
			and progress.record_retries == run_state.retries and progress.ghost[-Replay.STRIDE] == old[route],
			"Fantôme du record et statistiques correspondent à la tentative " + route)
		check(not Courses.medal(route, old[route]).is_empty() and Courses.medal(route, 90000).is_empty(),
			"Barème de médailles du parcours " + route)
		app._parkour_result()
		check(prefs.profile.data.career.parkour == old and prefs.profile.data.career.parkour_progress[route] == progress,
			"Résultat idempotent pour " + route)
		prefs.load_disk()
		check(prefs.profile.data.career.parkour == old and prefs.profile.data.career.parkour_progress[route] == progress,
			"Temps, statistiques et trace relus sur disque pour " + route)
	check(prefs.profile.data.career.parkour.size() == 3, "Les trois records sont indépendants")
	check(prefs.profile.data.coins == initial.coins and prefs.profile.data.xp == initial.xp
		and prefs.profile.data.owned == initial.owned and prefs.profile.data.slots == initial.slots,
		"Les chronos n’altèrent ni achats, ni équipement, ni XP")
	var before: Dictionary = prefs.profile.data.career.parkour.duplicate()
	var bad: Dictionary = prefs.complete_parkour("incomplete", {"route": "yard", "valid": false, "milliseconds": 1100, "checkpoints": 1})
	check(bad.ok and not bad.best and prefs.profile.data.career.parkour == before, "Un parcours invalide ne remplace aucun record")
	await verify_replay()
	var parkour_progress: Dictionary = prefs.profile.data.career.parkour_progress.duplicate(true)
	var reset: Dictionary = prefs.reset_progression()
	prefs.load_disk()
	check(reset.ok and prefs.profile.data.career.parkour == before
		and prefs.profile.data.career.parkour_progress == parkour_progress,
		"La réinitialisation de progression conserve les records Parkour et les fantômes")
	app.menu()
	root.get_node("Sounds").stop_all()
	await process_frame
	quit(failures)

func verify_replay() -> void:
	var route := "yard"
	var progress: Dictionary = prefs.profile.data.career.parkour_progress[route].duplicate(true)
	var record: int = prefs.profile.data.career.parkour[route]
	var slow := {"route": route, "valid": true, "milliseconds": record + 500, "checkpoints": Courses.ROUTES[route].points.size(), "retries": 0}
	var saved: Dictionary = prefs.complete_parkour("yard-valid-slower", slow)
	var stored: Dictionary = prefs.profile.data.career.parkour_progress[route]
	check(saved.ok and not saved.best and stored.finishes == 2 and stored.clean_finishes == 1
		and stored.ghost == progress.ghost, "Une arrivée plus lente est comptée et conserve le fantôme du record")
	check(Replay.sanitize([0, 0, 0, 0, 1500, 10001, 0, 0], 1500).is_empty()
		and Replay.sanitize([0, 0, 0, 0, 0, 0, 0, 0], 1500).is_empty(), "Les traces invalides sont écartées")
	app.begin("parkour", "standard", "skyline", 802, "", false, {"route": route})
	var stage = app.session
	var state = stage.director
	var ghost: Node3D = state.ghost
	check(not ghost.visible and ghost.get_child_count() == 1 and ghost.get_child(0) is MeshInstance3D,
		"Le fantôme est un repère visuel sans collision, masqué avant le départ")
	stage.player.remote_input = true
	stage.player.net_move = Vector2(0.0, -1.0)
	for frame in range(60):
		await physics_frame
		if state.started:
			break
	await ticks(8)
	check(state.started and ghost.visible, "Le départ réel lance le fantôme")
	app.pause()
	var position := ghost.position
	await ticks(12)
	check(ghost.position == position, "La pause fige le fantôme et le chrono")
	var children: int = stage.get_child_count()
	for attempt in range(30):
		app._restart()
	check(app.session == stage and stage.get_child_count() == children and state.samples.is_empty() and not ghost.visible,
		"Trente relances réutilisent le terrain et réinitialisent la trace")
	app.begin("parkour", "standard", "skyline", 803, "", false, {"route": route, "ghost": false})
	check(not is_instance_valid(app.session.director.ghost) and not app.session.director.options.ghost,
		"La désactivation retire le fantôme de la scène")

func drive(stage: Node3D, route: String, exercise_retry: bool) -> bool:
	var run_state = stage.director
	var pilot = stage.player
	pilot.remote_input = true
	var tested := false
	var jumps := 0
	for frame in range(3600):
		if run_state.phase == 3:
			break
		if exercise_retry and run_state.next == 2 and not tested:
			tested = true
			pilot.net_move = Vector2.ZERO
			app.pause()
			var time: float = run_state.elapsed
			await ticks(12)
			check(run_state.elapsed == time, "Pause gèle le chrono Parkour")
			app.hud()
			pilot.position.y = -3.0
			await ticks(3)
			check(run_state.retries == 1 and run_state.penalty == 2.0 and run_state.next == 2,
				"La chute revient au dernier checkpoint et ajoute exactement deux secondes")
		var point: Vector3 = Courses.ROUTES[route].points[mini(run_state.next, run_state.checkpoints.size() - 1)]
		var direction := Vector3(point.x - pilot.position.x, 0, point.z - pilot.position.z).normalized()
		pilot.net_move = Vector2(direction.x, direction.z)
		pilot.net_buttons = 4
		var leap := false
		if pilot.is_on_floor():
			if route == "yard":
				for bar in [8.0, 0.0, -8.0]:
					var gap: float = pilot.position.z - bar
					if gap > 0.6 and gap < 2.0:
						leap = true
			else:
				var probe: Vector3 = pilot.position + direction * 1.35
				leap = stage.ray(probe + Vector3.UP * 0.15, probe - Vector3.UP * 0.65, 1).is_empty()
		if leap:
			pilot.net_edges = 2
			jumps += 1
		await physics_frame
		if frame % 600 == 599:
			print("PARKOUR ", route, " frame=", frame, " next=", run_state.next, " at=", pilot.position, " retries=", run_state.retries)
	pilot.net_move = Vector2.ZERO
	pilot.net_buttons = 0
	pilot.remote_input = false
	print("COURSE ", route, " time=", run_state.milliseconds(), " jumps=", jumps, " retries=", run_state.retries, " valid=", run_state.eligible)
	return run_state.phase == 3 and jumps >= (3 if route == "yard" else 4)

func ticks(count: int) -> void:
	for frame in count:
		await physics_frame

func check(value: bool, caption: String) -> void:
	print("PASS " if value else "FAIL ", caption)
	if not value:
		failures += 1
