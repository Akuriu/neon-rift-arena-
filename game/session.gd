extends Node3D

const Arena := preload("res://game/arena.gd")
const Skyline := preload("res://game/skyline.gd")
const Cryo := preload("res://game/maps/cryo.gd")
const Frontiers := preload("res://game/maps/frontiers.gd")
const Pilot := preload("res://scenes/Pilot.tscn")
const Drone := preload("res://scenes/Drone.tscn")
const Director := preload("res://game/wave_director.gd")
const Effects := preload("res://game/effects.gd")
const Projectile := preload("res://game/projectile.gd")
const Pickup := preload("res://game/pickup.gd")
const Hazard := preload("res://game/hazard.gd")
const Catalog := preload("res://game/catalog.gd")
const Wallet := preload("res://game/economy/field_wallet.gd")
const Match := preload("res://game/modes/classic.gd")
const GunGame := preload("res://game/modes/gun_game.gd")
const Parkour := preload("res://game/modes/parkour.gd")
const ParkourYard := preload("res://game/maps/parkour_yard.gd")
const Courses := preload("res://game/modes/parkour_routes.gd")
const Workshop := preload("res://game/world/workshop.gd")
const CargoLift := preload("res://game/world/cargo_lift.gd")
const Rules := preload("res://game/modes/rules.gd")
const Generator := preload("res://game/waves/generator.gd")
signal intermission_updated

const PRACTICE := ["scout", "sentinel", "specter", "bulwark"]

var arena: Arena
var player
var net: Node
var pilots := {}
var wallets := {}
var director: Node
var classic: Match
var match_rules := {}
var effects: Effects
var projectiles: Node3D
var projectile_bin: Node3D
var test_weapon := ""
var critical := false
var pickups: Node3D
var hazards: Node3D
var units: Array[CharacterBody3D] = []
var respawn_queue: Array[Dictionary] = []
var shots := 0
var hits := 0
var last_hit := 0.0
var last_damage := 0.0
var mode := "survival"
var difficulty := "standard"
var map_id := "reactor"
var spawn_index := 0
var run_seed := -1
var run_id := ""
var random := RandomNumberGenerator.new()
var spawn_misses := 0
var wallet := Wallet.new()
var boss_kills := 0
var weapon_mastery := {}
var credited_result := {}
var result_override := {}
var module_selected := false
var buy_serial := 0
var boss: CharacterBody3D
var upgrades: Array[int] = [0, 0, 0, 0, 0, 0]
var pickup_hint := ""
var radio := ""
var radio_time := 0.0
var nearby: Node3D
var drop_serial := 0
var ray_parameters := PhysicsRayQueryParameters3D.new()
var relay_progress := 0.0
var relay_state := 0
var training_options := {"targets": "moving", "distance": 0, "time": 0}
var training_ended := false
var workshop: Workshop
var cargo_lift: CargoLift
var map_interactables: Array[Node3D] = []
var defer_arena_surfaces := false

func _ready() -> void:
	if run_seed < 0:
		run_seed = randi()
	run_id = net.match_id if is_instance_valid(net) else Crypto.new().generate_random_bytes(16).hex_encode()
	random.seed = run_seed
	if mode == "parkour":
		var yard := ParkourYard.new()
		yard.route = Courses.normalize(match_rules.get("route"))
		arena = yard
	else:
		match map_id:
			"skyline": arena = Skyline.new()
			"cryo": arena = Cryo.new()
			"bastion", "district", "grove", "station": arena = Frontiers.new(map_id)
			_: arena = Arena.new()
	arena.simulation_only = is_instance_valid(net) and net.dedicated
	arena.defer_surfaces = defer_arena_surfaces
	add_child(arena)
	effects = Effects.new()
	effects.enabled = not arena.simulation_only
	add_child(effects)
	projectiles = _group("Projectiles")
	projectile_bin = _group("ProjectilePool")
	pickups = _group("Pickups")
	hazards = _group("Hazards")
	if is_instance_valid(net):
		var local_id: int = net.local_id()
		for id in net.roster:
			add_pilot(int(id), net.roster[id], int(id) == local_id and not net.dedicated)
		player = pilots.get(local_id, pilots.values().front())
		wallet = wallets[player.peer_id]
	else:
		player = add_pilot(1, {"name": Prefs.profile.data.name, "gear": pilot_gear()}, true)
		wallet = wallets[1]
	upgrades = player.modules
	if mode == "parkour":
		director = Parkour.new()
		director.configure(self, mode, match_rules)
	elif Rules.LABELS.has(mode):
		classic = GunGame.new() if mode == "gungame" else Match.new()
		director = classic
		classic.configure(self, mode, match_rules)
	else:
		director = Director.new()
		director.configure(mode, Catalog.DIFFICULTIES[difficulty], run_seed)
		director.cap_override = 7 if Prefs.values.quality == 3 else 12
		director.player_count = pilots.size()
		director.spawn_requested.connect(_spawn)
		director.wave_opened.connect(_wave_opened)
		director.wave_secured.connect(_wave_secured)
	add_child(director)
	if is_instance_valid(net) and not net.hosting:
		director.set_physics_process(false)
	director.finished.connect(_match_finished)
	if mode == "training":
		_reset_training()
	if mode in ["training", "explore"] and map_id == "skyline" and not is_instance_valid(net):
		arena.footprints.append(CargoLift.FOOTPRINT)
		workshop = Workshop.new()
		workshop.stage = self
		add_child(workshop)
		cargo_lift = CargoLift.new()
		cargo_lift.stage = self
		add_child(cargo_lift)
		map_interactables.assign([workshop, cargo_lift])

