extends SceneTree

const Director := preload("res://game/wave_director.gd")
const Combat := preload("res://tests/survival.gd")
const Catalog := preload("res://game/catalog.gd")
var app
var net
var bot := Combat.new()
var deadline := 0
var failures := 0
var expected := 2
var port := 24562
var role := ""

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("NEON_QA_ISOLATED") != "1":
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	role = args[0]
	port = args[1].to_int()
	expected = args[2].to_int()
	deadline = Time.get_ticks_msec() + 110000
	app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	app.open_lobby()
	net = app.coop
	root.get_node("Prefs").values.telemetry = true
	if role == "host":
		await host_game()
	elif role == "version" or role == "password":
		await rejected()
	elif role == "dedicated":
		await dedicated_client()
	else:
		await client_game()
	bot.release()
	net.stop()
	app.menu()
	bot.free()
	quit(failures)

func host_game() -> void:
	check(not net.host(80), "Port invalide rejeté")
	app.lobby.port.text = str(port)
	app.lobby.code.text = "rift-qa"
	app.lobby.limit.value = expected
	app.lobby.map.select(Catalog.MAPS.keys().find("cryo"))
	app.lobby.difficulty.select(0)
	app.lobby.create.pressed.emit()
	check(net.hosting and net.room.map == "cryo", "Hébergement ouvert depuis le lobby")
	print("HOST READY")
	if not await until(func(): return net.roster.size() == expected and net.can_start(), "Pilotes prêts"):
		return
	app.lobby.start.pressed.emit()
	var stage = app.session
	var other_ids: Array = stage.pilots.keys()
	other_ids.erase(1)
	var starts := {}
	for id in other_ids:
		starts[id] = stage.pilots[id].position
	check(stage.pilots.size() == expected and stage.map_id == "cryo" and not net.match_id.is_empty(), "Même arène et pilotes autoritaires")
	var moved := false
	var move_until := Time.get_ticks_msec() + 2300
	while Time.get_ticks_msec() < move_until:
		moved = true
		for id in other_ids:
			moved = moved and stage.pilots[id].position.distance_to(starts[id]) > 1.5
		if moved:
			break
		await physics_frame
	check(moved, "Entrées des clients déplacent tous les pilotes côté hôte")
	var bosses := {}
	var attacking := false
	var before: Dictionary = {}
	while Time.get_ticks_msec() < deadline and stage.director.wave < 7:
		var wave: int = stage.director.wave
		var phase: int = stage.director.phase
		if phase == Director.Phase.PREP and wave < 6:
			stage.director.open_wave()
		elif phase == Director.Phase.ACTIVE and wave < 6:
			if stage.units.is_empty() and not stage.director.pending.is_empty():
				stage._spawn(stage.director.pending[0])
			for unit in stage.units.duplicate():
				if unit.kind in ["elite", "warden"]:
					bosses[unit.kind] = true
				unit.take_hit(90000.0, unit.center(), Vector3.DOWN)
		elif phase == Director.Phase.ACTIVE and wave == 6:
			if not attacking:
				for id in stage.pilots:
					before[id] = stage.pilots[id].stats.hits
				attacking = true
			bot.release()
			bot.play_step(stage, stage.player, int(Engine.get_physics_frames()))
		elif phase == Director.Phase.UPGRADE and net.shop_left > 1.0:
			bot.release()
			net.ready_up()
			if wave == 6:
				var bought := true
				for id in other_ids:
					bought = bought and stage.wallets[id].levels.get("barrier", 0) == 1
				if bought:
					check(stage.wallet.levels.get("barrier", 0) == 0, "Les achats distants restent personnels")
					for id in other_ids:
						check(stage.wallets[id].spent == 75 and stage.pilots[id].shield_max == 61.0, "Un débit et un seul effet par client")
					break
		await physics_frame
	bot.release()
	check(stage.director.cleared == 6 and attacking and bosses.has("elite"), "Vague 6 réellement combattue, mini-boss franchi")
	for id in stage.pilots:
		check(stage.pilots[id].stats.hits > before.get(id, 0), "Le pilote a réellement touché un robot côté serveur")
	if not await until(func(): return stage.director.wave == 7 and stage.director.phase == Director.Phase.ACTIVE, "Reprise de la vague 7"):
		return
	if not await until(func(): return net.roster.size() == expected - 1, "Client retiré en plein combat"):
		return
	while stage.director.phase == Director.Phase.ACTIVE and Time.get_ticks_msec() < deadline:
		if stage.units.is_empty() and not stage.director.pending.is_empty():
			stage._spawn(stage.director.pending[0])
		for unit in stage.units.duplicate():
			unit.take_hit(90000.0, unit.center(), Vector3.DOWN)
		await physics_frame
	if not await until(func(): return net.roster.size() == expected, "Reconnexion pendant la boutique"):
		return
	var restored := false
	for id in stage.pilots:
		if id != 1 and not other_ids.has(id):
			restored = stage.wallets[id].spent == 75 and stage.pilots[id].shield_max == 61.0
	check(restored, "La reconnexion restitue les crédits et l’amélioration au bon pilote")
	await create_timer(0.45).timeout
	stage.director.finish(true)
	if not await until(func(): return app.screen == "result", "Bilan de l’hôte"):
		return
	check(stage.credited_result.get("ok", false), "Progression coop enregistrée sur l’hôte")
	print("NET_METRICS pilots=%d snapshot_peak=%d snapshot_avg=%d engine_static_bytes=%d kills=%d" % [
		expected, net.packet_peak, roundi(float(net.snapshot_bytes) / maxi(1, net.snapshot_count)),
		Performance.get_monitor(Performance.MEMORY_STATIC), stage.director.kills])
	await create_timer(0.8).timeout
	app.leave_coop()
	check(app.screen == "lobby" and not net.active(), "Fermeture par l’hôte")
	await create_timer(0.25).timeout

