extends RefCounted

const DEFAULT_LOADOUT := ["wp_pulse", "wp_volt", "wp_prism", "wp_nova"]
const WEAPONS := [
	{"id": "wp_pulse", "name": "AR-24", "tag": "CARABINE", "class": "Automatique", "mode": "auto",
		"tint": Color("#dfc29b"), "mag": 24, "damage": 24.0, "range": 68.0, "cadence": 0.12,
		"reload": 1.05, "heat": 0.068, "sound": "pulse", "price": 0,
		"info": "Carabine d’assaut, 24 cartouches. Pour les distances courtes à moyennes."},
	{"id": "wp_volt", "name": "M7 Pompe", "tag": "FUSIL À POMPE", "class": "Fusil à pompe", "mode": "spread",
		"tint": Color("#ddbf91"), "mag": 7, "damage": 15.0, "range": 21.0, "cadence": 0.56,
		"reload": 1.3, "heat": 0.13, "sound": "volt", "price": 0,
		"info": "Sept plombs par cartouche. La dispersion augmente vite à distance."},
	{"id": "wp_prism", "name": "P9 Rafale", "tag": "PISTOLET", "class": "Pistolet", "mode": "burst",
		"tint": Color("#e1c49e"), "mag": 21, "damage": 31.0, "range": 83.0, "cadence": 0.40,
		"reload": 1.19, "heat": 0.057, "sound": "prism", "price": 0,
		"info": "Pistolet 9 mm à rafales de trois coups. Léger et rapide à manipuler."},
	{"id": "wp_nova", "name": "GL-40", "tag": "LANCE-GRENADES", "class": "Lance-grenades", "mode": "nova",
		"tint": Color("#cdb68e"), "mag": 5, "damage": 138.0, "range": 68.0, "cadence": 0.67,
		"reload": 1.52, "heat": 0.19, "sound": "nova", "price": 0,
		"info": "Maintenez le tir pour préparer le lancer, puis relâchez pour envoyer la grenade."},
	{"id": "wp_eclipse", "name": "DMR-762", "tag": "LUNETTE ×2 / ×4", "class": "Précision", "mode": "rail",
		"tint": Color("#d7c2a1"), "mag": 5, "damage": 151.0, "range": 128.0, "cadence": 0.83,
		"reload": 1.62, "heat": 0.17, "sound": "rail", "price": 110, "zoom": [2.0, 4.0],
		"info": "Fusil semi-automatique de précision. Deux grossissements, ×2 et ×4."},
	{"id": "wp_stellar", "name": "R700", "tag": "FUSIL À VERROU", "class": "Précision", "mode": "lance",
		"tint": Color("#e6cbaa"), "mag": 4, "damage": 275.0, "range": 147.0, "cadence": 0.54,
		"reload": 1.94, "heat": 0.21, "sound": "lance", "price": 160, "zoom": [1.6, 3.6],
		"info": "Maintenez pour stabiliser la visée, puis relâchez pour tirer. La lunette grossit pendant la stabilisation."},
	{"id": "wp_ion", "name": "SMG-42", "tag": "MITRAILLETTE", "class": "Mitraillette", "mode": "stream",
		"tint": Color("#d9c398"), "mag": 42, "damage": 11.0, "range": 28.0, "cadence": 0.052,
		"reload": 1.38, "heat": 0.091, "sound": "ion", "price": 85,
		"info": "Mitraillette à cadence élevée. Tirez par courtes rafales pour limiter la chauffe."},
	{"id": "wp_mortar", "name": "GL-6", "tag": "LANCE-GRENADES À BARILLET", "class": "Lance-grenades", "mode": "mortar",
		"tint": Color("#d8ad78"), "mag": 6, "damage": 103.0, "range": 42.0, "cadence": 0.71,
		"reload": 1.62, "heat": 0.20, "sound": "mortar", "price": 125,
		"info": "Six grenades à trajectoire courbe. Les obstacles protègent du souffle."},
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
