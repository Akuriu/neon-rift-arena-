extends SceneTree

var app
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("NEON_QA_ISOLATED") != "1":
		quit(2)
		return
	app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	app.begin("explore", "standard", "skyline", 910)
	var stage = app.session
	var workshop = stage.workshop
	var pilot = stage.player
	await ticks(3)
	check(is_instance_valid(workshop) and workshop.state == 0, "Atelier expérimental fermé au Dépôt de fret")
	check(not workshop.activate(pilot), "Le terminal refuse une activation distante")
	pilot.position = workshop.TERMINAL + Vector3(0, -0.95, 1.6)
	await ticks(4)
	check(workshop.can_reach(pilot) and stage.pickup_hint == "Ouvrir l’atelier", "Le terminal affiche une action contextuelle à portée")
	var from := Vector3(10.5, 1.2, 23)
	var to := Vector3(10.5, 1.2, 21)
	check(not stage.ray(from, to, 1).is_empty(), "La porte fermée possède une vraie collision")
	stage.interact()
	check(workshop.state == 1 and workshop.activations == 1 and not workshop.activate(pilot), "Activation unique et rejet pendant l’animation")
	await ticks(58)
	check(workshop.state == 2 and workshop.collider.disabled and stage.ray(from, to, 1).is_empty(), "La porte animée ouverte libère le passage physique")
	check(workshop.FOOTPRINT not in stage.arena.footprints, "Le passage ouvert met à jour les routes des cibles")
	app.pause()
	var hold: float = workshop.hold
	await ticks(10)
	check(workshop.hold == hold, "La pause gèle l’atelier interactif")
	app.hud()
	pilot.position = Vector3(10.5, 0.05, 22)
	workshop.hold = 0.001
	await ticks(15)
	check(workshop.obstructed and workshop.progress == 1.0 and pilot.alive,
		"La fermeture attend si le pilote occupe le passage, sans l’écraser")
	pilot.position = workshop.TERMINAL + Vector3(0, -0.95, 1.6)
	await ticks(58)
	check(workshop.state == 3 and not workshop.collider.disabled and not stage.ray(from, to, 1).is_empty(),
		"La porte se referme après libération du passage")
	check(workshop.FOOTPRINT in stage.arena.footprints and not workshop.activate(pilot),
		"La route fermée est rétablie et le délai empêche le spam")
	await ticks(94)
	check(workshop.state == 0 and workshop.activate(pilot), "Un cycle complet permet une nouvelle activation")
	await exercise_lift(stage)
	var dummy := Node.new()
	stage.net = dummy
	check(not workshop.activate(pilot), "L’atelier refuse l’activation dans un contexte réseau non pris en charge")
	check(not stage.cargo_lift.activate(pilot), "Le monte-charge refuse une activation en réseau")
	stage.net = null
	dummy.free()
	for mode in ["classic", "teams", "gungame", "survival"]:
		app.begin(mode, "standard", "skyline", 911, "", false, {"bots": 0})
		check(not is_instance_valid(app.session.workshop) and not is_instance_valid(app.session.cargo_lift),
			"Les mécanismes n’altèrent pas la carte du mode " + mode)
	app.begin("training", "standard", "skyline", 912)
	check(is_instance_valid(app.session.workshop) and is_instance_valid(app.session.cargo_lift)
		and app.session.player.arsenal.rack.size() == 8, "Le stand garde les huit armes et les mécanismes interactifs")
	app.menu()
	root.get_node("Sounds").stop_all()
	await process_frame
	quit(failures)

func exercise_lift(stage: Node3D) -> void:
	var lift = stage.cargo_lift
	var pilot = stage.player
	var base: Vector3 = lift.BASE
	check(is_instance_valid(lift) and lift.FOOTPRINT in stage.arena.footprints
		and not lift.activate(pilot), "Monte-charge présent et zone de mouvement évitée par les routes IA")
	pilot.respawn(base + Vector3(0, -0.10, 3.25))
	pilot.remote_input = true
	pilot.net_move = Vector2(0, -1)
	for frame in range(100):
		await physics_frame
		if pilot.position.z < base.z + 0.8:
			break
	pilot.net_move = Vector2.ZERO
	await ticks(12)
	check(lift.can_reach(pilot) and pilot.is_on_floor() and absf(pilot.position.y - base.y) < 0.10
		and stage.pickup_hint == "Monter au quai", "La rampe permet d’embarquer à pied et affiche la commande")
	stage.interact()
	await ticks(43)
	check(lift.moving and lift.progress > 0.1 and absf(pilot.position.y - lift.deck.position.y) < 0.13,
		"Le plancher mobile transporte réellement le pilote")
	app.pause()
	var progress: float = lift.progress
	await ticks(15)
	check(lift.progress == progress, "La pause suspend le monte-charge")
	app.hud()
	stage.interact()
	await ticks(18)
	check(lift.stopped and lift.progress == progress, "L’arrêt d’urgence immobilise le monte-charge")
	stage.interact()
	await ticks(170)
	check(lift.progress == 1.0 and not lift.moving and pilot.is_on_floor()
		and absf(pilot.position.y - lift.deck.position.y) < 0.12, "Reprise et arrivée stable au quai supérieur")
	pilot.net_move = Vector2(0, -1)
	for frame in range(90):
		await physics_frame
		if pilot.position.z < 8.62:
			break
	pilot.net_move = Vector2.ZERO
	await ticks(12)
	check(pilot.position.z < 8.9 and absf(pilot.position.y - lift.deck.position.y) < 0.13
		and pilot.is_on_floor(), "Le quai supérieur est accessible à pied depuis le plateau")
	pilot.respawn(lift.deck.position + Vector3.UP * 0.06)
	await ticks(10)
	var blocker = stage.spawn_unit("sentinel", base - Vector3.UP * 0.10, true)
	blocker.set_physics_process(false)
	stage.interact()
	await ticks(25)
	check(lift.obstructed and lift.progress == 1.0 and blocker.alive, "La descente attend un autre personnage sous le plateau")
	blocker.position += Vector3(4, 0, 0)
	await ticks(173)
	check(lift.progress == 0.0 and not lift.moving and not lift.obstructed and pilot.is_on_floor(),
		"Le retour au sol reprend après dégagement sans chute")
	var valid := true
	for cycle in range(10):
		stage.interact()
		await ticks(172)
		valid = valid and not lift.moving and lift.progress == float(1 - cycle % 2) and pilot.is_on_floor() \
			and absf(pilot.position.y - lift.deck.position.y) < 0.13
	check(valid, "Dix trajets aller-retour alternés gardent la collision et le pilote sur le plateau")
	pilot.respawn(lift.UPPER_CALL + Vector3(-1.05, -0.96, 0.55))
	await ticks(8)
	stage.interact()
	await ticks(172)
	check(lift.progress == 1.0 and not lift.moving, "Le terminal du quai appelle le plateau depuis le sol")
	pilot.respawn(lift.GROUND_CALL + Vector3(-0.5, -0.95, 0.75))
	await ticks(8)
	stage.interact()
	await ticks(172)
	check(lift.progress == 0.0 and not lift.moving, "Le terminal au sol rappelle le plateau depuis le quai")

func ticks(count: int) -> void:
	for frame in count:
		await physics_frame

func check(value: bool, caption: String) -> void:
	print("PASS " if value else "FAIL ", caption)
	if not value:
		failures += 1
