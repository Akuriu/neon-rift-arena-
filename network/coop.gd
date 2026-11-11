extends Node

signal changed
signal notice(message: String)
signal ended(message: String)

const Catalog := preload("res://game/catalog.gd")
const Arms := preload("res://game/weapons/catalog.gd")
const Profile := preload("res://services/profile.gd")
const Director := preload("res://game/wave_director.gd")
const Replication := preload("res://network/replication.gd")
const Inputs := preload("res://game/player.gd")
const Hazard := preload("res://game/hazard.gd")
const PROTOCOL := 4
const PORT := 24562
const MODES := ["survival", "short", "endless"]
const SHOP_TIME := 55.0
const CHUNK_BYTES := 1120

var app: Node
var peer: ENetMultiplayerPeer
var hosting := false
var dedicated := false
var roster := {}
var handshakes := {}
var commands := {}
var tokens := {}
var returning := {}
var reconnect_token := ""
var endpoint := ""
var match_id := ""
var pending_round := []
var pending_result := {}
var room := {"map": "reactor", "mode": "survival", "difficulty": "standard", "seed": 0}
var stage: Node3D
var status := "Hébergez une partie ou entrez l’adresse de l’hôte."
var listening_port := PORT
var capacity := 4
var password_hash := ""
var connect_left := 0.0
var snapshot_left := 0.0
var input_left := 0.0
var sequence := 0
var received_sequence := 0
var action_id := 0
var previous_phase := -1
var previous_wave := 0
var replicas := {}
var shop_left := 0.0
var effects_left := 0
var packet_peak := 0
var snapshot_bytes := 0
var snapshot_count := 0
var incoming_step := 0
var incoming := {}
var quit_due := 0.0
var client_protocol := PROTOCOL

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if multiplayer is SceneMultiplayer:
		multiplayer.server_relay = false
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connect_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)

func local_id() -> int:
	return multiplayer.get_unique_id() if peer != null else 1

func active() -> bool:
	return peer != null

func in_match() -> bool:
	return is_instance_valid(stage)

func _identity() -> Dictionary:
	var saved: Dictionary = Prefs.profile.data
	return {"name": Profile.safe_name(saved.name), "ready": false, "gear": {
		"slots": saved.slots.duplicate(), "gadget": saved.gadget, "module": saved.module,
		"skin": saved.skin, "reserve": Prefs.profile.owns("perk_reserve")}}

func host(port: int, limit := 4, passcode := "", headless := false) -> bool:
	stop()
	if port < 1024 or port > 65535 or limit < 2 or limit > 4:
		return _problem("Port entre 1024 et 65535 et capacité de 2 à 4 requis.")
	var connection := ENetMultiplayerPeer.new()
	var error := connection.create_server(port, limit if headless else limit - 1, 2)
	if error != OK:
		return _problem("Impossible d’ouvrir le port UDP %d. Essayez un autre port." % port)
	peer = connection
	multiplayer.multiplayer_peer = peer
	hosting = true
	dedicated = headless
	capacity = limit
	listening_port = port
	password_hash = "" if passcode.is_empty() else passcode.left(32).sha256_text()
	if not dedicated:
		roster[1] = _identity()
		roster[1].ready = true
		roster[1].seat = 0
	var addresses := Array(IP.get_local_addresses()).filter(func(ip: String) -> bool:
		return ip.contains(".") and not ip.begins_with("127.") and not ip.begins_with("169.254."))
	var local_ip: String = addresses[0] if not addresses.is_empty() else "127.0.0.1"
	status = "Salon ouvert · %s · UDP %d" % [local_ip, port]
	changed.emit()
	return true

func join(address: String, port: int, passcode := "", version := PROTOCOL) -> bool:
	stop()
	var target := address.strip_edges()
	if target == "localhost":
		target = "127.0.0.1"
	if not target.is_valid_ip_address() or port < 1024 or port > 65535:
		return _problem("Adresse IP ou port UDP invalide.")
	var requested := "%s|%d" % [target, port]
	if endpoint != requested:
		endpoint = requested
		reconnect_token = ""
	var connection := ENetMultiplayerPeer.new()
	var error := connection.create_client(target, port, 2)
	if error != OK:
		return _problem("Impossible de créer la connexion UDP.")
	peer = connection
	multiplayer.multiplayer_peer = peer
	listening_port = port
	password_hash = "" if passcode.is_empty() else passcode.left(32).sha256_text()
	client_protocol = version
	connect_left = 9.0
	status = "Connexion au salon…"
	changed.emit()
	return true