func rejected() -> void:
	net.join("127.0.0.1", port, "wrong" if role == "password" else "rift-qa", 1 if role == "version" else net.PROTOCOL)
	if await until(func(): return not net.active(), "Connexion refusée proprement"):
		check(("incompatible" if role == "version" else "incorrect") in net.status, "Motif du refus communiqué")

func dedicated_client() -> void:
	if not await enter_lobby():
		return
	net.ready_up()
	if not await until(func(): return net.in_match(), "Démarrage du serveur headless sans joueur hôte"):
		return
	var stage = app.session
	check(stage.mode == "short" and stage.map_id == "skyline" and not stage.pilots.has(1) and stage.pilots.size() == 2,
		"Deux pilotes connectés à Skyline, partie courte")
	await until(func(): return stage.director.phase == Director.Phase.ACTIVE and stage.director.live > 0,
		"Apparition d’un robot sur le serveur dédié")
	await create_timer(0.45).timeout

func client_game() -> void:
	if not await enter_lobby():
		return
	app.lobby.ready_button.pressed.emit()
	if not await until(func(): return net.in_match(), "Lancement reçu"):
		return
	var stage = app.session
	var pilot = stage.player
	var initial: Vector3 = pilot.position
	check(stage.map_id == "cryo" and stage.pilots.size() == expected and stage.pilots[1].avatar != null,
		"Carte commune et avatar 3D de l’hôte")
	Input.action_press("forward")
	await create_timer(0.65).timeout
	Input.action_release("forward")
	check(pilot.position.distance_to(initial) > 1.0, "Mouvement retourné par l’hôte")
	var last_ready := 0
	var seen_wave6 := false
	var before: int = 0
	while Time.get_ticks_msec() < deadline and net.in_match() and stage.director.wave < 7:
		var phase: int = stage.director.phase
		var wave: int = stage.director.wave
		if phase == Director.Phase.ACTIVE and wave == 6:
			if not seen_wave6:
				seen_wave6 = true
				before = stage.director.kills
				# An invalid payload must never teleport the pilot or select an unavailable weapon.
				net.send_input.rpc_id(1, net.match_id, net.sequence + 700, Vector2(1000, 0), 0.0, 0.0, 512, 7)
				net.request_field.rpc_id(1, net.match_id, wave, 101, "buy", "barrier", -1)
			bot.release()
			bot.play_step(stage, pilot, int(Engine.get_physics_frames()) + net.local_id() % 20)
		elif phase == Director.Phase.UPGRADE and wave != last_ready and net.shop_left > 1.0:
			bot.release()
			last_ready = wave
			if wave == 6:
				check(seen_wave6 and stage.director.kills > before and stage.hits > 0, "Robots, tirs et éliminations reçus en vague 6")
				var initial_balance: int = stage.wallet.balance
				app._buy_field("barrier")
				net.request_field.rpc_id(1, net.match_id, wave, net.action_id, "buy", "barrier", -1)
				net.request_field.rpc_id(1, net.match_id, wave - 1, 500, "buy", "barrier", -1)
				var accepted := func(): return stage.wallet.balance == initial_balance - 75 and pilot.shield_max == 61.0
				if not await until(accepted, "Reçu et portefeuille synchronisés"):
					return
			app.advance()
		await physics_frame
	bot.release()
	if not await until(func(): return stage.director.wave == 7 and stage.director.phase == Director.Phase.ACTIVE, "Vague 7 synchronisée"):
		return
	if role == "rejoin":
		app.leave_coop()
		await create_timer(2.4).timeout
		if not await enter_lobby():
			return
		if not await until(func(): return net.in_match() and app.screen == "upgrade" and app.session.player.shield_max == 61.0,
			"Retour dans la même partie et amélioration conservée"):
			return
	if not await until(func(): return app.screen == "result", "Bilan reçu de l’hôte"):
		return
	check(app.session.result_override.wave == 7 and app.session.credited_result.get("ok", false), "Bilan autoritaire et progression locale")
	if await until(func(): return not net.active(), "Fin de connexion de l’hôte"):
		check(app.screen == "lobby" and app.session == null, "Retour au salon sans état résiduel")

func enter_lobby() -> bool:
	app.lobby.port.text = str(port)
	app.lobby.code.text = "rift-qa"
	app.lobby.connect_button.pressed.emit()
	return await until(func(): return net.roster.has(net.local_id()), "Connexion via l’interface")

func until(condition: Callable, label: String) -> bool:
	var limit := mini(deadline, Time.get_ticks_msec() + 26000)
	while not condition.call() and Time.get_ticks_msec() < limit:
		await physics_frame
	var ok: bool = condition.call()
	check(ok, label)
	return ok

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1
