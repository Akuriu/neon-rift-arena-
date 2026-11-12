extends RefCounted

const Fabric := preload("res://game/fabric.gd")
const Materials := preload("res://art/materials.gd")
const DARK := Color("#3a3e3a")
const STEEL := Color("#6c706c")
const EDGE := Color("#8e8e83")
const RUBBER := Color("#282b28")
const GLASS := Color("#485952")
const WALNUT := Color("#946445")
const TAN := Color("#a39474")
const FLASH := Color("#fff2b7")
const MUZZLES := [-0.68, -0.72, -0.27, -0.43, -0.86, -0.91, -0.42, -0.60]
const SIGHT_HEIGHTS := [0.092, 0.063, 0.062, 0.104, 0.146, 0.150, 0.089, 0.099]

static var cache := {}

static func build(root: Node3D, index: int, skin := "", first_person := false, firing_fx := false) -> Dictionary:
	var key := [index, skin]
	if cache.has(key):
		for part in cache[key]:
			Fabric.place(root, part[0], part[1], part[2], Vector3.ZERO, false)
	else:
		var work := Fabric.Batch.new()
		var stock := _stock_color(index, skin)
		match index:
			0: _carbine(work, stock)
			1: _shotgun(work, stock)
			2: _pistol(work)
			3: _launcher(work, stock, false)
			4, 5: _precision(work, stock, index == 5)
			6: _submachine(work, stock)
			7: _launcher(work, stock, true)
		work.commit(root, false)
		var meshes := []
		for part in root.get_children():
			meshes.append([part.mesh, part.material_override, part.position])
		cache[key] = meshes

	var magazine := Node3D.new()
	var bolt := Node3D.new()
	root.add_child(magazine)
	root.add_child(bolt)
	_actions(magazine, bolt, index, _stock_color(index, skin))

	var muzzle := Node3D.new()
	muzzle.position = Vector3(0, 0.018 if index != 2 else 0.025, MUZZLES[index] - 0.017)
	root.add_child(muzzle)
	var flare := _muzzle_flash(muzzle) if first_person or firing_fx else null
	if first_person:
		_hands(root, index)
	return {"muzzle": muzzle, "flash": flare, "magazine": magazine, "bolt": bolt}

static func _stock_color(index: int, skin: String) -> Color:
	match skin:
		"skin_copper": return Color("#816349")
		"skin_glacier": return Color("#777e79")
		"skin_ash": return Color("#ad9e82")
		"skin_aurora": return Color("#737d5f")
	return WALNUT if index in [1, 5] else TAN if index in [0, 4] else Color("#555b4d")

static func _carbine(w: Fabric.Batch, stock: Color) -> void:
	_block(w, Vector3(0, 0, 0.047), Vector3(0.092, 0.133, 0.36), DARK)
	_block(w, Vector3(0, 0.058, 0.035), Vector3(0.079, 0.042, 0.365), STEEL)
	_block(w, Vector3(0, -0.019, -0.305), Vector3(0.098, 0.101, 0.334), stock)
	for side in [-1.0, 1.0]:
		for i in 7:
			_block(w, Vector3(side * 0.049, -0.018, -0.44 + 0.044 * i), Vector3(0.003, 0.024, 0.027), RUBBER, 0.001)
	_barrel(w, -0.423, MUZZLES[0], 0.019)
	_stock(w, stock, 0.45, true)
	_grip(w, 0.146)
	_rail(w, -0.258, 13, 0.072)
	_irons(w, -0.44, 0.202, SIGHT_HEIGHTS[0])

static func _shotgun(w: Fabric.Batch, stock: Color) -> void:
	_block(w, Vector3(0, 0.008, 0.012), Vector3(0.071, 0.104, 0.32), STEEL)
	_barrel(w, -0.105, MUZZLES[1], 0.024)
	_cylinder(w, Vector3(0, -0.039, -0.323), 0.021, 0.47, DARK)
	_block(w, Vector3(0, -0.020, 0.291), Vector3(0.073, 0.074, 0.27), stock, 0.023, Vector3(0.21, 0, 0), "timber")
	_block(w, Vector3(0, -0.074, 0.431), Vector3(0.077, 0.149, 0.22), stock, 0.028, Vector3(0.28, 0, 0), "timber")
	_block(w, Vector3(0, -0.090, 0.543), Vector3(0.080, 0.141, 0.029), RUBBER)
	_grip(w, 0.13, false)
	_irons(w, -0.665, 0.14, SIGHT_HEIGHTS[1])

