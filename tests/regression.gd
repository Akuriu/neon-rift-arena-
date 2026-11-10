extends SceneTree

const Director := preload("res://game/wave_director.gd")
var app
var prefs
var sounds
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("NEON_QA_ISOLATED") != "1":
		printerr("Utiliser un dossier utilisateur isolé et NEON_QA_ISOLATED=1.")
		quit(2)
		return
	prefs = root.get_node("Prefs")
	sounds = root.get_node("Sounds")
	app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	check(app.screen == "menu", "Menu au démarrage")
	press("JOUER")
	check(app.screen == "select", "Jouer ouvre les protocoles")
	press("DÉMARRER")
	check(app.screen == "hud" and app.session.mode == "survival", "Démarrer charge l’arène")
	await frames(9)
	var stage = app.session
	var start: Vector3 = stage.player.position
	await hold_key(KEY_Z, 26)
	check(stage.player.position.z < start.z - 1.5, "Déplacement AZERTY avec la touche Z")
	await escape()
	var time: float = stage.director.clock
	check(app.screen == "pause" and paused, "Échap suspend et ouvre la pause")
	await frames(22)
	check(is_equal_approx(time, stage.director.clock), "Le chrono ne s’écoule pas pendant la pause")
	press("Paramètres")
	check(app.screen == "settings" and paused, "Paramètres accessibles pendant la partie")
	app.settings.tabs[1].pressed.emit()
	var listen := false
	for button in app.settings.entries.find_children("*", "Button", true, false):
		listen = listen or button.text == "Écouter une impulsion"
	check(app.settings.active == 1 and listen, "Onglet Audio et bouton d’écoute")
	prefs.change_value("master", 0.0)
	check(AudioServer.is_bus_mute(0), "Le volume général agit sur la sortie")
	prefs.change_value("master", 0.5)
	check(absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.5)) < 0.02, "Le volume est appliqué en dB")
	prefs.change_value("quality", 2)
	check(is_equal_approx(root.scaling_3d_scale, 1.0) and stage.arena.sun.shadow_enabled, "Élevée active ombres et résolution native")
	prefs.change_value("quality", 0)
	check(is_equal_approx(root.scaling_3d_scale, 0.76) and not stage.arena.sun.shadow_enabled, "Faible réduit l’échelle 3D et coupe les ombres")
	prefs.change_value("fps_limit", 30)
	check(Engine.max_fps == 30, "La limite FPS est appliquée")
	prefs.change_value("fps_limit", 60)
	app.settings.tabs[3].pressed.emit()
	prefs.change_value("layout", 1)
	app.settings._start_binding("jump")
	send_key(KEY_J, true)
	send_key(KEY_J, false)
	await frames(2)
	check(prefs.keys.jump == KEY_J and prefs.keys.forward == KEY_W, "QWERTY et affectation de touche")
	await escape()
	check(app.screen == "pause", "Retour des réglages vers la pause")
	await escape()
	start = stage.player.position
	await hold_key(KEY_W, 23)
	check(app.screen == "hud" and stage.player.position.z < start.z - 1.4, "Reprise et déplacement WASD")
	await movement(stage)
	stage.player.damage_lock = 0.0
	stage.player.take_damage(999)
	await frames(3)
	check(app.screen == "result", "Défaite et bilan")
	press("REJOUER")
	check(app.screen == "hud" and app.session != stage and app.session.director.wave == 1, "Relance depuis le bilan")
	await three_restarts()
	await practice()
	await timeout_trial()
	save_tests()
	app.menu()
	check(app.screen == "menu" and app.session == null and not paused, "Menu sans ancienne session active")
	print("RÉGRESSION ", "OK" if failures == 0 else "ÉCHEC", " (", failures, ")")
	quit(failures)