func configure(map: String, mode: String, difficulty: String) -> void:
	if not hosting or not match_id.is_empty() or not Catalog.MAPS.has(map) or mode not in MODES or difficulty not in Prefs.DIFFICULTIES:
		return
	room = {"map": map, "mode": mode, "difficulty": difficulty, "seed": 0}
	_broadcast_room()

func can_start() -> bool:
	if not hosting or not match_id.is_empty() or roster.size() < 2:
		return false
	for entry in roster.values():
		if not entry.ready:
			return false
	return true

func start_match() -> void:
	if not can_start():
		return
	match_id = Crypto.new().generate_random_bytes(12).hex_encode()
	room.seed = randi()
	previous_phase = -1
	previous_wave = 0
	sequence = 0
	var initial := [Director.Phase.PREP, 1, 0, 10 if room.mode == "short" else (0 if room.mode == "endless" else 20), {}, false, 0.0, []]
	for id in roster:
		if int(id) != 1:
			receive_launch.rpc_id(id, match_id, room, roster, initial)
	app.launch_coop()
	if dedicated:
		print("MATCH started with ", roster.size(), " players")

func stop() -> void:
	if peer != null:
		if hosting:
			for id in roster:
				if int(id) != 1:
					peer.disconnect_peer(id)
		elif peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			peer.disconnect_peer(1)
		peer.close()
		multiplayer.multiplayer_peer = null
		peer = null
	hosting = false
	dedicated = false
	stage = null
	roster.clear()
	handshakes.clear()
	commands.clear()
	tokens.clear()
	returning.clear()
	replicas.clear()
	match_id = ""
	pending_round = []
	pending_result = {}
	connect_left = 0.0
	quit_due = 0.0
	sequence = 0
	received_sequence = 0
	incoming_step = 0
	incoming.clear()
	action_id = 0
	shop_left = 0.0

func _problem(message: String) -> bool:
	status = message
	changed.emit()
	return false

func _connected() -> void:
	var info := _identity()
	register.rpc_id(1, client_protocol, info.name, info.gear, password_hash, reconnect_token)

func _connect_failed() -> void:
	_disconnect("Connexion impossible. Vérifiez l’adresse et le port UDP.")

func _server_disconnected() -> void:
	if peer != null and not hosting and quit_due == 0.0:
		_disconnect("L’hôte a fermé la session.")

func _disconnect(message: String) -> void:
	stop()
	status = message
	ended.emit(message)
	changed.emit()

func _peer_connected(id: int) -> void:
	if hosting:
		handshakes[id] = 5.5

func _peer_disconnected(id: int) -> void:
	if not hosting:
		return
	handshakes.erase(id)
	commands.erase(id)
	if roster.has(id):
		var token: String = tokens.get(id, "")
		tokens.erase(id)
		if not token.is_empty() and in_match() and stage.pilots.has(id):
			if returning.size() >= 8:
				returning.erase(returning.keys()[0])
			returning[token] = {"entry": roster[id], "pilot": stage.pilot_checkpoint(id),
				"until": stage.director.wave + 2, "expires": Time.get_ticks_msec() + 120000}
		roster.erase(id)
		if in_match():
			stage.remove_pilot(id)
		if dedicated and roster.is_empty():
			_reset_empty_server.call_deferred()
		else:
			_broadcast_room.call_deferred()

func _reset_empty_server() -> void:
	if not hosting or not dedicated or not roster.is_empty():
		return
	app._drop_session()
	match_id = ""
	returning.clear()
	commands.clear()
	room.seed = 0
	print("COOP dedicated ready")

func _reject(id: int, reason: String) -> void:
	receive_reject.rpc_id(id, reason)
	handshakes[id] = 0.40

@rpc("authority", "call_remote", "reliable")
func receive_reject(reason: String) -> void:
	status = reason
	quit_due = 0.12