func _group(label: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = label
	add_child(holder)
	return holder

func _physics_process(delta: float) -> void:
	last_hit = maxf(last_hit - delta, 0.0)
	radio_time = maxf(radio_time - delta, 0.0)
	if not is_instance_valid(player) or director.phase == Director.Phase.DONE:
		return
	if mode == "parkour":
		return
	if is_instance_valid(net) and not net.hosting:
		director.notice = maxf(0.0, director.notice - delta)
		_scan_pickups(false)
		return
	_scan_pickups()
	if relay_state == 1 and director.phase == Director.Phase.ACTIVE:
		_tick_relay(delta)
	if mode == "training":
		if not training_ended and training_options.time > 0 and director.elapsed >= training_options.time:
			training_ended = true
			player.round_lock = true
			player.arsenal.cancel_trigger()
			show_radio("Exercice terminé · réarmez au terminal pour recommencer", 4.0)
		for index in range(respawn_queue.size() - 1, -1, -1):
			var entry := respawn_queue[index]
			entry.left -= delta
			if entry.left <= 0.0:
				spawn_unit(entry.kind, entry.at, true)
				director.live += 1
				respawn_queue.remove_at(index)

func _match_finished(_victory: bool) -> void:
	_clear_group(projectiles)
	_clear_group(hazards)
	for pilot in pilots.values():
		pilot.round_lock = true
	for unit in units:
		unit.set_physics_process(false)

func _wave_opened(wave: int) -> void:
	sound("wave")
	var mutation: String = director.current_wave.get("mutation", "")
	arena.alert_lighting(mutation == "alert")
	if not mutation.is_empty():
		show_radio(Generator.MODIFIERS[mutation], 2.6)
	relay_state = 0
	relay_progress = 0.0
	if not is_instance_valid(net) and mode in ["survival", "short", "endless"] and wave % 4 == 3:
		relay_state = 1
		if mutation.is_empty():
			show_radio("Option · stabilisez le relais près du terminal", 3.0)

func _tick_relay(delta: float) -> void:
	var ground := arena.terminal_at - Vector3.UP
	var holding: bool = player.alive and player.position.distance_squared_to(ground) < 8.4
	if holding:
		for unit in units:
			if unit.position.distance_squared_to(ground) < 9.0:
				holding = false
				break
	relay_progress = move_toward(relay_progress, 6.0 if holding else 0.0, delta * (1.0 if holding else 0.18))
	if relay_progress >= 6.0:
		relay_state = 2
		wallet.grant(48)
		show_radio("Relais stabilisé · +48 CR", 2.7)
		sound("upgrade")
		effects.wave(ground + Vector3.UP * 0.065, Color("#b7dabc"), 2.9)

func _spawn(kind: String) -> void:
	var forced := spawn_misses >= 3
	var chosen := find_spawn(forced)
	if not chosen.is_finite():
		spawn_misses += 1
		return
	var unit := spawn_unit(kind, chosen)
	if forced:
		unit.timer = maxf(unit.timer, 1.05)
		effects.beam(chosen + Vector3.UP * 0.2, chosen + Vector3.UP * 2.8, Catalog.UNITS[kind].tint, 0.22, 0.9)
	spawn_misses = 0
	director.registered_spawn()

func find_spawn(allow_visible := false) -> Vector3:
	var team := living_pilots()
	if team.is_empty():
		return Vector3.INF
	var point = team[0]
	var eye: Vector3 = point.head.global_position
	var forward: Vector3 = -point.head.global_basis.z
	var chosen := Vector3.INF
	var best := -INF
	for at in arena.spawn_points:
		var center := at + Vector3.UP * 1.18
		var to := center - eye
		var distance := to.length()
		var unsafe := false
		for member in team:
			if member.global_position.distance_squared_to(at) < (30.25 if allow_visible else 72.25):
				unsafe = true
				break
			if not allow_visible and _spawn_in_view(at, member.head):
				unsafe = true
				break
		if unsafe:
			continue
		var dot := forward.dot(to / distance)
		var occupied := false
		for unit in units:
			if unit.global_position.distance_squared_to(at) < 6.25:
				occupied = true
				break
		if occupied:
			continue
		var value := distance - dot * 5.0 + random.randf() * 5.0
		if value > best:
			best = value
			chosen = at
	return chosen

func _spawn_in_view(at: Vector3, camera: Camera3D) -> bool:
	var eye := camera.global_position
	var area := camera.get_viewport().get_visible_rect().grow(38)
	for height in [0.57, 1.19, 2.13]:
		var point: Vector3 = at + Vector3.UP * height
		if not camera.is_position_behind(point) and area.has_point(camera.unproject_position(point)):
			if ray(eye, point, 1).is_empty():
				return true
	return false

func spawn_unit(kind: String, at: Vector3, practice := false, mirror_id := -1, slot := -1) -> CharacterBody3D:
	var unit := Drone.instantiate()
	unit.kind = kind
	unit.tuning = (director.tuning if mode == "relax" else Catalog.DIFFICULTIES[difficulty]).duplicate()
	if kind not in Catalog.BOSSES:
		var mutation: String = director.current_wave.get("mutation", "")
		if mutation == "rush" or director.current_wave.get("risk", false):
			unit.tuning.tempo *= 0.85
		if mutation == "armor":
			unit.tuning.hp *= 1.15
	unit.target = nearest_pilot(at) if slot < 0 else null
	unit.arena_slot = slot
	unit.arena_side = classic.side_for(slot) if slot >= 0 else 1
	unit.replica = mirror_id >= 0
	unit.session = self
	unit.position = at
	unit.serial = mirror_id if mirror_id >= 0 else spawn_index
	unit.training = practice
	unit.patrol_origin = at
	if mirror_id < 0:
		spawn_index += 1
	unit.eliminated.connect(_on_defeated)
	add_child(unit)
	units.append(unit)
	if slot >= 0:
		classic.invalidate_combatants()
		classic.equip_actor(unit)
	effects.sparks(at + Vector3.UP, Catalog.UNITS[kind].tint, 14, 3.2)
	if kind in Catalog.BOSSES:
		boss = unit
		show_radio("%s détecté" % Catalog.UNITS[kind].name, 3.2)
		sound("boss", at)
		Sounds.set_track("pressure")
	return unit

func _on_defeated(unit: CharacterBody3D, points: int) -> void:
	units.erase(unit)
	effects.sparks(unit.center(), unit.spec.tint, 30, 6.0)
	sound("kill", unit.center())
	if is_instance_valid(classic):
		classic.invalidate_combatants()
		classic.eliminated(unit, unit.last_attacker, unit.last_credit_slot)
		if director.phase == Director.Phase.ACTIVE and random.randf() < 0.20:
			_drop_pickup("energy", unit.position)
		return
	if mode != "training" and director.phase in [Director.Phase.ACTIVE, Director.Phase.TRIAL]:
		var major: bool = unit.kind in Catalog.BOSSES
		boss_kills += int(major)
		grant_team(110 if unit.kind == "elite" else (310 if major else clampi(points / 8, 15, 34)))
	director.defeated(points)
	if mode == "training":
		respawn_queue.append({"kind": unit.kind, "at": unit.patrol_origin, "left": 1.7})
		return
	for pilot in living_pilots():
		if pilot.modules[4] > 0:
			pilot.arsenal.refill(pilot.modules[4])
	if director.kills % 3 == 0 or unit.kind in Catalog.BOSSES:
		var kind := "repair" if director.kills % 2 == 0 or unit.kind == "elite" else "energy"
		_drop_pickup(kind, unit.global_position)

func match_spawn() -> Vector3:
	var members := classic.combatants()
	var chosen := Vector3.INF
	var weight := -INF
	for at in arena.spawn_points + arena.practice_points + [arena.start_at]:
		var distance := 2000.0
		for actor in members:
			distance = minf(distance, actor.position.distance_squared_to(at))
		if distance < 4.2:
			continue
		var visible: bool = player.alive and _spawn_in_view(at, player.head)
		var value := sqrt(distance) - (6.0 if visible else 0.0) + random.randf() * 2.5
		if value > weight:
			weight = value
			chosen = at
	return chosen

func target_for(unit: CharacterBody3D) -> CharacterBody3D:
	return classic.target_for(unit) if is_instance_valid(classic) else nearest_pilot(unit.position)

func can_damage(attacker: CharacterBody3D, victim: Object) -> bool:
	return victim is CharacterBody3D and (not is_instance_valid(classic) or classic.enemies(attacker, victim))

func record_shot(weapon: String, actor: CharacterBody3D = null) -> void:
	if not is_instance_valid(actor):
		actor = player
	actor.stats.shots += 1
	var mastery: Dictionary = actor.stats.mastery
	mastery[weapon] = mini(2500, int(mastery.get(weapon, 0)) + 1)
	if actor == player:
		shots += 1
		weapon_mastery = mastery

func pilot_gear() -> Dictionary:
	var profile: Dictionary = Prefs.profile.data
	return {"slots": profile.slots.duplicate(), "gadget": profile.gadget, "module": profile.module,
		"skin": profile.skin, "reserve": Prefs.profile.owns("perk_reserve")}

func fire_rays(origin: Vector3, directions: Array[Vector3], data: Dictionary, muzzle: Vector3, boost: float,
		actor: CharacterBody3D = null) -> void:
	if not is_instance_valid(actor):
		actor = player
	record_shot(data.id, actor)
	var emission := muzzle if ray(origin, muzzle, 1).is_empty() else origin
	var weak := false
	var total := 0.0
	for direction in directions:
		var end: Vector3 = origin + direction * data.range
		var result := ray(origin, end, 1 | 4)
		if not result.is_empty():
			end = result.position
			var damage: float = 0.0
			if result.collider.has_method("take_hit") and can_damage(actor, result.collider):
				var falloff := 1.0 if directions.size() == 1 else clampf(1.22 - origin.distance_to(end) * 0.049, 0.22, 1.0)
				var unit = result.collider
				var focus: bool = data.mode in ["rail", "lance"] and absf(end.y - unit.center().y - 0.20) < 0.28
				damage = unit.take_hit(data.damage * falloff * boost * (1.22 if focus else 1.0), end, direction, actor)
				weak = weak or (focus and damage > 0.0)
			total += damage
			effects.impact(end, result.normal, data.tint, map_id, damage > 0.0)
		var from := emission if origin.distance_squared_to(end) > origin.distance_squared_to(emission) else origin
		var streak := from.move_toward(end, 7.4 if data.mode in ["rail", "lance"] else 3.5)
		var beam_width := 0.014 if directions.size() == 1 else 0.008
		var tracer := Color("#dfc598")
		effects.beam(from, streak, tracer, beam_width, 0.045)
		if is_instance_valid(net):
			net.visual("beam", from, streak, tracer, beam_width, 0.045)
	if Prefs.values.flashes > 0.05:
		effects.sparks(emission, data.tint, roundi(7.0 * Prefs.values.flashes), 2.2)
	_confirm_hit(total, weak, actor)

func _confirm_hit(total: float, weak := false, actor: CharacterBody3D = null) -> void:
	if total <= 0.0 or (is_instance_valid(net) and not is_instance_valid(actor)):
		return
	if not is_instance_valid(actor):
		actor = player
	actor.stats.hits += 1
	if actor == player:
		hits += 1
		hit_feedback(total, weak)
	elif is_instance_valid(net):
		net.feedback(actor.peer_id, total, weak)

func hit_feedback(total: float, weak: bool) -> void:
	last_hit = 0.25
	last_damage = total
	critical = weak
	Sounds.play("hit")

func launch(origin: Vector3, direction: Vector3, speed: float, damage: float,
		tint: Color, friendly: bool, splash := 0.0, gravity := 0.0,
		shooter: CharacterBody3D = null, weapon := "") -> void:
	var cap := 38 if Prefs.values.quality == 3 else 58
	if projectiles.get_child_count() >= cap:
		var oldest = projectiles.get_child(0)
		for existing in projectiles.get_children():
			if not existing.friendly:
				oldest = existing
				break
		recycle_bolt(oldest)
	var bolt: Node3D
	if projectile_bin.get_child_count() > 0:
		bolt = projectile_bin.get_child(-1)
		bolt.reparent(projectiles, false)
	else:
		bolt = Projectile.new()
		bolt.session = self
		projectiles.add_child(bolt)
	bolt.arm(origin, direction * speed, damage, tint, friendly, splash, gravity, shooter, weapon)

func recycle_bolt(bolt: Node3D) -> void:
	if bolt.get_parent() != projectiles:
		return
	bolt.sleep()
	bolt.reparent(projectile_bin, false)

func projectile_impact(bolt: Node3D, collider: Object, at: Vector3, direction: Vector3) -> void:
	var shooter: CharacterBody3D = bolt.shooter if is_instance_valid(bolt.shooter) else null
	if not bolt.friendly:
		if is_instance_valid(collider) and _bolt_can_damage(bolt, shooter, collider):
			if collider.has_method("take_damage"):
				collider.take_damage(bolt.damage, at - direction * 2.0, shooter, bolt.credit_slot)
			elif is_instance_valid(classic) and collider.has_method("take_hit"):
				collider.take_hit(bolt.damage, at, direction, shooter, bolt.credit_slot)
		if bolt.splash > 0.0:
			var blast := at - direction * 0.13
			var actors: Array = classic.combatants() if is_instance_valid(classic) else living_pilots()
			for actor in actors:
				if actor == collider or not _bolt_can_damage(bolt, shooter, actor):
					continue
				var center: Vector3 = actor.aim_point()
				var distance := center.distance_to(blast)
				if distance >= bolt.splash or not ray(blast, center, 1).is_empty():
					continue
				var amount: float = bolt.damage * lerpf(0.69, 0.25, distance / bolt.splash)
				if actor.has_method("take_damage"):
					actor.take_damage(amount, blast, shooter, bolt.credit_slot)
				else:
					actor.take_hit(amount, center, (center - blast).normalized(), shooter, bolt.credit_slot)
			effects.wave(blast, bolt.tint, bolt.splash)
		effects.sparks(at - direction * 0.055, bolt.tint, 9, 2.65)
		return
	var sum := 0.0
	if is_instance_valid(collider) and collider.has_method("take_hit") and can_damage(shooter, collider):
		sum += collider.take_hit(bolt.damage, at, direction, shooter)
	if bolt.splash > 0.0:
		var blast := at - direction * 0.13
		for unit in units.duplicate():
			if unit == collider or not can_damage(shooter, unit):
				continue
			var center: Vector3 = unit.center()
			var distance := center.distance_to(blast)
			if distance < bolt.splash and ray(blast, center, 1).is_empty():
				var fraction: float = lerpf(0.69, 0.25, distance / bolt.splash)
				sum += unit.take_hit(bolt.damage * fraction, center, (center - blast).normalized(), shooter)
		effects.sparks(blast, bolt.tint, 30, 6.4)
		effects.wave(blast, bolt.tint, bolt.splash)
		for index in 8:
			var angle := index * TAU / 8.0
			var end: Vector3 = blast + Vector3(sin(angle), 0.16, cos(angle)) * bolt.splash * 0.75
			effects.beam(blast, end, bolt.tint, 0.041, 0.17)
		sound("nova_impact", at)
	_confirm_hit(sum, false, shooter)

func _bolt_can_damage(bolt: Node3D, shooter: CharacterBody3D, victim: Object) -> bool:
	if mode == "gungame" and victim is CharacterBody3D and classic.scores.has(bolt.credit_slot):
		return bolt.credit_slot != victim.arena_slot
	return can_damage(shooter, victim)

func make_hazard(at: Vector3, radius: float, duration: float, damage: float,
		source: CharacterBody3D = null, slow := false) -> void:
	if hazards.get_child_count() >= 8:
		return
	var hazard := Hazard.new()
	hazard.position = at
	hazard.session = self
	hazard.radius = radius
	hazard.duration = duration
	hazard.power = damage
	hazard.source = source
	hazard.slow = slow
	if slow:
		hazard.tint = Color("#c596fa")
	hazards.add_child(hazard)
	if is_instance_valid(net):
		net.visual("zone", at, Vector3.ZERO, hazard.tint, radius, duration)
	show_radio("Brouillage au sol · sortez du cercle" if slow else "Onde au sol · sortez du cercle", 1.8)

func telegraph(unit: CharacterBody3D) -> void:
	var at: Vector3 = unit.center()
	var end: Vector3 = at + (unit.aim_at - at).normalized() * (1.45 if unit.kind == "scout" else 3.05)
	effects.beam(at, end, unit.spec.tint, 0.037, minf(0.48, unit.timer))
	effects.sparks(at, unit.spec.tint, 8, 1.3)
	sound("tell", at)

func ray(origin: Vector3, end: Vector3, mask: int, exclude: Array[RID] = []) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, end, mask)
	query.hit_from_inside = true
	query.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(query)

