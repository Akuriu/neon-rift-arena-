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
	var dummy := Node.new()
	stage.net = dummy
	check(not workshop.activate(pilot), "L’atelier refuse l’activation dans un contexte réseau non pris en charge")
	stage.net = null
	dummy.free()
	for mode in ["classic", "teams", "gungame", "survival"]:
		app.begin(mode, "standard", "skyline", 911, "", false, {"bots": 0})
		check(not is_instance_valid(app.session.workshop), "L’atelier n’altère pas la carte du mode " + mode)
	app.begin("training", "standard", "skyline", 912)
	check(is_instance_valid(app.session.workshop) and app.session.player.arsenal.rack.size() == 8,
		"Le stand garde les huit armes et son atelier interactif")
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
