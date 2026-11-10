extends "res://game/arena.gd"

const CONCRETE := Color("#a39c87")
const SAND := Color("#a28c65")
const BRICK := Color("#965844")
const WOOD := Color("#6a5141")
const LEAF := Color("#617451")
const WINDOW := Color("#6f929f")
const TARMAC := Color("#424952")
const TILE := Color("#b9c0be")

func _init(id := "bastion") -> void:
	map_id = id
	half_size = Vector2(25, 24)
	start_at = Vector3(0, 0.06, 19)
	terminal_at = Vector3(3.0, 1.0, 19.0)
	spawn_points.assign([Vector3(-20, 0.06, 19), Vector3(20, 0.06, 19), Vector3(-20, 0.06, -19),
		Vector3(20, 0.06, -19), Vector3(-22, 0.06, 0), Vector3(22, 0.06, 0),
		Vector3(-4, 0.06, -20), Vector3(4, 0.06, -20)])
	practice_points.assign([Vector3(-5, 0.06, 13), Vector3(0, 0.06, 7),
		Vector3(6, 0.06, 13), Vector3(-4, 0.06, -7)])
	control_points.assign([Vector3(-14, 0.06, 10), Vector3(0, 0.06, 0), Vector3(14, 0.06, -10)])

func _build_layout() -> void:
	name = {"bastion": "BastionRelay", "district": "MeridianDistrict", "grove": "AshgroveRuins", "station": "TransitHall"}[map_id]
	_floor()
	match map_id:
		"bastion":
			_boundary(3.6, SAND)
			_bastion()
		"district":
			_boundary(5.8, BRICK)
			_district()
		"grove":
			_boundary(3.2, LEAF)
			_grove()
		"station":
			_boundary(6.7, STEEL)
			_station()
	_terminal()

func _floor() -> void:
	deck_surface = ShaderMaterial.new()
	deck_surface.shader = preload("res://assets/art/deck.gdshader")
	var surface := PlaneMesh.new()
	surface.size = half_size * 2.0
	Fabric.place(structure, surface, deck_surface, Vector3.ZERO, Vector3.ZERO, false)
	_block(Vector3(0, -0.35, 0), Vector3(50, 0.7, 48), Vector3.ZERO, false)
	var plaque: String = {"bastion": "POSTE RADIO 02", "district": "RUE DU MARCHÉ",
		"grove": "SENTIER NORD", "station": "ACCÈS AUX QUAIS"}[map_id]
	_stencil(plaque, Vector3(0, 0.028, 16.3), Vector3(-PI * 0.5, 0, 0), 0.021, WHITE)

func _boundary(height: float, shade: Color) -> void:
	for side in [-1.0, 1.0]:
		_solid(Vector3(side * 24.8, height * 0.5, 0), Vector3(0.46, height, 48), shade, 0.14, false)
		_solid(Vector3(0, height * 0.5, side * 23.8), Vector3(50, height, 0.46), shade, 0.14, false)
		for i in range(-22, 23, 4):
			_box(Vector3(side * 24.53, height * 0.53, i), Vector3(0.24, height * 0.97, 0.32), shade.darkened(0.28))
			_box(Vector3(i, height * 0.53, side * 23.53), Vector3(0.32, height * 0.97, 0.24), shade.darkened(0.28))

func _bastion() -> void:
	for side in [-1.0, 1.0]:
		for z in [-13.0, 5.2]:
			var at := Vector3(side * 10.7, 0, z)
			_solid(at + Vector3.UP * 1.65, Vector3(6.6, 3.3, 4.5), SAND, 0.22)
			_box(at + Vector3.UP * 3.4, Vector3(7.1, 0.33, 5.0), CONCRETE, false, Vector3.ZERO, 0.18)
			_box(at + Vector3(0, 1.15, 2.29), Vector3(3.7, 2.3, 0.06), TARMAC)
			for rib in range(-2, 3):
				_box(at + Vector3(rib * 0.64, 1.15, 2.34), Vector3(0.09, 2.1, 0.08), STEEL)
			_stencil("SOUTE 02" if side < 0 else "SOUTE 03", at + Vector3(0, 2.80, 2.29), Vector3.ZERO, 0.012, WHITE)
		_ramp_deck(Vector3(side * 18.4, 0, 0), 3.5, 1.6, 8.0, SAND)
		_supply(Vector3(side * 6, 0, -3.5), Vector3(2.8, 1.27, 1.8), GOLD)
		for z in range(-16, 16, 4):
			_box(Vector3(side * 2.9, 0.016, z), Vector3(0.14, 0.026, 2.3), WHITE)
	var base := Vector3(0, 0, -13.5)
	_solid(base + Vector3.UP * 1.05, Vector3(3.2, 2.1, 2.6), CONCRETE, 0.23)
	for x in [-0.75, 0.75]:
		_box(base + Vector3(x, 5.65, 0), Vector3(0.16, 7.5, 0.16), STEEL)
	for y in range(3, 10):
		_box(base + Vector3(0, y, 0), Vector3(0.14, 1.8, 0.14), SLATE, false, Vector3(0, 0, 0.95 if y % 2 == 0 else -0.95))
	_box(base + Vector3(0, 9.36, 0), Vector3(0.32, 0.38, 0.32), GOLD, true)

