extends Node

signal changed

const Materials := preload("res://art/materials.gd")
const HUD_TINTS := [Color("#f2f1e8"), Color("#b0c2ce"), Color("#d8b688"), Color("#c3c8a8")]
const DANGER := Color("#d87b64")
const PALETTE := {"ui": Color("#dabb85"), "page": Color("#181a18"), "dark": Color("#292d27")}
const DAY := {
	"sky": Color("#8fa7b5"), "horizon": Color("#d4d3c4"), "sun": Color("#fff0d8"),
	"ambient": Color("#c5c9c4"), "floor": Color("#9a9b8b"), "seam": Color("#66645a"),
	"angle": Vector3(-39, -32, 0), "power": 1.04, "mist": 0.0022, "fill": 0.68,
	"wear": Color("#b3a697"), "utility": Color("#f1d6a3"), "clouds": 0.24,
}
const MAP_NOTES := {
	"reactor": {"floor": Color("#a6a597"), "sky": Color("#7c9ba9"), "wear": Color("#9c8372"),
		"angle": Vector3(-43, -34, 0), "weather": "dust", "ground": "concrete"},
	"skyline": {"floor": Color("#858477"), "sky": Color("#829fa8"), "sun": Color("#ffdfad"),
		"ambient": Color("#b5c6c7"), "angle": Vector3(-25, 32, 0), "horizon": Color("#ecd8b4"),
		"wear": Color("#a98f6c"), "power": 1.18, "clouds": 0.36, "weather": "dust", "ground": "gravel"},
	"cryo": {"floor": Color("#a4b1b6"), "sky": Color("#899fb4"), "ambient": Color("#bbd1e3"),
		"horizon": Color("#c3d7df"), "sun": Color("#e7f1ff"), "utility": Color("#b5dcf4"),
		"wear": Color("#c2d0d4"), "angle": Vector3(-48, -58, 0), "mist": 0.0034, "clouds": 0.43,
		"weather": "snow", "ground": "concrete"},
	"bastion": {"floor": Color("#b8a17d"), "sky": Color("#8eb2c4"), "horizon": Color("#e1d4ad"),
		"sun": Color("#ffe3b1"), "wear": Color("#8f7150"), "angle": Vector3(-42, -12, 0),
		"power": 1.23, "clouds": 0.13, "weather": "dust", "ground": "gravel"},
	"district": {"floor": Color("#aba395"), "sky": Color("#9da9ad"), "ambient": Color("#c5c3be"),
		"sun": Color("#ffdfc1"), "wear": Color("#a48a78"), "angle": Vector3(-38, 23, 0),
		"clouds": 0.41, "weather": "dust", "ground": "concrete"},
	"grove": {"floor": Color("#9e906b"), "sky": Color("#8aa79c"), "horizon": Color("#ded4ae"),
		"sun": Color("#fff0c1"), "ambient": Color("#b6c7a8"), "wear": Color("#768861"),
		"angle": Vector3(-33, -44, 0), "mist": 0.0031, "weather": "dust", "ground": "gravel"},
	"station": {"floor": Color("#b0b4ac"), "ambient": Color("#c5d0d4"), "sun": Color("#f7efdb"),
		"wear": Color("#86999b"), "utility": Color("#d1e0ee"), "fill": 0.84, "weather": "", "ground": "concrete"},
}

var catalog := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Prefs.changed.connect(_changed)

func palette() -> Dictionary:
	return PALETTE

func world(map_id: String) -> Dictionary:
	var colors := DAY.duplicate()
	colors.merge(MAP_NOTES.get(map_id, MAP_NOTES.reactor), true)
	return colors

func hud_color() -> Color:
	return HUD_TINTS[Prefs.values.hud_tone]

func effect_color(tint: Color) -> Color:
	return tint.lerp(Color("#eed1a0"), 0.42)

func surface(source: StandardMaterial3D) -> StandardMaterial3D:
	var key := source.get_instance_id()
	if catalog.has(key):
		return catalog[key]
	var paint: StandardMaterial3D = source.duplicate()
	var base := source.albedo_color
	var marking := source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.shading_mode = _shading()
	paint.emission_enabled = false
	if marking:
		var value := base.get_luminance()
		paint.albedo_color = Color("#ada896").lerp(Color("#d9ceb1"), smoothstep(0.3, 0.83, value))
		if base.r > base.b * 1.20 and base.s > 0.27:
			paint.albedo_color = Color("#c39d54")
	elif paint.albedo_texture == null:
		var material := Materials.finish(base, "steel" if source.metallic >= 0.22 else "concrete", 0.66)
		paint.albedo_texture = material.albedo_texture
		paint.uv1_scale = material.uv1_scale
		paint.uv1_triplanar = true
		paint.uv1_world_triplanar = true
		paint.albedo_color = base.lerp(Color(base.get_luminance(), base.get_luminance(), base.get_luminance()), 0.18)
	paint.roughness = 0.62 if not marking and paint.metallic >= 0.22 else maxf(paint.roughness, 0.83)
	catalog[key] = paint
	return paint

func _shading() -> BaseMaterial3D.ShadingMode:
	return BaseMaterial3D.SHADING_MODE_PER_VERTEX if Prefs.values.quality in [0, 3] else BaseMaterial3D.SHADING_MODE_PER_PIXEL

func _changed(key: String) -> void:
	if key in ["quality", "all"]:
		for paint in catalog.values():
			paint.shading_mode = _shading()
	if key in ["all", "quality", "fog", "weather", "hud_tone", "high_contrast"]:
		changed.emit()
