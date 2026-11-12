extends SceneTree

const Arms := preload("res://game/weapons/catalog.gd")
const Wallet := preload("res://game/economy/field_wallet.gd")
const Director := preload("res://game/wave_director.gd")

var app
var prefs
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("NEON_QA_ISOLATED") != "1":
		printerr("Un profil de test isolé est nécessaire.")
		quit(2)
		return
	prefs = root.get_node("Prefs")
	test_wallet()
	test_migration()
	app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	await test_hub()
	await test_arms()
	await test_endless()
	app.menu()
	await frames(5)
	check(app.session == null and not paused, "Retour au hub après la partie Infini")
	quit(failures)

func test_wallet() -> void:
	var wallet := Wallet.new()
	wallet.grant(215)
	var refused := wallet.buy("power", 1, 5, func(_id): return false)
	check(not refused.ok and wallet.balance == 215, "Achat de terrain annulé sans perte de crédits")
	var paid := wallet.buy("power", 1, 5, func(_id): return true)
	var replay := wallet.buy("power", 1, 5, func(_id): return true)
	check(paid.ok and not replay.ok and wallet.balance == 95, "Transaction atomique, rejeu rejeté")
	check(not wallet.buy("cool", 1, 6, func(_id): return true).ok, "Solde insuffisant rejeté")
	wallet.grant(100000000)
	check(wallet.balance == Wallet.MAX_CREDITS and wallet.grant(-1) == 0, "Solde entier borné")