func choices(actor: CharacterBody3D = null) -> Array[int]:
	if not is_instance_valid(actor):
		actor = player
	var offered: Array[int] = []
	for offset in Catalog.UPGRADES.size():
		var index := posmod((director.wave - 1) * 2 + offset, Catalog.UPGRADES.size())
		var limit: int = Catalog.UPGRADES[index].cap
		if limit == 0 or actor.modules[index] < limit:
			offered.append(index)
		if offered.size() == 3:
			break
	return offered

func choose_upgrade(which: int, actor: CharacterBody3D = null) -> bool:
	if not is_instance_valid(actor):
		actor = player
	if actor.module_selected or director.phase != Director.Phase.UPGRADE or not choices(actor).has(which):
		return false
	actor.module_selected = true
	if actor == player:
		module_selected = true
	actor.modules[which] += 1
	match which:
		0: actor.shield_max += 16
		1: actor.speed_bonus += 0.08
		2: actor.arsenal.reload_boost += 0.18
		3: actor.health = minf(100.0, actor.health + 38)
		5: actor.arsenal.damage_boost += 0.12
	Sounds.play("upgrade", actor.global_position)
	show_radio("Installé  /  %s" % Catalog.UPGRADES[which].name, 3.2)
	intermission_updated.emit()
	return true

