extends RefCounted

# Coordinates are normalized inside the game's safe rectangle.
const CONTROLS := {
	"stick": [0.113, 0.725, 58.0, "Mouvement", "••"],
	"fire": [0.935, 0.610, 41.0, "Tir", "TIR"],
	"ads": [0.850, 0.610, 34.0, "Visée", "VISÉE"],
	"jump": [0.855, 0.755, 36.0, "Saut", "SAUT"],
	"crouch": [0.935, 0.755, 34.0, "Glissade", "BAS"],
	"sprint": [0.208, 0.735, 34.0, "Sprint", "COURSE"],
	"reload": [0.760, 0.755, 34.0, "Recharger", "RECH."],
	"gadget": [0.760, 0.610, 34.0, "Gadget", "GADG."],
	"interact": [0.935, 0.470, 34.0, "Interagir", "ACTION"],
	"next": [0.935, 0.337, 34.0, "Arme suivante", "ARME"],
	"zoom": [0.850, 0.472, 33.0, "Zoom", "ZOOM"],
	"stats": [0.760, 0.474, 33.0, "Journal", "STATS"],
	"pause": [0.935, 0.222, 32.0, "Pause", "II"],
}

static func defaults() -> Dictionary:
	var layout := {}
	for id in CONTROLS:
		var spec: Array = CONTROLS[id]
		layout[id] = {"x": spec[0], "y": spec[1], "size": 1.0, "opacity": 0.82}
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
