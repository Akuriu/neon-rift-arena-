extends "res://game/modes/classic.gd"

const Arms := preload("res://game/weapons/catalog.gd")
const ORDER := [0, 6, 1, 2, 3, 7, 4, 5]
var order := []
var deaths_seen := {}
var winner := -1

func configure(session: Node3D, variant: String, raw: Dictionary) -> void:
	super.configure(session, variant, raw)
	order = ORDER.duplicate()
	if options.shuffled:
		var rng := RandomNumberGenerator.new()
		rng.seed = stage.run_seed
		for last in range(order.size() - 1, 0, -1):
			var pick := rng.randi_range(0, last)
			var weapon: int = order[last]
			order[last] = order[pick]
			order[pick] = weapon
	equip_actor(stage.player)

func bot_kind(_slot: int) -> String:
	return "sentinel"

func equip_actor(actor: CharacterBody3D) -> void:
	var index: int = order[mini(order.size() - 1, int(scores.get(actor.arena_slot, 0)))]
	if actor == stage.player:
		actor.arsenal.assign_stage(index)
	else:
		actor.equip_match_weapon(index)

func eliminated(victim: CharacterBody3D, source: CharacterBody3D, credit := -1) -> void:
	if phase != Wave.Phase.ACTIVE or victim.alive:
		return
	var life := "%s:%s" % [victim.get_instance_id(), victim.life_generation if victim == stage.player else victim.serial]
	if deaths_seen.has(life):
		return
	deaths_seen[life] = true
	var slot: int = victim.arena_slot
	respawns[slot] = 2.7 if slot == 0 else 3.1
	if slot == 0:
		deaths += 1
		stage.show_radio("Hors combat · votre palier est conservé", 2.6)
	var attacker: int = source.arena_slot if is_instance_valid(source) else credit
	if attacker == slot or not scores.has(attacker):
		return
	scores[attacker] = mini(order.size(), int(scores[attacker]) + 1)
	if attacker == 0:
		kills += 1
	score = scores[0]
	if int(scores[attacker]) == order.size():
		winner = attacker
		finish(attacker == 0)
		return
	if attacker == 0:
		equip_actor(stage.player)
	else:
		for actor in stage.units:
			if actor.alive and actor.arena_slot == attacker:
				equip_actor(actor)
				break
	if attacker == 0:
		stage.sound("upgrade")
		stage.show_radio("Palier %d / 8 · %s" % [score + 1, Arms.WEAPONS[order[score]].name], 2.1)
	changed.emit()

func rank_of(slot := 0) -> int:
	var rank := 1
	for other in scores:
		if int(scores[other]) > int(scores.get(slot, 0)):
			rank += 1
	return rank

func next_weapon() -> String:
	return Arms.WEAPONS[order[score + 1]].name if score + 1 < order.size() else "Dernière élimination"

func standings() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for slot: int in scores:
		rows.append({"slot": slot, "score": scores[slot], "rank": rank_of(slot)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.slot < b.slot if a.score == b.score else a.score > b.score)
	return rows