func test_migration() -> void:
	var legacy := {"version": 2, "settings": {"fov": 91, "quality": 1, "master": 0.0},
		"bindings": {"jump": KEY_J, "interact": KEY_G}, "records": {"survival|standard|reactor": [{"score": 9912, "kills": 41}]}}
	var file := FileAccess.open(prefs.profile_file(prefs.SAVE), FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var hash := FileAccess.get_sha256(prefs.profile_file(prefs.SAVE))
	prefs.load_disk()
	check(prefs.values.fov == 91.0 and prefs.values.master == 0.0 and prefs.values.quality == 1 and prefs.keys.jump == KEY_J,
		"Migration v2 → v3 préserve réglages, mute et touches")
	check(prefs.leaderboard("survival", "standard", "reactor")[0].score == 9912, "Ancien record conservé")
	check(prefs.keys.interact == KEY_G and prefs.keys.gadget != KEY_G, "La nouvelle touche Gadget respecte une ancienne affectation de G")
	check(prefs.profile.data.slots.size() == 4 and prefs.profile.data.coins == 0, "Nouveaux champs initialisés")
	var report := {"score": 11000, "wave": 20, "kills": 101, "seconds": 600, "shots": 310,
		"hits": 258, "bosses": 4, "victory": true, "credits": 3850, "spent": 814, "mastery": {"wp_pulse": 45}}
	var earned: Dictionary = prefs.complete_run("qa-stable-run", "survival", "standard", "reactor", report)
	var repeated: Dictionary = prefs.complete_run("qa-stable-run", "survival", "standard", "reactor", report)
	check(earned.ok and not repeated.ok and prefs.profile.data.coins == earned.coins and earned.xp > 0,
		"Bilan et progression payés une seule fois")
	check(FileAccess.get_sha256(prefs.profile_file(prefs.LEGACY_BACKUP)) == hash, "Copie v1 conservée octet pour octet")
	var gained := int(prefs.profile.data.coins)
	file = FileAccess.open(prefs.profile_file(prefs.TEMP), FileAccess.WRITE)
	file.store_string("{\"version\":3")
	file.close()
	prefs.load_disk()
	check(prefs.profile.data.coins == gained and prefs.profile.data.stats.best_wave == 20, "Temporaire tronqué ignoré")
	var receipt: Dictionary = prefs.profile_action(prefs.profile.claim.bind("waves"))
	check(receipt.ok and not prefs.profile_action(prefs.profile.claim.bind("waves")).ok, "Contrat quotidien encaissé une fois")

func test_hub() -> void:
	app.open_hub("shop", "Armes", "wp_eclipse")
	var coins: int = prefs.profile.data.coins
	check(click("Débloquer"), "Bouton de boutique permanente visible")
	check(app.screen == "confirm", "Confirmation du déblocage")
	await frames(3)
	check(click("Confirmer"), "Validation via l’interface")
	check(app.screen == "hub" and prefs.profile.owns("wp_eclipse") and prefs.profile.data.coins == coins - 110,
		"Achat du sniper appliqué après confirmation")
	check(click("Équiper"), "Équipement via l’arsenal")
	prefs.load_disk()
	check(prefs.profile.owns("wp_eclipse") and prefs.profile.data.slots[0] == "wp_eclipse",
		"Achat et emplacement conservés après relecture du profil")
	app.menu()

func test_arms() -> void:
	check(Arms.WEAPONS.size() == 8, "Huit définitions d’armes")
	var all_fire := true
	var all_models := true
	for data in Arms.WEAPONS:
		app.begin("training", "standard", "reactor", 1234, data.id)
		await frames(12)
		var stage = app.session
		var pilot = stage.player
		var gun = pilot.arsenal
		all_models = all_models and gun.spec().id == data.id and gun.view.get_child_count() > 2 \
			and root.get_node("Sounds").get_sample(data.sound) != null
		var target = stage.units[0]
		target.position = pilot.position + Vector3(0.0, 0.0, -6.5)
		target.set_physics_process(false)
		await frames(2)
		aim(pilot, target.center())
		if data.mode in ["rail", "lance"]:
			Input.action_press("ads")
			await frames(34)
			check(gun.scope > 0.95 and is_equal_approx(gun.magnification(), data.zoom[0]) \
				and absf(pilot.head.fov - gun.aim_fov(prefs.values.fov)) < 1.5, "%s en visée" % data.name)
			if data.mode == "rail":
				gun.wheel(1)
				await frames(25)
				check(gun.magnification() == 4.0 and pilot.head.fov < 30.0, "Rail avec zoom ×4")
		Input.action_press("fire")
		await frames(72 if data.mode in ["lance", "nova"] else 12)
		if data.mode == "lance":
			check(gun.magnification() > 3.2, "Lance avec zoom progressif en charge")
		Input.action_release("fire")
		await frames(43)
		all_fire = all_fire and stage.shots > 0
		if data.mode in ["rail", "lance"]:
			check(stage.hits > 0, "%s touche le robot" % data.name)
			Input.action_release("ads")
			gun.select(0)
			await frames(35)
			check(gun.scope < 0.04 and pilot.head.fov > 70.0, "Sortie de la lunette après changement")
	check(all_fire and all_models, "Huit armes avec tir, viewmodel et audio en entraînement")

func test_endless() -> void:
	app.begin("endless", "discovery", "cryo", 893)
	await frames(3)
	var stage = app.session
	var route_ok := true
	for at in stage.arena.spawn_points:
		route_ok = route_ok and not stage.arena.routes.find(at, stage.player.position).is_empty()
	check(route_ok, "Cryo Foundry · chaque spawn a une route vers le pilote")
	var retained := {}
	for wave in range(1, 102):
		stage.director.open_wave()
		while stage.director.remaining() > 0:
			if stage.units.is_empty():
				stage._spawn(stage.director.pending[0])
			for unit in stage.units.duplicate():
				unit.take_hit(90000.0, unit.center(), Vector3.DOWN)
			await frames(2)
		if wave == 1:
			var initial: int = stage.wallet.balance
			var old_shield: float = stage.player.shield_max
			app._buy_field("barrier")
			check(stage.wallet.balance == initial - 75 and stage.player.shield_max == old_shield + 6.0,
				"Boutique en jeu applique réellement l’achat à l’intermission")
		if wave in [20, 50, 75, 100]:
			retained[wave] = Performance.get_monitor(Performance.MEMORY_STATIC)
		if wave < 101:
			app.pick(stage.choices()[0])
			app.advance()
			await frames(2)
	check(stage.director.cleared == 101 and stage.director.total_waves == 0, "101 vagues Infini accélérées dans la scène")
	check(stage.pickups.get_child_count() <= 10 and stage.projectile_bin.get_child_count() <= 58 \
		and stage.hazards.get_child_count() == 0, "Entités temporaires bornées après 101 vagues")
	print("ENDURANCE engine_static_bytes=", retained)
	var coins: int = prefs.profile.data.coins
	app.bank_run()
	app.bank_run()
	await frames(3)
	check(app.screen == "result" and prefs.profile.data.coins > coins, "Extraction volontaire et pièces créditées")

func click(fragment: String) -> bool:
	for item in app.view.find_children("*", "Button", true, false):
		if fragment in item.text and not item.disabled:
			item.pressed.emit()
			return true
	return false

func aim(pilot, at: Vector3) -> void:
	var offset: Vector3 = at - pilot.head.global_position
	pilot.rotation.y = atan2(-offset.x, -offset.z)
	pilot.head.rotation.x = atan2(offset.y, Vector2(offset.x, offset.z).length())

func frames(count: int) -> void:
	for _i in count:
		await physics_frame

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures += 1
