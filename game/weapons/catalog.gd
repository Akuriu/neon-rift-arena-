extends RefCounted

const DEFAULT_LOADOUT := ["wp_pulse", "wp_volt", "wp_prism", "wp_nova"]
const WEAPONS := [
	{"id": "wp_pulse", "name": "Pulse-7", "tag": "IMPULSIONS", "class": "Automatique", "mode": "auto",
		"tint": Color("#60e5ff"), "mag": 24, "damage": 24.0, "range": 68.0, "cadence": 0.12,
		"reload": 1.05, "heat": 0.068, "sound": "pulse", "price": 0,
		"info": "Flux polyvalent. Idéal pour garder la pression tout en bougeant."},
	{"id": "wp_volt", "name": "Volt Arc", "tag": "ÉVENTAIL", "class": "Dispersion", "mode": "spread",
		"tint": Color("#ffc165"), "mag": 7, "damage": 15.0, "range": 21.0, "cadence": 0.56,
		"reload": 1.3, "heat": 0.13, "sound": "volt", "price": 0,
		"info": "Sept arcs par décharge. Les éventails se dispersent à distance."},
	{"id": "wp_prism", "name": "Prism Burst", "tag": "RAFALE TRIPLE", "class": "Rafale", "mode": "burst",
		"tint": Color("#ff80cb"), "mag": 21, "damage": 31.0, "range": 83.0, "cadence": 0.40,
		"reload": 1.19, "heat": 0.057, "sound": "prism", "price": 0,
		"info": "Trois impulsions rapides par pression. Précis à moyenne distance."},
	{"id": "wp_nova", "name": "Nova Charge", "tag": "NOYAU CHARGÉ", "class": "Zone", "mode": "nova",
		"tint": Color("#a6a2ff"), "mag": 5, "damage": 138.0, "range": 68.0, "cadence": 0.67,
		"reload": 1.52, "heat": 0.19, "sound": "nova", "price": 0,
		"info": "Maintenez le tir pour charger un noyau explosif, puis relâchez."},
	{"id": "wp_eclipse", "name": "Eclipse Rail", "tag": "LUNETTE ×2 / ×4", "class": "Précision", "mode": "rail",
		"tint": Color("#7cffed"), "mag": 5, "damage": 151.0, "range": 128.0, "cadence": 0.83,
		"reload": 1.62, "heat": 0.17, "sound": "rail", "price": 110, "zoom": [2.0, 4.0],
		"info": "Impulsion instantanée. En visée, la molette passe de ×2 à ×4 et la dispersion diminue."},
	{"id": "wp_stellar", "name": "Stellar Lance", "tag": "LUNETTE À CHARGE", "class": "Précision", "mode": "lance",
		"tint": Color("#f6caff"), "mag": 4, "damage": 275.0, "range": 147.0, "cadence": 0.54,
		"reload": 1.94, "heat": 0.21, "sound": "lance", "price": 160, "zoom": [1.6, 3.6],
		"info": "Maintenez puis relâchez le tir. Le zoom progresse pendant la charge. Efficace sur un point faible."},
	{"id": "wp_ion", "name": "Ion Repeater", "tag": "FLUX CONTINU", "class": "Soutien", "mode": "stream",
		"tint": Color("#aaf17d"), "mag": 42, "damage": 11.0, "range": 28.0, "cadence": 0.052,
		"reload": 1.38, "heat": 0.091, "sound": "ion", "price": 85,
		"info": "Flux à portée courte. La chaleur accumulée impose de relâcher régulièrement."},
	{"id": "wp_mortar", "name": "Arc Mortar", "tag": "ORBE INCURVÉ", "class": "Zone", "mode": "mortar",
		"tint": Color("#ffab83"), "mag": 6, "damage": 103.0, "range": 42.0, "cadence": 0.71,
		"reload": 1.62, "heat": 0.20, "sound": "mortar", "price": 125,
		"info": "Orbe lobé à courbe courte. La zone énergétique est bloquée par le décor."},
]

static func index_of(id: String) -> int:
	for index in WEAPONS.size():
		if WEAPONS[index].id == id:
			return index
	return -1

static func normalize_slots(raw: Variant, owned: Array) -> Array[String]:
	var result: Array[String] = []
	if raw is Array:
		for id in raw.slice(0, 4):
			if id is String and id in owned and index_of(id) >= 0 and id not in result:
				result.append(id)
	for id in DEFAULT_LOADOUT:
		if result.size() == 4:
			break
		if id not in result:
			result.append(id)
	return result
