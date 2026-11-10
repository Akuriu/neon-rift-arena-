extends RefCounted

const Catalog := preload("res://game/catalog.gd")
const Director := preload("res://game/wave_director.gd")
const KINDS := ["scout", "sentinel", "bulwark", "specter", "elite", "warden",
	"skimmer", "medic", "disruptor", "artillery", "colossus", "architect"]

static func snapshot(stage: Node3D) -> Array:
	var director = stage.director
	var board := [director.wave, director.live, director.pending.size(), director.kills, director.score,
		director.elapsed, director.clock, director.combo, director.combo_left, director.highest_combo, director.phase]
	var pilots := []
	for id in stage.pilots:
		var pilot = stage.pilots[id]
		var gun = pilot.arsenal
		pilots.append([id, pilot.position, pilot.rotation.y, pilot.head.rotation.x, pilot.velocity.length(), pilot.height,
			pilot.health, pilot.shield, pilot.shield_max, pilot.alive, gun.active, gun.rounds(), gun.reserve(),
			gun.heat[gun.active], gun.charge, gun.reload_left, gun.cycle_length, gun.capacity_bonus,
			pilot.gadget_left, stage.wallets[id].balance, pilot.module_selected, pilot.modules.duplicate(),
			pilot.stats.shots, pilot.stats.hits, stage.wallets[id].levels, pilot.damage_from])
	var units := []
	for unit in stage.units:
		units.append([unit.serial, KINDS.find(unit.kind), unit.position, unit.rotation.y, unit.health,
			unit.maximum, unit.state, unit.phase, unit.timer])
	var projectiles := []
	for index in mini(20, stage.projectiles.get_child_count()):
		var bolt = stage.projectiles.get_child(index)
		projectiles.append([bolt.position, bolt.velocity.normalized(), bolt.tint])
	var pickups := []
	for item in stage.pickups.get_children():
		if not item.is_queued_for_deletion():
			pickups.append([item.serial, item.kind, item.position])
	return [board, pilots, units, projectiles, pickups]

static func apply(stage: Node3D, data: Array, known: Dictionary) -> void:
	var director = stage.director
	var board: Array = data[0]
	if int(board[0]) == director.wave:
		director.live = board[1]
		director.pending.resize(board[2])
		director.kills = board[3]
		director.score = board[4]
		director.elapsed = board[5]
		director.clock = board[6]
		director.combo = board[7]
		director.combo_left = board[8]
		director.highest_combo = board[9]
	for row in data[1]:
		var id: int = row[0]
		if not stage.pilots.has(id):
			continue
		var pilot = stage.pilots[id]
		pilot.replica_pos = row[1]
		pilot.replica_yaw = row[2]
		pilot.replica_pitch = row[3]
		pilot.replica_speed = row[4]
		pilot.height = row[5]
		if row[6] < pilot.health:
			pilot.hull_flash = 1.0
		if row[7] < pilot.shield:
			pilot.shield_flash = 0.85
		pilot.health = row[6]
		pilot.shield = row[7]
		pilot.shield_max = row[8]
		pilot.alive = row[9]
		var gun = pilot.arsenal
		gun.capacity_bonus = row[17]
		if pilot == stage.player:
			if gun.active == int(row[10]):
				gun.magazines[gun.active] = row[11]
				gun.reserves[gun.active] = row[12]
				gun.heat[gun.active] = row[13]
				gun.charge = row[14]
				gun.reload_left = row[15]
				gun.cycle_length = row[16]
			pilot.gadget_left = row[18]
			stage.wallet.balance = row[19]
			stage.module_selected = row[20]
			pilot.module_selected = row[20]
			pilot.modules.assign(row[21])
			stage.shots = row[22]
			stage.hits = row[23]
			stage.wallet.levels = row[24]
			pilot.damage_from = row[25]
	var alive := {}
	for row in data[2]:
		var id: int = row[0]
		var kind: String = KINDS[row[1]]
		if not known.has(id):
			known[id] = stage.spawn_unit(kind, row[2], false, id)
		var unit = known[id]
		unit.replica_at = row[2]
		unit.replica_yaw = row[3]
		if row[4] < unit.health:
			unit.hit_flash = 1.0
		unit.health = row[4]
		unit.maximum = row[5]
		unit.state = row[6]
		unit.phase = row[7]
		unit.timer = row[8]
		alive[id] = true
	for id in known.keys():
		if not alive.has(id):
			var unit: CharacterBody3D = known[id]
			stage.effects.sparks(unit.center(), unit.spec.tint, 12, 3.1)
			stage.units.erase(unit)
			unit.queue_free()
			known.erase(id)
	for bolt in data[3]:
		stage.effects.beam(bolt[0], bolt[0] - bolt[1] * 0.73, bolt[2], 0.065, 0.077)
	var present := {}
	for row in data[4]:
		present[row[0]] = row
	for item in stage.pickups.get_children():
		if present.has(item.serial):
			present.erase(item.serial)
		else:
			item.queue_free()
	for row in present.values():
		stage._drop_pickup(row[1], row[2], row[0])