func _wave_secured(_wave: int, bonus: int) -> void:
	arena.alert_lighting(false)
	Sounds.set_track("combat")
	grant_team(bonus)
	module_selected = false
	_clear_group(projectiles)
	_clear_group(hazards)
	for pilot in pilots.values():
		pilot.module_selected = false
		pilot.round_lock = is_instance_valid(net)
		if not pilot.alive:
			pilot.position = arena.start_at + Vector3.RIGHT * (float(pilots.values().find(pilot)) * 1.25)
			pilot.reset_physics_interpolation()
			pilot.health = 64.0
			pilot.alive = true
			pilot.collision_layer = 2
			if is_instance_valid(pilot.avatar):
				pilot.avatar.present_alive(true)
		pilot.health = minf(100.0, pilot.health + 9)
		pilot.shield = pilot.shield_max
		pilot.shield_wait = 0.0
		pilot.damage_lock = 0.65
		pilot.arsenal.supply_at_intermission()

func ready_next_wave(risk := false) -> void:
	if director.phase == Director.Phase.UPGRADE:
		for pilot in pilots.values():
			pilot.round_lock = false
		director.player_count = pilots.size()
		director.next_wave(risk and not is_instance_valid(net))

func buy_offer(id: String, actor: CharacterBody3D = null, nonce := -1) -> Dictionary:
	if not is_instance_valid(actor):
		actor = player
	if director.phase != Director.Phase.UPGRADE or not actor.alive:
		return {"ok": false, "message": "Boutique disponible entre deux vagues."}
	buy_serial += 1
	var bank: Wallet = wallets[actor.peer_id]
	var receipt := bank.buy(id, director.wave, nonce if nonce >= 0 else buy_serial, _apply_offer.bind(actor))
	if receipt.ok:
		Sounds.play("upgrade", actor.global_position)
	return receipt