static func _pistol(w: Fabric.Batch) -> void:
	_block(w, Vector3(0, -0.009, -0.044), Vector3(0.066, 0.059, 0.32), RUBBER)
	_barrel(w, -0.065, MUZZLES[2], 0.015)
	_block(w, Vector3(0, -0.105, 0.103), Vector3(0.063, 0.184, 0.101), DARK, 0.014, Vector3(-0.22, 0, 0))
	for side in [-1.0, 1.0]:
		_block(w, Vector3(side * 0.033, -0.109, 0.105), Vector3(0.008, 0.113, 0.069), RUBBER, 0.003, Vector3(-0.22, 0, 0))
		_block(w, Vector3(side * 0.034, -0.029, 0.013), Vector3(0.006, 0.017, 0.044), STEEL, 0.002)
	_block(w, Vector3(0, -0.081, -0.027), Vector3(0.027, 0.016, 0.15), DARK)
	_block(w, Vector3(0, -0.044, -0.089), Vector3(0.024, 0.067, 0.016), DARK)

static func _precision(w: Fabric.Batch, stock: Color, bolt_action: bool) -> void:
	_block(w, Vector3(0, -0.018, -0.036), Vector3(0.087, 0.101, 0.48), stock,
		0.019, Vector3.ZERO, "timber" if bolt_action else "steel")
	_block(w, Vector3(0, 0.030, 0.015), Vector3(0.081, 0.066, 0.37), STEEL)
	_block(w, Vector3(0, -0.017, -0.320), Vector3(0.076, 0.077, 0.26), stock,
		0.016, Vector3.ZERO, "timber" if bolt_action else "steel")
	_barrel(w, -0.19, MUZZLES[5 if bolt_action else 4], 0.018 if bolt_action else 0.022)
	_stock(w, stock, 0.49, not bolt_action)
	_grip(w, 0.158)
	_rail(w, -0.177, 11, 0.063)
	_scope(w, -0.053, 0.144 if bolt_action else 0.141, 0.37 if bolt_action else 0.315)

static func _submachine(w: Fabric.Batch, stock: Color) -> void:
	_block(w, Vector3(0, 0.014, -0.031), Vector3(0.078, 0.102, 0.36), DARK)
	_block(w, Vector3(0, -0.008, -0.242), Vector3(0.088, 0.111, 0.145), stock)
	_cylinder(w, Vector3(0, 0.018, -0.36), 0.023, 0.075, STEEL)
	_barrel(w, -0.28, MUZZLES[6], 0.015)
	_grip(w, 0.116)
	for side in [-1.0, 1.0]:
		_block(w, Vector3(side * 0.024, 0.016, 0.27), Vector3(0.023, 0.026, 0.26), STEEL)
	_block(w, Vector3(0, -0.01, 0.399), Vector3(0.073, 0.135, 0.026), RUBBER)
	_rail(w, -0.112, 8, 0.068)
	_irons(w, -0.282, 0.127, SIGHT_HEIGHTS[6])

static func _launcher(w: Fabric.Batch, stock: Color, drum: bool) -> void:
	var tip := MUZZLES[7 if drum else 3] as float
	var breech := -0.28 if drum else 0.049
	var radius := 0.046 if drum else 0.053
	_barrel(w, breech, tip, radius)
	_cylinder(w, Vector3(0, 0.018, tip + 0.056), radius + 0.005, 0.085, STEEL)
	_block(w, Vector3(0, -0.04, 0.104), Vector3(0.083, 0.114, 0.23), DARK)
	_block(w, Vector3(0, -0.036, tip + 0.125), Vector3(0.11, 0.071, 0.16), stock)
	for i in 4:
		_block(w, Vector3(0, -0.071, tip + 0.076 + i * 0.029), Vector3(0.104, 0.021, 0.011), RUBBER, 0.004)
	_grip(w, 0.168)
	_stock(w, stock, 0.44, true)
	_irons(w, tip + 0.077, 0.13, SIGHT_HEIGHTS[7 if drum else 3])

