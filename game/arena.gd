extends Node3D

const Fabric := preload("res://game/fabric.gd")
const Routes := preload("res://game/routes.gd")
const Scenery := preload("res://art/scenery.gd")
const FONT := preload("res://assets/fonts/OpenSans-CondBold.ttf")
const START := Vector3(0, 0.06, 18.0)
const TERMINAL := Vector3(3.2, 1.0, 17.0)
const HALF := Vector2(26.0, 24.0)
const CYAN := Color("#5af3ea")
const GOLD := Color("#ffb85e")
const INK := Color("#19262d")
const SLATE := Color("#34474d")
const STEEL := Color("#6f8083")
const WHITE := Color("#a8b7ac")
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
var atmosphere: Environment
var dome: ShaderMaterial
var daylight: Node3D
var air: CPUParticles3D
var deck_surface: ShaderMaterial
var turbine: Node3D
var sleeve: Node3D
var is_backdrop := false
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
	add_child(structure)
	if not is_backdrop:
		collision = StaticBody3D.new()
		collision.name = "DeckCollision"
		add_child(collision)
	_light()
	_build_layout()
	batches.commit(structure)
	if map_id != "station":
		daylight = Scenery.build(self)
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
	sun.shadow_enabled = Prefs.values.quality in [1, 2]
	sun.directional_shadow_max_distance = 47.0 if Prefs.values.quality == 2 else 28.0
	if is_instance_valid(deck_surface):
		deck_surface.set_shader_parameter("low_detail", Prefs.values.quality in [0, 3])
	dome.set_shader_parameter("low_detail", Prefs.values.quality in [0, 3])
	atmosphere.fog_enabled = Prefs.values.fog and Prefs.values.quality in [1, 2]
	if is_instance_valid(daylight):
		daylight.visible = Prefs.values.art_style != 1 and Prefs.values.quality != 3
	_apply_weather()

func _process(delta: float) -> void:
	if is_instance_valid(turbine):
		turbine.rotate_y(delta * 0.36)
		sleeve.rotate_y(-delta * 0.53)

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
	sun.shadow_bias = 0.09
	sun.shadow_normal_bias = 0.72
	add_child(sun)

func apply_art() -> void:
	var colors: Dictionary = Art.world(map_id)
	atmosphere.background_color = colors.horizon
	atmosphere.ambient_light_color = colors.ambient
	atmosphere.ambient_light_energy = 0.67 if Prefs.values.art_style == 1 else 0.78
	atmosphere.fog_enabled = Prefs.values.fog and Prefs.values.quality in [1, 2]
	atmosphere.fog_density = colors.mist
	atmosphere.fog_light_color = colors.horizon
	dome.set_shader_parameter("zenith", colors.sky)
	dome.set_shader_parameter("haze", colors.horizon)
	dome.set_shader_parameter("sun_tint", colors.sun)
	dome.set_shader_parameter("cloud_amount", [0.34, 0.07, 0.19, 0.30][Prefs.values.art_style])
	sun.rotation_degrees = colors.angle
	sun.light_color = colors.sun
	sun.light_energy = colors.power * (0.82 if emergency else 1.0)
	if emergency:
		sun.light_color = colors.sun.lerp(Color("#f6c2a8"), 0.30)
	dome.set_shader_parameter("sun_direction", sun.basis.z)
	if is_instance_valid(deck_surface):
		deck_surface.set_shader_parameter("base_color", colors.floor)
		deck_surface.set_shader_parameter("groove_color", colors.seam)
		deck_surface.set_shader_parameter("ground_path", map_id == "grove" and Prefs.values.art_style != 1)
	if is_instance_valid(daylight):
		daylight.visible = Prefs.values.art_style != 1 and Prefs.values.quality != 3
	for child in structure.get_children():
		if child is Label3D and child.has_meta("original_ink"):
			var original: Color = child.get_meta("original_ink")
			child.modulate = original if Prefs.values.art_style == 1 else original.lerp(colors.dark, 0.62)
	_apply_weather()

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