func _apply_offer(id: String, actor: CharacterBody3D) -> bool:
	match id:
		"heal":
			if actor.health >= 100.0:
				return false
			actor.health = minf(100.0, actor.health + 40.0)
		"cells":
			actor.arsenal.reset_supply()
		"barrier":
			actor.shield_max += 6.0
			actor.shield = actor.shield_max
		"power":
			actor.arsenal.damage_boost += 0.07
		"cool":
			actor.arsenal.reload_boost += 0.10
		"rack":
			actor.arsenal.expand_magazines()
		"mobility":
			actor.speed_bonus += 0.04
		_:
			return false
	return true

func result_data(victory: bool, actor: CharacterBody3D = null) -> Dictionary:
	if not is_instance_valid(actor):
		actor = player
	var bank: Wallet = wallets[actor.peer_id]
	var fired: int = actor.stats.shots
	var connected: int = actor.stats.hits
	var report := {"score": director.score, "wave": director.cleared,
		"seconds": roundi(director.elapsed), "kills": director.kills,
		"accuracy": roundi(100.0 * connected / maxi(1, fired)), "victory": victory,
		"bosses": boss_kills, "shots": fired, "hits": connected,
		"credits": bank.earned, "spent": bank.spent, "mastery": actor.stats.mastery.duplicate(),
		"participated": not is_instance_valid(net) or connected > 0 or actor.stats.support > 0.0}
	if is_instance_valid(classic):
		report.participated = classic.enemies_limit > 0 and (classic.kills > 0 or classic.objective_time >= 3.0)
		report.objectives = floori(classic.objective_time)
		report.rules = Rules.key(classic.options)
		report.rival = classic.rival_score()
		report.outcome = classic.outcome
		report.deaths = classic.deaths
	elif mode == "relax":
		report.participated = false
	report.seed = run_seed
	return report

