extends SceneTree

const Generator := preload("res://game/waves/generator.gd")
const Director := preload("res://game/wave_director.gd")
const Catalog := preload("res://game/catalog.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var valid := true
	var deterministic := true
	for difficulty in Catalog.DIFFICULTIES.values():
		for sample in [1, 7, 11, 67432, 75437101]:
			for wave in range(1, 201):
				var group: int = 1 + sample % 4
				var definition := Generator.generate(wave, sample, difficulty, group)
				deterministic = deterministic and definition == Generator.generate(wave, sample, difficulty, group)
				valid = valid and definition.cap <= 12 and definition.cost <= definition.budget
				valid = valid and not definition.composition.is_empty() and definition.composition.size() <= 38
				valid = valid and (definition.boss != "") == (wave % 5 == 0)
				for unit in definition.composition:
					valid = valid and Catalog.UNITS.has(unit)
	check(valid, "3 000 vagues générées, budget/caps/archétypes/paliers valides")
	check(deterministic, "Composition reproductible à seed, difficulté et équipe identiques")
	var director := Director.new()
	director.configure("survival", Catalog.DIFFICULTIES.standard, 789)
	var total_finish := [0]
	director.finished.connect(func(_won): total_finish[0] += 1)
	for wave in range(1, 101):
		check(director.wave == wave, "Transition réelle vers %d" % wave, wave in [7, 10, 20, 21, 50, 100])
		director.open_wave()
		var original := director.remaining()
		director.open_wave()
		if director.remaining() != original:
			failures += 1
		while not director.pending.is_empty():
			director.registered_spawn()
			director.defeated(10)
		if wave == 20:
			check(director.phase == Director.Phase.MILESTONE and total_finish[0] == 0, "Vague 20 permet de poursuivre avant règlement")
			director.continue_endless()
		if director.remaining() != 0 or director.cleared != wave:
			failures += 1
		director.next_wave()
	check(director.wave == 101 and director.total_waves == 0, "100 transitions de suite, sans plafond")
	director.bank()
	director.bank()
	director.finish(false)
	check(total_finish[0] == 1, "Règlement et défaite concurrents ne terminent qu’une fois")
	director.free()
	quit(0 if failures == 0 else 1)

func check(success: bool, label: String, show := true) -> void:
	if show or not success:
		print("PASS " if success else "FAIL ", label)
	if not success:
		failures += 1