func _deck() -> void:
	var finish := ShaderMaterial.new()
	finish.shader = preload("res://assets/art/deck.gdshader")
	deck_surface = finish
	var deck := PlaneMesh.new()
	deck.size = half_size * 2.0
	Fabric.place(structure, deck, finish, Vector3.ZERO)
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
	_stencil("07  /  COURT", Vector3(0, 0.026, 12.7), Vector3(-PI / 2, 0, 0), 0.025, WHITE)
	_stencil("A  /  BYPASS", Vector3(-16.9, 0.026, 12.7), Vector3(-PI / 2, 0, 0), 0.023, CYAN)
	_stencil("B  /  BYPASS", Vector3(16.9, 0.026, 12.7), Vector3(-PI / 2, 0, 0), 0.023, GOLD)

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
	_stencil("R C T   /   0 7", Vector3(0, 4.37, -23.08), Vector3.ZERO, 0.036, WHITE)
	_stencil("R E A C T O R    C O U R T", Vector3(0, 3.82, -23.07), Vector3.ZERO, 0.013, CYAN)
	_stencil("M A I N T E N A N C E   /   0 7", Vector3(0, 3.46, 23.05), Vector3(0, PI, 0), 0.021, WHITE)

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
	for layer in [
		[3.46, 0.26, 0.13, INK], [3.35, 0.19, 0.34, GOLD], [3.21, 0.51, 0.61, STEEL],
		[2.97, 0.57, 0.98, INK], [2.73, 0.15, 1.31, CYAN], [2.53, 0.67, 1.65, SLATE],
		[2.23, 2.58, 3.03, INK], [2.61, 0.36, 4.40, STEEL], [2.35, 0.11, 4.65, CYAN],
		[2.50, 0.58, 4.96, SLATE], [2.17, 0.17, 5.33, GOLD], [1.88, 0.55, 5.62, INK],
		[1.28, 0.32, 6.08, STEEL], [0.77, 0.41, 6.35, WHITE], [0.40, 0.12, 6.62, CYAN],
	]:
		var color: Color = layer[3]
		batches.put(Fabric.tube(layer[0], layer[1], 12), Fabric.paint(color, color in [CYAN, GOLD]),
			Vector3(0, layer[2], 0))
	for index in 12:
		var angle := index * TAU / 12.0
		var direction := Vector3(sin(angle), 0, cos(angle))
		_box(direction * 2.25 + Vector3.UP * 3.03, Vector3(0.43, 2.53, 0.38), STEEL,
			false, Vector3(0, angle, -0.17))
		_box(direction * 2.47 + Vector3.UP * 3.05, Vector3(0.075, 2.00, 0.045), CYAN,
			true, Vector3(0, angle, -0.17))
		var bay := direction * 3.36
		_box(bay + Vector3.UP * 0.023, Vector3(0.24, 0.035, 0.54), GOLD, false, Vector3(0, angle, 0))
	for side in [-1.0, 1.0]:
		var x: float = side * 8.1
		for z in [-1.0, 1.0]:
			batches.put(Fabric.tube(0.22, 11.15, 10), Fabric.paint(COPPER),
				Vector3(x, 5.02 + z * 0.22, z * 0.77), Vector3(0, 0, PI / 2))
			for index in 4:
				batches.put(Fabric.tube(0.285, 0.17, 10), Fabric.paint(STEEL),
					Vector3(side * (4.7 + index * 2.2), 5.02 + z * 0.22, z * 0.77),
					Vector3(0, 0, PI / 2))
		_box(Vector3(side * 13.55, 5.0, 0), Vector3(1.26, 1.20, 2.24), SLATE, false, Vector3.ZERO, 0.28)
		_box(Vector3(side * 13.55, 4.76, 1.17), Vector3(0.63, 0.15, 0.08), GOLD, true)
	turbine = Node3D.new()
	turbine.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	turbine.position.y = 5.73
	add_child(turbine)
	sleeve = Node3D.new()
	sleeve.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	sleeve.position.y = 3.53
	add_child(sleeve)
	Fabric.place(turbine, Fabric.ring(2.42, 0.12), Art.surface(Fabric.paint(CYAN, true)), Vector3.ZERO, Vector3(0.16, 0, 0.07), false)
	Fabric.place(sleeve, Fabric.ring(2.84, 0.18), Art.surface(Fabric.paint(COPPER)), Vector3.ZERO, Vector3(-0.16, 0, 0.09))
	for i in 5:
		var angle := TAU * i / 5.0
		Fabric.place(turbine, Fabric.bevel(Vector3(0.48, 0.22, 0.43), 0.12),
			Fabric.paint(WHITE), Vector3(sin(angle), 0.02, cos(angle)) * 2.42, Vector3(0, angle, 0))
	_stencil("07", Vector3(0, 2.56, 2.73), Vector3.ZERO, 0.032, CYAN)
	_stencil("RIFT CORE", Vector3(0, 2.15, 2.72), Vector3.ZERO, 0.010, WHITE)

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
	_solid(at + Vector3.UP * size.y * 0.5, size, SLATE, 0.16)
	_box(at + Vector3.UP * (size.y - 0.09), Vector3(size.x + 0.11, 0.18, size.z + 0.11), STEEL,
		false, Vector3.ZERO, 0.14)
	_box(at + Vector3.UP * 0.16, Vector3(size.x + 0.06, 0.24, size.z + 0.06), INK, false, Vector3.ZERO, 0.16)
	for side in [-1.0, 1.0]:
		var z: float = side * (size.z * 0.5 + 0.034)
		_box(at + Vector3(0, size.y * 0.57, z), Vector3(size.x - 0.54, size.y * 0.51, 0.055), INK)
		_box(at + Vector3(0, size.y * 0.76, z + side * 0.037), Vector3(size.x - 0.60, 0.048, 0.025), accent, true)
		for j in 5:
			var x := (j - 2) * (size.x - 0.68) / 5.0
			_box(at + Vector3(x, size.y * 0.51, z + side * 0.038), Vector3(0.08, size.y * 0.28, 0.035), STEEL,
				false, Vector3(0, 0, -0.27))

