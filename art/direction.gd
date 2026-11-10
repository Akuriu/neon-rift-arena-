extends Node

signal changed

const LABELS := ["Classique / Normal", "Néon raffiné", "Cinématique", "Arcade coloré"]
const HUD_TINTS := [Color("#dcebe3"), Color("#80e0f1"), Color("#f1ca8a"), Color("#e5cfed")]
const DANGER := Color("#ef8c62")
const THEMES := [
	{"sky": Color("#79abc7"), "horizon": Color("#d8e1d9"), "sun": Color("#fff0ce"), "ambient": Color("#c2d1d9"),
		"dark": Color("#353e39"), "stone": Color("#b6b5a1"), "steel": Color("#7b8886"), "warm": Color("#a37146"),
		"floor": Color("#818378"), "seam": Color("#535a51"), "accent": Color("#568373"), "ui": Color("#a0ccb2"),
		"page": Color("#17241f"), "angle": Vector3(-51, -31, 0), "power": 1.20},
	{"sky": Color("#182840"), "horizon": Color("#6e8997"), "sun": Color("#e7b99b"), "ambient": Color("#b8d8ee"),
		"dark": Color("#172736"), "stone": Color("#536a76"), "steel": Color("#43616d"), "warm": Color("#aa6749"),
		"floor": Color("#485d68"), "seam": Color("#273641"), "accent": Color("#4fbfaf"), "ui": Color("#76e1d4"),
		"page": Color("#101e29"), "angle": Vector3(-43, -25, 0), "power": 1.08},
	{"sky": Color("#496378"), "horizon": Color("#ccb18b"), "sun": Color("#ffd5a4"), "ambient": Color("#aabed3"),
		"dark": Color("#303941"), "stone": Color("#a7a18d"), "steel": Color("#667b86"), "warm": Color("#946a51"),
		"floor": Color("#62696a"), "seam": Color("#414d55"), "accent": Color("#c29859"), "ui": Color("#e8c891"),
		"page": Color("#242631"), "angle": Vector3(-25, 39, 0), "power": 1.26},
	{"sky": Color("#66b7df"), "horizon": Color("#cbe6ed"), "sun": Color("#fff0b7"), "ambient": Color("#b9ddf1"),
		"dark": Color("#314d72"), "stone": Color("#dfc798"), "steel": Color("#6385a9"), "warm": Color("#d28363"),
		"floor": Color("#8c9ca0"), "seam": Color("#526f83"), "accent": Color("#59aa85"), "ui": Color("#90e2b9"),
		"page": Color("#192b42"), "angle": Vector3(-62, -54, 0), "power": 1.16},
]
const MAP_NOTES := {
	"reactor": {"tone": Color("#b6b39a"), "angle": Vector3.ZERO, "mist": 0.0024, "weather": "dust"},
	"skyline": {"tone": Color("#baa083"), "angle": Vector3(11, 31, 0), "mist": 0.0034, "weather": "dust"},
	"cryo": {"tone": Color("#869da1"), "angle": Vector3(-8, -14, 0), "mist": 0.0037, "weather": "snow"},
	"bastion": {"tone": Color("#bbad83"), "angle": Vector3(4, 27, 0), "mist": 0.0026, "weather": "dust"},
	"district": {"tone": Color("#b0a89b"), "angle": Vector3(6, -26, 0), "mist": 0.0021, "weather": "dust"},
	"grove": {"tone": Color("#869377"), "angle": Vector3(-5, 16, 0), "mist": 0.0032, "weather": "dust"},
	"station": {"tone": Color("#8c959b"), "angle": Vector3(0, -22, 0), "mist": 0.0014, "weather": ""},
}

var catalog := {}
var blend := 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	Prefs.changed.connect(_changed)

func palette() -> Dictionary:
	return THEMES[Prefs.values.art_style]