func _reset_training() -> void:
	for unit in units:
		unit.set_physics_process(false)
		unit.collision_layer = 0
		unit.queue_free()
	units.clear()
	respawn_queue.clear()
	_clear_group(projectiles)
	var points := _training_points()
	for index in PRACTICE.size():
		var kind: String = "skimmer" if training_options.targets == "air" else PRACTICE[index]
		spawn_unit(kind, points[index], true)
	training_ended = false
	player.round_lock = false
	director.live = units.size()
	director.kills = 0
	director.elapsed = 0.0
	shots = 0
	hits = 0
	player.stats = {"shots": 0, "hits": 0, "support": 0.0, "mastery": {}}
	player.arsenal.reset_supply()

func configure_training(targets: String, distance: int, duration: int) -> void:
	if mode != "training":
		return
	training_options = {"targets": targets if targets in ["fixed", "moving", "air"] else "moving",
		"distance": distance if distance in [0, 8, 16, 24] else 0,
		"time": duration if duration in [0, 30, 60, 90] else 0}
	_reset_training()

func _training_points() -> Array[Vector3]:
	var points: Array[Vector3] = arena.practice_points.duplicate()
	if training_options.distance == 0:
		return points
	var from := Vector2(arena.start_at.x, arena.start_at.z)
	var applied := 0
	for i in [0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5]:
		var aim := Vector2(0.0, -training_options.distance).rotated(i * 0.19)
		var at := from + aim
		if not Rect2(-arena.half_size, arena.half_size * 2.0).grow(-2.0).has_point(at):
			continue
		if arena.routes.clear_segment(from, at, 0.70):
			points[applied] = Vector3(at.x, 0.06, at.y)
			applied += 1
			if applied == points.size():
				break
	return points

