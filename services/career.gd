extends RefCounted

const Arms := preload("res://game/weapons/catalog.gd")
const Presets := {
	"poly": {"name": "Polyvalent", "slots": ["wp_pulse", "wp_volt", "wp_prism", "wp_nova"], "gadget": "gd_dash", "module": ""},
	"range": {"name": "Précision", "slots": ["wp_eclipse", "wp_stellar", "wp_prism", "wp_pulse"], "gadget": "gd_dash", "module": "mod_cycle"},
	"move": {"name": "Mobilité", "slots": ["wp_ion", "wp_volt", "wp_pulse", "wp_prism"], "gadget": "gd_dash", "module": "mod_cycle"},
	"guard": {"name": "Défense", "slots": ["wp_mortar", "wp_nova", "wp_ion", "wp_pulse"], "gadget": "gd_aegis", "module": "mod_rack"},
}
const Modes := ["survival", "short", "endless", "trial", "coop", "boss_rush", "classic", "teams", "capture", "domination", "gungame"]
const Badges := {
	"sortie": ["Première extraction", "Terminer une opération victorieuse."],
	"twenty": ["Architecte du retour", "Sécuriser vingt vagues dans la même partie."],
	"century": ["Centurion", "Sécuriser cent vagues au total."],
	"crew": ["Escouade", "Gagner une partie coop."],
	"range": ["Visée froide", "Réussir 20 tirs avec au moins 80 % de précision en opération."],
	"sector": ["Cartographe", "Terminer des opérations sur cinq arènes différentes."],
	"frontier": ["Au-delà du secteur", "Atteindre la vague 25."],
	"aurora": ["Aurore", "Atteindre la vague 50 et obtenir la finition Aurore."],
	"seventy_five": ["Horizon", "Atteindre la vague 75."],
	"hundred": ["Sentinelle", "Atteindre la vague 100."],
}
const Challenges := [
	["Semaine · Secteurs sécurisés", "wave", 25],
	["Semaine · Neutralisations", "kills", 90],
	["Semaine · Extractions", "victory", 3],
	["Semaine · Tirs confirmés", "hits", 150],
]
const Weeks := 604800

static func week() -> int:
	return floori((Time.get_unix_time_from_system() + 259200.0) / Weeks)

static func challenge(period: int) -> Array:
	return Challenges[posmod(period, Challenges.size())]

static func sanitize(raw: Variant, owned: Array, parse_number: Callable) -> Dictionary:
	var input: Dictionary = raw if raw is Dictionary else {}
	var list: Array = []
	var history: Variant = input.get("history")
	if history is Array:
		for row in history.slice(0, 32):
			if not row is Dictionary or row.get("mode") not in Modes or not row.get("map") is String:
				continue
			var run := {"mode": row.mode, "map": String(row.map).substr(0, 20),
				"difficulty": row.get("difficulty") if row.get("difficulty") in ["discovery", "standard", "expert"] else "standard",
				"rules": String(row.get("rules", "")).substr(0, 20), "victory": row.get("victory") == true}
			for key in ["seed", "score", "seconds", "coins", "xp", "kills", "wave"]:
				run[key] = parse_number.call(row.get(key), 4294967295 if key == "seed" else 1000000000)
			list.append(run)
	var receipts: Array = []
	var ledger: Variant = input.get("ledger")
	if ledger is Array:
		for row in ledger.slice(0, 48):
			if not row is Dictionary or not row.get("id") is String or not row.get("label") is String:
				continue
			var amount: Variant = row.get("amount", 0)
			receipts.append({"id": row.id.substr(0, 64), "label": row.label.substr(0, 64),
				"amount": clampi(roundi(amount), -9999, 9999) if typeof(amount) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(amount)) else 0})
	var badges: Array = []
	for id in Badges:
		if input.get("badges") is Array and id in input.badges:
			badges.append(id)
	var maps: Array[String] = []
	if input.get("maps") is Array:
		for id in input.maps.slice(0, 16):
			if id is String and id.length() <= 20 and id not in maps:
				maps.append(id)
	var source: Variant = input.get("weekly")
	var stored: Dictionary = source if source is Dictionary else {}
	var period: int = maxi(week(), parse_number.call(stored.get("period"), 200000))
	var current := {"period": period, "value": 0, "claimed": false}
	if stored.get("period") == period:
		current.value = parse_number.call(stored.get("value"), challenge(period)[2])
		current.claimed = stored.get("claimed") == true
	var saved: Variant = input.get("saved")
	var own := {}
	if saved is Dictionary and not saved.is_empty():
		own = {"slots": Arms.normalize_slots(saved.get("slots"), owned),
			"gadget": saved.get("gadget") if saved.get("gadget") in owned and String(saved.gadget).begins_with("gd_") else "gd_dash",
			"module": saved.get("module") if saved.get("module") in owned and String(saved.module).begins_with("mod_") else ""}
	return {"history": list, "ledger": receipts, "badges": badges, "maps": maps, "weekly": current, "saved": own}

static func refresh(career: Dictionary) -> void:
	var now := week()
	if now > career.weekly.period:
		career.weekly = {"period": now, "value": 0, "claimed": false}

static func transaction(career: Dictionary, label: String, amount: int) -> void:
	if amount == 0:
		return
	career.ledger.push_front({"id": Crypto.new().generate_random_bytes(12).hex_encode(), "label": label, "amount": amount})
	if career.ledger.size() > 48:
		career.ledger.resize(48)

static func record(data: Dictionary, mode: String, difficulty: String, report: Dictionary, reward: Dictionary) -> Array[String]:
	var career: Dictionary = data.career
	var map: String = report.get("map", "reactor")
	var run := {"mode": mode, "map": map, "difficulty": difficulty, "seed": report.get("seed", 0),
		"rules": report.get("rules", ""), "score": report.score, "seconds": report.get("seconds", 0),
		"kills": report.get("kills", 0), "wave": report.get("wave", 0),
		"victory": report.get("victory", false), "coins": reward.coins, "xp": reward.xp}
	career.history.push_front(run)
	if career.history.size() > 32:
		career.history.resize(32)
	if map not in career.maps:
		career.maps.append(map)
	transaction(career, "Bilan · " + map.capitalize(), reward.coins)
	refresh(career)
	var goal := challenge(career.weekly.period)
	if reward.xp > 0:
		career.weekly.value = mini(goal[2], career.weekly.value + int(report.get(goal[1], 0)))
	var conditions := {"sortie": data.stats.wins > 0, "twenty": data.stats.best_wave >= 20,
		"century": data.stats.waves >= 100, "crew": mode == "coop" and run.victory,
		"range": report.get("shots", 0) >= 20 and report.get("accuracy", 0) >= 80,
		"sector": career.maps.size() >= 5}
	for threshold in [["frontier", 25], ["aurora", 50], ["seventy_five", 75], ["hundred", 100]]:
		conditions[threshold[0]] = data.stats.best_wave >= threshold[1]
	var earned: Array[String] = []
	for id in conditions:
		if conditions[id] and id not in career.badges:
			career.badges.append(id)
			earned.append(Badges[id][0])
	return earned