func _terminal() -> void:
	var foot := terminal_at - Vector3.UP
	_solid(foot + Vector3.UP * 0.48, Vector3(0.68, 0.96, 0.56), INK, 0.13, false)
	_box(foot + Vector3.UP * 0.19, Vector3(0.83, 0.13, 0.75), STEEL, false, Vector3.ZERO, 0.13)
	_box(foot + Vector3.UP * 1.03, Vector3(0.90, 0.22, 0.72), STEEL, false, Vector3(0.42, 0, 0), 0.15)
	_box(foot + Vector3(0, 1.11, 0.015), Vector3(0.59, 0.037, 0.44), CYAN, true, Vector3(0.42, 0, 0), 0.08)
	_box(foot + Vector3(0, 0.65, 0.295), Vector3(0.27, 0.05, 0.025), GOLD, true)
	_stencil("CONTROL / 07", foot + Vector3(0, 1.44, 0.0), Vector3.ZERO, 0.008, CYAN)

func _skyline() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 87374
	for side in [-1.0, 1.0]:
		for i in 13:
			var x := -55.0 + 9.0 * i + random.randf_range(-2.0, 2.0)
			var z: float = side * random.randf_range(31.5, 58.0)
			var h := random.randf_range(7.0, 27.0)
			var width := random.randf_range(3.1, 7.7)
			var depth := floorf((absf(z) - 30.0) / 6.0) / 5.0
			var shade := Color("#324d57").lerp(Color("#67818b"), depth)
			_box(Vector3(x, h * 0.5, z), Vector3(width, h, 4.5), shade, false, Vector3.ZERO, 0.65)
			_box(Vector3(x, h + 0.4, z), Vector3(width * 0.70, 0.90, 3.2), shade.lightened(0.09))
			for j in range(2, floori(h), 3):
				_box(Vector3(x, j, z - side * 2.26), Vector3(width * 0.56, 0.13, 0.035),
					Color("#789899") if (j + i) % 4 > 0 else Color("#c79671"), true)
			if i % 3 == 1:
				_box(Vector3(x + 0.8, h + 2.1, z), Vector3(0.13, 3.45, 0.15), INK)
				_box(Vector3(x + 0.8, h + 3.87, z), Vector3(0.19, 0.17, 0.19), GOLD, true)

func _box(at: Vector3, size: Vector3, color: Color, glow := false,
		rot := Vector3.ZERO, bevel := 0.0) -> void:
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