func _district() -> void:
	_box(Vector3(0, 0.018, 0), Vector3(7.6, 0.027, 47.0), TARMAC)
	_box(Vector3(0, 0.019, 0), Vector3(48.0, 0.028, 6.4), TARMAC)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 3.1, 0.031, 0), Vector3(0.10, 0.018, 44), CONCRETE)
		_box(Vector3(side * 0.78, 0.033, 0), Vector3(0.11, 0.021, 46), STEEL)
		for z in [-11.0, 10.0]:
			var at := Vector3(side * 12.5, 0, z)
			var height: float = 5.1 if side * z > 0.0 else 7.6
			var color := BRICK if height > 6.0 else CONCRETE
			var width := 6.5 if side * z > 0.0 else 8.1
			_building(at, width, height, 5.5, color)
		for i in range(-2, 3):
			_box(Vector3(i * 0.60, 0.041, side * 3.5), Vector3(0.37, 0.015, 1.0), WHITE)
		_supply(Vector3(side * 5.7, 0, side * 5.8), Vector3(2.1, 0.97, 1.10), Color("#789077"))
		_box(Vector3(side * 7.8, 2.8, -side * 3.9), Vector3(0.11, 5.6, 0.11), SLATE)
		_box(Vector3(side * 7.48, 5.45, -side * 3.9), Vector3(0.8, 0.12, 0.24), WHITE, true)
	# Points des îlots, dégagés des façades.
	control_points[0] = Vector3(-7.4, 0.06, 12.8)
	control_points[2] = Vector3(7.2, 0.06, -11.1)

func _building(at: Vector3, width: float, height: float, depth: float, color: Color) -> void:
	var volume := Vector3(width, height, depth)
	_block(at + Vector3.UP * height * 0.5, volume)
	var material := Materials.finish(color, "brick" if height > 6.0 else "concrete", 0.57)
	batches.put(Fabric.bevel(volume, 0.055), material, at + Vector3.UP * height * 0.5)
	_box(at + Vector3.UP * (height + 0.14), Vector3(width + 0.45, 0.32, depth + 0.45), CONCRETE)
	for face in [-1.0, 1.0]:
		_box(at + Vector3(0, 1.06, face * (depth * 0.5 + 0.021)), Vector3(width * 0.67, 1.7, 0.047), TARMAC)
		for level in range(3, int(height), 2):
			for i in [-1.0, 0.0, 1.0]:
				var window := at + Vector3(i * width * 0.265, level, face * (depth * 0.5 + 0.025))
				_box(window, Vector3(1.22, 0.83, 0.07), STEEL)
				_box(window + Vector3(0, 0, face * 0.047), Vector3(1.01, 0.66, 0.033), WINDOW)
				_box(window - Vector3.UP * 0.43, Vector3(1.38, 0.13, 0.18), CONCRETE)

	for side in [-1.0, 1.0]:
		var face: float = side * (width * 0.5 + 0.044)
		for level in range(2, int(height), 2):
			for column in [-0.28, 0.0, 0.28]:
				var at_window := at + Vector3(face, level + 0.38, depth * column)
				_box(at_window, Vector3(0.072, 0.98, 1.08), CONCRETE)
				_box(at_window + Vector3(side * 0.045, 0, 0), Vector3(0.039, 0.79, 0.91), WINDOW.darkened(0.31))
				_box(at_window + Vector3(side * 0.073, 0, 0), Vector3(0.026, 0.80, 0.043), STEEL)
		var storefront := at + Vector3(face, 1.09, 0.0)
		_box(storefront, Vector3(0.10, 1.99, 2.4), TARMAC)
		for slat in 12:
			_box(storefront + Vector3(side * 0.057, -0.89 + slat * 0.16, 0), Vector3(0.025, 0.046, 2.34), STEEL)
		var sign_at := storefront + Vector3(side * 0.093, 1.21, 0)
		_box(sign_at, Vector3(0.13, 0.36, 2.48), Color("#66664d"))
		_stencil("MARCHÉ" if height > 6.0 else "ATELIER", sign_at + Vector3(side * 0.071, 0, 0),
			Vector3(0, side * PI * 0.5, 0), 0.007, WHITE)