func movement(stage) -> void:
	var pilot = stage.player
	pilot.position = Vector3(0, 0.06, 22.2)
	pilot.rotation.y = PI
	pilot.head.rotation = Vector3.ZERO
	pilot.velocity = Vector3.ZERO
	Input.action_press("forward")
	Input.action_press("sprint")
	await frames(51)
	check(pilot.position.z < 23.3, "Le sprint ne traverse pas le mur d’enceinte")
	pilot.rotation.y = 0.0
	pilot.velocity = Vector3.ZERO
	await frames(17)
	Input.action_press("crouch")
	await frames(7)
	check(pilot.slide > 0.0 and pilot.height < 1.6, "Accroupissement et glissade pendant le sprint")
	Input.action_release("crouch")
	Input.action_release("sprint")
	Input.action_release("forward")
	await frames(36)
	var floor: float = pilot.position.y
	await hold_key(KEY_J, 13)
	check(pilot.position.y > floor + 0.55, "Saut avec la touche réassignée")
	await frames(31)
	pilot.position = Vector3(19.82, 0.06, 11.4)
	pilot.rotation.y = 0.0
	pilot.velocity = Vector3.ZERO
	Input.action_press("forward")
	await frames(81)
	Input.action_release("forward")
	check(pilot.position.y > 1.42 and pilot.position.z < 5.0, "Rampe et accès à la passerelle")

func three_restarts() -> void:
	for index in 3:
		var before: int = app.session.get_instance_id()
		await escape()
		press("Recommencer")
		check(app.screen == "confirm", "Confirmation du redémarrage %d" % (index + 1))
		press("Confirmer")
		await frames(8)
		check(app.session.get_instance_id() != before and app.session.units.is_empty() \
			and app.session.director.phase == Director.Phase.PREP and root.get_node("Prefs") == prefs,
			"Un seul directeur au redémarrage %d" % (index + 1))
	await escape()
	press("Retour au menu")
	await escape()
	check(app.screen == "pause", "La confirmation peut être annulée")
	press("Retour au menu")
	press("Confirmer")
	check(app.screen == "menu", "Retour au menu confirmé")

func practice() -> void:
	press("ENTRAÎNEMENT")
	var stage = app.session
	var pilot = stage.player
	await frames(45)
	check(stage.mode == "training" and stage.units.size() == 4, "Quatre cibles actives en entraînement")
	var unit = stage.units[0]
	var movement_origin: Vector3 = unit.position
	await frames(50)
	check(unit.position.distance_to(movement_origin) > 0.4, "Les cibles d’entraînement se déplacent")
	pilot.damage_lock = 0.0
	pilot.take_damage(500)
	check(pilot.alive and pilot.health == 100.0, "Entraînement sans défaite")
	pilot.position = Vector3(0, 0.05, 14.6)
	pilot.velocity = Vector3.ZERO
	unit.position = Vector3(0, 0.04, 9.7)
	unit.set_physics_process(false)
	await frames(7)
	aim(pilot, unit.center())
	var hits: int = stage.hits
	await hold_action("fire", 5)
	check(stage.hits == hits + 1 and unit.health < unit.maximum, "Pulse-7 touche une vraie collision")
	await hold_action("reload", 3)
	check(pilot.arsenal.reload_left > 0.0, "Recharge active")
	await hold_key(KEY_2, 3)
	await frames(16)
	check(pilot.arsenal.active == 1 and pilot.arsenal.reload_left == 0.0, "Changer d’équipement annule la recharge")
	aim(pilot, unit.center())
	var rounds: int = pilot.arsenal.rounds()
	await hold_action("fire", 4)
	check(pilot.arsenal.rounds() == rounds - 1 and stage.hits > hits, "Volt Arc dépense une charge par éventail")
	await hold_key(KEY_3, 3)
	await frames(38)
	var prior_shots: int = stage.shots
	await hold_action("fire", 18)
	check(stage.shots == prior_shots + 3, "Prism Burst tire une rafale de trois")
	await frames(105)
	check(stage.units.size() == 4, "Les cibles neutralisées réapparaissent")
	await hold_key(KEY_4, 3)
	await frames(35)
	var target = stage.units[0]
	target.position = Vector3(0, 0.04, 10.0)
	target.set_physics_process(false)
	await frames(4)
	aim(pilot, target.center())
	prior_shots = stage.shots
	hits = stage.hits
	Input.action_press("fire")
	await frames(55)
	check(pilot.arsenal.charge > 0.8 and stage.shots == prior_shots, "Nova monte en charge avant de tirer")
	Input.action_release("fire")
	await frames(31)
	check(stage.shots == prior_shots + 1 and stage.hits == hits + 1 and stage.projectiles.get_child_count() == 0,
		"Nova balistique, impact et retrait du projectile")
	pilot.position = Vector3(-8.85, 0.05, 12.5)
	var blocked = stage.units[0]
	blocked.position = Vector3(-8.85, 0.04, 4.6)
	blocked.set_physics_process(false)
	await hold_key(KEY_1, 3)
	await frames(46)
	aim(pilot, blocked.center())
	hits = stage.hits
	await hold_action("fire", 7)
	check(stage.hits == hits, "Les tirs sont arrêtés par le décor")
	pilot.position = Vector3(3.2, 0.05, 18.4)
	await frames(4)
	await hold_action("interact", 3)
	check(stage.shots == 0 and stage.units.size() == 4, "Console E et réarmement en entraînement")
	app.menu()

