extends RefCounted

const Fabric := preload("res://game/fabric.gd")
const DARK := Color("#222b31")
const PLATE := Color("#8a9691")
const LIGHT := Color("#d0c8ad")
const RUST := Color("#b6684a")

static var cache := {}

static func build(hull: Node3D, kind: String, tint: Color) -> MeshInstance3D:
	var boss := kind in ["warden", "colossus", "architect"]
	var large := boss or kind in ["bulwark", "elite"]
	var size := (1.72 if kind == "colossus" else 1.58) if boss else (1.19 if kind == "elite" else 1.0)
	var model := Node3D.new()
	hull.add_child(model)
	model.scale = Vector3.ONE * size
	model.position.y = 0.14 if boss else 0.0
	if cache.has(kind):
		for part in cache[kind]:
			Fabric.place(model, part[0], part[1], part[2])
	else:
		var work := Fabric.Batch.new()
		match kind:
			"scout":
				_scout(work, tint)
			"sentinel":
				_sentinel(work, tint)
			"specter":
				_specter(work, tint)
			"skimmer", "medic", "disruptor", "artillery", "colossus", "architect":
				_special(work, tint, kind)
			_:
				_heavy(work, tint, boss)
		work.commit(model)
		var parts := []
		for mesh in model.get_children():
			parts.append([mesh.mesh, mesh.material_override, mesh.position])
		cache[kind] = parts
	var core_y := 0.97 if large else 1.05
	var core_z := -0.57 if large else -0.43
	var lens_mesh := Fabric.bevel(Vector3(0.26 if large else 0.20, 0.155, 0.084), 0.035)
	return Fabric.place(model, lens_mesh, Fabric.paint(tint, true), Vector3(0, core_y, core_z),
		Vector3.ZERO, false)

static func _scout(w: Fabric.Batch, c: Color) -> void:
	_block(w, Vector3(0, 0.94, 0), Vector3(0.72, 0.32, 0.74), DARK, 0.13)
	_block(w, Vector3(0, 1.13, 0.04), Vector3(0.54, 0.16, 0.63), LIGHT, 0.15)
	_block(w, Vector3(0, 0.82, -0.07), Vector3(0.49, 0.14, 0.48), RUST, 0.09)
	for side in [-1.0, 1.0]:
		var x: float = side * 0.43
		_block(w, Vector3(x, 0.92, 0.075), Vector3(0.34, 0.17, 0.53), PLATE, 0.095, Vector3(0, side * -0.23, 0))
		_disk(w, Vector3(x, 0.91, 0.10), 0.205, 0.15, DARK, 10)
		_disk(w, Vector3(x, 0.83, 0.10), 0.179, 0.030, c, 10, true)
		_block(w, Vector3(side * 0.23, 0.99, -0.388), Vector3(0.11, 0.045, 0.025), c, 0.008, Vector3.ZERO, true)
	_block(w, Vector3(0, 1.09, -0.31), Vector3(0.33, 0.15, 0.17), DARK, 0.048)

static func _sentinel(w: Fabric.Batch, c: Color) -> void:
	_disk(w, Vector3(0, 0.95, 0.01), 0.46, 0.34, DARK, 10)
	_disk(w, Vector3(0, 1.18, 0.03), 0.45, 0.13, PLATE, 10)
	_disk(w, Vector3(0, 1.28, 0.04), 0.31, 0.12, LIGHT, 10)
	_disk(w, Vector3(0, 0.74, 0.02), 0.27, 0.10, c, 8, true)
	for side in [-1.0, 1.0]:
		_block(w, Vector3(side * 0.50, 1.01, 0.0), Vector3(0.17, 0.24, 0.85), LIGHT, 0.07, Vector3(0, side * -0.20, side * 0.16))
		_block(w, Vector3(side * 0.54, 0.95, -0.29), Vector3(0.105, 0.13, 0.43), DARK, 0.038)
		_block(w, Vector3(side * 0.54, 1.025, -0.29), Vector3(0.065, 0.032, 0.33), c, 0.025, Vector3.ZERO, true)
	_block(w, Vector3(0, 1.08, -0.38), Vector3(0.32, 0.20, 0.15), DARK, 0.04)
	_block(w, Vector3(0.15, 1.44, 0.15), Vector3(0.040, 0.28, 0.040), PLATE, 0.008, Vector3(0, 0, -0.22))
	_block(w, Vector3(0.17, 1.59, 0.15), Vector3(0.070, 0.038, 0.055), c, 0.010, Vector3.ZERO, true)

static func _specter(w: Fabric.Batch, c: Color) -> void:
	_block(w, Vector3(0, 1.04, 0.08), Vector3(0.45, 0.27, 0.88), DARK, 0.21)
	_block(w, Vector3(0, 1.21, 0.13), Vector3(0.39, 0.10, 0.56), LIGHT, 0.15)
	for side in [-1.0, 1.0]:
		_block(w, Vector3(side * 0.42, 1.05, 0.15), Vector3(0.26, 0.14, 0.68), PLATE, 0.11,
			Vector3(0, -side * 0.62, side * 0.21))
		_block(w, Vector3(side * 0.49, 1.10, 0.27), Vector3(0.077, 0.061, 0.38), c, 0.036,
			Vector3(0, -side * 0.62, 0), true)
		_disk(w, Vector3(side * 0.29, 0.90, 0.27), 0.16, 0.063, c, 8, true)
	_block(w, Vector3(0, 1.05, -0.37), Vector3(0.29, 0.12, 0.11), PLATE, 0.051)

