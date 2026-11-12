extends SceneTree

const APP := "res://scenes/App.tscn"

var boot_script: GDScript

var failed := 0
var states: Array[int] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("NEON_QA_ISOLATED") != "1":
		printerr("Ce test exige un profil isolé.")
		quit(2)
		return
	boot_script = load("res://ui/boot/boot_flow.gd")
	var boot = make_boot()
	check(boot.state == boot_script.State.BOOT and boot.splash.meter.fraction < 0.0 \
		and not boot.splash.retry_button.visible, "Première composition sans pourcentage simulé")
	var first := await until_reveal(boot)
	check(first != null and first.screen == "menu" and first.view.is_visible_in_tree(),
		"La scène App est interactive au moment de la révélation")
	check(states == [boot_script.State.PROFILE_CHECK, boot_script.State.RESOURCE_LOADING, boot_script.State.SCENE_READY, boot_script.State.REVEAL_MENU],
		"États de démarrage dans l’ordre")
	if first == null:
		quit(1)
		return
	check(await until_removed(boot), "Le masque libère sa couche après révélation")
	check(first.coop.get_path() == NodePath("/root/NeonRift/Coop"), "Le chemin ENet de l’application est conservé")
	first.queue_free()
	await process_frame

	states.clear()
	boot = make_boot("res://scenes/Manquante.tscn")
	var deadline := Time.get_ticks_msec() + 5000
	while boot.state != boot_script.State.ERROR and Time.get_ticks_msec() < deadline:
		await process_frame
	check(boot.state == boot_script.State.ERROR and boot.splash.retry_button.visible and boot.splash.quit_button.visible,
		"Une scène absente donne accès à Réessayer et Quitter")
	check(boot.splash.count.text.is_empty(), "Une erreur n’affiche aucun faux 100 %")
	boot.app_path = APP
	boot.splash.retry_button.pressed.emit()
	check(boot.state == boot_script.State.RETRY, "Le bouton Réessayer relance la demande")
	var second := await until_reveal(boot)
	check(second != null and second.screen == "menu", "La reprise atteint un menu jouable")
	if second != null:
		check(await until_removed(boot), "La reprise ne laisse pas de couche de chargement")
		root.get_node("Sounds").stop_all()
		second.queue_free()
		await process_frame
	quit(1 if failed else 0)

func make_boot(path := APP) -> Node:
	var boot := (load("res://scenes/Bootstrap.tscn") as PackedScene).instantiate()
	boot.app_path = path
	boot.state_changed.connect(func(state: int): states.append(state))
	root.add_child(boot)
	current_scene = boot
	return boot

func until_reveal(boot) -> Node:
	var last := -1.0
	var monotone := true
	var deadline := Time.get_ticks_msec() + 12000
	while is_instance_valid(boot) and boot.state != boot_script.State.REVEAL_MENU \
		and boot.state != boot_script.State.ERROR and Time.get_ticks_msec() < deadline:
		if boot.state == boot_script.State.RESOURCE_LOADING:
			monotone = monotone and boot.loader.progress >= last and boot.splash.meter.fraction < 1.0
			last = boot.loader.progress
		await process_frame
	check(monotone, "La progression mesurée reste monotone et sous 100 % avant le menu")
	return current_scene if is_instance_valid(current_scene) and current_scene != boot else null

func until_removed(boot) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while is_instance_valid(boot) and Time.get_ticks_msec() < deadline:
		await process_frame
	return not is_instance_valid(boot)

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failed += 1
