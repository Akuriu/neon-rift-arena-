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
	"sprint": [0.205, 0.581, 35.0, "Sprint", ""],
	"gadget": [0.709, 0.764, 30.0, "Gadget", "Kit"],
	"stats": [0.056, 0.220, 27.0, "Bilan", "Bilan"],
}
const SECONDARY := ["crouch", "gadget", "stats"]
const PRIMARY := ["stick", "fire", "ads", "jump", "sprint", "next"]
const AMMO_WIDTH := 1.65

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

static func radius(id: String, entry: Dictionary, extent: Vector2) -> float:
	return CONTROLS[id][2] * entry.size * minf(extent.x / 1280.0, extent.y / 720.0)

static func center(id: String, entry: Dictionary, extent: Vector2, left_handed: bool) -> Vector2:
	var size := radius(id, entry, extent)
	var margin := Vector2(size * AMMO_WIDTH if id == "reload" else size, size)
	var x: float = 1.0 - entry.x if left_handed else entry.x
	return (Vector2(x, entry.y) * extent).clamp(margin, extent - margin)

static func hit_distance(id: String, offset: Vector2, size: float) -> float:
	var local := offset / maxf(1.0, size)
	return maxf(absf(local.x) / AMMO_WIDTH, absf(local.y)) if id == "reload" else local.length()

static func overlaps(a: String, a_center: Vector2, a_radius: float, b: String, b_center: Vector2, b_radius: float) -> bool:
	if a == "reload" or b == "reload":
		var offset := (a_center - b_center).abs()
		var ammo_radius := a_radius if a == "reload" else b_radius
		var other_radius := b_radius if a == "reload" else a_radius
		var nearest := (offset - Vector2(AMMO_WIDTH, 1.0) * ammo_radius).max(Vector2.ZERO)
		return nearest.length_squared() < other_radius * other_radius
	return a_center.distance_squared_to(b_center) < pow(a_radius + b_radius, 2.0)
