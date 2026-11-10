extends SceneTree

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
	app.open_classic()
	check(app.screen == "classic" and app.classic_setup.maps.item_count == 7, "Configuration du match et sept cartes")
	app._start_classic("classic", "standard", "bastion", 224, {"bots": 0, "duration": 300, "target": 10})
	var stage = app.session
	var match_state = stage.classic
	await ticks(185)
	check(stage.units.is_empty() and match_state.phase == 1, "Compte à rebours et match sans bots")
	match_state.elapsed = 299.99
	await ticks(4)
	check(app.screen == "result" and match_state.outcome == "égalité" and prefs.records.is_empty(), "Égalité au chrono sans gain permanent")
	app._restart()
	check(app.session.run_seed == 224 and app.session.classic.options.bots == 0, "Le redémarrage reproduit la graine et les règles")
	app.begin("classic", "standard", "bastion", 129, "", false, {"bots": 1, "target": 10})
	stage = app.session
	match_state = stage.classic
	await ticks(4)
	match_state.open_wave()
	await ticks(3)
	check(stage.units.size() == 1 and stage.units[0].arena_slot == 1, "Un bot apparaît en chacun pour soi")
	var enemy = stage.units[0]
	await ticks(55)
	stage.player.take_damage(500.0, enemy.position, enemy)
	check(not stage.player.alive and match_state.deaths == 1 and match_state.rival_score() == 1, "Élimination et point adverse")
	await ticks(170)
	check(stage.player.alive and stage.player.shield > 0.0, "Réapparition du pilote avec protection")
	match_state.scores[0] = 9
	enemy.take_hit(999.0, enemy.center(), Vector3.FORWARD, stage.player)
	await ticks(4)
	check(app.screen == "result" and match_state.outcome == "victoire" and match_state.score == 10, "Victoire à la limite de score et écran de résultat")
	check(prefs.leaderboard("classic", "standard", "bastion", "1-300-10").size() == 1
		and prefs.leaderboard("classic", "standard", "bastion", "2-300-10").is_empty(), "Classement isolé par règles")
	prefs.load_disk()
	check(prefs.leaderboard("classic", "standard", "bastion", "1-300-10").size() == 1, "Relecture du classement personnalisé")
	app.begin("teams", "standard", "district", 31, "", false, {"bots": 12})
	stage = app.session
	match_state = stage.classic
	await ticks(2)
	match_state.open_wave()
	await ticks(3)
	check(stage.units.size() == 12, "Douze bots en équipes avec effectif disponible")
	var ally = stage.units[1]
	enemy = stage.units[0]
	check(not stage.can_damage(stage.player, ally) and stage.can_damage(stage.player, enemy)
		and not stage.can_damage(enemy, stage.units[2]), "Équipes distinctes et tir allié neutralisé")
	await ticks(600)
	check(stage.spawn_index > 12 or stage.projectiles.get_child_count() > 0 or stage.player.shield < stage.player.shield_max,
		"Les bots combattent et génèrent de vrais projectiles")
	app.begin("capture", "standard", "grove", 341, "", false, {"bots": 2, "target": 10})
	stage = app.session
	match_state = stage.classic
	await ticks(2)
	match_state.open_wave()
	await ticks(3)
	var zone = match_state.zones[0]
	var opponents: Array = stage.units.duplicate()
	for bot in opponents:
		bot.set_physics_process(false)
	stage.player.position = zone.position + Vector3.UP * 0.04
	await ticks(252)
	check(zone.owner_side == 0 and match_state.score > 0, "La présence capture la zone et marque des points")
	opponents[0].position = zone.position + Vector3(1.5, 0.0, 0.0)
	var prior: int = match_state.score
	await ticks(95)
	check(zone.contested and match_state.score == prior, "Contestation bloque le score de zone")
	match_state.elapsed = 299.99
	match_state.scores[1] = match_state.score + 1
	await ticks(4)
	check(app.screen == "result" and match_state.outcome == "défaite", "Défaite au chrono et bilan")
	app.begin("domination", "standard", "station", 321, "", false, {"bots": 0, "target": 10})
	stage = app.session
	match_state = stage.classic
	await ticks(2)
	match_state.open_wave()
	for point in match_state.zones:
		stage.player.position = point.position + Vector3.UP * 0.04
		await ticks(185)
	await ticks(180)
	check(match_state.zones.size() == 3 and match_state.outcome == "victoire", "Domination à trois points et fin au score")
	for id in prefs.MAPS:
		app.begin("explore", "standard", id, 282)
		stage = app.session
		await ticks(2)
		var connected := true
		for point in stage.arena.spawn_points + stage.arena.control_points:
			var at := Vector2(point.x, point.z)
			if not stage.arena.routes.clear_segment(at, at) or stage.arena.routes.find(stage.arena.start_at, point).is_empty():
				connected = false
				print("Point à corriger ", id, " ", point)
		check(connected and stage.units.is_empty() and stage.director.phase == 4, "Exploration et accès aux points · " + id)
	app.begin("relax", "expert", "bastion", 14)
	app.session.director.open_wave()
	await ticks(30)
	check(app.session.director.total_waves == 5 and app.session.director.cap <= 4
		and app.session.director.tuning.power < 1.0, "Détente à cinq vagues et pression réduite")
	app.menu()
	await process_frame
	check(app.screen == "menu", "Retour au menu depuis un match")
	quit(failures)

func ticks(count: int) -> void:
	for _i in count:
		await physics_frame

func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1