static func _actions(magazine: Node3D, bolt: Node3D, index: int, stock: Color) -> void:
	var w := Fabric.Batch.new()
	var b := Fabric.Batch.new()
	magazine.position = Vector3(0, -0.075, -0.072)
	match index:
		1:
			magazine.position = Vector3(0, -0.061, -0.126)
			_cylinder(w, Vector3.ZERO, 0.015, 0.058, Color("#825244"))
			_cylinder(w, Vector3(0, 0, 0.024), 0.0155, 0.013, Color("#a98a54"))
			_block(b, Vector3(0, -0.037, -0.38), Vector3(0.087, 0.073, 0.205), stock, 0.020, Vector3.ZERO, "timber")
			for i in 7:
				_block(b, Vector3(0, -0.077, -0.468 + i * 0.028), Vector3(0.080, 0.015, 0.011), stock.darkened(0.28), 0.003)
		2:
			magazine.position = Vector3(0, -0.144, 0.121)
			_block(w, Vector3(0, -0.005, 0), Vector3(0.046, 0.108, 0.073), DARK)
			_block(w, Vector3(0, -0.054, 0), Vector3(0.069, 0.018, 0.094), RUBBER)
			_block(b, Vector3(0, 0.024, -0.040), Vector3(0.065, 0.052, 0.370), STEEL)
			_block(b, Vector3(0.012, 0.052, -0.022), Vector3(0.041, 0.004, 0.075), DARK, 0.002)
			for side in [-1.0, 1.0]:
				for i in 6:
					_block(b, Vector3(side * 0.033, 0.024, 0.073 + i * 0.011), Vector3(0.006, 0.039, 0.004), DARK, 0.001, Vector3(-0.22, 0, 0))
			_irons(b, -0.195, 0.125, SIGHT_HEIGHTS[2])
		3:
			magazine.position = Vector3(0, -0.005, -0.109)
			_cylinder(w, Vector3.ZERO, 0.032, 0.107, Color("#8e886d"))
			_cylinder(w, Vector3(0, 0, 0.040), 0.0325, 0.023, Color("#b29963"))
			_block(b, Vector3(0.051, 0.029, 0.071), Vector3(0.024, 0.048, 0.081), STEEL)
		7:
			magazine.position = Vector3(0, 0.004, -0.124)
			_cylinder(w, Vector3.ZERO, 0.100, 0.175, DARK, 12)
			for i in 6:
				var angle := TAU * i / 6.0
				_cylinder(w, Vector3(sin(angle) * 0.053, cos(angle) * 0.053, -0.087), 0.027, 0.009, STEEL)
			_block(b, Vector3(0, 0.074, -0.079), Vector3(0.076, 0.019, 0.21), STEEL)
		_:
			var length := 0.18 if index in [0, 6] else 0.098
			var width := 0.043 if index == 6 else 0.061
			var depth := 0.064 if index == 6 else 0.105
			_block(w, Vector3(0, -length * 0.45, -0.007), Vector3(width, length, depth), STEEL,
				0.009, Vector3(-0.16 if index == 0 else 0.04, 0, 0))
			_block(w, Vector3(0, -length, 0), Vector3(width + 0.012, 0.024, depth + 0.015), RUBBER)
			for side in [-1.0, 1.0]:
				_block(w, Vector3(side * width * 0.50, -length * 0.47, 0.009), Vector3(0.004, length * 0.72, 0.019), DARK, 0.001)
			_block(b, Vector3(0.040, 0.045, -0.018), Vector3(0.012, 0.041, 0.107), RUBBER, 0.004)
			_block(b, Vector3(0.044, 0.043, -0.015), Vector3(0.013, 0.023, 0.068), EDGE, 0.003)
			if index in [4, 5]:
				_block(b, Vector3(0.072, 0.045, 0.072), Vector3(0.062, 0.022, 0.024), STEEL, 0.005, Vector3(0, 0, -0.41))
				_block(b, Vector3(0.102, 0.031, 0.074), Vector3(0.026, 0.031, 0.027), DARK, 0.008)
	magazine.set_meta("home", magazine.position)
	w.commit(magazine, false)
	b.commit(bolt, false)

static func _stock(w: Fabric.Batch, c: Color, rear: float, adjustable: bool) -> void:
	if adjustable:
		_cylinder(w, Vector3(0, 0.006, rear - 0.126), 0.028, 0.25, STEEL)
		_block(w, Vector3(0, 0.005, rear - 0.051), Vector3(0.080, 0.075, 0.185), c, 0.018)
		_block(w, Vector3(0, -0.079, rear - 0.043), Vector3(0.060, 0.035, 0.16), c,
			0.012, Vector3(-0.38, 0, 0))
	else:
		_block(w, Vector3(0, -0.028, rear - 0.102), Vector3(0.085, 0.123, 0.32), c,
			0.024, Vector3(0.13, 0, 0), "timber")
	_block(w, Vector3(0, -0.034, rear + 0.052), Vector3(0.091, 0.156, 0.038), RUBBER, 0.012)

static func _grip(w: Fabric.Batch, z: float, grip := true) -> void:
	if grip:
		_block(w, Vector3(0, -0.116, z), Vector3(0.058, 0.156, 0.073), RUBBER,
			0.011, Vector3(-0.25, 0, 0))
	_block(w, Vector3(0, -0.093, z - 0.076), Vector3(0.024, 0.017, 0.133), DARK)
	_block(w, Vector3(0, -0.071, z - 0.127), Vector3(0.025, 0.052, 0.022), DARK)
	_block(w, Vector3(0, -0.064, z - 0.063), Vector3(0.016, 0.054, 0.013), STEEL,
		0.003, Vector3(0.3, 0, 0))

static func _barrel(w: Fabric.Batch, near_z: float, tip: float, radius: float) -> void:
	_cylinder(w, Vector3(0, 0.018, (near_z + tip) * 0.5), radius, near_z - tip, STEEL)
	_cylinder(w, Vector3(0, 0.018, tip + 0.018), radius * 1.16, 0.041, DARK)
	_cylinder(w, Vector3(0, 0.018, tip - 0.0035), radius * 0.73, 0.0025, RUBBER)

