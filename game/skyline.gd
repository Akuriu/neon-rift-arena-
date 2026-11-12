extends "res://game/arena.gd"

const SAND := Color("#b6a78b")
const VERMILION := Color("#a75c47")
const MINT := Color("#bbb6a1")
const CLAY := Color("#a77d55")
const CARGO := Color("#536a67")
const LILAC := Color("#b5ad95")

func _init() -> void:
	map_id = "skyline"
	half_size = Vector2(30.0, 25.0)
	start_at = Vector3(1.0, 0.06, 20.5)
	terminal_at = Vector3(4.5, 1.0, 20.0)
	spawn_points.assign([
		Vector3(-24.2, 0.04, 19.8), Vector3(23.7, 0.04, 19.4),
		Vector3(-24.6, 0.04, -18.8), Vector3(24.5, 0.04, -18.9),
		Vector3(-27.4, 0.04, 1.4), Vector3(27.5, 0.04, -1.1),
		Vector3(-7.4, 0.04, -22.8), Vector3(9.1, 0.04, -23.1),
	])
	practice_points.assign([
		Vector3(-3.7, 0.05, 12.2), Vector3(1.4, 0.05, 8.7),
		Vector3(8.8, 0.05, 3.6), Vector3(-19.9, 0.05, 5.2),
	])

func _build_layout() -> void:
	_floor()
	_perimeter()
	_loading_gantry()
	_cargo_yards()
	_terminal()
	_skyline()
	_distant_beacon()

func _floor() -> void:
	_paint_deck()
	_block(Vector3(0, -0.25, 0), Vector3(60, 0.5, 50), Vector3.ZERO, false)
	for lane in [-9.1, 9.1]:
		for j in 12:
			var z := -21.8 + j * 3.9
			_box(Vector3(lane, 0.018, z), Vector3(0.11, 0.021, 2.65), SAND)
			_box(Vector3(lane + 0.24, 0.017, z), Vector3(0.05, 0.020, 2.65), CLAY, true)
	for index in 9:
		_box(Vector3(-1.52 + index * 0.61, 0.022, 14.6), Vector3(0.34, 0.025, 0.72), SAND,
			false, Vector3(0, 0.49, 0))
	_stencil("DÉPÔT 12", Vector3(1, 0.030, 17.55), Vector3(-PI / 2, 0, 0), 0.023, SAND)
	_stencil("QUAI A", Vector3(-20.0, 0.030, 11.1), Vector3(-PI / 2, 0, 0), 0.026, LILAC)
	_stencil("QUAI B", Vector3(20.9, 0.030, 11.1), Vector3(-PI / 2, 0, 0), 0.026, MINT)

func _perimeter() -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * 29.75
		var z: float = side * 24.77
		var stripe := LILAC if side < 0 else MINT
		_solid(Vector3(x, 1.57, 0), Vector3(0.54, 3.14, 50.0), INK, 0.08, false)
		_solid(Vector3(0, 1.40, z), Vector3(60.0, 2.80, 0.53), CARGO, 0.09, false)
		_box(Vector3(0, 2.91, z), Vector3(60, 0.18, 0.67), SAND)
		for i in 10:
			var f := -22.5 + i * 5.0
			_box(Vector3(x - side * 0.38, 0.57, f), Vector3(0.29, 1.03, 4.46), STEEL)
			_box(Vector3(x - side * 0.40, 2.97, f), Vector3(0.09, 0.08, 3.5), stripe, true)
			_box(Vector3(f, 1.37, z - side * 0.35), Vector3(4.15, 0.17, 0.16), VERMILION)
			_box(Vector3(f, 3.43, z), Vector3(0.21, 1.04, 0.36), SLATE)
		_box(Vector3(0, 3.95, z), Vector3(59.0, 0.10, 0.18), SLATE)
		_block(Vector3(0, 3.55, z), Vector3(59.0, 1.75, 0.37), Vector3.ZERO, false)
		for f in [-20.3, 0.3, 20.3]:
			var rot := Vector3(0, -side * PI / 2, 0)
			_wall_module(Vector3(x + side * 0.02, 0, f), rot, stripe, true)
			_box(Vector3(x - side * 1.37, 3.23, f), Vector3(2.65, 0.29, 4.7), CARGO, false, Vector3.ZERO, 0.27)
	_stencil("DÉPÔT DE FRET", Vector3(0.0, 2.32, -24.43), Vector3.ZERO, 0.028, SAND)
	_stencil("ZONE DE CHARGEMENT", Vector3(0.0, 1.86, -24.43), Vector3.ZERO, 0.012, CLAY)