@rpc("any_peer", "call_remote", "reliable")
func register(version: int, pilot_name: String, gear: Dictionary, passcode: String, resume: String) -> void:
	if not hosting:
		return
	var id := multiplayer.get_remote_sender_id()
	if not handshakes.has(id) or roster.has(id) or gear.size() > 8 or pilot_name.length() > 50 or passcode.length() > 64 or resume.length() > 32:
		return
	if version != PROTOCOL:
		_reject(id, "Version incompatible. Utilisez NEON RIFT 3.0.")
		return
	if passcode != password_hash:
		_reject(id, "Code du salon incorrect.")
		return
	if roster.size() >= capacity:
		_reject(id, "Salon complet.")
		return
	if not match_id.is_empty() and (not in_match() or stage.director.phase != Director.Phase.UPGRADE):
		_reject(id, "Partie en cours. Rejoignez pendant l’intermission.")
		return
	handshakes.erase(id)
	var seat := _free_seat()
	roster[id] = {"name": Profile.safe_name(pilot_name), "gear": _gear(gear), "ready": false, "seat": seat}
	var checkpoint: Dictionary = returning.get(resume, {})
	returning.erase(resume)
	var token := Crypto.new().generate_random_bytes(16).hex_encode()
	tokens[id] = token
	remember_token.rpc_id(id, token)
	if in_match():
		var restore: bool = not checkpoint.is_empty() and stage.director.wave <= checkpoint.until and Time.get_ticks_msec() <= checkpoint.expires
		if restore:
			roster[id] = checkpoint.entry
			roster[id].ready = false
			roster[id].seat = seat
		var pilot = stage.add_pilot(id, roster[id], false)
		if restore:
			stage.restore_pilot(pilot, checkpoint.pilot)
		receive_launch.rpc_id(id, match_id, room, roster, _round_data(id))
	_broadcast_room()

func _free_seat() -> int:
	var seats := [0, 1, 2, 3]
	for member in roster.values():
		seats.erase(member.seat)
	return seats[0]

@rpc("authority", "call_remote", "reliable")
func remember_token(value: String) -> void:
	if value.length() == 32 and value.is_valid_hex_number():
		reconnect_token = value

func _gear(raw: Dictionary) -> Dictionary:
	var valid: Array[String] = []
	for item in Arms.WEAPONS:
		valid.append(item.id)
	var gadget: Variant = raw.get("gadget")
	var module: Variant = raw.get("module")
	var skin: Variant = raw.get("skin")
	return {"slots": Arms.normalize_slots(raw.get("slots"), valid),
		"gadget": gadget if gadget is String and gadget in ["gd_dash", "gd_aegis"] else "gd_dash",
		"module": module if module is String and module in ["mod_cycle", "mod_rack"] else "",
		"skin": skin if skin is String and skin in ["skin_copper", "skin_glacier", "skin_ash", "skin_aurora"] else "",
		"reserve": raw.get("reserve", false) is bool and bool(raw.get("reserve", false))}

func _broadcast_room() -> void:
	if not hosting:
		return
	for id in multiplayer.get_peers():
		if roster.has(id) and peer.get_peer(id).get_state() == ENetPacketPeer.STATE_CONNECTED:
			receive_room.rpc_id(id, roster, room)
	changed.emit()

@rpc("authority", "call_remote", "reliable")
func receive_room(members: Dictionary, options: Dictionary) -> void:
	roster = members
	room = options
	connect_left = 0.0
	status = "Salon rejoint. Indiquez quand vous êtes prêt."
	if in_match():
		for id in stage.pilots.keys():
			if not roster.has(id):
				stage.remove_pilot(id)
		for id in roster:
			if not stage.pilots.has(id):
				stage.add_pilot(int(id), roster[id], false)
	changed.emit()

@rpc("authority", "call_remote", "reliable")
func receive_launch(id: String, options: Dictionary, members: Dictionary, initial: Array) -> void:
	if id.is_empty() or not match_id.is_empty():
		return
	match_id = id
	room = options
	roster = members
	replicas.clear()
	connect_left = 0.0
	received_sequence = 0
	pending_round = initial
	app.launch_coop()

func attach(session: Node3D) -> void:
	stage = session
	replicas.clear()
	previous_phase = -1
	snapshot_left = 0.0
	input_left = 0.0
	packet_peak = 0
	snapshot_bytes = 0
	snapshot_count = 0
	incoming_step = 0
	incoming.clear()
	if hosting:
		stage.director.finished.connect(_finish_round, CONNECT_DEFERRED)

func complete_launch() -> void:
	# These reliable updates can arrive before the arena exists. A round replaces the
	# whole preceding round state, and the result follows it once the UI is connected.
	var round_state := pending_round
	var result := pending_result
	pending_round = []
	pending_result = {}
	if not round_state.is_empty():
		receive_round(match_id, round_state)
	if not result.is_empty():
		receive_result(match_id, result)