static func _rail(w: Fabric.Batch, start: float, count: int, height: float) -> void:
	for i in count:
		_block(w, Vector3(0, height, start + i * 0.031), Vector3(0.057, 0.016, 0.022), DARK, 0.003)

static func _irons(w: Fabric.Batch, front: float, back: float, y: float) -> void:
	_block(w, Vector3(0, y - 0.008, front), Vector3(0.011, 0.027, 0.019), RUBBER, 0.002)
	for side in [-1.0, 1.0]:
		_block(w, Vector3(side * 0.019, y - 0.009, back), Vector3(0.019, 0.021, 0.027), DARK, 0.003)
		_block(w, Vector3(side * 0.013, y - 0.006, back + 0.016), Vector3(0.003, 0.006, 0.003), EDGE, 0.001)
	_block(w, Vector3(0, y - 0.022, back), Vector3(0.058, 0.014, 0.026), RUBBER, 0.004)

static func _scope(w: Fabric.Batch, z: float, y: float, length: float) -> void:
	for end in [-1.0, 1.0]:
		_block(w, Vector3(0, y - 0.049, z + end * 0.087), Vector3(0.079, 0.062, 0.035), STEEL)
		_cylinder(w, Vector3(0, y, z + end * (length * 0.5 - 0.043)), 0.043, 0.086, DARK)
		_cylinder(w, Vector3(0, y, z + end * (length * 0.5 + 0.001)), 0.033, 0.004, GLASS)
	_cylinder(w, Vector3(0, y, z), 0.028, length - 0.06, DARK)
	w.put(Fabric.tint_surface(Fabric.tube(0.021, 0.024, 10), STEEL), Materials.vertex_finish("steel", 9.0, 0.32),
		Vector3(0, y + 0.030, z), Vector3.ZERO, false)

static func _hands(root: Node3D, index: int) -> void:
	var w := Fabric.Batch.new()
	var right := Vector3(0.028, -0.11, 0.152 if index != 2 else 0.114)
	var left := Vector3(-0.046, -0.075, [-0.255, -0.362, 0.055, -0.231, -0.277, -0.291, -0.215, -0.259][index])
	for side in [0, 1]:
		var palm: Vector3 = right if side == 0 else left
		var wrist := palm + Vector3(0.023 if side == 0 else -0.034, -0.025, 0.049)
		var elbow := Vector3(0.17 if side == 0 else -0.23, -0.37, 0.52)
		var link := elbow - wrist
		w.put(Fabric.tint_surface(Fabric.tube(0.064, link.length(), 10, 0.044), Color("#747860")),
			Materials.vertex_finish("canvas", 12.0),
			(wrist + elbow) * 0.5, Basis(Quaternion(Vector3.UP, link.normalized())).get_euler(), false)
		_block(w, wrist, Vector3(0.092, 0.079, 0.075), Color("#5c5e52"), 0.02, Vector3(0.28, 0, 0), "canvas")
		_block(w, palm, Vector3(0.079, 0.101 if side == 0 else 0.066, 0.112), Color("#4b4a40"),
			0.024, Vector3(0.16, 0, -0.22), "canvas")
		for i in 4:
			var knuckle := palm + Vector3(-0.028, -0.026 + i * 0.016, -0.049 + i * 0.007)
			_block(w, knuckle, Vector3(0.042, 0.019, 0.037), Color("#5c5a4a"), 0.009)
	w.commit(root, false)

static func _muzzle_flash(anchor: Node3D) -> Node3D:
	var flash := Node3D.new()
	anchor.add_child(flash)
	for angle in [0.0, PI * 0.5]:
		Fabric.place(flash, Fabric.bevel(Vector3(0.105, 0.017, 0.21), 0.046),
			Fabric.paint(FLASH, true), Vector3(0, 0, -0.075), Vector3(0, 0, angle), false)
	flash.hide()
	return flash

static func _block(w: Fabric.Batch, at: Vector3, size: Vector3, color: Color, cut := 0.012,
		rotation := Vector3.ZERO, finish := "steel") -> void:
	var paint := Materials.vertex_finish(finish, 9.0 if finish == "steel" else 4.0, 0.26 if finish == "steel" else 0.0)
	w.put(Fabric.bevel(size, cut, color), paint, at, rotation, false)

static func _cylinder(w: Fabric.Batch, at: Vector3, radius: float, depth: float, color: Color, sides := 12) -> void:
	w.put(Fabric.tint_surface(Fabric.tube(radius, depth, sides), color), Materials.vertex_finish("steel", 9.0, 0.33),
		at, Vector3(PI * 0.5, 0, 0), false)
