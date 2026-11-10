extends SceneTree

const ViewMotion := preload("res://game/weapons/view_animation.gd")

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
	app.begin("training", "standard", "reactor", 381, "wp_pulse")
	var pilot = app.session.player
	var gun = pilot.arsenal
	await ticks(12)
	check(pilot.presentation.current and pilot.presentation != pilot.head, "Caméra de rendu distincte du repère balistique")
	pilot.look_input(Vector2(17, -6))
	await process_frame
	await process_frame
	check(pilot.presentation.global_basis.z.is_equal_approx(pilot.head.global_basis.z), "Souris appliquée sans amortir la direction du tir")
	var reserve: int = gun.reserves[0]
	gun.magazines[0] -= 6
	gun.cycle()
	await ticks(24)
	check(gun.animator.state == ViewMotion.Pose.RELOAD_CELL and gun.cell.position.y < -0.13,
		"Le rechargement manipule réellement la cellule")
	gun.select(1)
	await ticks(25)
	check(gun.magazines[0] == gun.capacity(0) - 6 and gun.reserves[0] == reserve, "Annulation sans transfert de munitions")
	for i in 24:
		gun.select(i % 8)
		await ticks(1)
	await ticks(28)
	var visible := 0
	for parts in gun.models.values():
		visible += int(parts[0].visible)
	check(visible == 1 and gun.active == gun.visual_index and gun.models.size() == 8,
		"Vingt-quatre changements rapides, un seul modèle visible")
	gun.select(3)
	await ticks(20)
	Input.action_press("fire")
	await ticks(19)
	check(gun.charge > 0.15, "Charge Nova pendant pression")
	gun.select(4)
	Input.action_release("fire")
	await ticks(24)
	check(gun.charge == 0.0 and gun.active == 4, "Charge annulée au changement")
	Input.action_press("ads")
	await ticks(24)
	gun.wheel(1)
	await ticks(23)
	check(gun.scope > 0.96 and gun.magnification() == 4.0 and pilot.presentation.fov < 28.0,
		"Rail en visée ×4 et FOV amorti")
	Input.action_release("ads")
	await ticks(24)
	check(gun.scope < 0.04 and gun.view.visible, "Retour de lunette et de l’arme")
	Input.action_press("crouch")
	await ticks(18)
	var roof := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 0.23, 4)
	collision.shape = shape
	roof.position = pilot.position + Vector3.UP * 1.42
	roof.add_child(collision)
	app.session.add_child(roof)
	Input.action_release("crouch")
	await ticks(16)
	check(pilot.low_profile and pilot.height < 1.25, "Le plafond empêche le déploiement de la capsule")
	roof.queue_free()
	await ticks(25)
	check(absf(pilot.height - pilot.STAND) < 0.01 and pilot.presentation.eye_height > 1.55,
		"Redressement progressif après sortie du plafond")
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
