extends Node3D

const Fabric := preload("res://game/fabric.gd")
const Routes := preload("res://game/routes.gd")
const Scenery := preload("res://art/scenery.gd")
const Materials := preload("res://art/materials.gd")
const FONT := preload("res://assets/fonts/OpenSans-CondBold.ttf")
const START := Vector3(0, 0.06, 18.0)
const TERMINAL := Vector3(3.2, 1.0, 17.0)
const HALF := Vector2(26.0, 24.0)
const CYAN := Color("#9faaa1")
const GOLD := Color("#c0a16a")
const INK := Color("#555b56")
const SLATE := Color("#5e6561")
const STEEL := Color("#818781")
const WHITE := Color("#d0cdc1")
const COPPER := Color("#a65335")

var spawn_points: Array[Vector3] = [
	Vector3(-21.8, 0.04, 19.3), Vector3(21.8, 0.04, 19.3),
	Vector3(-21.8, 0.04, -19.3), Vector3(21.8, 0.04, -19.3),
	Vector3(-23.8, 0.04, 0.0), Vector3(23.8, 0.04, 0.0),
	Vector3(-6.4, 0.04, -21.8), Vector3(6.4, 0.04, -21.8),
]
var footprints: Array[Rect2] = []
var routes := Routes.new()
var batches := Fabric.Batch.new()
var structure: Node3D
var collision: StaticBody3D
var sun: DirectionalLight3D
var utility_light: OmniLight3D
var atmosphere: Environment
var dome: ShaderMaterial
var air: CPUParticles3D
var deck_surface: ShaderMaterial
var is_backdrop := false
var simulation_only := false
var build_landscape := true
var emergency := false
var map_id := "reactor"
var start_at := START
var terminal_at := TERMINAL
var half_size := HALF
var practice_points: Array[Vector3] = [
	Vector3(-4.1, 0.05, 9.9), Vector3(0, 0.05, 7.2), Vector3(7.0, 0.05, 4.6), Vector3(-11.9, 0.05, -4.5),
]
var control_points: Array[Vector3] = [Vector3(-14, 0.06, 10), Vector3(0, 0.06, 7), Vector3(13, 0.06, -10)]

func _ready() -> void:
	name = {"reactor": "ReactorCourt", "skyline": "SkylineDepot", "cryo": "CryoFoundry"}.get(map_id, "Arena")
	structure = Node3D.new()
	structure.name = "Architecture"
	batches.world_materials = true
	batches.enabled = not simulation_only
	add_child(structure)
	if not is_backdrop:
		collision = StaticBody3D.new()
		collision.name = "DeckCollision"
		add_child(collision)
	if not simulation_only:
		_light()
	_build_layout()
	if simulation_only:
		routes.setup(footprints, half_size)
		return
	batches.commit(structure)
	if map_id != "station" and build_landscape:
		Scenery.build(self)
	if not is_backdrop:
		routes.setup(footprints, half_size)
	apply_quality()
	Art.changed.connect(apply_art)
	apply_art()

func _build_layout() -> void:
	_deck()
	_enclosure()
	_reactor()
	_routes_and_cover()
	_terminal()
	_skyline()

func apply_quality() -> void:
	if simulation_only:
		return
	sun.shadow_enabled = Prefs.values.quality in [1, 2]
	sun.directional_shadow_max_distance = 47.0 if Prefs.values.quality == 2 else 28.0
	if is_instance_valid(deck_surface):
		deck_surface.set_shader_parameter("low_detail", Prefs.values.quality in [0, 3])
	dome.set_shader_parameter("low_detail", Prefs.values.quality in [0, 3])
	atmosphere.fog_enabled = Prefs.values.fog and Prefs.values.quality in [1, 2]
	_update_utility_light(Art.world(map_id).utility)
	_apply_weather()

