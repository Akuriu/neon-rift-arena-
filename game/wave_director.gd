extends Node

signal spawn_requested(kind: String)
signal changed
signal finished(victory: bool)
signal wave_opened(number: int)
signal wave_secured(number: int, credits: int)
signal campaign_complete

const Catalog := preload("res://game/catalog.gd")
const Generator := preload("res://game/waves/generator.gd")
const TRIAL_TIME := 90.0
enum Phase { PREP, ACTIVE, UPGRADE, DONE, TRAINING, TRIAL, MILESTONE }

var phase := Phase.PREP
var mode := "survival"
var tuning: Dictionary
var wave := 1
var cleared := 0
var total_waves := 20
var pending: Array[String] = []
var live := 0
var kills := 0
var score := 0
var elapsed := 0.0
var clock := 3.0
var spawn_delay := 0.0
var cap := 7
var combo := 0
var highest_combo := 0
var combo_left := 0.0
var trial_goal := Catalog.TRIAL.size()
var notice := 0.0
var run_seed := 1
var player_count := 1
var cap_override := 12
var current_wave := {}
var milestone_reached := false
var withdrawn := false
var risk := false

func configure(type: String, difficulty: Dictionary, world_seed := 1) -> void:
	mode = type
	tuning = difficulty
	run_seed = world_seed
	cap = difficulty.cap
	match mode:
		"short": total_waves = 10
		"relax":
			total_waves = 5
			tuning = Catalog.DIFFICULTIES.discovery.duplicate()
			tuning.tempo = maxf(1.45, tuning.tempo)
		"endless": total_waves = 0
		"boss_rush": total_waves = Generator.BOSSES.size()
		"training", "explore": phase = Phase.TRAINING

func _physics_process(delta: float) -> void:
	notice = maxf(0, notice - delta)
	if phase == Phase.TRAINING:
		elapsed += delta
		return
	if phase == Phase.PREP:
		clock -= delta
		if clock <= 0.0:
			open_wave()
		return
	if phase not in [Phase.ACTIVE, Phase.TRIAL]:
		return
	elapsed += delta
	combo_left = maxf(0, combo_left - delta)
	if combo_left == 0.0:
		combo = 0
	if phase == Phase.TRIAL and elapsed >= TRIAL_TIME:
		elapsed = TRIAL_TIME
		finish(false)
		return
	spawn_delay -= delta
	if not pending.is_empty() and live < cap and spawn_delay <= 0.0:
		var interval: float = current_wave.get("interval", 0.61)
		spawn_delay = interval * tuning.tempo * (0.7 if live == 0 else 1.0)
		spawn_requested.emit(pending[0])

func open_wave() -> void:
	if phase != Phase.PREP:
		return
	if mode == "trial":
		phase = Phase.TRIAL
		pending.assign(Catalog.TRIAL)
		cap = mini(int(tuning.cap), cap_override)
	else:
		phase = Phase.ACTIVE
		current_wave = preview_wave(wave)
		if risk:
			current_wave.wave_bonus += 60
			current_wave.interval *= 0.85
			current_wave["risk"] = true
		pending.assign(current_wave.composition)
		cap = mini(int(current_wave.cap), cap_override)
		if mode == "relax":
			cap = mini(cap, 4)
	spawn_delay = 0.0
	notice = 2.25
	wave_opened.emit(wave)
	changed.emit()

func preview_wave(number: int) -> Dictionary:
	return Generator.boss_rush(number, run_seed) if mode == "boss_rush" else Generator.generate(number, run_seed, tuning, player_count)

func registered_spawn() -> void:
	if pending.is_empty() or phase not in [Phase.ACTIVE, Phase.TRIAL]:
		return
	pending.pop_front()
	live += 1
	changed.emit()

func defeated(points: int) -> void:
	if live <= 0 or phase not in [Phase.ACTIVE, Phase.TRIAL, Phase.TRAINING]:
		return
	kills += 1
	if phase != Phase.TRAINING:
		combo = mini(combo + 1, 6)
		highest_combo = maxi(highest_combo, combo)
		combo_left = 5.5
		score += points + roundi(points * 0.10 * (combo - 1))
	remove_unit()

func remove_unit() -> void:
	if live <= 0 or phase not in [Phase.ACTIVE, Phase.TRIAL, Phase.TRAINING]:
		return
	live -= 1
	if live == 0 and pending.is_empty():
		_clear_wave()
	changed.emit()

func _clear_wave() -> void:
	if phase == Phase.TRAINING:
		return
	cleared = wave
	if phase == Phase.TRIAL:
		score += 250 + roundi(maxf(0.0, TRIAL_TIME - elapsed) * 18.0)
		finish(true)
		return
	score += 160 * mini(wave, 1000000)
	wave_secured.emit(wave, current_wave.get("wave_bonus", 60))
	if mode == "survival" and wave == 20 and total_waves == 20:
		milestone_reached = true
		phase = Phase.MILESTONE
		campaign_complete.emit()
	elif total_waves > 0 and cleared == total_waves:
		finish(true)
	else:
		phase = Phase.UPGRADE

func next_wave(extra_risk := false) -> void:
	if phase != Phase.UPGRADE:
		return
	wave += 1
	risk = extra_risk
	clock = 2.6
	combo = 0
	combo_left = 0.0
	phase = Phase.PREP
	changed.emit()

func continue_endless() -> void:
	if phase != Phase.MILESTONE:
		return
	total_waves = 0
	phase = Phase.UPGRADE
	changed.emit()

func bank() -> void:
	if phase == Phase.MILESTONE:
		finish(true)
	elif total_waves == 0 and cleared > 0:
		withdrawn = true
		finish(milestone_reached)

func finish(victory: bool) -> void:
	if phase == Phase.DONE or phase == Phase.TRAINING:
		return
	phase = Phase.DONE
	finished.emit(victory)

func remaining() -> int:
	return live + pending.size()
