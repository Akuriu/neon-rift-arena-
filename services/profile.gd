extends RefCounted

const Arms := preload("res://game/weapons/catalog.gd")
const Career := preload("res://services/career.gd")
const CAP := 1000000000
const GEAR := {
	"gd_dash": {"name": "Propulseur", "class": "Gadgets", "price": 0, "info": "Dash court dans la direction du mouvement. Recharge de 7 s."},
	"gd_aegis": {"name": "Aegis Pulse", "class": "Gadgets", "price": 115, "info": "Restaure 32 points de bouclier aux pilotes proches. Recharge de 13 s."},
	"mod_cycle": {"name": "Catalyseur", "class": "Modules", "price": 100, "info": "Recharge et refroidissement accélérés de 12 %."},
	"mod_rack": {"name": "Double cellule", "class": "Modules", "price": 120, "info": "Une charge supplémentaire par chargeur."},
	"skin_copper": {"name": "Cuivre industriel", "class": "Apparences", "price": 65, "info": "Boîtier cuivré et couleur de pilote orange."},
	"skin_glacier": {"name": "Verre glacial", "class": "Apparences", "price": 70, "info": "Boîtier bleu nuit et couleur de pilote turquoise."},
	"skin_ash": {"name": "Cendre & ivoire", "class": "Apparences", "price": 85, "info": "Revêtement ivoire mat et armure graphite. Purement cosmétique."},
	"skin_aurora": {"name": "Aurore", "class": "Apparences", "price": 0, "wave": 50,
		"info": "Finition bleu pétrole et ivoire. Récompense cosmétique après la vague 50."},
	"perk_reserve": {"name": "Sacoche renforcée", "class": "Améliorations", "price": 135, "info": "Démarre chaque partie avec deux chargeurs supplémentaires en réserve."},
}
const CONTRACTS := {
	"kills": {"name": "Nettoyage du secteur", "goal": 40, "coins": 35, "xp": 70},
	"waves": {"name": "Tenir la ligne", "goal": 12, "coins": 45, "xp": 90},
	"runs": {"name": "Double sortie", "goal": 2, "coins": 25, "xp": 50},
}
const STAT_KEYS := ["runs", "wins", "losses", "ties", "kills", "deaths", "objectives", "bosses",
	"shots", "hits", "seconds", "waves", "best_wave", "credits", "spent"]
var data: Dictionary = {}

func _init() -> void:
	restore({})

static func number(value: Variant, upper := CAP) -> int:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)):
		return roundi(clampf(float(value), 0.0, upper))
	return 0

static func item(id: String) -> Dictionary:
	var index := Arms.index_of(id)
	return Arms.WEAPONS[index] if index >= 0 else GEAR.get(id, {})

static func safe_name(raw: Variant) -> String:
	if not raw is String:
		return "Pilote"
	var filtered := (raw as String).strip_edges().replace("\n", "").replace("\r", "").replace("\t", "").substr(0, 18)
	return "Pilote" if filtered.is_empty() else filtered

func restore(raw: Variant) -> void:
	var source: Dictionary = raw if raw is Dictionary else {}
	var uid: Variant = source.get("id", "")
	if not uid is String or uid.length() != 24 or not uid.is_valid_hex_number():
		uid = Crypto.new().generate_random_bytes(12).hex_encode()
	var owned: Array[String] = []
	owned.assign(Arms.DEFAULT_LOADOUT + ["gd_dash"])
	var entries: Variant = source.get("owned", [])
	if entries is Array:
		for id in entries.slice(0, 48):
			if id is String and not item(id).is_empty() and id not in owned:
				owned.append(id)
	var stats := _stats(source.get("stats"))
	var modes := {}
	var raw_modes: Variant = source.get("modes")
	if raw_modes is Dictionary:
		for mode in Career.Modes:
			if raw_modes.has(mode):
				modes[mode] = _stats(raw_modes[mode])
	var mastery := {}
	var raw_mastery: Variant = source.get("mastery")
	if raw_mastery is Dictionary:
		for weapon in Arms.WEAPONS:
			mastery[weapon.id] = number(raw_mastery.get(weapon.id), 100000)
	var receipts: Array[String] = []
	var stored_receipts: Variant = source.get("settled")
	if stored_receipts is Array:
		for receipt in stored_receipts.slice(-128):
			if receipt is String and receipt.length() <= 64 and receipt not in receipts:
				receipts.append(receipt)
	data = {"id": uid, "name": safe_name(source.get("name")), "coins": number(source.get("coins")),
		"xp": number(source.get("xp")), "owned": owned,
		"slots": Arms.normalize_slots(source.get("slots"), owned),
		"gadget": _equipped(source.get("gadget"), owned, "gd_", "gd_dash"),
		"module": _equipped(source.get("module"), owned, "mod_", ""),
		"skin": _equipped(source.get("skin"), owned, "skin_", ""),
		"stats": stats, "modes": modes, "mastery": mastery, "settled": receipts,
		"contracts": _contracts(source.get("contracts")),
		"career": Career.sanitize(source.get("career"), owned, number)}