func _clear_group(group: Node3D) -> void:
	for child in group.get_children():
		if group == projectiles:
			recycle_bolt(child)
		else:
			child.set_physics_process(false)
			child.queue_free()

func _drop_pickup(kind: String, at: Vector3, mirror_id := -1) -> void:
	if pickups.get_child_count() >= 10:
		pickups.get_child(0).queue_free()
	var pickup := Pickup.new()
	pickup.kind = kind
	pickup.serial = mirror_id if mirror_id >= 0 else drop_serial
	drop_serial += 1
	pickup.position = at
	pickups.add_child(pickup)

func _scan_pickups(authority := true) -> void:
	nearby = null
	pickup_hint = ""
	var closest := 2.75
	for pickup in pickups.get_children():
		if pickup.is_queued_for_deletion():
			continue
		var distance: float = player.global_position.distance_to(pickup.global_position)
		if distance < closest:
			closest = distance
			nearby = pickup
	if is_instance_valid(nearby):
		if closest < 0.93 and authority and player.alive:
			_collect(nearby)
		else:
			pickup_hint = "Récupérer le kit" if nearby.kind == "repair" else "Récupérer les charges"
	elif player.global_position.distance_to(arena.terminal_at) < 2.6:
		if mode == "training":
			pickup_hint = "Réarmer et réinitialiser les cibles"
		elif director.phase == Director.Phase.PREP:
			pickup_hint = "Lancer le match" if is_instance_valid(classic) else ("Lancer le chrono" if mode == "trial" else "Lancer la vague maintenant")
	else:
		var interactable := _map_interactable(player)
		if is_instance_valid(interactable):
			pickup_hint = interactable.hint()
	if authority and is_instance_valid(net):
		for pilot in living_pilots():
			if pilot == player:
				continue
			for item in pickups.get_children():
				if not item.is_queued_for_deletion() and item.position.distance_squared_to(pilot.position) < 0.86:
					_collect(item, pilot)

func _map_interactable(actor: CharacterBody3D) -> Node3D:
	for item in map_interactables:
		if is_instance_valid(item) and item.can_reach(actor):
			return item
	return null

func interact(actor: CharacterBody3D = null) -> void:
	if mode == "parkour":
		director.retry_checkpoint()
		return
	if not is_instance_valid(actor):
		actor = player
	var interactable := _map_interactable(actor)
	if is_instance_valid(interactable):
		interactable.activate(actor)
		return
	if actor != player:
		for item in pickups.get_children():
			if item.global_position.distance_squared_to(actor.global_position) < 5.5 and ray(actor.head.global_position, item.global_position + Vector3.UP * 0.22, 1).is_empty():
				_collect(item, actor)
				return
		if director.phase == Director.Phase.PREP and actor.position.distance_to(arena.terminal_at) < 2.6:
			director.open_wave()
		return
	if is_instance_valid(nearby):
		var point: Vector3 = nearby.global_position + Vector3.UP * 0.22
		if ray(player.head.global_position, point, 1).is_empty():
			_collect(nearby)
	elif player.global_position.distance_to(arena.terminal_at) < 2.6:
		if mode == "training":
			_reset_training()
			show_radio("Cibles remises en service", 2.5)
			sound("upgrade")
		elif director.phase == Director.Phase.PREP:
			director.open_wave()

func _collect(item: Node3D, actor: CharacterBody3D = null) -> void:
	if not is_instance_valid(actor):
		actor = player
	if item.is_queued_for_deletion():
		return
	if item.kind == "repair":
		actor.health = minf(100, actor.health + 22)
		actor.shield = minf(actor.shield_max, actor.shield + 14)
		show_radio("Kit  /  Intégrité +22", 1.9)
	else:
		actor.arsenal.refill(maxi(2, roundi(actor.arsenal.spec().mag * 0.28)))
		show_radio("Cellule  /  Charges récupérées", 1.9)
	effects.sparks(item.global_position + Vector3.UP * 0.4, item.tint, 16, 2.2)
	item.queue_free()
	sound("pickup")
	nearby = null

func show_radio(message: String, duration: float) -> void:
	radio = message
	radio_time = duration

func sound(id: String, at := Vector3.INF) -> void:
	Sounds.play(id, at)

func repair_pulse(pilot: CharacterBody3D) -> void:
	for ally in living_pilots():
		if ally == pilot or (ally.position.distance_squared_to(pilot.position) < 64.0 and ray(pilot.head.global_position, ally.head.global_position, 1).is_empty()):
			var previous: float = ally.shield
			ally.shield = minf(ally.shield_max, ally.shield + 32.0)
			if ally != pilot:
				pilot.stats.support += ally.shield - previous
	effects.sparks(pilot.global_position + Vector3.UP, Color("#7df2dc"), 22, 3.0)
	show_radio("Aegis · Bouclier restauré", 1.6)

