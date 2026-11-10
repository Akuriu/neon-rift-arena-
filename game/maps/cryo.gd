extends "res://game/arena.gd"

const ICE := Color("#85dce9")
const FROST := Color("#cfebed")
const DARK := Color("#172732")
const BLUE := Color("#355563")
const SERVICE := Color("#f4bc76")
const BEACON := Color("#92f1fb")

func _init() -> void:
	map_id = "cryo"
	half_size = Vector2(28.0, 26.0)
	start_at = Vector3(0, 0.06, 21.0)
	terminal_at = Vector3(4.2, 1.0, 20.2)
	spawn_points.assign([
		Vector3(-23.0, 0.04, 21.8), Vector3(23.0, 0.04, 21.8),
		Vector3(-23.0, 0.04, -21.8), Vector3(23.0, 0.04, -21.8),
		Vector3(-25.0, 0.04, 1.4), Vector3(25.0, 0.04, -1.4),
		Vector3(-7.0, 0.04, -23.8), Vector3(7.0, 0.04, -23.8),
	])
	practice_points.assign([Vector3(-5, 0.04, 10), Vector3(0, 0.04, 8),
		Vector3(7, 0.04, 13), Vector3(-15, 0.04, 16)])

func _build_layout() -> void:
	_floor()
	_shell()
	_manifolds()
	_platforms()
	_terminal()

func _floor() -> void:
	var surface := PlaneMesh.new()
	surface.size = half_size * 2.0
	var frost := ShaderMaterial.new()
	frost.shader = preload("res://assets/art/deck.gdshader")
	deck_surface = frost
	frost.set_shader_parameter("base_color", Color("#526b74"))
	frost.set_shader_parameter("groove_color", Color("#273c47"))
	Fabric.place(structure, surface, frost, Vector3.ZERO, Vector3.ZERO, false)
	_block(Vector3(0, -0.45, 0), Vector3(56, 0.9, 52), Vector3.ZERO, false)
	for side in [-1.0, 1.0]:
		for row in 13:
			_box(Vector3(side * 4.3, 0.011, -24 + row * 4.0), Vector3(0.15, 0.02, 2.9), ICE, true)
			_box(Vector3(side * 19.4, 0.012, -24 + row * 4.0), Vector3(0.11, 0.02, 2.6), SERVICE, true)
	_stencil("CRYO  /  FOUNDRY 03", Vector3(0, 0.025, 16.8),
		Vector3(-PI * 0.5, 0, 0), 0.023, FROST)

func _shell() -> void:
	for side in [-1.0, 1.0]:
		_solid(Vector3(27.75 * side, 4.5, 0), Vector3(0.65, 9.0, 52), DARK, 0.1, false)
		_solid(Vector3(0, 4.2, 25.75 * side), Vector3(56, 8.4, 0.55), DARK, 0.1, false)
		for section in 8:
			var lane := -22.0 + section * 6.2
			_wall_module(Vector3(27.2 * side, 0, lane), Vector3(0, -side * PI / 2, 0), ICE, section % 2 == 0)
			_wall_module(Vector3(lane, 0, side * 25.4), Vector3(0, PI if side > 0 else 0.0, 0), SERVICE, section in [2, 5])
			_box(Vector3(side * 27.3, 6.05, lane), Vector3(0.35, 2.05, 5.1), BLUE, false, Vector3.ZERO, 0.2)
			_box(Vector3(side * 27.09, 6.93, lane), Vector3(0.03, 0.055, 4.8), ICE, true)
		_box(Vector3(0, 8.1, side * 23.2), Vector3(55, 0.38, 1.05), STEEL)
		for line in [-9.0, 9.0]:
			batches.put(Fabric.tube(0.41, 49.0, 10), Fabric.paint(BLUE),
				Vector3(line, 7.4 + side * 0.52, 0), Vector3(PI * 0.5, 0, 0))
	for z in [-17.0, 0.0, 17.0]:
		_box(Vector3(0, 8.9, z), Vector3(53.5, 0.46, 1.15), BLUE, false, Vector3.ZERO, 0.3)
		_box(Vector3(0, 8.61, z), Vector3(48.0, 0.06, 0.18), BEACON, true)
		_box(Vector3(0, 10.0, z), Vector3(43.0, 0.16, 4.6), DARK, false, Vector3.ZERO, 0.35)

func _manifolds() -> void:
	for side in [-1.0, 1.0]:
		for z in [-10.0, 1.0, 12.0]:
			var at := Vector3(side * 9.8, 0.0, z)
			_solid(at + Vector3.UP * 0.57, Vector3(4.05, 1.14, 5.4), BLUE, 0.27)
			for lane in [-1.23, 1.23]:
				var tank := at + Vector3(lane, 2.3, 0)
				batches.put(Fabric.tube(0.88, 3.35, 13), Fabric.paint(STEEL), tank)
				batches.put(Fabric.tube(0.86, 0.95, 13), Fabric.paint(ICE, true), tank + Vector3.UP * 0.11)
				batches.put(Fabric.tube(0.92, 0.21, 13), Fabric.paint(FROST), tank + Vector3.UP * 1.71)
				_block(tank, Vector3(1.58, 3.3, 1.58))
			_box(at + Vector3(0, 4.31, 0), Vector3(4.2, 0.3, 1.7), BLUE)
			_stencil("CIRCUIT %d" % (1 + roundi((z + 10.0) / 11.0)), at + Vector3(0, 1.04, 2.73),
				Vector3.ZERO, 0.012, FROST)
	for at in [Vector3(-3.1, 0.0, -6.5), Vector3(3.1, 0.0, 7.0),
			Vector3(-15.2, 0.0, -17.0), Vector3(15.2, 0.0, 17.0)]:
		_supply(at, Vector3(2.6, 1.18, 1.45), SERVICE)

func _platforms() -> void:
	for side in [-1.0, 1.0]:
		var x: float = 20.9 * side
		_solid(Vector3(x, 0.89, 0.0), Vector3(5.5, 1.78, 16.8), BLUE, 0.19)
		for z_sign in [-1.0, 1.0]:
			var center := Vector3(x, 0.82, 11.28 * z_sign)
			var incline := Vector3(z_sign * 0.30, 0, 0)
			_box(center, Vector3(5.5, 0.24, 6.12), STEEL, false, incline, 0.06)
			_block(center, Vector3(5.5, 0.24, 6.12), incline)
			_box(center + Vector3(0.0, 0.14, 0.0), Vector3(0.11, 0.03, 5.82), SERVICE, true, incline)
		for i in 8:
			var z := -7.5 + i * 2.14
			_box(Vector3(x + side * 2.57, 2.15, z), Vector3(0.17, 0.85, 0.15), ICE)
		_box(Vector3(x + side * 2.57, 2.57, 0), Vector3(0.13, 0.13, 16.0), FROST)
