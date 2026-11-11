extends RefCounted

const IDS := ["yard", "gantry", "roofs"]
const MEDAL_TIMES := {"yard": [5500, 8000, 14000], "gantry": [6500, 10000, 17000], "roofs": [10000, 15000, 23000]}
const MEDALS := ["Or", "Argent", "Bronze"]
const ROUTES := {
	"yard": {"name": "Cour d’initiation", "level": "DÉBUTANT", "width": 5.8,
		"copy": "Une ligne lisible, trois haies basses. Apprenez à enchaîner sprint et saut.",
		"points": [Vector3(0, 0.04, 17), Vector3(0, 0.04, 11), Vector3(0, 0.04, 5),
			Vector3(0, 0.04, -1), Vector3(0, 0.04, -7), Vector3(0, 0.04, -13), Vector3(0, 0.04, -18)]},
	"gantry": {"name": "Passerelles de service", "level": "INTERMÉDIAIRE", "width": 4.6,
		"copy": "Des plateformes espacées et de légers dénivelés. Gardez votre élan.",
		"points": [Vector3(0, 0.04, 17), Vector3(-1.3, 0.29, 12), Vector3(1.3, 0.54, 6.4),
			Vector3(-1.3, 0.79, 0.8), Vector3(1.3, 0.54, -4.8), Vector3(0, 0.29, -10.4), Vector3(0, 0.04, -16)]},
	"roofs": {"name": "Ligne des toits", "level": "EXPERT", "width": 2.7,
		"copy": "Des appuis étroits en quinconce. Préparez chaque impulsion et visez votre réception.",
		"points": [Vector3(0, 0.04, 17), Vector3(-1.8, 0.29, 12), Vector3(1.8, 0.54, 6.8),
			Vector3(-1.8, 0.79, 1.6), Vector3(1.8, 1.04, -3.6), Vector3(-1.8, 0.64, -8.8),
			Vector3(1, 0.34, -14), Vector3(0, 0.04, -19.2)]},
}

static func normalize(id: Variant) -> String:
	return id if id is String and id in IDS else "yard"

static func clock(milliseconds: int) -> String:
	return "%02d:%05.2f" % [milliseconds / 60000, fmod(milliseconds / 1000.0, 60.0)]

static func medal(id: String, milliseconds: int) -> String:
	if milliseconds <= 0:
		return ""
	var thresholds: Array = MEDAL_TIMES[id]
	for index in thresholds.size():
		if milliseconds <= thresholds[index]:
			return MEDALS[index]
	return ""
