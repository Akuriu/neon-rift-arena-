extends Node

signal changed
signal finished(victory: bool)
signal campaign_complete

const Wave := preload("res://game/wave_director.gd")
const Rules := preload("res://game/modes/rules.gd")
const Zone := preload("res://game/modes/control_zone.gd")
const BOTS := ["sentinel", "scout", "specter", "bulwark", "skimmer"]

var stage: Node3D
var mode := "classic"
var options := {}
var phase := Wave.Phase.PREP
var clock := 3.0
var elapsed := 0.0
var wave := 0
var cleared := 0
var total_waves := 0
var withdrawn := false
var current_wave := {}
var notice := 0.0
var combo := 0
var combo_left := 0.0
var highest_combo := 0
var score := 0
var kills := 0
var deaths := 0
var outcome := ""
var bots := 0
var scores := {}
var respawns := {}
var zones: Array[Node3D] = []
var objective_timer := 1.0
var supply_timer := 9.0
var enemies_limit := 0
var objective_time := 0.0
var members_frame := -1
var members_cache: Array = []

func configure(session: Node3D, variant: String, raw: Dictionary) -> void:
	stage = session
	mode = variant
	options = Rules.normalize(raw, mode)
	bots = mini(options.bots, 7 if Prefs.values.quality == 3 else 12)
	options.bots = bots
	stage.player.round_lock = true
	scores[0] = 0
	for slot in range(1, bots + 1):
		scores[side_for(slot)] = 0
		respawns[slot] = 0.0
		enemies_limit += int(side_for(slot) != 0)
	var count := 1 if mode == "capture" else (3 if mode == "domination" else 0)
	for i in count:
		var zone := Zone.new()
		zone.badge = ["A", "B", "C"][i]
		zone.position = stage.arena.control_points[1 if count == 1 else i]
		zones.append(zone)
		stage.add_child(zone)

func side_for(slot: int) -> int:
	return slot if mode in ["classic", "gungame"] else slot % 2

func bot_kind(slot: int) -> String:
	return BOTS[(slot - 1) % BOTS.size()]

func equip_actor(_actor: CharacterBody3D) -> void:
	pass

func remaining() -> int:
	return stage.units.size()

func time_left() -> float:
	return maxf(0.0, options.duration - elapsed)

func enemies(a: CharacterBody3D, b: CharacterBody3D) -> bool:
	return is_instance_valid(a) and is_instance_valid(b) and a.arena_side != b.arena_side

func combatants() -> Array:
	var frame := Engine.get_physics_frames()
	if members_frame != frame:
		members_cache = stage.units.duplicate()
		if stage.player.alive:
			members_cache.append(stage.player)
		members_frame = frame
	return members_cache

func invalidate_combatants() -> void:
	members_frame = -1

func protected(actor: CharacterBody3D) -> bool:
	return actor.damage_lock > 0.16 if actor == stage.player else actor.spawn_guard > 0.0

func target_for(unit: CharacterBody3D) -> CharacterBody3D:
	var target: CharacterBody3D
	var best := INF
	for actor in combatants():
		if not enemies(unit, actor) or not actor.alive or protected(actor):
			continue
		var distance: float = unit.position.distance_squared_to(actor.position)
		if distance < best:
			target = actor
			best = distance
	return target

func objective_for(unit: CharacterBody3D) -> Vector3:
	var result := Vector3.INF
	var best := INF
	for zone in zones:
		var distance: float = zone.position.distance_squared_to(unit.position)
		if zone.owner_side == unit.arena_side:
			distance += 180.0
		if distance < best:
			best = distance
			result = zone.position
	return result

func _physics_process(delta: float) -> void:
	if phase == Wave.Phase.PREP:
		clock -= delta
		if clock <= 0.0:
			open_wave()
		return
	if phase != Wave.Phase.ACTIVE:
		return
	elapsed += delta
	if time_left() <= 0.0:
		finish(_compare() > 0)
		return
	_advance_respawns(delta)
	supply_timer -= delta
	if supply_timer <= 0.0:
		supply_timer = 16.0
		var points: Array = stage.arena.practice_points
		var location: Vector3 = points[stage.random.randi_range(0, points.size() - 1)]
		stage._drop_pickup("energy" if stage.random.randf() < 0.60 else "repair", location)
	if not zones.is_empty():
		_control(delta)

func open_wave() -> void:
	if phase != Wave.Phase.PREP:
		return
	phase = Wave.Phase.ACTIVE
	stage.player.round_lock = false
	stage.show_radio("Match lancé", 2.2)
	changed.emit()

func _advance_respawns(delta: float) -> void:
	for slot in respawns.keys():
		respawns[slot] -= delta
		if respawns[slot] > 0.0:
			continue
		var at: Vector3 = stage.match_spawn()
		if not at.is_finite():
			respawns[slot] = 0.25
			continue
		respawns.erase(slot)
		if slot == 0:
			stage.player.respawn(at)
			invalidate_combatants()
			equip_actor(stage.player)
			stage.show_radio("Pilote redéployé", 1.25)
		else:
			stage.spawn_unit(bot_kind(int(slot)), at, false, -1, int(slot))

func _control(delta: float) -> void:
	var members := combatants()
	var owned := [0, 0]
	for zone in zones:
		var side: int = zone.advance(delta, members)
		if side >= 0:
			owned[side] += 1
		if side == 0 and stage.player.alive and zone.contains(stage.player.position):
			objective_time += delta
	objective_timer -= delta
	if objective_timer <= 0.0:
		objective_timer += 1.0
		for side in range(2):
			scores[side] = int(scores.get(side, 0)) + owned[side]
		score = scores[0]
		_check_target()

func eliminated(victim: CharacterBody3D, source: CharacterBody3D, _credit := -1) -> void:
	if phase != Wave.Phase.ACTIVE:
		return
	var slot: int = victim.arena_slot
	respawns[slot] = 2.7 if slot == 0 else 3.1
	if slot == 0:
		deaths += 1
		stage.show_radio("Hors combat · redéploiement", 2.6)
	if not enemies(victim, source):
		return
	if source.arena_slot == 0:
		kills += 1
	if zones.is_empty():
		scores[source.arena_side] += 1
		score = scores[0]
		_check_target()

func _check_target() -> void:
	if scores.values().max() >= options.target:
		finish(_compare() > 0)

func rival_score() -> int:
	var highest := 0
	for side in scores:
		if side != 0:
			highest = maxi(highest, scores[side])
	return highest

func _compare() -> int:
	return signi(score - rival_score())

func finish(_victory: bool) -> void:
	if phase == Wave.Phase.DONE:
		return
	var ranking := _compare()
	outcome = "victoire" if ranking > 0 else ("défaite" if ranking < 0 else "égalité")
	phase = Wave.Phase.DONE
	respawns.clear()
	finished.emit(ranking > 0)