func timeout_trial() -> void:
	app.begin("trial", "standard")
	var stage = app.session
	await frames(190)
	check(stage.director.phase == Director.Phase.TRIAL and stage.director.remaining() == 15, "Le défi démarre avec 15 cibles")
	stage.director.elapsed = Director.TRIAL_TIME - 0.03
	await frames(6)
	check(app.screen == "result" and is_equal_approx(stage.director.elapsed, 90.0), "Le chrono déclenche un résultat à 90 secondes")
	app.menu()

func save_tests() -> void:
	prefs.change_value("fov", 90.0)
	check(prefs.save_disk(), "Écriture de la première révision du profil")
	prefs.change_value("fov", 96.0)
	prefs.log_result("trial", "expert", "reactor", {"score": 2780, "seconds": 72, "kills": 15, "accuracy": 48, "victory": true})
	prefs.load_disk()
	check(prefs.values.fov == 96.0 and prefs.keys.jump == KEY_J \
		and prefs.leaderboard("trial", "expert", "reactor")[0].score == 2780, "Relecture des réglages, des touches et du record")
	var file := FileAccess.open(prefs.profile_file(prefs.SAVE), FileAccess.WRITE)
	file.store_string("{corrompu")
	file.close()
	prefs.load_disk()
	check(prefs.values.fov == 90.0 and prefs.keys.jump == KEY_J, "Profil corrompu récupéré depuis la révision précédente")
	DirAccess.remove_absolute(prefs.profile_file(prefs.SAVE))
	DirAccess.remove_absolute(prefs.profile_file(prefs.BACKUP))
	prefs.load_disk()
	check(prefs.values.fov == 82.0 and prefs.keys.forward == KEY_Z, "Retour aux valeurs d’origine si le profil est absent")
	check(sounds.bank.size() == 45 and sounds.bank.pulse.data.size() > 1000 \
		and sounds.bank.combat.loop_mode == AudioStreamWAV.LOOP_FORWARD \
		and absf(sounds.bank.combat.loop_end / float(sounds.bank.combat.mix_rate) - 13.44) < 0.025 \
		and sounds.bank.pressure.loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"Banque locale et boucle audio intégrale de 13,44 secondes")

func press(fragment: String) -> void:
	for control in app.view.find_children("*", "Button", true, false):
		if fragment in control.text and not control.disabled:
			control.pressed.emit()
			return
	check(false, "Bouton absent " + fragment)

func escape() -> void:
	await hold_key(KEY_ESCAPE, 1)

func send_key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func hold_key(code: int, duration: int) -> void:
	send_key(code, true)
	await frames(duration)
	send_key(code, false)
	await frames(2)

func hold_action(action: String, duration: int) -> void:
	Input.action_press(action)
	await frames(duration)
	Input.action_release(action)
	await frames(2)

func aim(pilot, point: Vector3) -> void:
	var d: Vector3 = point - pilot.head.global_position
	pilot.rotation.y = atan2(-d.x, -d.z)
	pilot.head.rotation = Vector3(atan2(d.y, Vector2(d.x, d.z).length()), 0, 0)

func frames(count: int) -> void:
	for _i in count:
		await physics_frame

func check(condition: bool, title: String) -> void:
	print("PASS " if condition else "FAIL ", title)
	if not condition:
		failures += 1