func living_pilots() -> Array:
	var living: Array[CharacterBody3D] = []
	for pilot in pilots.values():
		if is_instance_valid(pilot) and pilot.alive:
			living.append(pilot)
	return living

func nearest_pilot(at: Vector3) -> CharacterBody3D:
	var chosen: CharacterBody3D
	var best := INF
	for pilot in living_pilots():
		var distance: float = pilot.global_position.distance_squared_to(at)
		if distance < best:
			best = distance
			chosen = pilot
	return chosen

func find_patient(medic: CharacterBody3D) -> CharacterBody3D:
	var patient: CharacterBody3D
	var best := 121.0
	for unit in units:
		if unit == medic or not unit.alive or unit.maximum - unit.health < 24.0:
			continue
		var distance: float = unit.position.distance_squared_to(medic.position)
		if distance < best and ray(medic.center(), unit.center(), 1).is_empty():
			patient = unit
			best = distance
	return patient

func resolve_stall(unit: CharacterBody3D) -> void:
	if is_instance_valid(classic):
		var recovery := match_spawn()
		if recovery.is_finite() and not _spawn_in_view(recovery, player.head):
			unit.position = recovery
			unit.reset_physics_interpolation()
			unit.path.clear()
			unit.decision = 0.0
		return
	var at := find_spawn(true)
	if unit.relocations < 2 and at.is_finite():
		unit.relocations += 1
		unit.position = at
		unit.reset_physics_interpolation()
		unit.path.clear()
		unit.velocity = Vector3.ZERO
		unit.timer = 0.95
		unit.state = 0
		effects.beam(at, at + Vector3.UP * 2.6, unit.spec.tint, 0.17, 0.82)
		return
	unit.alive = false
	units.erase(unit)
	unit.queue_free()
	director.remove_unit()

func add_pilot(id: int, data: Dictionary, local: bool) -> CharacterBody3D:
	if pilots.has(id):
		return pilots[id]
	var pilot := Pilot.instantiate()
	var seat := clampi(int(data.get("seat", pilots.size())), 0, 3)
	pilot.position = arena.start_at + Vector3.RIGHT * ([0.0, -1.7, 1.7, -3.4][seat] as float)
	pilot.session = self
	pilot.gear = data.get("gear", {})
	pilot.pilot_name = data.get("name", "Pilote")
	pilot.seat = seat
	pilot.local_view = local
	pilot.remote_input = not local and is_instance_valid(net) and net.hosting
	pilot.replica = is_instance_valid(net) and not net.hosting
	pilot.round_lock = is_instance_valid(director) and director.phase in [Director.Phase.UPGRADE, Director.Phase.MILESTONE]
	pilot.peer_id = id
	pilot.eliminated.connect(_pilot_eliminated.bind(id))
	pilots[id] = pilot
	wallets[id] = Wallet.new()
	add_child(pilot)
	return pilot

func remove_pilot(id: int) -> void:
	if not pilots.has(id):
		return
	var pilot = pilots[id]
	pilots.erase(id)
	wallets.erase(id)
	pilot.queue_free()
	if pilot == player:
		player = null if pilots.is_empty() else pilots.values().front()
		if is_instance_valid(player):
			wallet = wallets[player.peer_id]
	_pilot_eliminated(id)

func pilot_checkpoint(id: int) -> Dictionary:
	var pilot = pilots[id]
	var gun = pilot.arsenal
	return {"bank": wallets[id], "modules": pilot.modules.duplicate(), "stats": pilot.stats.duplicate(true),
		"shield_max": pilot.shield_max, "health": pilot.health, "speed": pilot.speed_bonus,
		"damage": gun.damage_boost, "reload": gun.reload_boost, "capacity": gun.capacity_bonus,
		"magazines": gun.magazines.duplicate(), "reserves": gun.reserves.duplicate(), "gadget": pilot.gadget_left}

func restore_pilot(pilot: CharacterBody3D, state: Dictionary) -> void:
	wallets[pilot.peer_id] = state.bank
	pilot.modules.assign(state.modules)
	pilot.stats = state.stats
	pilot.shield_max = state.shield_max
	pilot.shield = state.shield_max
	pilot.health = maxf(64.0, state.health)
	pilot.speed_bonus = state.speed
	pilot.gadget_left = state.gadget
	var gun = pilot.arsenal
	gun.damage_boost = state.damage
	gun.reload_boost = state.reload
	gun.capacity_bonus = state.capacity
	gun.magazines.assign(state.magazines)
	gun.reserves.assign(state.reserves)
	gun.supply_at_intermission()

func _pilot_eliminated(_id: int) -> void:
	if is_instance_valid(classic):
		classic.invalidate_combatants()
		classic.eliminated(player, player.last_attacker, player.last_credit_slot)
		return
	if (not is_instance_valid(net) or net.hosting) and living_pilots().is_empty():
		director.finish(false)

func grant_team(amount: int) -> void:
	for bank in wallets.values():
		bank.grant(amount)
