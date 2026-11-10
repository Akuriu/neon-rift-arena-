extends RefCounted

# Coordinates are normalized inside the safe play area, independently of aspect ratio.
const CONTROLS := {
	"stick": [0.124, 0.743, 62.0, "Joystick", ""],
	"fire": [0.913, 0.622, 47.0, "Tirer", ""],
	"ads": [0.806, 0.698, 34.0, "Viser", ""],
	"jump": [0.910, 0.804, 35.0, "Saut / glissade", ""],
	"next": [0.767, 0.897, 33.0, "Changer d’arme", ""],
	"reload": [0.906, 0.935, 32.0, "Munitions / recharge", ""],
	"interact": [0.697, 0.635, 33.0, "Interagir", "Prendre"],
	"zoom": [0.792, 0.522, 28.0, "Grossissement", "×2"],
	"pause": [0.950, 0.082, 32.0, "Pause", ""],
	"crouch": [0.964, 0.799, 26.0, "S’accroupir", "Bas"],
	"sprint": [0.203, 0.593, 30.0, "Sprint", "Sprint"],
	"gadget": [0.709, 0.764, 30.0, "Gadget", "Kit"],
	"stats": [0.056, 0.220, 27.0, "Bilan", "Bilan"],
}
const SECONDARY := ["crouch", "sprint", "gadget", "stats"]

static func defaults() -> Dictionary:
	var layout := {}
	for id in CONTROLS:
		var spec: Array = CONTROLS[id]
		layout[id] = {"x": spec[0], "y": spec[1], "size": 1.0, "opacity": 0.87}
	return layout

static func normalize(raw: Variant) -> Dictionary:
	var layout := defaults()
	if not raw is Dictionary:
		return layout
	for id in CONTROLS:
		var choice: Variant = raw.get(id)
		if not choice is Dictionary:
			continue
		for key in ["x", "y", "size", "opacity"]:
			var value: Variant = choice.get(key)
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
				continue
			match key:
				"x", "y": layout[id][key] = clampf(value, 0.04, 0.96)
				"size": layout[id][key] = clampf(value, 0.70, 1.48)
				"opacity": layout[id][key] = clampf(value, 0.35, 1.0)
	return layout
