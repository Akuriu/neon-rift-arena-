extends SceneTree

var app
var prefs
var failures := 0
const Rules := preload("res://game/modes/rules.gd")

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
	check(app.classic_setup.allowed == ["gungame"] and app.classic_setup.order.item_count == 2
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
		victim.spawn_guard = 0.0
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
	app.begin("gungame", "standard", "reactor", 780, "", false, {"bots": 1})
	stage = app.session
	match_state = stage.classic
	match_state.open_wave()
	match_state._advance_respawns(0.1)
	bot = stage.units[0]
	bot.spawn_guard = 0.0
	bot.set_physics_process(false)
	stage.launch(bot.center(), Vector3.UP, 1, 2000, Color.WHITE, false, 0, 0, bot, "wp_pulse")
	var first_bolt = stage.projectiles.get_child(-1)
	first_bolt.set_physics_process(false)
	stage.launch(bot.center(), Vector3.UP, 1, 2000, Color.WHITE, false, 0, 0, bot, "wp_pulse")
	var second_bolt = stage.projectiles.get_child(-1)
	second_bolt.set_physics_process(false)
	bot.take_hit(2000, bot.center(), Vector3.FORWARD, stage.player)
	await ticks(48)
	check(not is_instance_valid(bot) and first_bolt.credit_slot == 1, "Un projectile conserve l’identité du bot après libération de son nœud")
	stage.player.damage_lock = 0.0
	stage.projectile_impact(first_bolt, stage.player, stage.player.aim_point(), Vector3.FORWARD)
	stage.recycle_bolt(first_bolt)
	check(match_state.scores[1] == 1 and match_state.deaths == 1, "Une élimination posthume est attribuée au bon bot")
	match_state._advance_respawns(3.2)
	bot = stage.units[0]
	bot.set_physics_process(false)
	check(bot.match_weapon == match_state.ORDER[1], "Le bot réapparaît au palier obtenu après sa mort")
	stage.player.damage_lock = 0.0
	stage.projectile_impact(second_bolt, stage.player, stage.player.aim_point(), Vector3.FORWARD)
	stage.recycle_bolt(second_bolt)
	check(match_state.scores[1] == 2 and bot.match_weapon == match_state.ORDER[2],
		"Un second projectile ancien équipe le nouveau corps du bot au bon palier")
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
	await exercise_shuffled()
	app.menu()
	root.get_node("Sounds").stop_all()
	await process_frame
	quit(failures)

func exercise_shuffled() -> void:
	var options := {"bots": 1, "duration": 180, "shuffled": true}
	var expected_order: Array
	for map_id: String in prefs.MAPS:
		app.begin("gungame", "standard", map_id, 881, "", false, options)
		var stage = app.session
		var state = stage.classic
		if expected_order.is_empty():
			expected_order = state.order.duplicate()
		state.open_wave()
		state._advance_respawns(0.1)
		check(stage.units.size() == 1 and state.order == expected_order
			and stage.player.arsenal.active == expected_order[0] and stage.units[0].match_weapon == expected_order[0],
			"Ordre seedé partagé par le pilote et le bot sur " + map_id)
		await ticks(1)
	var sorted := expected_order.duplicate()
	sorted.sort()
	check(sorted == range(8) and expected_order != app.session.classic.ORDER, "Le mélange utilise exactement les huit armes")
	check(Rules.valid_key("1-180-8-mix", "gungame") and not Rules.valid_key("1-180-8-mix", "classic")
		and not Rules.valid_key("1-180-10-mix", "gungame"), "Catégorie mélangée réservée au Gun Game")
	app.begin("gungame", "expert", "district", 882, "", false, options)
	var stage = app.session
	var state = stage.classic
	check(state.order != expected_order, "Changer de graine change l’ordre du match")
	state.open_wave()
	state._advance_respawns(0.1)
	check(state.standings() == [{"slot": 0, "score": 0, "rank": 1}, {"slot": 1, "score": 0, "rank": 1}],
		"Deux joueurs à égalité partagent le rang")
	var target = stage.units[0]
	target.spawn_guard = 0.0
	target.take_hit(2000, target.center(), Vector3.FORWARD, stage.player)
	check(state.standings() == [{"slot": 0, "score": 1, "rank": 1}, {"slot": 1, "score": 0, "rank": 2}]
		and stage.player.arsenal.active == state.order[1], "Classement et palier suivent l’élimination réelle")
	state.elapsed = 179.99
	await ticks(5)
	prefs.load_disk()
	check(app.screen == "result" and prefs.leaderboard("gungame", "expert", "district", "1-180-8-mix").size() == 1
		and prefs.leaderboard("gungame", "expert", "district", "1-180-8").is_empty(), "Le record mélangé survit à la relecture dans sa catégorie")
	var order: Array = state.order.duplicate()
	app._restart()
	check(app.session.classic.order == order and app.session.run_seed == 882, "Rejouer restaure le mélange et sa graine")

func ticks(count: int) -> void:
	for frame in count:
		await physics_frame

func check(value: bool, caption: String) -> void:
	print("PASS " if value else "FAIL ", caption)
	if not value:
		failures += 1