static func _heavy(w: Fabric.Batch, c: Color, boss: bool) -> void:
	_block(w, Vector3(0, 0.88, 0.07), Vector3(0.95, 0.56, 0.99), DARK, 0.16)
	_block(w, Vector3(0, 1.23, 0.13), Vector3(0.86, 0.21, 0.76), PLATE, 0.20)
	_block(w, Vector3(0, 1.37, 0.05), Vector3(0.65, 0.12, 0.63), LIGHT, 0.10)
	_block(w, Vector3(0, 0.94, -0.47), Vector3(0.94, 0.46, 0.15), RUST, 0.07)
	_block(w, Vector3(0, 1.19, -0.49), Vector3(0.84, 0.045, 0.085), c, 0.024, Vector3.ZERO, true)
	for side in [-1.0, 1.0]:
		_disk(w, Vector3(side * 0.52, 0.68, 0.17), 0.20, 0.52, DARK, 8)
		_disk(w, Vector3(side * 0.52, 0.44, 0.17), 0.18, 0.069, c, 8, true)
		_block(w, Vector3(side * 0.55, 0.99, 0.18), Vector3(0.27, 0.22, 0.66), LIGHT, 0.085)
		_block(w, Vector3(side * 0.699, 0.91, 0.12), Vector3(0.039, 0.12, 0.26), c, 0.011, Vector3.ZERO, true)
		if boss:
			_block(w, Vector3(side * 0.63, 1.28, 0.05), Vector3(0.29, 0.20, 0.67), RUST, 0.09,
				Vector3(-0.28, 0, 0))
			_disk(w, Vector3(side * 0.63, 1.35, -0.12), 0.11, 0.44, PLATE, 8, false, Vector3(PI / 2, 0, 0))
	if boss:
		_disk(w, Vector3(0, 1.64, 0.16), 0.28, 0.40, DARK, 8)
		_disk(w, Vector3(0, 1.86, 0.16), 0.19, 0.065, c, 8, true)

static func _special(w: Fabric.Batch, c: Color, role: String) -> void:
	match role:
		"skimmer":
			_specter(w, c)
			for side in [-1.0, 1.0]:
				_disk(w, Vector3(side * 0.52, 1.18, 0.14), 0.22, 0.085, DARK, 10)
				w.put(Fabric.ring(0.24, 0.029, 14), Fabric.paint(c, true), Vector3(side * 0.52, 1.23, 0.14), Vector3.ZERO, false)
		"medic":
			_sentinel(w, c)
			_block(w, Vector3(0, 1.37, 0.11), Vector3(0.45, 0.20, 0.48), LIGHT, 0.08)
			_block(w, Vector3(0, 1.49, 0.11), Vector3(0.31, 0.035, 0.083), c, 0.015, Vector3.ZERO, true)
			_block(w, Vector3(0, 1.49, 0.11), Vector3(0.083, 0.035, 0.31), c, 0.015, Vector3.ZERO, true)
		"disruptor":
			_scout(w, c)
			w.put(Fabric.ring(0.52, 0.048, 12), Fabric.paint(c, true), Vector3(0, 1.08, 0.12), Vector3(0.25, 0, 0.4), false)
			_disk(w, Vector3(0, 1.27, 0.07), 0.21, 0.29, PLATE, 8)
		"artillery":
			_heavy(w, c, false)
			for side in [-1.0, 1.0]:
				_disk(w, Vector3(side * 0.30, 1.46, -0.05), 0.14, 0.65, PLATE, 9, false, Vector3(0.85, 0, 0))
				_disk(w, Vector3(side * 0.30, 1.69, -0.27), 0.115, 0.078, c, 9, true, Vector3(0.85, 0, 0))
		"colossus":
			_heavy(w, c, true)
			for side in [-1.0, 1.0]:
				_block(w, Vector3(side * 0.65, 1.02, -0.37), Vector3(0.47, 0.73, 0.22), PLATE, 0.12, Vector3(0, side * 0.29, 0))
				_block(w, Vector3(side * 0.65, 1.13, -0.51), Vector3(0.30, 0.072, 0.031), c, 0.013, Vector3(0, side * 0.29, 0), true)
		"architect":
			_sentinel(w, c)
			_disk(w, Vector3(0, 1.39, 0.04), 0.27, 0.45, DARK, 8)
			for y in [1.25, 1.50, 1.72]:
				w.put(Fabric.ring(0.58 - (y - 1.25) * 0.32, 0.038, 14), Fabric.paint(c, true),
					Vector3(0, y, 0.04), Vector3(0.22, y, -0.26), false)
static func _block(w: Fabric.Batch, at: Vector3, size: Vector3, c: Color,
		cut: float, rot := Vector3.ZERO, luminous := false) -> void:
	w.put(Fabric.bevel(size, cut), Fabric.paint(c, luminous), at, rot, false)

static func _disk(w: Fabric.Batch, at: Vector3, radius: float, depth: float, c: Color,
		sides: int, luminous := false, rot := Vector3.ZERO) -> void:
	w.put(Fabric.tube(radius, depth, sides), Fabric.paint(c, luminous), at, rot, false)