func _equipped(raw: Variant, owned: Array, prefix: String, fallback: String) -> String:
	return raw if raw is String and raw.begins_with(prefix) and raw in owned else fallback

func _stats(raw: Variant) -> Dictionary:
	var values := {}
	for key in STAT_KEYS:
		values[key] = number(raw.get(key)) if raw is Dictionary else 0
	values.hits = mini(values.hits, values.shots)
	return values

func _contracts(raw: Variant) -> Dictionary:
	var today := Time.get_date_string_from_system()
	if raw is Dictionary and raw.get("date") is String:
		var previous: String = raw.date
		var fields := previous.split("-")
		if previous.length() == 10 and fields.size() == 3 and fields[0].is_valid_int() \
			and fields[1].is_valid_int() and int(fields[1]) in range(1, 13) \
			and fields[2].is_valid_int() and int(fields[2]) in range(1, 32) and previous > today:
			today = previous
	var out := {"date": today, "progress": {}, "claimed": {}}
	for id in CONTRACTS:
		out.progress[id] = 0
		out.claimed[id] = false
	if raw is Dictionary and raw.get("date") == today:
		var progress: Variant = raw.get("progress")
		var claimed: Variant = raw.get("claimed")
		for id in CONTRACTS:
			if progress is Dictionary:
				out.progress[id] = number(progress.get(id), CONTRACTS[id].goal)
			if claimed is Dictionary:
				var value: Variant = claimed.get(id)
				out.claimed[id] = value if value is bool else false
	return out

func refresh_contracts() -> void:
	if data.contracts.date < Time.get_date_string_from_system():
		data.contracts = _contracts({})
	Career.refresh(data.career)

func owns(id: String) -> bool:
	return id in data.owned

func buy(id: String) -> Dictionary:
	var offer := item(id)
	if offer.is_empty() or owns(id):
		return {"ok": false, "message": "Article indisponible ou déjà possédé."}
	if offer.has("wave") and data.stats.best_wave < offer.wave:
		return {"ok": false, "message": "Débloqué à la vague %d." % offer.wave}
	if data.coins < int(offer.price):
		return {"ok": false, "message": "Pièces du pilote insuffisantes."}
	data.coins -= int(offer.price)
	data.owned.append(id)
	Career.transaction(data.career, "Achat · " + offer.name, -int(offer.price))
	return {"ok": true, "message": "%s débloqué" % offer.name}

func equip(id: String, slot: int) -> Dictionary:
	if not owns(id):
		return {"ok": false, "message": "Débloquez d’abord cet article."}
	if Arms.index_of(id) >= 0:
		if slot not in range(4):
			return {"ok": false, "message": "Emplacement invalide."}
		var prior: int = data.slots.find(id)
		if prior >= 0:
			data.slots[prior] = data.slots[slot]
		data.slots[slot] = id
	elif id.begins_with("gd_"):
		data.gadget = id
	elif id.begins_with("mod_"):
		data.module = "" if data.module == id else id
	elif id.begins_with("skin_"):
		data.skin = "" if data.skin == id else id
	else:
		return {"ok": false, "message": "Cet avantage est appliqué automatiquement."}
	return {"ok": true, "message": "Équipement actualisé."}

func loadout(id: String) -> Dictionary:
	if id == "save":
		data.career.saved = {"slots": data.slots.duplicate(), "gadget": data.gadget, "module": data.module}
		return {"ok": true, "message": "Configuration personnelle enregistrée."}
	var selection: Dictionary = data.career.saved if id == "own" else Career.Presets.get(id, {})
	if selection.is_empty():
		return {"ok": false, "message": "Enregistrez d’abord un équipement personnel."}
	data.slots = Arms.normalize_slots(selection.slots, data.owned)
	data.gadget = _equipped(selection.gadget, data.owned, "gd_", "gd_dash")
	data.module = _equipped(selection.module, data.owned, "mod_", "")
	return {"ok": true, "message": "%s · équipement actualisé." % selection.get("name", "Personnel")}

static func level(experience: int) -> int:
	return mini(500, 1 + floori(sqrt(float(maxi(0, experience)) / 80.0)))

