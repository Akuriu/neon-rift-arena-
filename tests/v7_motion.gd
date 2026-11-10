extends SceneTree

const View := preload("res://game/weapons/view_animation.gd")
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
	app.begin("training", "standard", "reactor", 920)
	var stage = app.session
	var pilot = stage.player
	var gun = pilot.arsenal
	await ticks(25)
	var swaps := true
	for i in range(50):
		gun.select((gun.active + 1) % 8)
		var shots: int = stage.shots
		Input.action_press("fire")
		Input.action_press("reload")
		await ticks(11)
		swaps = swaps and stage.shots == shots and gun.reload_left == 0.0
		Input.action_release("fire")
		Input.action_release("reload")
		await ticks(9)
		swaps = swaps and gun.active == gun.visual_index and gun.view.position.is_finite()
	check(swaps, "Cinquante changements rapides sans tir ni recharge pendant le rangement/équipement")
	gun.select(0)
	await ticks(22)
	Input.action_press("ads")
	await ticks(30)
	gun.magazines[0] -= 5
	gun.cycle()
	gun.reload_left = gun.cycle_length * 0.5
	gun.pose(0.016, 1.0, true, 0.0)
	check(gun.animator.state == View.Pose.RELOAD_CELL and not gun.aiming(), "La recharge reste prioritaire sur visée et sprint")
	Input.action_release("ads")
	var rotation: Vector3 = pilot.head.rotation
	gun.pose(4.0, 1.0, true, 0.0)
	pilot.presentation.present(4.0)
	check(gun.view.position.is_finite() and pilot.presentation.position.is_finite() and pilot.head.rotation == rotation,
		"Un delta visuel après suspension ne déplace pas la visée logique")
	pilot.presentation.lean = 0.04
	pilot.respawn(stage.arena.start_at)
	check(pilot.presentation.lean == 0.0 and not gun.animator.warmed, "Respawn réinitialise les ressorts visuels et la pose")
	var prefs = root.get_node("Prefs")
	prefs.change_value("quality", 0)
	for map_id in prefs.MAPS:
		app.begin("classic", "standard", map_id, 921, "", false, {"bots": 12, "target": 100})
		stage = app.session
		var match_state = stage.classic
		match_state.open_wave()
		match_state._advance_respawns(0.1)
		var unit = stage.units[0]
		var health: float = unit.health
		check(unit.take_hit(30, unit.center(), Vector3.FORWARD, stage.player) == 0.0 and unit.health == health,
			"Protection physique du bot à l’apparition sur " + map_id)
		stage.player.damage_lock = 100.0
		unit.timer = 10.0
		await ticks(62)
		check(unit.spawn_guard == 0.0 and unit.take_hit(1.0, unit.center(), Vector3.FORWARD, stage.player) > 0.0,
			"La protection expire et les dégâts reprennent sur " + map_id)
		await ticks(120)
		var finite: bool = stage.units.size() <= 12
		for bot in stage.units:
			finite = finite and bot.position.is_finite() and bot.velocity.is_finite()
		check(finite and match_state.combatants().size() <= 13, "Douze bots : poursuite et séparation valides sur " + map_id)
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
