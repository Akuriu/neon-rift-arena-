extends RefCounted

const COST := {
	"scout": 2, "sentinel": 3, "specter": 3, "skimmer": 3, "bulwark": 5,
	"medic": 4, "disruptor": 4, "artillery": 5, "elite": 9, "warden": 14,
	"colossus": 16, "architect": 18,
}
const INTRO := {
	"scout": 1, "sentinel": 1, "specter": 2, "bulwark": 3, "skimmer": 4,
	"medic": 6, "disruptor": 7, "artillery": 8,
}
const THEMES := [
	{"name": "Patrouilles", "pool": ["scout", "sentinel", "specter", "bulwark"]},
	{"name": "Essaim mobile", "pool": ["scout", "skimmer", "skimmer", "specter"]},
	{"name": "Escorte blindée", "pool": ["bulwark", "bulwark", "sentinel", "medic"]},
	{"name": "Brouillage", "pool": ["disruptor", "specter", "skimmer", "sentinel"]},
	{"name": "Batterie orbitale", "pool": ["artillery", "sentinel", "medic", "scout"]},
	{"name": "Tenaille", "pool": ["specter", "specter", "scout", "artillery"]},
	{"name": "Relais médical", "pool": ["medic", "medic", "bulwark", "sentinel"]},
	{"name": "Balayage", "pool": ["skimmer", "skimmer", "artillery", "specter"]},
	{"name": "Veilleurs", "pool": ["sentinel", "sentinel", "artillery", "scout"]},
	{"name": "Avant-garde", "pool": ["scout", "scout", "bulwark", "skimmer"]},
	{"name": "Circuit lourd", "pool": ["bulwark", "bulwark", "artillery", "disruptor"]},
	{"name": "Batterie mixte", "pool": ["artillery", "disruptor", "medic", "skimmer"]},
]
const MODIFIERS := {"rush": "Unités rapides", "armor": "Coques renforcées", "light": "Gravité douce", "alert": "Éclairage d’urgence"}
const BOSSES := ["elite", "warden", "colossus", "architect"]
const ESCORTS := [
	["scout", "sentinel", "scout"],
	["skimmer", "bulwark", "medic"],
	["disruptor", "sentinel", "bulwark", "skimmer"],
	["artillery", "medic", "disruptor", "specter", "bulwark"],
]

static func boss_rush(index: int, run_seed: int) -> Dictionary:
	var slot := clampi(index - 1, 0, BOSSES.size() - 1)
	var escort: Array = ESCORTS[slot].duplicate()
	if posmod(run_seed + index, 2) == 1:
		escort.reverse()
	escort.push_front(BOSSES[slot])
	return {"wave": index, "theme": "Escorte du boss", "boss": BOSSES[slot],
		"composition": escort, "cap": 5, "interval": 1.3, "wave_bonus": 125 + index * 20}

static func generate(index: int, run_seed: int, difficulty: Dictionary, players := 1) -> Dictionary:
	var wave := maxi(1, index)
	var group := clampi(players, 1, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d/%d/%d" % [run_seed, wave, group]).hash()
	var theme: Dictionary = THEMES[0] if wave <= 3 else THEMES[rng.randi_range(0, 4 if wave <= 20 else THEMES.size() - 1)]
	var boss := BOSSES[posmod(wave / 5 - 1, BOSSES.size())] as String if wave % 5 == 0 else ""
	var pressure := mini(24, roundi(log(float(mini(wave, 2000)) + 1.0) * 5.2))
	var difficulty_bonus := mini(wave / 3, maxi(0, int(difficulty.cap) - 5))
	var budget := 5 + mini(wave, 20) + pressure + difficulty_bonus + (group - 1) * mini(7, 3 + wave / 4)
	if wave >= 5 and boss != "":
		budget += COST[boss]
	var pending: Array[String] = []
	var spent := 0
	var counts := {}
	if boss != "":
		pending.append(boss)
		spent += COST[boss]
	var pool: Array[String] = []
	for kind in theme.pool:
		if INTRO[kind] <= wave:
			pool.append(kind)
	for kind in INTRO:
		if INTRO[kind] <= wave:
			pool.append(kind)
	while budget - spent >= COST.scout and pending.size() < 29 + (group - 1) * 3:
		var candidates: Array[String] = []
		for kind in pool:
			var limit := 2 if kind in ["medic", "artillery", "disruptor"] else 12
			if COST[kind] <= budget - spent and int(counts.get(kind, 0)) < limit:
				candidates.append(kind)
		if candidates.is_empty():
			break
		var chosen := candidates[rng.randi_range(0, candidates.size() - 1)]
		pending.append(chosen)
		counts[chosen] = int(counts.get(chosen, 0)) + 1
		spent += COST[chosen]
	var mutation := ""
	if wave > 20 and wave % 5 in [2, 4]:
		mutation = MODIFIERS.keys()[posmod(wave + run_seed, MODIFIERS.size())]
	var interval := clampf(0.76 - minf(wave, 30) * 0.013, 0.36, 0.76)
	if wave > 20:
		interval *= [0.86, 1.08, 0.92, 1.30][wave % 4]
	return {"wave": wave, "seed": run_seed, "theme": theme.name, "boss": boss,
		"budget": budget, "cost": spent, "composition": pending,
		"cap": clampi(int(difficulty.cap) + group - 1, 4, 12),
		"interval": interval,
		"wave_bonus": 60 + mini(wave, 40) * 7,
		"mutation": mutation}
