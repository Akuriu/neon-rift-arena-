extends RefCounted

const Fabric := preload("res://game/fabric.gd")
const GRAPHITE := Color("#242d33")
const FRAME := Color("#6d8189")
const CERAMIC := Color("#c8d1c6")
const WARNING := Color("#be6f45")
static var cache := {}

static func make(root: Node3D, index: int, tint: Color, skin := "") -> MeshInstance3D:
	var key := "%d/%s" % [index, skin]
	var shell := Color("#b86d4d") if skin == "skin_copper" else (Color("#7cabc7") if skin == "skin_glacier" else CERAMIC)
	if skin == "skin_ash":
		shell = Color("#d9d0b9")
	elif skin == "skin_aurora":
		shell = Color("#428878")
	if cache.has(key):
		for part in cache[key]:
			Fabric.place(root, part[0], part[1], part[2], Vector3.ZERO, false)
	else:
		var batch := Fabric.Batch.new()
		var length := [0.55, 0.42, 0.61, 0.48, 0.92, 0.84, 0.69, 0.56][index] as float
		_block(batch, Vector3(0.0, -0.010, 0.015), Vector3(0.20, 0.148, length), GRAPHITE, 0.048)
		_block(batch, Vector3(0.0, -0.101, 0.100), Vector3(0.105, 0.185, 0.18), GRAPHITE,
			0.026, Vector3(-0.35, 0, 0))
		_block(batch, Vector3(0.010, -0.174, 0.135), Vector3(0.155, 0.095, 0.205), FRAME,
			0.030, Vector3(-0.28, 0, -0.12))
		_block(batch, Vector3(0.0, 0.073, 0.062), Vector3(0.145, 0.055, 0.235), shell, 0.025)
		_block(batch, Vector3(0.0, 0.104, 0.117), Vector3(0.105, 0.012, 0.069), GRAPHITE, 0.012)
		_block(batch, Vector3(0.0, 0.112, 0.119), Vector3(0.070, 0.009, 0.049), tint,
			0.009, Vector3.ZERO, true)
		_block(batch, Vector3(0.0, 0.029, 0.22), Vector3(0.163, 0.097, 0.105), FRAME, 0.025)
		for side in [-1.0, 1.0]:
			_block(batch, Vector3(side * 0.091, 0.010, -0.024), Vector3(0.044, 0.115, length * 0.73),
				shell if index % 2 == 0 else FRAME, 0.014)
			_block(batch, Vector3(side * 0.116, 0.043, -0.035), Vector3(0.009, 0.019, length * 0.56),
				tint, 0.003, Vector3.ZERO, true)
			for vent in 4:
				_block(batch, Vector3(side * 0.116, 0.001, 0.058 - 0.042 * vent),
					Vector3(0.009, 0.034, 0.013), GRAPHITE, 0.003, Vector3(-0.30, 0, 0))
		match index:
			0:
				_block(batch, Vector3(0, 0.004, -0.240), Vector3(0.122, 0.111, 0.158), FRAME, 0.023)
				_block(batch, Vector3(0, 0.008, -0.327), Vector3(0.084, 0.061, 0.022), tint,
					0.011, Vector3.ZERO, true)
			1:
				for side in [-1.0, 1.0]:
					_block(batch, Vector3(side * 0.098, 0.008, -0.211), Vector3(0.063, 0.109, 0.22),
						WARNING, 0.018, Vector3(0, side * -0.31, 0))
					_block(batch, Vector3(side * 0.117, 0.071, -0.236), Vector3(0.035, 0.015, 0.13),
						tint, 0.009, Vector3(0, side * -0.31, 0), true)
			2:
				for y in [-0.037, 0.008, 0.053]:
					_block(batch, Vector3(0, y, -0.289), Vector3(0.123, 0.023, 0.154),
						tint, 0.009, Vector3.ZERO, true)
			3:
				batch.put(Fabric.ring(0.099, 0.030, 14), Fabric.paint(tint, true),
					Vector3(0, 0.020, -0.250), Vector3(PI / 2, 0, 0), false)
				batch.put(Fabric.ring(0.127, 0.033, 14), Fabric.paint(FRAME),
					Vector3(0, 0.020, -0.203), Vector3(PI / 2, 0, 0), false)
			4, 5:
				var tip := -length * 0.49
				for side in [-1.0, 1.0]:
					_block(batch, Vector3(side * 0.085, 0.021, tip), Vector3(0.046, 0.094, 0.31), FRAME, 0.017)
					_block(batch, Vector3(side * 0.085, 0.074, tip), Vector3(0.027, 0.021, 0.27), tint, 0.008, Vector3.ZERO, true)
				batch.put(Fabric.tube(0.061, 0.265, 10), Fabric.paint(GRAPHITE),
					Vector3(0, 0.153, -0.008), Vector3(PI / 2, 0, 0), false)
				batch.put(Fabric.ring(0.067, 0.015, 14), Fabric.paint(tint, true),
					Vector3(0, 0.153, -0.142), Vector3(PI / 2, 0, 0), false)
				if index == 5:
					batch.put(Fabric.orb(0.058, 0.115, 12), Fabric.paint(tint, true), Vector3(0, 0.03, tip - 0.11), Vector3.ZERO, false)
			6:
				for y in [-0.033, 0.035, 0.089]:
					batch.put(Fabric.tube(0.032, 0.35, 7), Fabric.paint(FRAME), Vector3(0, y, -0.27), Vector3(PI / 2, 0, 0), false)
				batch.put(Fabric.ring(0.105, 0.026, 12), Fabric.paint(tint, true), Vector3(0, 0.031, -0.43), Vector3(PI / 2, 0, 0), false)
			7:
				batch.put(Fabric.tube(0.108, 0.31, 10), Fabric.paint(WARNING), Vector3(0, 0.035, -0.24), Vector3(PI / 2, 0, 0), false)
				batch.put(Fabric.ring(0.124, 0.038, 12), Fabric.paint(tint, true), Vector3(0, 0.035, -0.402), Vector3(PI / 2, 0, 0), false)
		batch.commit(root, false)
		var parts := []
		for node in root.get_children():
			parts.append([node.mesh, node.material_override, node.position])
		cache[key] = parts
	var flash := Fabric.place(root, Fabric.orb(0.055, 0.10, 10), Fabric.paint(tint, true),
		Vector3(0, 0.015, [-0.335, -0.33, -0.37, -0.33, -0.61, -0.55, -0.47, -0.42][index]), Vector3.ZERO, false)
	flash.hide()
	return flash

static func _block(batch: Fabric.Batch, at: Vector3, size: Vector3, color: Color, cut: float,
		rot := Vector3.ZERO, glow := false) -> void:
	batch.put(Fabric.bevel(size, cut), Fabric.paint(color, glow), at, rot, false)
