extends RefCounted

const LABELS := {"gungame": "Gun Game", "classic": "Chacun pour soi", "teams": "Match en équipes",
	"capture": "Capture", "domination": "Domination"}
const DURATIONS := [180, 300, 600, 900]
const TARGETS := [10, 20, 35, 60, 100]
const DEFAULTS := {"bots": 6, "duration": 300, "target": 20}

static func normalize(raw: Dictionary, mode: String) -> Dictionary:
	var duration: int = raw.get("duration", DEFAULTS.duration)
	var target: int = raw.get("target", DEFAULTS.target)
	return {"bots": clampi(int(raw.get("bots", DEFAULTS.bots)), 0, 12),
		"duration": duration if duration in DURATIONS else DEFAULTS.duration,
		"target": 8 if mode == "gungame" else (target if target in TARGETS else (60 if mode in ["capture", "domination"] else DEFAULTS.target))}

static func key(options: Dictionary) -> String:
	return "%d-%d-%d" % [options.bots, options.duration, options.target]

static func valid_key(value: String) -> bool:
	var parts := value.split("-")
	return parts.size() == 3 and parts[0].is_valid_int() and int(parts[0]) in range(0, 13) \
		and str(int(parts[0])) == parts[0] and parts[1].is_valid_int() and int(parts[1]) in DURATIONS \
		and str(int(parts[1])) == parts[1] and parts[2].is_valid_int() and (int(parts[2]) in TARGETS or int(parts[2]) == 8) \
		and str(int(parts[2])) == parts[2]