func world(map_id: String) -> Dictionary:
	var colors := palette().duplicate()
	var map: Dictionary = MAP_NOTES.get(map_id, MAP_NOTES.reactor)
	colors.floor = colors.floor.lerp(map.tone, 0.24)
	colors.angle += map.angle
	colors.mist = map.mist
	colors.weather = map.weather
	if map_id == "cryo":
		colors.horizon = colors.horizon.lerp(Color("#b8d3dd"), 0.35)
	elif map_id == "skyline":
		colors.horizon = colors.horizon.lerp(Color("#e0bca0"), 0.23)
	if Prefs.values.art_style == 0:
		match map_id:
			"skyline":
				colors.sky = Color("#a5bbc5")
				colors.horizon = Color("#f0d0ad")
				colors.sun = Color("#ffd8ae")
			"cryo":
				colors.ambient = Color("#b1c5df")
				colors.floor = Color("#8498a2")
				colors.sun = Color("#edf4ff")
			"bastion":
				colors.floor = Color("#b1a083")
				colors.horizon = Color("#e7d6b3")
			"grove":
				colors.floor = Color("#8c875d")
				colors.ambient = Color("#bfd5c5")
			"station":
				colors.floor = Color("#a9b1ab")
				colors.sun = Color("#eff4f1")
	return colors

func hud_color() -> Color:
	return HUD_TINTS[Prefs.values.hud_tone]

func effect_color(tint: Color) -> Color:
	return tint.lerp(Color("#e9d5bd"), 0.25) if Prefs.values.art_style == 0 else tint

func surface(source: StandardMaterial3D) -> StandardMaterial3D:
	var key := source.get_instance_id()
	if catalog.has(key):
		return catalog[key].paint
	var paint: StandardMaterial3D = source.duplicate()
	var item := {"source": source, "paint": paint, "marking": source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED}
	paint.shading_mode = _shading()
	paint.emission_enabled = item.marking
	item.goal = _target(item)
	item.start = item.goal
	item.strength = _emission(item)
	item.energy = item.strength
	catalog[key] = item
	_apply(item, 1.0)
	return paint

func _target(item: Dictionary) -> Color:
	var base: Color = item.source.albedo_color
	var scheme := palette()
	if Prefs.values.art_style == 1:
		return base.lerp(scheme.dark, 0.20) if item.marking else base
	var warm := base.r > base.b * 1.18 and base.s > 0.26
	if item.marking:
		return scheme.warm.lightened(0.18) if warm else scheme.accent
	var target: Color = scheme.dark.lerp(scheme.stone, smoothstep(0.13, 0.76, base.v))
	if warm:
		target = target.lerp(scheme.warm, 0.57)
	if base.s > 0.24:
		target = target.lerp(scheme.steel, 0.16)
	if Prefs.values.art_style == 0:
		target = target.lerp(base, 0.45)
	return target

func _shading() -> BaseMaterial3D.ShadingMode:
	return BaseMaterial3D.SHADING_MODE_PER_VERTEX if Prefs.values.quality in [0, 3] else BaseMaterial3D.SHADING_MODE_PER_PIXEL

func _emission(item: Dictionary) -> float:
	if not item.marking:
		return 0.0
	return [0.012, 0.35, 0.052, 0.085][Prefs.values.art_style] * Prefs.values.emission

func _apply(item: Dictionary, amount: float) -> void:
	var paint: StandardMaterial3D = item.paint
	paint.albedo_color = item.start.lerp(item.goal, amount)
	if item.marking:
		paint.emission = paint.albedo_color
		paint.emission_energy_multiplier = lerpf(item.energy, item.strength, amount)

func _changed(key: String) -> void:
	if key in ["quality", "all"]:
		for item in catalog.values():
			item.paint.shading_mode = _shading()
	if key not in ["all", "art_style", "emission", "fog", "weather", "hud_tone", "high_contrast"]:
		return
	if key in ["all", "art_style", "emission"]:
		for item in catalog.values():
			item.start = item.paint.albedo_color
			item.goal = _target(item)
			item.energy = item.paint.emission_energy_multiplier
			item.strength = _emission(item)
		blend = 0.0 if Prefs.values.ui_motion else 1.0
		for item in catalog.values():
			_apply(item, blend)
		set_process(blend < 1.0)
	changed.emit()

func _process(delta: float) -> void:
	blend = minf(1.0, blend + delta / 0.23)
	var amount := smoothstep(0.0, 1.0, blend)
	for item in catalog.values():
		_apply(item, amount)
	if blend >= 1.0:
		set_process(false)