func _light() -> void:
	var world := WorldEnvironment.new()
	atmosphere = Environment.new()
	atmosphere.background_mode = Environment.BG_COLOR
	atmosphere.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	atmosphere.fog_sky_affect = 0.0
	world.environment = atmosphere
	add_child(world)
	dome = ShaderMaterial.new()
	dome.shader = preload("res://assets/art/horizon.gdshader")
	Fabric.place(structure, Fabric.orb(116.0, 232.0, 28), dome, Vector3.ZERO, Vector3.ZERO, false)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias = 0.17
	sun.shadow_normal_bias = 0.95
	add_child(sun)

func apply_art() -> void:
	if simulation_only:
		return
	var colors: Dictionary = Art.world(map_id)
	atmosphere.background_color = colors.horizon
	atmosphere.ambient_light_color = colors.ambient
	atmosphere.ambient_light_energy = colors.fill
	atmosphere.fog_enabled = Prefs.values.fog and Prefs.values.quality in [1, 2]
	atmosphere.fog_density = colors.mist
	atmosphere.fog_light_color = colors.horizon
	dome.set_shader_parameter("zenith", colors.sky)
	dome.set_shader_parameter("haze", colors.horizon)
	dome.set_shader_parameter("sun_tint", colors.sun)
	dome.set_shader_parameter("cloud_amount", colors.clouds)
	sun.rotation_degrees = colors.angle
	sun.light_color = colors.sun
	sun.light_energy = colors.power * (0.82 if emergency else 1.0)
	if emergency:
		sun.light_color = colors.sun.lerp(Color("#f6c2a8"), 0.30)
	dome.set_shader_parameter("sun_direction", sun.basis.z)
	if is_instance_valid(deck_surface):
		deck_surface.set_shader_parameter("base_color", colors.floor)
		deck_surface.set_shader_parameter("groove_color", colors.seam)
		deck_surface.set_shader_parameter("wear_color", colors.wear)
		deck_surface.set_shader_parameter("ground_path", map_id == "grove")
		deck_surface.set_shader_parameter("aggregate", Materials.texture(colors.ground))
		deck_surface.set_shader_parameter("joint_scale", 0.55 if map_id == "station" else (0.18 if map_id in ["reactor", "cryo", "district"] else 0.0))
	_update_utility_light(colors.utility)
	for child in structure.get_children():
		if child is Label3D and child.has_meta("original_ink"):
			var original: Color = child.get_meta("original_ink")
			child.modulate = original.lerp(Color("#c4bba6"), 0.31)
	_apply_weather()

func _update_utility_light(tint: Color) -> void:
	var enabled: bool = not is_backdrop and Prefs.values.quality in [1, 2] and DisplayServer.get_name() != "headless"
	if not enabled:
		if is_instance_valid(utility_light):
			utility_light.hide()
		return
	if not is_instance_valid(utility_light):
		utility_light = OmniLight3D.new()
		utility_light.name = "TerminalFill"
		utility_light.omni_range = 8.5
		utility_light.omni_attenuation = 1.45
		utility_light.light_specular = 0.35
		utility_light.position = terminal_at + Vector3(0.0, 2.35, -1.0)
		add_child(utility_light)
	utility_light.light_color = tint
	utility_light.light_energy = 0.38 if Prefs.values.quality == 1 else 0.58
	utility_light.show()

func alert_lighting(enabled: bool) -> void:
	if enabled != emergency:
		emergency = enabled
		apply_art()

func _apply_weather() -> void:
	var kind: String = Art.MAP_NOTES.get(map_id, Art.MAP_NOTES.reactor).weather
	var enabled: bool = Prefs.values.weather and Prefs.values.quality != 3 and not is_backdrop and not kind.is_empty()
	if enabled and not is_instance_valid(air):
		air = Scenery.weather(self, kind == "snow")
	if is_instance_valid(air):
		air.emitting = enabled
		air.visible = enabled

func _paint_deck() -> void:
	if simulation_only:
		return
	deck_surface = ShaderMaterial.new()
	deck_surface.shader = preload("res://assets/art/deck.gdshader")
	var deck := PlaneMesh.new()
	deck.size = half_size * 2.0
	Fabric.place(structure, deck, deck_surface, Vector3.ZERO, Vector3.ZERO, false)

