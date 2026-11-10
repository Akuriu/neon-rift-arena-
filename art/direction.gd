extends Node

signal changed

const Materials := preload("res://art/materials.gd")
const HUD_TINTS := [Color("#f2f1e8"), Color("#b0c2ce"), Color("#d8b688"), Color("#c3c8a8")]
const DANGER := Color("#d87b64")
const PALETTE := {"ui": Color("#dabb85"), "page": Color("#181a18"), "dark": Color("#292d27")}
const DAY := {
	"sky": Color("#8fa7b5"), "horizon": Color("#d4d3c4"), "sun": Color("#fff0d8"),
	"ambient": Color("#c5c9c4"), "floor": Color("#9a9b8b"), "seam": Color("#66645a"),
	"angle": Vector3(-39, -32, 0), "power": 0.99, "mist": 0.0022,
}
const MAP_NOTES := {
	"reactor": {"floor": Color("#a2a095"), "weather": "dust", "ground": "concrete"},
	"skyline": {"floor": Color("#696a63"), "sun": Color("#ffe0b9"), "angle": Vector3(-30, 29, 0),
		"horizon": Color("#ded5c2"), "weather": "dust", "ground": "gravel"},
	"cryo": {"floor": Color("#969c9c"), "ambient": Color("#c4cfd8"), "sun": Color("#eef4ff"),
		"angle": Vector3(-54, -60, 0), "weather": "snow", "ground": "concrete"},
	"bastion": {"floor": Color("#b2a382"), "sky": Color("#a0b9c4"), "weather": "dust", "ground": "gravel"},
	"district": {"floor": Color("#aba89c"), "angle": Vector3(-41, 18, 0), "weather": "dust", "ground": "concrete"},
	"grove": {"floor": Color("#928663"), "sun": Color("#efe8c5"), "ambient": Color("#bbc9b9"),
		"weather": "dust", "ground": "gravel"},
	"station": {"floor": Color("#aab0ad"), "ambient": Color("#d2d0c6"), "sun": Color("#eff1ea"),
		"weather": "", "ground": "concrete"},
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
