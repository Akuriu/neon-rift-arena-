extends RefCounted

const Fabric := preload("res://game/fabric.gd")
const Materials := preload("res://art/materials.gd")

static var quad := []
static var blade: Mesh

static func drone(root: Node3D, rotors: Array[Node3D]) -> MeshInstance3D:
	if quad.is_empty():
		var w := Fabric.Batch.new()
		var nylon := Materials.finish(Color("#535a51"), "steel", 4.0)
		var carbon := Materials.finish(Color("#3b403b"), "steel", 4.0, 0.28)
		var steel := Materials.finish(Color("#858477"), "steel", 5.0, 0.30)
		w.put(Fabric.bevel(Vector3(0.40, 0.16, 0.41), 0.071), nylon, Vector3(0, 0.95, 0), Vector3.ZERO, false)
		w.put(Fabric.bevel(Vector3(0.23, 0.070, 0.29), 0.026), steel, Vector3(0, 1.051, 0.014), Vector3.ZERO, false)
		w.put(Fabric.bevel(Vector3(0.19, 0.14, 0.16), 0.035), carbon, Vector3(0, 0.869, -0.184), Vector3.ZERO, false)
		for side in [-1.0, 1.0]:
			for end in [-1.0, 1.0]:
				w.put(Fabric.bevel(Vector3(0.093, 0.053, 0.37), 0.014), carbon,
					Vector3(side * 0.208, 0.97, end * 0.147), Vector3(0, side * end * 0.87, 0), false)
				var axis := Vector3(side * 0.339, 0.999, end * 0.249)
				w.put(Fabric.tube(0.054, 0.090, 10), steel, axis, Vector3.ZERO, false)
				w.put(Fabric.ring(0.145, 0.014, 13), nylon, axis + Vector3.UP * 0.025, Vector3.ZERO, false)
		w.commit(root)
		for part in root.get_children():
			quad.append([part.mesh, part.material_override, part.position])
	else:
		for part in quad:
			Fabric.place(root, part[0], part[1], part[2])
	if blade == null:
		blade = Fabric.bevel(Vector3(0.25, 0.012, 0.032), 0.013)
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			var rotor := Fabric.place(root, blade, Materials.finish(Color("#3b403b"), "steel", 4.0, 0.28),
				Vector3(side * 0.339, 1.059, end * 0.249), Vector3.ZERO, false)
			rotors.append(rotor)
	return Fabric.place(root, Fabric.orb(0.045, 0.090, 10), Fabric.paint(Color("#838076")),
		Vector3(0, 0.862, -0.268), Vector3.ZERO, false)

static func target(root: Node3D) -> MeshInstance3D:
	var panel := Materials.finish(Color("#b9ab89"), "concrete", 2.4)
	var wood := Materials.finish(Color("#8d7357"), "timber", 3.4)
	var steel := Materials.finish(Color("#53574c"), "steel", 3.1, 0.25)
	Fabric.place(root, Fabric.bevel(Vector3(0.61, 0.07, 0.35), 0.019), steel, Vector3(0, 0.055, 0.06))
	for x in [-0.151, 0.151]:
		Fabric.place(root, Fabric.cube(Vector3(0.055, 1.36, 0.06)), wood, Vector3(x, 0.74, 0.075))
	Fabric.place(root, Fabric.bevel(Vector3(0.45, 0.57, 0.052), 0.020), panel, Vector3(0, 1.035, 0))
	Fabric.place(root, Fabric.bevel(Vector3(0.22, 0.188, 0.052), 0.020), panel, Vector3(0, 1.398, 0))
	for radius in [0.192, 0.147, 0.103, 0.059]:
		Fabric.place(root, Fabric.ring(radius, 0.007, 20), steel, Vector3(0, 1.02, 0), Vector3(PI * 0.5, 0, 0), false)
	return Fabric.place(root, Fabric.tube(0.023, 0.061, 10), Fabric.paint(Color("#a66b4b")),
		Vector3(0, 1.02, 0), Vector3(PI * 0.5, 0, 0), false)
