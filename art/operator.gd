extends RefCounted

const Fabric := preload("res://game/fabric.gd")
const Materials := preload("res://art/materials.gd")
const Weapons := preload("res://game/weapon_models.gd")
const BOOT := Color("#393a34")
const WEBBING := Color("#585345")
const PLATE := Color("#666555")
const FACE := Color("#ac8467")
const GLASS := Color("#494a43")

static var sections := {}
var torso: Node3D
var left_leg: Node3D
var right_leg: Node3D
var weapon: Node3D
var mark: MeshInstance3D
var arms: Array[Node3D] = []
var weapon_models := {}
var weapon_index := -1
var gait := 0.0
var recoil := 0.0
var skin := ""

func build(parent: Node3D, uniform: Color, band: Color, heavy := false, accessory := "") -> void:
	var hips := Node3D.new()
	parent.add_child(hips)
	var waist := Fabric.Batch.new()
	_box(waist, Vector3(0, 0.87, 0.018), Vector3(0.34, 0.24, 0.26), uniform, 0.057)
	_box(waist, Vector3(0, 0.96, 0.014), Vector3(0.355, 0.056, 0.28), WEBBING, 0.013)
	_box(waist, Vector3(0.011, 0.96, -0.132), Vector3(0.075, 0.043, 0.029), BOOT, 0.006)
	waist.commit(hips)
	left_leg = _leg(hips, -0.109, uniform)
	right_leg = _leg(hips, 0.109, uniform)
	torso = Node3D.new()
	parent.add_child(torso)
	var key := [uniform, heavy, accessory]
	if sections.has(key):
		for part in sections[key]:
			Fabric.place(torso, part[0], part[1], part[2])
	else:
		_body(torso, uniform, heavy, accessory)
		var meshes := []
		for part in torso.get_children():
			meshes.append([part.mesh, part.material_override, part.position])
		sections[key] = meshes
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.212, 1.349, 0.0)
		torso.add_child(arm)
		arms.append(arm)
		_arm(arm, side, uniform, heavy)
	mark = Fabric.place(torso, Fabric.bevel(Vector3(0.095, 0.044, 0.012), 0.004),
		Fabric.paint(band), Vector3(0.102, 1.34, -0.157), Vector3.ZERO, false)
	weapon = Node3D.new()
	weapon.position = Vector3(0.095, 1.24, -0.23)
	weapon.scale = Vector3.ONE * 0.73
	torso.add_child(weapon)

func set_weapon(index: int) -> void:
	if index == weapon_index:
		return
	if weapon_models.has(weapon_index):
		weapon_models[weapon_index].hide()
	weapon_index = index
	if not weapon_models.has(index):
		var model := Node3D.new()
		weapon.add_child(model)
		Weapons.build(model, index, skin)
		weapon_models[index] = model
	weapon_models[index].show()

func animate(delta: float, speed: float, pitch: float, low: float, run: bool, aiming: bool, reload: float) -> void:
	gait = fposmod(gait + delta * speed * 4.05, TAU)
	var blend := 1.0 - exp(-13.0 * delta)
	var step := sin(gait) * minf(speed * 0.127, 0.70)
	left_leg.rotation.x = lerpf(left_leg.rotation.x, step - low * 0.46, blend)
	right_leg.rotation.x = lerpf(right_leg.rotation.x, -step - low * 0.46, blend)
	torso.position.y = lerpf(torso.position.y, -0.43 * low + absf(step) * 0.021, blend)
	torso.rotation.x = lerpf(torso.rotation.x, -0.07 * low + (0.17 if run else 0.0), blend)
	recoil = move_toward(recoil, 0.0, delta * 8.0)
	var service := sin(reload * PI)
	var tilt := clampf(pitch, -0.80, 0.80) * 0.66 + recoil * 0.095 - service * 0.29
	weapon.rotation.x = lerpf(weapon.rotation.x, tilt - (0.10 if run else 0.0), blend)
	weapon.rotation.z = lerpf(weapon.rotation.z, 0.24 * service, blend)
	weapon.position.x = lerpf(weapon.position.x, 0.067 if aiming else 0.095, blend)
	weapon.position.z = -0.23 + recoil * 0.038
	for arm in arms:
		arm.rotation.x = lerpf(arm.rotation.x, tilt - 0.075 + step * 0.073, blend)