func _deck() -> void:
	_paint_deck()
	_block(Vector3(0, -0.25, 0), Vector3(half_size.x * 2, 0.5, half_size.y * 2), Vector3.ZERO, false)
	for side in [-1.0, 1.0]:
		var accent := CYAN if side < 0 else GOLD
		for z in range(-20, 21, 5):
			_box(Vector3(side * 15.32, 0.012, z), Vector3(0.09, 0.018, 3.3), accent, true)
			_box(Vector3(side * 15.60, 0.01, z), Vector3(0.04, 0.015, 4.9), STEEL)
		for index in 11:
			var z := -20.0 + index * 4.0
			_box(Vector3(side * 25.36, 0.025, z), Vector3(0.32, 0.025, 3.45), STEEL)
			_box(Vector3(side * 25.25, 0.04, z), Vector3(0.045, 0.02, 2.35), accent, true)
	for index in 14:
		var x := -20.8 + index * 3.2
		_box(Vector3(x, 0.012, 22.0), Vector3(2.25, 0.02, 0.10), STEEL)
		_box(Vector3(x, 0.012, -21.8), Vector3(2.25, 0.02, 0.10), STEEL)
	for index in 9:
		_box(Vector3((index - 4) * 0.4, 0.012, 15.0), Vector3(0.22, 0.016, 0.72), GOLD,
			false, Vector3(0, -0.51, 0))
	_stencil("COUR 07", Vector3(0, 0.026, 12.7), Vector3(-PI / 2, 0, 0), 0.025, WHITE)
	_stencil("VOIE A", Vector3(-16.9, 0.026, 12.7), Vector3(-PI / 2, 0, 0), 0.023, CYAN)
	_stencil("VOIE B", Vector3(16.9, 0.026, 12.7), Vector3(-PI / 2, 0, 0), 0.023, GOLD)

func _enclosure() -> void:
	for side in [-1.0, 1.0]:
		_solid(Vector3(25.85 * side, 2.6, 0), Vector3(0.6, 5.2, 48), INK, 0.18, false)
		_solid(Vector3(0, 2.7, 23.85 * side), Vector3(52, 5.4, 0.65), INK, 0.16, false)
		var accent := CYAN if side < 0 else GOLD
		for index in 8:
			var axis := -21.0 + index * 6.0
			var side_turn := Vector3(0, -side * PI / 2, 0)
			var end_turn := Vector3(0, 0 if side < 0 else PI, 0)
			_wall_module(Vector3(25.52 * side, 0.0, axis), side_turn, accent, index in [0, 3, 4, 7])
			_wall_module(Vector3(axis, 0.0, 23.52 * side), end_turn, accent, index in [2, 5])
		_box(Vector3(25.68 * side, 5.45, 0), Vector3(0.9, 0.43, 48), SLATE)
		_box(Vector3(0, 5.54, 23.68 * side), Vector3(52, 0.53, 0.9), STEEL)
		for index in 7:
			var z := -18.0 + index * 6.0
			_box(Vector3(side * 25.40, 5.56, z), Vector3(0.16, 0.085, 4.5), accent, true)
		for z in [-13.8, 13.8]:
			_solid(Vector3(side * 24.7, 4.13, z), Vector3(1.22, 8.26, 1.54), SLATE, 0.26)
			_box(Vector3(side * 24.04, 4.2, z), Vector3(0.035, 6.45, 0.11), accent, true)
			_box(Vector3(side * 20.2, 7.32, z), Vector3(10.0, 0.47, 0.7), STEEL,
				false, Vector3(0, 0, side * -0.24))
			_box(Vector3(side * 18.9, 6.70, z), Vector3(9.3, 0.12, 0.26), INK,
				false, Vector3(0, 0, side * 0.12))
	for z in [-13.8, 13.8]:
		_box(Vector3(0, 8.35, z), Vector3(50.0, 0.42, 0.70), INK)
		_box(Vector3(0, 8.59, z + 0.39), Vector3(49.0, 0.16, 0.14), STEEL)
		for index in 12:
			var x := -22.0 + index * 4.0
			_box(Vector3(x, 8.10, z), Vector3(1.7, 0.11, 0.40), CYAN if index % 2 == 0 else GOLD, true)
			_box(Vector3(x, 8.71, z), Vector3(0.38, 0.82, 0.52), SLATE)
	_stencil("ATELIER 07", Vector3(0, 4.37, -23.08), Vector3.ZERO, 0.036, WHITE)
	_stencil("AIRE TECHNIQUE", Vector3(0, 3.82, -23.07), Vector3.ZERO, 0.013, CYAN)
	_stencil("ACCÈS ENTRETIEN", Vector3(0, 3.46, 23.05), Vector3(0, PI, 0), 0.021, WHITE)