func _grove() -> void:
	for side in [-1.0, 1.0]:
		for z in [-13.4, 6.8]:
			var at := Vector3(side * 10.2, 0, z)
			for x in [-2.45, 2.45]:
				_solid(at + Vector3(x, 1.58, 0), Vector3(1.78, 3.16, 1.20), CONCRETE, 0.28)
				_box(at + Vector3(x, 3.12, 0), Vector3(2.12, 0.33, 1.4), LEAF, false, Vector3.ZERO, 0.12)
			_solid(at + Vector3(0, 3.08, 0), Vector3(4.18, 0.68, 1.05), CONCRETE, 0.23, false)
			for column in [-2.46, 2.46]:
				for course in 6:
					var depth := 0.62 + 0.04 * sin(float(course) * 2.1)
					var face := at + Vector3(column + sin(float(course) * 2.7) * 0.12, 0.37 + course * 0.49, depth)
					_box(face, Vector3(1.45, 0.42, 0.16), CONCRETE.darkened(0.07 + 0.07 * (course % 3)),
						false, Vector3(0, 0, 0.04 * sin(float(course))), 0.077)
			for j in 7:
				var stone := at + Vector3(-2.64 + j * 0.81, 0.09, 0.90 + 0.67 * cos(float(j) * 2.42))
				_box(stone, Vector3(0.32, 0.17, 0.38), CONCRETE.darkened(0.12), false,
					Vector3(0, float(j) * 0.41, 0.16), 0.089)
		for z in [-17.8, -6.7, 5.3, 14.1]:
			_tree(Vector3(side * (15.4 + fposmod(z, 3.1)), 0, z), 5.8 + fposmod(z, 1.5))
		_solid(Vector3(side * 5.9, 0.57, side * -8.8), Vector3(3.3, 1.14, 1.6), SAND, 0.46)
		_solid(Vector3(side * 11.0, 0.64, side * 14.7), Vector3(3.3, 1.28, 1.8), LEAF, 0.40)

func _tree(at: Vector3, height: float) -> void:
	var branch := RandomNumberGenerator.new()
	branch.seed = hash(at)
	Scenery.tree(batches, at, height, branch)
	_block(at + Vector3.UP * height * 0.5, Vector3(0.63, height, 0.63))

func _station() -> void:
	_solid(Vector3(0, 6.74, 0), Vector3(50, 0.30, 48), TILE, 0.12, false)
	for z in range(-19, 20, 6):
		_box(Vector3(0, 6.20, z), Vector3(48, 0.57, 0.39), SLATE)
		for x in [-16.0, -8.0, 0.0, 8.0, 16.0]:
			_box(Vector3(x, 5.86, z), Vector3(2.2, 0.09, 0.30), INK)
			_box(Vector3(x, 5.80, z), Vector3(1.96, 0.034, 0.18), WHITE)
	for side in [-1.0, 1.0]:
		_ramp_deck(Vector3(side * 19, 0, 0), 4.5, 1.9, 16, TILE)
		_box(Vector3(side * 22.8, 2.82, 0), Vector3(0.18, 1.1, 17.5), STEEL)
		for z in [-12.0, 3.5, 12.6]:
			var at := Vector3(side * 8.9, 0, z)
			_solid(at + Vector3.UP * 3.24, Vector3(1.12, 6.48, 1.12), TILE, 0.18)
			_box(at + Vector3.UP * 0.6, Vector3(1.2, 0.23, 1.2), GOLD)
			_supply(at + Vector3(side * 1.55, 0, 0), Vector3(1.7, 1.08, 2.3), WINDOW)
		_box(Vector3(side * 5, 0.025, 0), Vector3(0.14, 0.04, 47.0), GOLD)
		_box(Vector3(side * 4.3, 0.023, 0), Vector3(0.11, 0.035, 47.0), STEEL)
		for lane in [-0.70, 0.70]:
			_box(Vector3(side * 2.4 + lane, 0.035, 0), Vector3(0.052, 0.025, 46.6), Color("#6f746e"))
		for z in range(-22, 23, 2):
			_box(Vector3(side * 2.4, 0.019, z), Vector3(1.62, 0.024, 0.19), WOOD.darkened(0.31))
		_box(Vector3(side * 13, 3.27, -23.10), Vector3(5.7, 0.93, 0.17), Color("#384249"))
		_stencil("QUAI %s" % ("01" if side < 0 else "02"), Vector3(side * 13, 3.29, -22.99), Vector3.ZERO, 0.013, WHITE)
		_supply(Vector3(side * 3.8, 0, side * 9), Vector3(1.9, 1.18, 2.7), WINDOW)

func _ramp_deck(at: Vector3, width: float, rise: float, length: float, shade: Color) -> void:
	_solid(at + Vector3.UP * rise * 0.5, Vector3(width, rise, length), shade, 0.11)
	var run := rise * 3.4
	var slope := atan2(rise, run)
	for side in [-1.0, 1.0]:
		var ramp := at + Vector3(0, rise * 0.5 - 0.07, side * (length + run) * 0.5)
		var turn := Vector3(side * slope, 0, 0)
		var volume := Vector3(width, 0.24, Vector2(rise, run).length() + 0.09)
		_box(ramp, volume, shade, false, turn, 0.06)
		_block(ramp, volume, turn, false)
