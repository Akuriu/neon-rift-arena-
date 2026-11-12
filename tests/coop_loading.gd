extends SceneTree

var failures := 0
var host: Node
var client: Node

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("NEON_QA_ISOLATED") != "1":
		quit(2)
		return
	var isolated := SubViewport.new()
	isolated.name = "HostViewport"
	isolated.size = Vector2i(1280, 720)
	isolated.own_world_3d = true
	isolated.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(isolated)
	set_multiplayer(MultiplayerAPI.create_default_interface(), isolated.get_path())
	var scene := load("res://scenes/App.tscn") as PackedScene
	host = scene.instantiate()
	isolated.add_child(host)
	client = scene.instantiate()
	root.add_child(client)
	client.staged_loading = true
	await check_buffered_finish()
	await check_disconnect()
	await check_cancel_assembly()
	client.coop.stop()
	host.coop.stop()
	root.get_node("Sounds").stop_all()
	client.queue_free()
	isolated.queue_free()
	await process_frame
	await create_timer(0.28, true, false, true).timeout
	quit(1 if failures > 0 else 0)

func connect_room() -> bool:
	host.leave_coop()
	client.leave_coop()
	var probe := PacketPeerUDP.new()
	if not check(probe.bind(0, "127.0.0.1") == OK, "Port de test disponible"):
		return false
	var port := probe.get_local_port()
	probe.close()
	if not check(host.coop.host(port), "Salon ENet ouvert"):
		return false
	host.coop.configure("grove", "short", "discovery")
	client.coop.join("127.0.0.1", port)
	if not await until(func(): return client.coop.roster.has(client.coop.local_id()), "Pilote inscrit au salon"):
		return false
	client.coop.ready_up()
	return await until(func(): return host.coop.can_start(), "Les deux pilotes sont prêts")

func check_buffered_finish() -> void:
	if not await connect_room():
		return
	host.coop.start_match()
	var director: Node = host.session.director
	director.open_wave()
	host.coop._host_tick(0.0)
	director.finish(true)
	if not await until(func(): return not client.coop.pending_result.is_empty(), "Le résultat fiable arrive pendant le chargement"):
		return
	check(client.screen == "loading" and not client.coop.in_match()
		and client.coop.pending_round.size() == 8 and not client.coop.pending_round[4].is_empty(),
		"L’état de vague le plus récent attend avec le résultat avant le premier HUD")
	var directory := OS.get_environment("RIFLE_QA_CAPTURE_DIR")
	if DisplayServer.get_name() != "headless" and not directory.is_empty():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(directory.path_join("26-coop-chargement.png")) == OK,
			"Capture moteur du chargement coop")
	if not await until(func(): return client.screen == "result", "Le bilan s’ouvre une fois l’arène chargée"):
		return
	check(client.session.result_override.victory and not client.session.director.current_wave.is_empty()
		and client.coop.pending_round.is_empty() and client.coop.pending_result.is_empty(),
		"La vague et le bilan de l’hôte sont appliqués une seule fois")

func check_disconnect() -> void:
	if not await connect_room():
		return
	host.coop.start_match()
	if not await until(func(): return client.screen == "loading" and not client.coop.in_match(),
			"Le client attend sous le masque avant d’attacher la partie"):
		return
	host.leave_coop()
	if await until(func(): return not client.coop.active(), "Fermeture du salon pendant le chargement reçue"):
		for frame in 5:
			await process_frame
		check(client.screen == "lobby" and client.session == null and client.map_loading == null
			and client.coop.pending_round.is_empty() and not paused,
			"La fermeture révoque la construction et restitue le salon")

func check_cancel_assembly() -> void:
	if not await connect_room():
		return
	host.coop.start_match()
	var still_building := func() -> bool:
		return client.screen == "loading" and is_instance_valid(client.session) \
			and client.session.arena.pending_surface_count() > 0
	if not await until(still_building, "Le décor coop est assemblé sur plusieurs images"):
		return
	client._back()
	if await until(func(): return host.coop.roster.size() == 1, "L’hôte retire le pilote qui annule"):
		check(client.screen == "lobby" and client.session == null and client.map_loading == null
			and client.coop.pending_round.is_empty() and not paused,
			"Annuler libère l’arène partielle et réactive le salon")

func until(condition: Callable, message: String) -> bool:
	var end := Time.get_ticks_msec() + 5000
	while not condition.call() and Time.get_ticks_msec() < end:
		await process_frame
	return check(condition.call(), message)

func check(ok: bool, message: String) -> bool:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		failures += 1
	return ok
