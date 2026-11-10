extends SceneTree

var app
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	seed(74516)
	app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "survival"
	var arena: String = args[1] if args.size() > 1 else "reactor"
	var difficulty: String = args[2] if args.size() > 2 else "discovery"
	app.begin(mode, difficulty, arena)
	var stage = app.session
	var pilot = stage.player
	var seen := {}
	var passed := 0
	var health_low := 100.0
	var phase_reached := 1
	for step in 16000:
		if app.screen == "result":
			break
		if app.screen == "milestone":
			app.bank_run()
		elif app.screen == "upgrade":
			var available: Array = stage.choices()
			var option: int = 5 if 5 in available else available[0]
			app.pick(option)
			if stage.wallet.balance >= 120 and stage.wallet.levels.get("power", 0) < 4:
				app._buy_field("power")
			app.advance()
			passed += 1
			print("WAVE ", stage.director.cleared, " score=", stage.director.score,
				" hull=", pilot.health, " combo=", stage.director.highest_combo)
		else:
			for unit in stage.units:
				seen[unit.kind] = true
				if unit.kind == "warden":
					phase_reached = maxi(phase_reached, unit.phase)
			health_low = minf(health_low, pilot.health)
			play_step(stage, pilot, step)
		await frames(4)
		release()
	if mode == "trial":
		check(app.screen == "result" and stage.director.kills == 15 and stage.director.elapsed < 90.0,
			"Défi complet, les 15 cibles avant 90 secondes")
		check(stage.shots >= stage.hits and stage.hits > 20, "Tirs et impacts réels du défi")
	elif mode == "boss_rush":
		check(app.screen == "result" and stage.director.cleared == 4 and stage.credited_result.get("ok", false),
			"Boss Rush complet et récompenses enregistrées")
		check(seen.has("elite") and seen.has("warden") and seen.has("colossus") and seen.has("architect") and passed == 3,
			"Les quatre boss et les trois ravitaillements ont été joués")
	else:
		var goal := 10 if mode == "short" else 20
		check(app.screen == "result" and stage.director.cleared == goal, "Survie complète, victoire en %d vagues" % goal)
		check(passed == goal - 1, "Toutes les intermissions ont été jouées")
		check(seen.has("elite") and seen.has("warden") and (goal == 10 or seen.has("architect")), "Paliers de boss rencontrés")
		check(phase_reached == 3, "Trois phases du Warden atteintes")
		check(stage.shots >= stage.hits and stage.hits > 80 and stage.director.kills > 45,
			"Score, crédits et tirs réels comptabilisés")
		check(stage.wallet.spent > 0 and stage.credited_result.get("ok", false), "Achats de terrain et bilan validés")
	print("MATCH ", mode, " / ", arena, " / ", difficulty, " kills=", stage.director.kills, " shots=", stage.shots, " hits=", stage.hits,
		" time=", stage.director.elapsed, " HP minimum=", health_low, " score=", stage.director.score)
	app.menu()
	quit(failures)

func play_step(stage, pilot, step: int) -> void:
	var visible: CharacterBody3D
	var nearest: CharacterBody3D
	var best := INF
	var best_visible := INF
	for unit in stage.units:
		var distance: float = unit.position.distance_squared_to(pilot.position)
		if distance < best:
			nearest = unit
			best = distance
		if distance < best_visible and stage.ray(pilot.head.global_position, unit.center(), 1).is_empty():
			visible = unit
			best_visible = distance
	if is_instance_valid(visible):
		aim(pilot, visible.center())
		Input.action_press("fire")
		var lateral: Vector3 = pilot.global_basis.x * (1.0 if (step / 21) % 2 == 0 else -1.0)
		var at: Vector3 = pilot.global_position
		if stage.ray(at + Vector3.UP * 0.75, at + Vector3.UP * 0.75 + lateral * 2.7, 1).is_empty():
			Input.action_press("right" if lateral.dot(pilot.global_basis.x) > 0 else "left")
		if best_visible < 10.0 and stage.ray(at + Vector3.UP * 0.7, at + Vector3.UP * 0.7 + pilot.global_basis.z * 2.9, 1).is_empty():
			Input.action_press("back")
		if stage.hazards.get_child_count() > 0:
			Input.action_press("jump")
	elif is_instance_valid(nearest):
		var route: PackedVector3Array = stage.arena.routes.find(pilot.position, nearest.position)
		if not route.is_empty():
			aim(pilot, route[0] + Vector3.UP * pilot.head.global_position.y)
			Input.action_press("forward")
			Input.action_press("sprint")
		if pilot.arsenal.rounds() < 11:
			Input.action_press("reload")
	elif stage.director.pending.size() > 0:
		# Sweep the view until a spawn pocket is safely off camera.
		pilot.rotate_y(0.04)

func aim(pilot, target: Vector3) -> void:
	var vector: Vector3 = target - pilot.head.global_position
	pilot.rotation.y = atan2(-vector.x, -vector.z)
	pilot.head.rotation = Vector3(clampf(atan2(vector.y, Vector2(vector.x, vector.z).length()), -1.50, 1.50), 0, 0)

func release() -> void:
	for action in ["fire", "left", "right", "back", "forward", "sprint", "jump", "reload"]:
		Input.action_release(action)

func frames(number: int) -> void:
	for _i in number:
		await physics_frame

func check(condition: bool, caption: String) -> void:
	print("PASS " if condition else "FAIL ", caption)
	if not condition:
		failures += 1
