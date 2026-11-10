extends "res://game/modes/classic.gd"

const Arms := preload("res://game/weapons/catalog.gd")
# One immutable sequence: the final R700 elimination wins the match.
const ORDER := [0, 6, 1, 2, 3, 7, 4, 5]
var deaths_seen := {}
var winner := -1

func configure(session: Node3D, variant: String, raw: Dictionary) -> void:
	super.configure(session, variant, raw)
	equip_actor(stage.player)

func bot_kind(_slot: int) -> String:
	return "sentinel"

func equip_actor(actor: CharacterBody3D) -> void:
	var index: int = ORDER[mini(ORDER.size() - 1, int(scores.get(actor.arena_slot, 0)))]
	if actor == stage.player:
		actor.arsenal.assign_stage(index)
	else:
		actor.equip_match_weapon(index)

func eliminated(victim: CharacterBody3D, source: CharacterBody3D) -> void:
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
	if not enemies(victim, source) or not scores.has(source.arena_slot):
		return
	var attacker: int = source.arena_slot
	scores[attacker] = mini(ORDER.size(), int(scores[attacker]) + 1)
	if attacker == 0:
		kills += 1
	score = scores[0]
	if int(scores[attacker]) == ORDER.size():
		winner = attacker
		finish(attacker == 0)
		return
	equip_actor(source)
	if attacker == 0:
		stage.sound("upgrade")
		stage.show_radio("Palier %d / 8 · %s" % [score + 1, Arms.WEAPONS[ORDER[score]].name], 2.1)
	changed.emit()

func rank_of(slot := 0) -> int:
	var rank := 1
	for other in scores:
		if int(scores[other]) > int(scores.get(slot, 0)):
			rank += 1
	return rank

func next_weapon() -> String:
	return Arms.WEAPONS[ORDER[score + 1]].name if score + 1 < ORDER.size() else "Dernière élimination"