static func _body(node: Node3D, cloth: Color, heavy: bool, accessory: String) -> void:
	var w := Fabric.Batch.new()
	_box(w, Vector3(0, 1.175, 0.017), Vector3(0.405, 0.431, 0.239), cloth, 0.072)
	_box(w, Vector3(0, 1.272, 0.021), Vector3(0.433, 0.184, 0.251), cloth, 0.061)
	_box(w, Vector3(0, 1.220, -0.095), Vector3(0.363, 0.338, 0.128), PLATE if heavy else WEBBING, 0.034)
	_box(w, Vector3(0, 1.175, 0.148), Vector3(0.271, 0.372, 0.152), cloth.darkened(0.25), 0.042)
	_box(w, Vector3(0, 1.287, 0.217), Vector3(0.236, 0.057, 0.023), WEBBING, 0.009)
	for side in [-1.0, 1.0]:
		_box(w, Vector3(side * 0.123, 1.336, -0.061), Vector3(0.063, 0.153, 0.175), WEBBING, 0.021, Vector3(0.36, 0, 0))
		_box(w, Vector3(side * 0.137, 1.074, 0.017), Vector3(0.093, 0.141, 0.263), WEBBING, 0.016)
	for i in 3:
		var x := (i - 1) * 0.102
		_box(w, Vector3(x, 1.145, -0.170), Vector3(0.085, 0.137, 0.069), cloth.darkened(0.14), 0.016)
		_box(w, Vector3(x, 1.175, -0.204), Vector3(0.078, 0.024, 0.013), WEBBING, 0.004)
	if accessory == "medic":
		_box(w, Vector3(0, 1.161, 0.232), Vector3(0.125, 0.131, 0.014), Color("#c6beaa"), 0.004)
		_box(w, Vector3(0, 1.161, 0.242), Vector3(0.084, 0.023, 0.010), Color("#905240"), 0.002)
		_box(w, Vector3(0, 1.161, 0.242), Vector3(0.023, 0.084, 0.010), Color("#905240"), 0.002)
	elif accessory in ["artillery", "disruptor", "architect"]:
		_box(w, Vector3(-0.128, 1.358, 0.162), Vector3(0.092, 0.132, 0.091), BOOT, 0.015)
		_box(w, Vector3(-0.144, 1.493, 0.185), Vector3(0.015, 0.234, 0.014), GLASS, 0.003, Vector3(0.11, 0, -0.10))
	_box(w, Vector3(0, 1.421, -0.004), Vector3(0.147, 0.116, 0.143), cloth.darkened(0.13), 0.043)
	_box(w, Vector3(0, 1.521, -0.010), Vector3(0.187, 0.224, 0.182), FACE, 0.047)
	_box(w, Vector3(0, 1.594, 0.006), Vector3(0.239 if heavy else 0.215, 0.162, 0.221), PLATE, 0.047)
	_box(w, Vector3(0, 1.529, -0.108), Vector3(0.186, 0.053 if not heavy else 0.072, 0.047), GLASS, 0.017)
	_box(w, Vector3(0, 1.475, -0.100), Vector3(0.163, 0.066, 0.043), WEBBING if heavy else cloth, 0.017)
	for side in [-1.0, 1.0]:
		_box(w, Vector3(side * 0.107, 1.541, 0.006), Vector3(0.036, 0.097, 0.096), WEBBING, 0.012)
	w.commit(node)

static func _arm(node: Node3D, side: float, cloth: Color, heavy: bool) -> void:
	var w := Fabric.Batch.new()
	_box(w, Vector3(side * 0.025, -0.098, 0.002), Vector3(0.155, 0.265, 0.173), cloth,
		0.042, Vector3(-0.15, 0, side * 0.13))
	_box(w, Vector3(side * 0.015, -0.166, -0.131), Vector3(0.132, 0.145, 0.263), cloth,
		0.040, Vector3(-0.20, 0.33 * side, 0))
	_box(w, Vector3(-side * 0.048, -0.123, -0.261), Vector3(0.082, 0.083, 0.090), BOOT, 0.020)
	if heavy:
		_box(w, Vector3(side * 0.058, -0.020, -0.003), Vector3(0.132, 0.127, 0.19), PLATE, 0.029)
	w.commit(node)

static func _leg(parent: Node3D, x: float, cloth: Color) -> Node3D:
	var leg := Node3D.new()
	leg.position = Vector3(x, 0.87, 0.024)
	parent.add_child(leg)
	var w := Fabric.Batch.new()
	_box(w, Vector3(0, -0.17, 0.010), Vector3(0.175, 0.411, 0.204), cloth, 0.049, Vector3(-0.06, 0, 0))
	_box(w, Vector3(0, -0.435, -0.006), Vector3(0.145, 0.34, 0.159), cloth.darkened(0.07), 0.035)
	_box(w, Vector3(0, -0.324, -0.089), Vector3(0.152, 0.125, 0.059), WEBBING, 0.018)
	_box(w, Vector3(0, -0.665, 0.018), Vector3(0.145, 0.200, 0.164), BOOT, 0.027)
	_box(w, Vector3(0, -0.787, -0.039), Vector3(0.148, 0.112, 0.252), BOOT, 0.026)
	w.commit(leg)
	return leg

static func _box(w: Fabric.Batch, at: Vector3, size: Vector3, color: Color, cut: float,
		rotation := Vector3.ZERO) -> void:
	w.put(Fabric.bevel(size, cut), Materials.finish(color, "canvas", 7.5), at, rotation, false)