func ready_up() -> void:
	if hosting:
		_ready_for(1, match_id, stage.director.wave if in_match() else 0)
	elif peer != null:
		request_pilot_ready.rpc_id(1, match_id, stage.director.wave if in_match() else 0)

@rpc("any_peer", "call_remote", "reliable")
func request_pilot_ready(id: String, wave: int) -> void:
	_ready_for(multiplayer.get_remote_sender_id(), id, wave)

func _ready_for(sender: int, id: String, wave: int) -> void:
	if not hosting or not roster.has(sender) or id != match_id:
		return
	if not in_match() and not match_id.is_empty():
		return
	if in_match() and (stage.director.phase != Director.Phase.UPGRADE or wave != stage.director.wave):
		return
	roster[sender].ready = not roster[sender].ready if not in_match() else true
	_broadcast_room()
	if dedicated and not in_match() and can_start():
		start_match()

func ready_count() -> int:
	var count := 0
	for item in roster.values():
		count += int(item.ready)
	return count

func field_action(action: String, offer: String, option: int) -> void:
	if not in_match():
		return
	action_id += 1
	var wave: int = stage.director.wave
	if hosting:
		_field_for(1, match_id, wave, action_id, action, offer, option)
	elif peer != null:
		request_field.rpc_id(1, match_id, wave, action_id, action, offer, option)

@rpc("any_peer", "call_remote", "reliable")
func request_field(id: String, wave: int, nonce: int, action: String, offer: String, option: int) -> void:
	_field_for(multiplayer.get_remote_sender_id(), id, wave, nonce, action, offer, option)

func _field_for(sender: int, id: String, wave: int, nonce: int, action: String, offer: String, option: int) -> void:
	if not hosting or not in_match() or id != match_id or wave != stage.director.wave \
			or stage.director.phase != Director.Phase.UPGRADE or not stage.pilots.has(sender) \
			or nonce < 0 or nonce > 10000000 or offer.length() > 24 or action.length() > 12:
		return
	var pilot: CharacterBody3D = stage.pilots[sender]
	var message := "Action inconnue."
	match action:
		"buy":
			var result: Dictionary = stage.buy_offer(offer, pilot, nonce)
			message = result.message
		"module":
			message = "Module installé." if stage.choose_upgrade(option, pilot) else "Module indisponible."
	if sender == 1:
		notice.emit(message)
	else:
		receive_receipt.rpc_id(sender, match_id, message, _shop_state(sender), sequence)

@rpc("authority", "call_remote", "reliable")
func receive_receipt(id: String, message: String, state: Array, frame: int) -> void:
	if id != match_id or not in_match():
		return
	received_sequence = maxi(received_sequence, frame)
	_apply_shop(state)
	notice.emit(message)

func _physics_process(delta: float) -> void:
	if peer == null:
		return
	if quit_due > 0.0:
		quit_due -= delta
		if quit_due <= 0.0:
			_disconnect(status)
			return
	if connect_left > 0.0:
		connect_left -= delta
		if connect_left <= 0.0:
			_disconnect("Délai de connexion dépassé. Vérifiez l’hôte et le pare-feu.")
			return
	if hosting:
		for id in handshakes.keys():
			handshakes[id] -= delta
			if handshakes[id] <= 0.0:
				handshakes.erase(id)
				peer.disconnect_peer(id)
	if not in_match():
		return
	if hosting:
		_host_tick(delta)
	else:
		_client_tick(delta)

func _host_tick(delta: float) -> void:
	var director = stage.director
	for id in commands.keys():
		var state: Dictionary = commands[id]
		state.age += delta
		if state.age > 0.6 and stage.pilots.has(id):
			var pilot = stage.pilots[id]
			pilot.net_buttons = 0
			pilot.net_move = Vector2.ZERO
	if previous_phase != director.phase or previous_wave != director.wave:
		previous_phase = director.phase
		previous_wave = director.wave
		if director.phase == Director.Phase.UPGRADE:
			shop_left = SHOP_TIME
			for data in roster.values():
				data.ready = false
			_broadcast_room()
		for id in roster:
			if int(id) != 1:
				receive_round.rpc_id(id, match_id, _round_data(int(id)))
	if director.phase == Director.Phase.UPGRADE:
		shop_left = maxf(0.0, shop_left - delta)
		if ready_count() == roster.size() or shop_left <= 0.0:
			stage.ready_next_wave()
	snapshot_left -= delta
	if snapshot_left <= 0.0:
		snapshot_left = 0.063
		effects_left = 18
		sequence += 1
		_send_frame()