static func rewards(report: Dictionary, difficulty: String) -> Dictionary:
	var waves := number(report.get("wave"), 150)
	var kills := number(report.get("kills"), 5000)
	var bosses := number(report.get("bosses"), 30)
	var seconds := number(report.get("seconds"), 3600)
	var victory: bool = report.get("victory", false)
	var factor := 1.28 if difficulty == "expert" else (0.85 if difficulty == "discovery" else 1.0)
	var active: bool = report.get("participated", true) and (kills > 0 or waves > 0)
	if report.has("outcome"):
		var effort := mini(80, kills * 3 + number(report.get("objectives"), 120) / 3)
		if not report.get("participated", false) or seconds < 30 or effort < 3:
			return {"coins": 0, "xp": 0}
		return {"coins": mini(125, floori((effort * 0.68 + (14 if victory else 2)) * factor)),
			"xp": mini(340, floori((effort * 2.0 + minf(seconds, 600) * 0.10 + (40 if victory else 0)) * factor))}
	var coins := floori((waves * 7.0 + kills * 0.9 + bosses * 9.0 + (35 if victory else 0)) * factor) if active else 0
	var xp := floori((waves * 16.0 + kills * 2.7 + bosses * 21.0 + seconds * 0.18 + (80 if victory else 0)) * factor) if active else 0
	return {"coins": mini(1800, coins), "xp": mini(5000, xp)}

func settle(id: String, mode: String, difficulty: String, report: Dictionary) -> Dictionary:
	if id.is_empty() or id.length() > 64 or id in data.settled or mode == "training":
		return {"ok": false, "message": "Session déjà réglée ou hors progression."}
	var reward := rewards(report, difficulty)
	data.settled.append(id)
	if data.settled.size() > 128:
		data.settled.pop_front()
	data.coins = mini(CAP, data.coins + reward.coins)
	data.xp = mini(CAP, data.xp + reward.xp)
	if not data.modes.has(mode):
		data.modes[mode] = _stats({})
	for stats in [data.stats, data.modes[mode]]:
		_add_stats(stats, report)
	for weapon in report.get("mastery", {}):
		if Arms.index_of(weapon) >= 0:
			data.mastery[weapon] = mini(100000, int(data.mastery.get(weapon, 0)) + number(report.mastery[weapon], 2500))
	refresh_contracts()
	for key in CONTRACTS:
		var gain := 0
		if reward.xp > 0:
			gain = 1 if key == "runs" else number(report.get("wave" if key == "waves" else key))
		data.contracts.progress[key] = mini(CONTRACTS[key].goal, data.contracts.progress[key] + gain)
	reward.badges = Career.record(data, mode, difficulty, report, reward)
	if data.stats.best_wave >= 50 and not owns("skin_aurora"):
		data.owned.append("skin_aurora")
	reward.ok = true
	return reward

func _add_stats(stats: Dictionary, report: Dictionary) -> void:
	stats.runs = mini(CAP, stats.runs + 1)
	var result := "ties" if report.get("outcome", "") == "égalité" else ("wins" if report.get("victory", false) else "losses")
	stats[result] = mini(CAP, stats[result] + 1)
	for key in ["kills", "deaths", "objectives", "bosses", "shots", "hits", "seconds", "credits", "spent"]:
		stats[key] = mini(CAP, stats[key] + number(report.get(key)))
	stats.hits = mini(stats.hits, stats.shots)
	var wave := number(report.get("wave"))
	stats.waves = mini(CAP, stats.waves + wave)
	stats.best_wave = maxi(stats.best_wave, wave)

func claim(contract: String) -> Dictionary:
	refresh_contracts()
	if not CONTRACTS.has(contract) or data.contracts.claimed[contract] or data.contracts.progress[contract] < CONTRACTS[contract].goal:
		return {"ok": false, "message": "Contrat incomplet ou déjà encaissé."}
	var reward: Dictionary = CONTRACTS[contract]
	data.contracts.claimed[contract] = true
	data.coins = mini(CAP, data.coins + reward.coins)
	data.xp = mini(CAP, data.xp + reward.xp)
	Career.transaction(data.career, "Contrat · " + reward.name, reward.coins)
	return {"ok": true, "message": "+%d pièces · +%d XP" % [reward.coins, reward.xp]}

func claim_weekly() -> Dictionary:
	refresh_contracts()
	var current: Dictionary = data.career.weekly
	var challenge := Career.challenge(current.period)
	if current.claimed or current.value < challenge[2]:
		return {"ok": false, "message": "Défi hebdomadaire incomplet ou déjà encaissé."}
	current.claimed = true
	data.coins = mini(CAP, data.coins + 70)
	data.xp = mini(CAP, data.xp + 150)
	Career.transaction(data.career, challenge[0], 70)
	return {"ok": true, "message": "+70 pièces · +150 XP"}
