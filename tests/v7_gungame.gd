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
	app.open_classic("gungame")
	check(app.classic_setup.allowed == ["gungame"] and app.classic_setup.targets.disabled
		and app.classic_setup.maps.item_count == 7, "Gun Game accessible avec huit paliers et les sept cartes")
	var gear: Dictionary = prefs.profile.data.duplicate(true)
	app.begin("gungame", "standard", "district", 777, "", false, {"bots": 1, "duration": 180})
	var stage = app.session
	var match_state = stage.classic
	await ticks(185)
	check(match_state.phase == 1 and stage.units.size() == 1 and stage.player.arsenal.rack == [0],
		"Le compte à rebours lance un match Gun Game avec l’AR-24 en prêt")
	stage.player.damage_lock = 1000.0
	var seen := []
	for level in range(8):
		if stage.units.is_empty():
			match_state._advance_respawns(3.2)
		var victim = stage.units[0]
		victim.set_physics_process(false)
		seen.append(stage.player.arsenal.active)
		check(victim.match_weapon == 0 and victim.spec.damage == 24.0, "Le bot démarre avec les caractéristiques de sa vraie arme")
		stage.player.arsenal.reload_left = 0.5
		stage.player.arsenal.burst_left = 2
		victim.take_hit(2000.0, victim.center(), Vector3.FORWARD, stage.player)
		var after: int = match_state.score
		match_state.eliminated(victim, stage.player)
		check(match_state.score == level + 1 and match_state.score == after,
			"Élimination %d validée une seule fois malgré l’événement répété" % (level + 1))
		if level < 7:
			check(stage.player.arsenal.active == match_state.ORDER[level + 1]
				and stage.player.arsenal.reload_left == 0.0 and stage.player.arsenal.burst_left == 0,
				"Changement réel d’arme et annulation du rechargement/rafale")
			match_state._advance_respawns(3.2)
	match_state.elapsed = 45.0
	await ticks(4)
	check(seen.size() == 8 and seen.duplicate().all(func(i): return seen.count(i) == 1),
		"Les huit équipements distincts sont utilisés")
	check(app.screen == "result" and match_state.outcome == "victoire" and match_state.winner == 0,
		"La dernière élimination termine une seule partie et ouvre le bilan")
	var coins: int = prefs.profile.data.coins
	app._result(true, stage)
	check(prefs.profile.data.coins == coins and prefs.leaderboard("gungame", "standard", "district", "1-180-8").size() == 1,
		"Le bilan ne paie pas deux fois et le classement est séparé par règles")
	check(prefs.profile.data.slots == gear.slots and prefs.profile.data.owned == gear.owned,
		"Les prêts du Gun Game ne modifient ni achats ni équipement permanent")
	prefs.load_disk()
	check(prefs.leaderboard("gungame", "standard", "district", "1-180-8").size() == 1,
		"Le classement Gun Game survit au rechargement du profil")
	app._restart()
	check(app.session.run_seed == 777 and app.session.classic.options.duration == 180,
		"Rejouer conserve graine, carte et durée")
	app.begin("gungame", "discovery", "grove", 778, "", false, {"bots": 1})
	stage = app.session
	match_state = stage.classic
	match_state.open_wave()
	match_state._advance_respawns(0.1)
	var bot = stage.units[0]
	bot.set_physics_process(false)
	for level in range(8):
		stage.player.damage_lock = 0.0
		stage.player.take_damage(2000.0, bot.position, bot)
		if level < 7:
			match_state._advance_respawns(3.2)
			check(bot.match_weapon == match_state.ORDER[level + 1]
				and bot.spec.damage == load("res://game/weapons/catalog.gd").WEAPONS[bot.match_weapon].damage,
				"Le bot progresse avec le modèle et les dégâts du palier %d" % (level + 2))
	check(match_state.winner == 1 and match_state.outcome == "défaite" and match_state.deaths == 8,
		"Le bot peut terminer les huit paliers et gagner")
	await ticks(4)
	app.begin("gungame", "standard", "bastion", 779, "", false, {"bots": 0, "duration": 180})
	stage = app.session
	match_state = stage.classic
	match_state.open_wave()
	app.pause()
	var before: float = match_state.elapsed
	await ticks(10)
	check(match_state.elapsed == before, "La pause gèle le chronomètre Gun Game")
	app.hud()
	match_state.elapsed = 179.99
	await ticks(5)
	check(app.screen == "result" and match_state.outcome == "égalité"
		and prefs.leaderboard("gungame", "standard", "bastion", "0-180-8").is_empty(),
		"Zéro bot termine à égalité sans récompense ni faux record")
	app.menu()
	root.get_node("Sounds").stop_all()
	await process_frame
	quit(failures)

func ticks(count: int) -> void:
	for frame in count:
		await physics_frame

func check(value: bool, caption: String) -> void:
	print("PASS " if value else "FAIL ", caption)
	if not value:
		failures += 1