func _send_frame() -> void:
	var payload := var_to_bytes(Replication.snapshot(stage))
	var packed := payload.compress(FileAccess.COMPRESSION_DEFLATE)
	var parts := ceili(float(packed.size()) / CHUNK_BYTES)
	if Prefs.values.telemetry:
		packet_peak = maxi(packet_peak, packed.size())
		snapshot_bytes += packed.size()
		snapshot_count += 1
	for index in parts:
		var chunk := packed.slice(index * CHUNK_BYTES, (index + 1) * CHUNK_BYTES)
		for id in roster:
			if int(id) != 1:
				receive_frame.rpc_id(id, match_id, sequence, chunk, payload.size(), shop_left, index, parts)

func _client_tick(delta: float) -> void:
	input_left -= delta
	if input_left > 0.0 or not roster.has(local_id()) or stage.director.phase == Director.Phase.DONE:
		return
	input_left = 0.032
	var pilot = stage.player
	var flags := 0
	for key in Inputs.INPUT_BITS:
		if pilot.down(key):
			flags |= Inputs.INPUT_BITS[key]
	sequence += 1
	send_input.rpc_id(1, match_id, sequence, pilot.steering(), pilot.rotation.y, pilot.head.rotation.x, flags, pilot.arsenal.active)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func send_input(id: String, step: int, move: Vector2, yaw: float, pitch: float, buttons: int, gun: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not hosting or not in_match() or id != match_id or not stage.pilots.has(sender):
		return
	var pilot = stage.pilots[sender]
	if not pilot.alive or not move.is_finite() or move.length_squared() > 1.03 or not is_finite(yaw) \
			or not is_finite(pitch) or absf(yaw) > 1000000.0 or absf(pitch) > 1.58 \
			or buttons < 0 or buttons > 511 or not pilot.arsenal.rack.has(gun):
		return
	var now := Time.get_ticks_msec()
	var command: Dictionary = commands.get(sender, {"stamp": -1000, "step": 0, "age": 0.0})
	if step <= command.step or step > command.step + 8192 or now - int(command.stamp) < 12:
		return
	commands[sender] = {"stamp": now, "step": step, "age": 0.0}
	pilot.accept_input(move, yaw, pitch, buttons, gun)

func _round_data(id: int) -> Array:
	var director = stage.director
	var state := _shop_state(id) if director.phase in [Director.Phase.UPGRADE, Director.Phase.MILESTONE] else []
	return [director.phase, director.wave, director.cleared, director.total_waves, director.current_wave,
		director.milestone_reached, shop_left, state]

func _shop_state(id: int) -> Array:
	var pilot = stage.pilots[id]
	var bank = stage.wallets[id]
	return [bank.balance, bank.levels, pilot.module_selected, pilot.modules, pilot.shield_max,
		stage.director.score, stage.director.kills, pilot.stats.shots, pilot.stats.hits]

func _apply_shop(state: Array) -> void:
	if state.size() != 9:
		return
	stage.wallet.balance = state[0]
	stage.wallet.levels = state[1]
	stage.module_selected = state[2]
	stage.player.module_selected = state[2]
	stage.player.modules.assign(state[3])
	stage.player.shield_max = state[4]
	stage.director.score = state[5]
	stage.director.kills = state[6]
	stage.shots = state[7]
	stage.hits = state[8]

@rpc("authority", "call_remote", "reliable")
func receive_round(id: String, value: Array) -> void:
	if id.is_empty() or id != match_id or value.size() != 8:
		return
	if not in_match():
		pending_round = value
		return
	var director = stage.director
	var changed_phase: bool = director.phase != int(value[0]) or director.wave != int(value[1])
	director.phase = value[0]
	director.wave = value[1]
	director.cleared = value[2]
	director.total_waves = value[3]
	director.current_wave = value[4]
	director.milestone_reached = value[5]
	shop_left = value[6]
	_apply_shop(value[7])
	if changed_phase:
		director.notice = 2.0
		if director.phase == Director.Phase.MILESTONE:
			director.campaign_complete.emit()
		director.changed.emit()

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_frame(id: String, step: int, chunk: PackedByteArray, raw_size: int, countdown: float, index: int, parts: int) -> void:
	if id != match_id or not in_match() or step <= received_sequence or step < incoming_step \
			or raw_size < 1 or raw_size > 16000 or parts < 1 or parts > 4 or index < 0 or index >= parts \
			or chunk.size() > CHUNK_BYTES:
		return
	if step != incoming_step:
		incoming_step = step
		incoming.clear()
	incoming[index] = chunk
	if incoming.size() != parts:
		return
	var packed := PackedByteArray()
	for fragment in parts:
		packed.append_array(incoming[fragment])
	incoming.clear()
	var value: Variant = bytes_to_var(packed.decompress(raw_size, FileAccess.COMPRESSION_DEFLATE))
	if not Replication.valid(value):
		return
	if value[0][0] != stage.director.wave or value[0][10] != stage.director.phase:
		return
	received_sequence = step
	shop_left = countdown
	Replication.apply(stage, value, replicas)

func _finish_round(victory: bool) -> void:
	if not hosting or not in_match():
		return
	for id in roster:
		if int(id) != 1 and stage.pilots.has(id):
			receive_result.rpc_id(id, match_id, stage.result_data(victory, stage.pilots[id]))
	if dedicated:
		print("MATCH complete wave=", stage.director.cleared, " score=", stage.director.score)

@rpc("authority", "call_remote", "reliable")
func receive_result(id: String, result: Dictionary) -> void:
	if id.is_empty() or id != match_id:
		return
	if not in_match():
		pending_result = result
		return
	if not stage.result_override.is_empty():
		return
	var report := {}
	for key in ["score", "wave", "kills", "seconds", "bosses", "shots", "hits", "credits", "spent"]:
		report[key] = Profile.number(result.get(key))
	report.hits = mini(report.hits, report.shots)
	report.victory = result.get("victory") == true
	report.participated = result.get("participated") == true
	report.mastery = result.mastery if result.get("mastery") is Dictionary else {}
	report.accuracy = roundi(100.0 * report.hits / maxi(1, report.shots))
	stage.result_override = report
	stage.director.score = report.score
	stage.director.cleared = report.wave
	stage.director.kills = report.kills
	stage.director.elapsed = report.seconds
	stage.director.phase = Director.Phase.DONE
	stage.director.finished.emit(report.victory)

func feedback(id: int, damage: float, weak: bool) -> void:
	if hosting:
		receive_hit.rpc_id(id, match_id, damage, weak)

@rpc("authority", "call_remote", "unreliable", 2)
func receive_hit(id: String, damage: float, weak: bool) -> void:
	if id == match_id and in_match():
		stage.hit_feedback(damage, weak)

func visual(kind: String, at: Vector3, end: Vector3, tint: Color, width: float, time: float) -> void:
	if not hosting or (effects_left <= 0 and kind != "zone"):
		return
	effects_left -= 1
	for id in roster:
		if int(id) != 1:
			receive_visual.rpc_id(id, match_id, kind, at, end, tint, width, time)

@rpc("authority", "call_remote", "unreliable", 2)
func receive_visual(id: String, kind: String, at: Vector3, end: Vector3, tint: Color, width: float, time: float) -> void:
	if id != match_id or not in_match():
		return
	if kind == "beam":
		stage.effects.beam(at, end, tint, width, time)
	elif kind == "zone" and stage.hazards.get_child_count() < 8:
		var marker := Hazard.new()
		marker.position = at
		marker.duration = time
		marker.radius = width
		marker.tint = tint
		marker.session = stage
		marker.visual_only = true
		stage.hazards.add_child(marker)

func shot(shooter: int, cue: String, at: Vector3) -> void:
	for id in roster:
		if int(id) != 1:
			receive_shot.rpc_id(id, match_id, shooter, cue, at)

@rpc("authority", "call_remote", "unreliable", 2)
func receive_shot(id: String, shooter: int, cue: String, at: Vector3) -> void:
	if id != match_id or not in_match() or not stage.pilots.has(shooter):
		return
	var pilot = stage.pilots[shooter]
	if pilot == stage.player:
		pilot.arsenal.shot_kick = 1.0
		Sounds.play(cue)
	else:
		pilot.avatar.kick()
		Sounds.play(cue, at)
