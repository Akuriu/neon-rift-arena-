extends SceneTree

const Generator := preload("res://game/waves/generator.gd")
const Catalog := preload("res://game/catalog.gd")
const Phase := preload("res://game/wave_director.gd").Phase
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("NEON_QA_ISOLATED") != "1":
		quit(2)
		return
	var themes := {}
	var mutations := {}
	var valid := true
	for seed in [14, 207, 711, 1009]:
		for number in range(1, 51):
			var wave := Generator.generate(number, seed, Catalog.DIFFICULTIES.standard)
			themes[wave.theme] = true
			mutations[wave.mutation] = true
			valid = valid and wave == Generator.generate(number, seed, Catalog.DIFFICULTIES.standard)
	check(valid and themes.size() == 12 and mutations.size() == 5, "200 définitions déterministes, douze thèmes et quatre mutateurs")
	var prefs = root.get_node("Prefs")
	var app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	app.begin("training", "standard", "bastion", 224)
	await ticks(6)
	var stage = app.session
	app.pause()
	app.open_training()
	check(app.screen == "training_setup", "Réglages du stand accessibles depuis Pause")
	stage.configure_training("fixed", 8, 30)
	app.hud()
	var first = stage.units[0]
	var where: Vector3 = first.position
	await ticks(120)
	check(first.position.is_equal_approx(where) and absf(where.distance_to(stage.arena.start_at) - 8.0) < 0.2,
		"Cible fixe positionnée à huit mètres")
	stage.director.elapsed = 29.99
	await ticks(4)
	check(stage.training_ended and stage.player.round_lock, "Le chronomètre termine l’exercice")
	stage.configure_training("air", 16, 60)
	await ticks(3)
	var airborne := true
	for unit in stage.units:
		airborne = airborne and unit.kind == "skimmer" and unit.position.y > 0.50
	check(airborne and stage.player.arsenal.rack.size() == 8 and not stage.player.round_lock,
		"Quatre cibles aériennes, huit armes et réinitialisation")
	app.begin("short", "discovery", "bastion", 711)
	stage = app.session
	await ticks(2)
	stage.director.wave = 3
	stage.director.open_wave()
	stage.director.cap = 0
	stage.player.position = stage.arena.terminal_at - Vector3.UP
	var credits: int = stage.wallet.balance
	await ticks(390)
	check(stage.relay_state == 2 and stage.wallet.balance - credits == 48, "Objectif optionnel accorde ses crédits une fois")
	await ticks(390)
	check(stage.wallet.balance - credits == 48, "Le relais ne donne plus de crédits après stabilisation")
	stage.director.phase = Phase.UPGRADE
	stage.director.cleared = 5
	stage.director.wave = 5
	var next: Dictionary = stage.director.preview_wave(6)
	stage.ready_next_wave(true)
	stage.director.open_wave()
	check(stage.director.current_wave.wave_bonus == next.wave_bonus + 60
		and stage.director.current_wave.interval < next.interval, "Choix de renforts plus rapides et prime de risque")
	var arena = stage.arena
	var footprints: Array = arena.footprints.duplicate()
	arena.alert_lighting(true)
	check(arena.emergency and arena.footprints == footprints, "Éclairage d’urgence conserve routes et collisions")
	prefs.change_value("flashes", 0.0)
	prefs.change_value("particles", 0.0)
	var pool = stage.effects
	await ticks(50)
	var prior: int = pool.active.size()
	pool.sparks(stage.player.position, Color.WHITE, 30)
	check(pool.active.size() == prior, "Les étincelles facultatives sont désactivables")
	pool.wave(stage.player.position, Color.WHITE, 2.3)
	check(pool.active.size() > prior, "L’indication de zone reste disponible sans étincelles")
	var profile = prefs.profile
	check(not profile.buy("skin_aurora").ok, "La finition Aurore est verrouillée avant la vague 50")
	var gain: Dictionary = prefs.complete_run("v3-field-100", "endless", "standard", "bastion",
		{"score": 50001, "wave": 100, "seconds": 1200, "kills": 600, "victory": true})
	check(gain.ok and profile.owns("skin_aurora") and "hundred" in profile.data.career.badges,
		"Paliers 25/50/75/100 et finition du mode Infini")
	app.menu()
	await process_frame
	quit(failures)

func ticks(count: int) -> void:
	for _i in count:
		await physics_frame

func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1