func _wall_module(at: Vector3, rot: Vector3, accent: Color, port: bool) -> void:
	var frame := Basis.from_euler(rot)
	_box(at + frame * Vector3(0, 2.2, 0.03), Vector3(5.63, 4.37, 0.20), SLATE, false, rot, 0.27)
	_box(at + frame * Vector3(0, 4.42, 0.21), Vector3(5.62, 0.32, 0.44), STEEL, false, rot, 0.15)
	_box(at + frame * Vector3(-2.71, 2.3, 0.23), Vector3(0.22, 4.60, 0.54), INK, false, rot)
	_box(at + frame * Vector3(0, 0.23, 0.28), Vector3(5.50, 0.40, 0.36), STEEL, false, rot)
	if port:
		_box(at + frame * Vector3(0, 1.51, 0.23), Vector3(3.45, 3.0, 0.28), INK, false, rot, 0.19)
		_box(at + frame * Vector3(0, 3.17, 0.40), Vector3(3.50, 0.25, 0.38), WHITE, false, rot)
		_box(at + frame * Vector3(0, 2.87, 0.39), Vector3(2.84, 0.065, 0.055), accent, true, rot)
		for x in [-1.44, 1.44]:
			_box(at + frame * Vector3(x, 1.46, 0.41), Vector3(0.065, 2.51, 0.055), accent, true, rot)
		for x in range(-4, 5):
			_box(at + frame * Vector3(x * 0.29, 1.4, 0.39), Vector3(0.13, 2.45, 0.045), SLATE, false, rot)
	else:
		for index in 6:
			var y := 1.04 + index * 0.40
			_box(at + frame * Vector3(0, y, 0.20), Vector3(4.64, 0.18, 0.27), INK, false, rot)
		_box(at + frame * Vector3(-1.62, 3.91, 0.26), Vector3(1.78, 0.052, 0.065), accent, true, rot)
		_box(at + frame * Vector3(1.72, 1.16, 0.35), Vector3(0.51, 0.75, 0.21), COPPER, false, rot, 0.08)