func _loading_gantry() -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * 8.25
		for z in [-4.8, 4.8]:
			_solid(Vector3(x, 3.41, z), Vector3(1.26, 6.82, 1.47), VERMILION, 0.21)
			_box(Vector3(x, 0.32, z), Vector3(1.82, 0.63, 1.94), INK, false, Vector3.ZERO, 0.21)
			_box(Vector3(x, 6.77, z), Vector3(1.64, 0.58, 1.89), CARGO, false, Vector3.ZERO, 0.13)
			_box(Vector3(x - side * 0.65, 3.06, z), Vector3(0.055, 4.78, 0.14), CLAY, true)
		_box(Vector3(x, 7.03, 0), Vector3(1.0, 0.48, 11.0), SLATE)
		_box(Vector3(x, 7.56, 0), Vector3(0.76, 0.25, 11.5), SAND)
	for z in [-4.78, 4.78]:
		_box(Vector3(0, 7.06, z), Vector3(18.7, 0.55, 0.86), VERMILION)
		_box(Vector3(0, 7.58, z), Vector3(18.5, 0.22, 0.70), CARGO)
		for i in 8:
			_box(Vector3(-8.08 + i * 2.32, 7.33, z), Vector3(1.21, 0.18, 0.37), SAND,
				false, Vector3(0, 0, (1 if i % 2 == 0 else -1) * 0.56))
	_box(Vector3(0, 6.62, 4.85), Vector3(4.18, 1.28, 0.56), INK, false, Vector3.ZERO, 0.13)
	_box(Vector3(0, 6.04, 5.15), Vector3(3.94, 0.06, 0.04), MINT, true)
	_stencil("PORTIQUE 12", Vector3(0, 6.59, 5.15), Vector3.ZERO, 0.021, SAND)
	_box(Vector3(0, 7.08, 0), Vector3(0.34, 0.34, 10.45), SAND)
	_box(Vector3(0, 5.64, -2.3), Vector3(0.17, 2.65, 0.17), INK)
	_box(Vector3(0, 4.38, -2.3), Vector3(1.66, 0.27, 0.58), VERMILION, false, Vector3.ZERO, 0.09)
	_box(Vector3(0, 4.22, -2.3), Vector3(1.35, 0.09, 0.52), CLAY, true)

func _cargo_yards() -> void:
	_container(Vector3(-16.8, 0.0, -4.7), Vector3(5.0, 3.66, 9.6), VERMILION, LILAC, "A–17")
	_container(Vector3(15.3, 0.0, -16.8), Vector3(5.0, 4.0, 4.55), CARGO, MINT, "B–19")
	_container(Vector3(-15.6, 0.0, 14.5), Vector3(3.3, 3.10, 7.1), CARGO, LILAC, "A–23")
	_container(Vector3(21.0, 0.0, 15.9), Vector3(4.1, 3.65, 4.4), VERMILION, MINT, "B–24")
	_container(Vector3(-17.5, 0.0, -17.0), Vector3(4.7, 2.46, 4.2), CARGO, LILAC, "A–09")
	_container(Vector3(13.7, 0.0, 7.2), Vector3(3.34, 2.25, 3.7), CARGO, MINT, "B–16")
	for at in [Vector3(5.1, 0, -10.6), Vector3(-3.9, 0, 4.8), Vector3(4.6, 0, 13.4),
			Vector3(-5.9, 0, -13.8), Vector3(0, 0, -18.7), Vector3(-22.5, 0, 5.8)]:
		_supply(at, Vector3(2.75, 1.06, 1.47), CLAY)
	_elevated(Vector3(21.6, 0, -3.2), MINT, 1.0)
	_elevated(Vector3(-22.4, 0, -8.1), LILAC, -1.0)