func _reactor() -> void:
	_cylinder_collision(0.22, 3.40, 0.44)
	_cylinder_collision(0.75, 3.10, 0.62)
	_cylinder_collision(2.69, 2.52, 3.25)
	_cylinder_collision(4.79, 2.59, 0.97)
	if not is_backdrop:
		footprints.append(Rect2(-3.09, -3.09, 6.18, 6.18))
	var concrete := Materials.finish(Color("#969388"), "concrete", 0.74)
	var painted := Materials.finish(Color("#777b72"), "steel", 0.78, 0.25)
	var galvanized := Materials.finish(Color("#a2a39a"), "steel", 0.90, 0.33)
	batches.put(Fabric.tube(3.39, 0.43, 22), concrete, Vector3(0, 0.215, 0))
	batches.put(Fabric.tube(3.10, 0.62, 22), concrete, Vector3(0, 0.75, 0))
	batches.put(Fabric.tube(2.50, 3.42, 28), painted, Vector3(0, 2.75, 0))
	batches.put(Fabric.tube(2.56, 0.34, 28, 2.36), galvanized, Vector3(0, 4.61, 0))
	batches.put(Fabric.tube(2.36, 0.39, 28, 1.67), painted, Vector3(0, 4.97, 0))
	batches.put(Fabric.tube(1.69, 0.17, 24, 0.74), galvanized, Vector3(0, 5.24, 0))
	batches.put(Fabric.tube(0.39, 0.45, 12), galvanized, Vector3(0, 5.50, 0))
	for height in [1.32, 2.76, 4.35]:
		batches.put(Fabric.tube(2.55, 0.06, 28), galvanized, Vector3(0, height, 0))
	for i in 8:
		var angle := TAU * i / 8.0
		var direction := Vector3(sin(angle), 0, cos(angle))
		_box(direction * 2.47 + Vector3.UP * 1.42, Vector3(0.46, 1.03, 0.28), SLATE, false, Vector3(0, angle, 0))
		_box(direction * 2.48 + Vector3.UP * 4.43, Vector3(0.11, 0.97, 0.11), STEEL)
	for height in [4.91, 5.20]:
		batches.put(Fabric.ring(2.58, 0.043, 24), galvanized, Vector3(0, height, 0))
	for x in [-0.25, 0.25]:
		_box(Vector3(x, 2.99, 2.59), Vector3(0.055, 3.45, 0.067), STEEL)
	for i in 11:
		_box(Vector3(0, 1.35 + i * 0.30, 2.59), Vector3(0.54, 0.037, 0.054), STEEL)
	for side in [-1.0, 1.0]:
		for z in [-0.74, 0.74]:
			batches.put(Fabric.tube(0.20, 11.12, 12), galvanized,
				Vector3(side * 8.10, 4.83, z), Vector3(0, 0, PI * 0.5))
			for i in 4:
				batches.put(Fabric.tube(0.264, 0.15, 12), painted,
					Vector3(side * (4.85 + i * 2.20), 4.83, z), Vector3(0, 0, PI * 0.5))
		_box(Vector3(side * 13.64, 4.15, 0), Vector3(1.13, 2.30, 2.03), SLATE, false, Vector3.ZERO, 0.09)
		_box(Vector3(side * 13.64, 3.34, 1.03), Vector3(0.62, 0.22, 0.06), GOLD)
	_box(Vector3(0.87, 2.89, 2.43), Vector3(0.69, 0.48, 0.11), INK, false, Vector3(0, 0.32, 0))
	_stencil("T-07", Vector3(0.87, 2.90, 2.52), Vector3(0, 0.32, 0), 0.008, WHITE)

func _routes_and_cover() -> void:
	for side in [-1.0, 1.0]:
		var accent := CYAN if side < 0 else GOLD
		var x: float = side * 19.82
		_solid(Vector3(x, 0.85, 0), Vector3(5.2, 1.7, 8.6), SLATE, 0.18)
		_box(Vector3(x, 1.675, 0), Vector3(5.25, 0.05, 8.61), STEEL, false, Vector3.ZERO, 0.11)
		_box(Vector3(x - side * 2.59, 1.50, 0), Vector3(0.075, 0.075, 8.2), accent, true)
		for z_side in [-1.0, 1.0]:
			var rot := Vector3(z_side * atan2(1.7, 5.5), 0, 0)
			var at := Vector3(x, 0.70, z_side * 7.03)
			_block(at, Vector3(5.17, 0.29, 5.75), rot)
			_box(at, Vector3(5.17, 0.29, 5.75), STEEL, false, rot, 0.13)
			for stripe in [-2.51, 2.51]:
				_box(at + Vector3(stripe, 0.15, 0), Vector3(0.044, 0.06, 5.4), accent, true, rot)
		for z in [-3.2, 0.0, 3.2]:
			_box(Vector3(x + side * 2.53, 2.19, z), Vector3(0.12, 1.0, 0.12), INK)
		_solid(Vector3(x + side * 2.55, 2.59, 0), Vector3(0.14, 0.17, 8.05), WHITE, 0.035, false)
		_stencil("0" + ("1" if side < 0 else "2"), Vector3(x - side * 2.63, 1.04, 0),
			Vector3(0, -side * PI / 2, 0), 0.025, accent)
		for z in [-10.7, 8.4]:
			_supply(Vector3(side * 8.85, 0.0, z), Vector3(3.55, 2.31, 3.82), accent)
		for z in [-16.7, 16.7]:
			_supply(Vector3(side * 17.0, 0.0, z), Vector3(3.04, 3.3, 4.25), accent)
			_box(Vector3(side * 17.0, 3.43, z), Vector3(2.84, 0.24, 4.02), STEEL, false, Vector3.ZERO, 0.19)
		for z in [-5.7, 13.2]:
			_supply(Vector3(side * 5.18, 0.0, z), Vector3(1.96, 0.91, 1.38), GOLD)
		_supply(Vector3(side * 12.65, 0.0, -1.2), Vector3(1.92, 1.45, 2.37), accent)
		for z in [-17.5, 17.5]:
			_box(Vector3(side * 22.01, 0.03, z), Vector3(2.7, 0.03, 0.08), accent, true)
			_box(Vector3(side * 22.01, 0.03, z + signf(z) * 2.7), Vector3(2.7, 0.03, 0.08), accent, true)
	_supply(Vector3(0, 0, -16.5), Vector3(3.0, 2.15, 1.60), CYAN)

func _supply(at: Vector3, size: Vector3, accent: Color) -> void:
	_block(at + Vector3.UP * size.y * 0.5, size)
	var wood := Color("#987958").lerp(accent, 0.09)
	var boards := Materials.finish(wood, "timber", 0.79)
	batches.put(Fabric.bevel(size, 0.018), boards, at + Vector3.UP * size.y * 0.5)
	var frame := wood.darkened(0.30)
	for y in [0.10, size.y - 0.10]:
		_box(at + Vector3.UP * y, Vector3(size.x + 0.074, 0.15, size.z + 0.074), frame)
	for side in [-1.0, 1.0]:
		for edge in [-1.0, 1.0]:
			var corner := at + Vector3(side * size.x * 0.463, size.y * 0.5, edge * size.z * 0.507)
			_box(corner, Vector3(0.13, size.y, 0.056), frame)
			for y in [0.19, size.y - 0.19]:
				_box(Vector3(corner.x, at.y + y, corner.z + edge * 0.032), Vector3(0.042, 0.042, 0.014), INK)
		var diagonal := Vector2(size.x * 0.84, size.y * 0.68)
		_box(at + Vector3(0, size.y * 0.51, side * (size.z * 0.5 + 0.038)),
			Vector3(diagonal.length(), 0.135, 0.053), wood.lightened(0.17),
			false, Vector3(0, 0, side * diagonal.angle()))
	if size.y < 1.65:
		_box(at + Vector3(0, size.y * 0.67, size.z * 0.5 + 0.034), Vector3(0.34, 0.15, 0.018), INK)
		_box(at + Vector3(0, size.y * 0.67, size.z * 0.5 + 0.059), Vector3(0.21, 0.039, 0.056), STEEL)