func _elevated(at: Vector3, stripe: Color, slope_side: float) -> void:
	_solid(at + Vector3.UP * 0.85, Vector3(4.6, 1.7, 6.5), CARGO, 0.20)
	_box(at + Vector3.UP * 1.67, Vector3(4.67, 0.06, 6.52), SAND, false, Vector3.ZERO, 0.10)
	var turn := Vector3(slope_side * atan2(1.7, 5.55), 0, 0)
	var ramp := at + Vector3(0, 0.71, slope_side * 6.0)
	_block(ramp, Vector3(4.55, 0.28, 5.78), turn)
	_box(ramp, Vector3(4.56, 0.28, 5.78), STEEL, false, turn, 0.10)
	_box(ramp + Vector3(2.19, 0.146, 0), Vector3(0.055, 0.044, 5.58), stripe, true, turn)
	for z in [-2.90, 0, 2.90]:
		_box(at + Vector3(2.26, 2.17, z), Vector3(0.12, 0.99, 0.10), CARGO)
	_solid(at + Vector3(2.27, 2.65, 0), Vector3(0.10, 0.13, 6.1), SAND, 0.027, false)

func _container(at: Vector3, size: Vector3, color: Color, accent: Color, code: String) -> void:
	_block(at + Vector3.UP * size.y * 0.5, size)
	var paint := Materials.finish(color, "steel", 0.91, 0.31)
	batches.put(Fabric.cube(size), paint, at + Vector3.UP * size.y * 0.5)
	for y in [0.09, size.y - 0.09]:
		_box(at + Vector3.UP * y, Vector3(size.x + 0.09, 0.18, size.z + 0.09), color.darkened(0.23))
	var ribs := maxi(7, roundi(size.z / 0.32))
	for side in [-1.0, 1.0]:
		for i in ribs:
			var z := size.z * (-0.46 + 0.92 * float(i) / float(ribs - 1))
			_box(at + Vector3(side * size.x * 0.506, size.y * 0.5, z),
				Vector3(0.088, size.y - 0.38, 0.094), color.lightened(0.12))
		for end in [-1.0, 1.0]:
			_box(at + Vector3(side * size.x * 0.485, size.y * 0.5, end * size.z * 0.495),
				Vector3(0.16, size.y, 0.19), color.darkened(0.19))
		var door := at + Vector3(side * size.x * 0.24, size.y * 0.5, size.z * 0.505)
		_box(door, Vector3(size.x * 0.44, size.y - 0.39, 0.07), color.darkened(0.14))
		for bar in [-0.12, 0.12]:
			var center := door + Vector3(bar * size.x, 0, 0.054)
			batches.put(Fabric.tube(0.032, size.y * 0.88, 6), Fabric.paint(STEEL), center)
			_box(center + Vector3(0.11, -0.24, 0.029), Vector3(0.24, 0.043, 0.053), INK)
	_stencil(code, at + Vector3(size.x * 0.23, size.y * 0.71, size.z * 0.5 + 0.09), Vector3.ZERO, 0.009, accent)

func _distant_beacon() -> void:
	_box(Vector3(18, 12.0, -41), Vector3(4.6, 24.0, 4.6), Color("#48566a"), false, Vector3.ZERO, 0.43)
	_box(Vector3(18, 24.2, -41), Vector3(5.3, 0.61, 5.3), Color("#586c7c"), false, Vector3.ZERO, 0.48)
	batches.put(Fabric.tube(0.18, 6.2, 10), Fabric.paint(SLATE), Vector3(18, 27.4, -41))
	_box(Vector3(18, 30.58, -41), Vector3(0.53, 0.29, 0.53), CLAY, true)