func _terminal() -> void:
	var foot := terminal_at - Vector3.UP
	var olive := Color("#6c7458")
	_block(foot + Vector3.UP * 0.48, Vector3(0.68, 0.96, 0.56), Vector3.ZERO, false)
	_box(foot + Vector3.UP * 0.44, Vector3(0.71, 0.88, 0.57), olive, false, Vector3.ZERO, 0.034)
	for y in [0.09, 0.48, 0.85]:
		_box(foot + Vector3.UP * y, Vector3(0.75, 0.09, 0.61), olive.darkened(0.30))
	for x in [-0.23, 0.23]:
		_box(foot + Vector3(x, 0.71, 0.294), Vector3(0.08, 0.12, 0.042), STEEL, false, Vector3.ZERO, 0.01)
	_box(foot + Vector3(0, 0.30, 0.305), Vector3(0.33, 0.18, 0.033), INK)
	_stencil("MUNITIONS", foot + Vector3(0, 0.30, 0.328), Vector3.ZERO, 0.0039, WHITE)
	_box(foot + Vector3(-0.07, 0.92, 0), Vector3(0.46, 0.105, 0.33), INK, false, Vector3.ZERO, 0.02)
	for x in [-0.21, 0.07]:
		_box(foot + Vector3(x, 0.984, 0), Vector3(0.077, 0.025, 0.24), STEEL)
	_box(foot + Vector3(0.23, 1.0, -0.04), Vector3(0.071, 0.24, 0.083), STEEL, false, Vector3(0.20, 0, 0))

func _skyline() -> void:
	if simulation_only:
		return
	var random := RandomNumberGenerator.new()
	random.seed = 87374
	for side in [-1.0, 1.0]:
		for i in 13:
			var x := -55.0 + 9.0 * i + random.randf_range(-2.0, 2.0)
			var z: float = side * random.randf_range(31.5, 58.0)
			var h := random.randf_range(7.0, 27.0)
			var width := random.randf_range(5.1, 9.0)
			var depth := floorf((absf(z) - 30.0) / 6.0) / 5.0
			var shade := Color("#6e7472").lerp(Color("#adb0a6"), depth)
			_box(Vector3(x, h * 0.5, z), Vector3(width, h, 4.5), shade, false, Vector3.ZERO, 0.65)
			_box(Vector3(x, h + 0.4, z), Vector3(width * 0.70, 0.90, 3.2), shade.lightened(0.09))
			for j in range(3, floori(h), 3):
				for column in [-0.28, 0.0, 0.28]:
					_box(Vector3(x + width * column, j, z - side * 2.26), Vector3(width * 0.16, 0.78, 0.035),
						Color("#6d7577"))
			if i % 3 == 1:
				_box(Vector3(x + 0.8, h + 2.1, z), Vector3(0.13, 3.45, 0.15), INK)
				_box(Vector3(x + 0.8, h + 3.87, z), Vector3(0.19, 0.17, 0.19), GOLD, true)

func _box(at: Vector3, size: Vector3, color: Color, glow := false,
		rot := Vector3.ZERO, bevel := 0.0) -> void:
	if simulation_only:
		return
	var mesh: Mesh = Fabric.bevel(size, bevel) if bevel > 0.0 else Fabric.cube(size)
	batches.put(mesh, Fabric.paint(color, glow), at, rot)

func _solid(at: Vector3, size: Vector3, color: Color, bevel := 0.0, nav := true) -> void:
	_box(at, size, color, false, Vector3.ZERO, bevel)
	_block(at, size, Vector3.ZERO, nav)

func _block(at: Vector3, size: Vector3, rot := Vector3.ZERO, nav := true) -> void:
	if is_backdrop:
		return
	if nav:
		var rect_size := Vector2(size.x, size.z)
		footprints.append(Rect2(Vector2(at.x, at.z) - rect_size * 0.5, rect_size))
	var node := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = size
	node.shape = volume
	node.position = at
	node.rotation = rot
	collision.add_child(node)

func _cylinder_collision(y: float, radius: float, height: float) -> void:
	if is_backdrop:
		return
	var node := CollisionShape3D.new()
	var volume := CylinderShape3D.new()
	volume.radius = radius
	volume.height = height
	node.shape = volume
	node.position.y = y
	collision.add_child(node)

func _stencil(text: String, at: Vector3, rot: Vector3, pixels: float, color: Color) -> void:
	if simulation_only:
		return
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = 45
	label.outline_size = 0
	label.pixel_size = pixels
	label.modulate = color
	label.set_meta("original_ink", color)
	label.position = at
	label.rotation = rot
	structure.add_child(label)
