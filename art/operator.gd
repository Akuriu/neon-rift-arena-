extends RefCounted

const Fabric := preload("res://game/fabric.gd")
const Materials := preload("res://art/materials.gd")
const Weapons := preload("res://game/weapon_models.gd")

const Track := preload("res://network/snapshot_track.gd")

const HIP := 0.883
const BOOT := Color("#393a34")
const WEBBING := Color("#585345")
const PLATE := Color("#666555")
const FACE := Color("#ac8467")
const GLASS := Color("#494a43")
const GRIP_Z := [0.146, 0.130, 0.109, 0.168, 0.158, 0.158, 0.116, 0.168]
const SUPPORT_Z := [-0.278, -0.321, 0.070, -0.246, -0.267, -0.287, -0.213, -0.196]

# Segments are drawn down the local Y axis. The bend vector selects the knee or elbow plane.
class Limb:
	var upper: Node3D
	var lower: Node3D
	var tip: Node3D
	var upper_length: float
	var lower_length: float

	func place(origin: Vector3, target: Vector3, bend: Vector3) -> void:
		var reach := target - origin
		var axis := reach.normalized() if reach.length_squared() > 0.0001 else Vector3.DOWN
		var length := clampf(reach.length(), absf(upper_length - lower_length) + 0.008,
			upper_length + lower_length - 0.006)
		var along := (upper_length * upper_length - lower_length * lower_length + length * length) / (2.0 * length)
		var sideways := bend - axis * bend.dot(axis)
		if sideways.length_squared() < 0.0001:
			sideways = axis.cross(Vector3.FORWARD if absf(axis.x) > 0.92 else Vector3.RIGHT)
		var joint := origin + axis * along + sideways.normalized() * sqrt(maxf(0.0, upper_length * upper_length - along * along))
		tip.position = origin + axis * length
		upper.position = origin
		upper.basis = Basis(Quaternion(Vector3.DOWN, (joint - origin).normalized()))
		lower.position = joint
		lower.basis = Basis(Quaternion(Vector3.DOWN, (tip.position - joint).normalized()))

static var sections := {}
var hips: Node3D
var torso: Node3D
var legs: Array[Limb] = []
var arms: Array[Limb] = []
var weapon: Node3D
var mark: MeshInstance3D
var weapon_models := {}
var weapon_index := -1
var gait := 0.0
var movement := Vector2.ZERO
var lean := 0.0
var low_weight := 0.0
var slide_weight := 0.0
var air_weight := 0.0
var landing := 0.0
var was_airborne := false
var idle_clock := 0.0
var recoil := 0.0
var flash_time := 0.0
var swap := 0.0
var skin := ""

func build(parent: Node3D, uniform: Color, band: Color, heavy := false, accessory := "") -> void:
	hips = Node3D.new()
	parent.add_child(hips)
	var waist := Fabric.Batch.new()
	_box(waist, Vector3(0, -0.013, 0.018), Vector3(0.34, 0.24, 0.26), uniform, 0.057)
	_box(waist, Vector3(0, 0.077, 0.014), Vector3(0.355, 0.056, 0.28), WEBBING, 0.013)
	_box(waist, Vector3(0.011, 0.077, -0.132), Vector3(0.075, 0.043, 0.029), BOOT, 0.006)
	waist.commit(hips)
	torso = Node3D.new()
	hips.add_child(torso)
	var body := Node3D.new()
	body.position.y = -HIP
	torso.add_child(body)
	var key := [uniform, heavy, accessory]
	if sections.has(key):
		for part in sections[key]:
			Fabric.place(body, part[0], part[1], part[2])
	else:
		_body(body, uniform, heavy, accessory)
		var meshes := []
		for part in body.get_children():
			meshes.append([part.mesh, part.material_override, part.position])
		sections[key] = meshes
	for side in [-1.0, 1.0]:
		legs.append(_leg(parent, uniform))
		arms.append(_arm(torso, side, uniform, heavy))
	mark = Fabric.place(body, Fabric.bevel(Vector3(0.095, 0.044, 0.012), 0.004),
		Fabric.paint(band), Vector3(0.102, 1.34, -0.157), Vector3.ZERO, false)
	weapon = Node3D.new()
	weapon.position = Vector3(0.118, 0.401, -0.30)
	weapon.scale = Vector3.ONE * 0.71
	torso.add_child(weapon)
	hips.position.y = HIP

func set_weapon(index: int) -> void:
	if index == weapon_index or index < 0 or index >= GRIP_Z.size():
		return
	if weapon_models.has(weapon_index):
		weapon_models[weapon_index].model.hide()
		swap = 0.23
	weapon_index = index
	if not weapon_models.has(index):
		var model := Node3D.new()
		weapon.add_child(model)
		var parts := Weapons.build(model, index, skin, false, true)
		parts.model = model
		weapon_models[index] = parts
	weapon_models[index].model.show()

func kick(fire := true) -> void:
	recoil = 1.0
	flash_time = 0.060 if fire else 0.0

func reset_motion() -> void:
	gait = 0.0
	movement = Vector2.ZERO
	lean = 0.0
	low_weight = 0.0
	slide_weight = 0.0
	air_weight = 0.0
	landing = 0.0
	was_airborne = false
	idle_clock = 0.0
	recoil = 0.0
	flash_time = 0.0
	swap = 0.0
	torso.rotation = Vector3.ZERO
	_aim_weapon(0.0, 0.0, false, false, 0.0, 1.0)

func animate(delta: float, motion: Vector3, pitch: float, crouch: float, flags: int, reload: float) -> void:
	var running := (flags & (Track.RUN | Track.DASH)) != 0
	var aiming := (flags & Track.AIM) != 0
	var airborne := (flags & Track.AIR) != 0
	var slide := (flags & Track.SLIDE) != 0
	var blend := 1.0 - exp(-14.0 * delta)
	movement = movement.lerp(Vector2(motion.x, motion.z).limit_length(14.0), blend)
	var speed := movement.length()
	var stride := clampf(speed / 7.0, 0.0, 1.0)
	var direction := Vector3(movement.x, 0, movement.y).normalized()
	gait = fposmod(gait + delta * clampf(speed * (0.36 if running else 0.43), 0.0, 3.45), 1.0)
	idle_clock += delta
	low_weight = lerpf(low_weight, crouch, blend)
	slide_weight = lerpf(slide_weight, float(slide), blend)
	air_weight = lerpf(air_weight, float(airborne), blend)
	if was_airborne and not airborne:
		landing = 1.0
	was_airborne = airborne
	var bounce := absf(sin(gait * TAU)) * stride * 0.029 * (1.0 - air_weight)
	var weight_shift := sin(gait * TAU) * stride * (1.0 - maxf(air_weight, slide_weight))
	hips.position = Vector3(weight_shift * 0.032, HIP - low_weight * 0.30 - slide_weight * 0.095 - landing * 0.107 + bounce,
		slide_weight * 0.040)
	lean = lerpf(lean, clampf(-motion.z * 0.018, -0.12, 0.22) - slide_weight * 0.31, blend)
	torso.rotation.x = lean - landing * 0.15 + sin(idle_clock * 2.0) * 0.014
	torso.rotation.z = lerpf(torso.rotation.z, clampf(-motion.x * 0.017, -0.17, 0.17) - weight_shift * 0.032, blend)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var phase := fposmod(gait + i * 0.5, 1.0)
		var swing := clampf((phase - 0.60) / 0.40, 0.0, 1.0)
		var travel := lerpf(0.43, -0.48, phase / 0.60) if phase < 0.60 else lerpf(-0.48, 0.43, smoothstep(0.0, 1.0, swing))
		var lift := sin(PI * swing) * (0.21 if running else 0.14)
		var foot := Vector3(side * 0.111, 0.090 + lift * stride, 0.023)
		foot += direction * travel * stride * (1.32 if running else 0.92)
		foot = foot.lerp(Vector3(side * 0.12, 0.22 + i * 0.068, 0.17 - i * 0.25), air_weight)
		foot = foot.lerp(Vector3(side * 0.15, 0.092, -0.48 + i * 0.27), slide_weight)
		var limb := legs[i]
		limb.place(hips.position + Vector3(side * 0.109, 0, 0.024), foot, Vector3(side * 0.20, 0, -1.0))
		var ankle := sin(TAU * swing) * 0.19 * stride * (1.0 - maxf(air_weight, slide_weight))
		limb.tip.rotation.x = ankle + air_weight * (0.31 - i * 0.24) - slide_weight * 0.19
	landing = move_toward(landing, 0.0, delta * 4.1)
	_aim_weapon(delta, pitch, aiming, running, reload, blend)

func _aim_weapon(delta: float, pitch: float, aiming: bool, running: bool, reload: float, blend: float) -> void:
	if weapon_index < 0:
		return
	var data: Dictionary = weapon_models[weapon_index]
	var service := sin(clampf(reload, 0.0, 1.0) * PI)
	var holster := sin(swap / 0.23 * PI) if swap > 0.0 else 0.0
	var pistol := weapon_index == 2
	var low_ready := 0.14 if running and not aiming else 0.0
	var at := Vector3(0.078 if aiming else 0.118,
		0.401 - low_ready * 0.57 - service * 0.11 - holster * 0.12,
		(-0.36 if pistol else -0.30) + recoil * 0.054)
	weapon.position = weapon.position.lerp(at, blend)
	weapon.rotation.x = lerpf(weapon.rotation.x, clampf(pitch, -0.89, 0.89) * 0.78 + recoil * 0.17
		- service * 0.32 - low_ready - holster * 0.59, blend)
	weapon.rotation.z = lerpf(weapon.rotation.z, 0.33 * service - low_ready * 0.72, blend)
	var mag: Node3D = data.magazine
	var origin: Vector3 = mag.get_meta("home")
	mag.position = origin + Vector3(-0.031, -0.16, 0.033) * service
	mag.rotation.z = -service * 0.32
	data.bolt.position.z = recoil * 0.037
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var support := Vector3(-0.042, -0.038, SUPPORT_Z[weapon_index])
		if i == 0:
			support = support.lerp(mag.position + Vector3(-0.026, -0.061, 0.010), service)
		else:
			support = Vector3(0.024, -0.103, GRIP_Z[weapon_index])
		var hand: Vector3 = weapon.transform * support
		arms[i].place(Vector3(side * 0.212, 1.349 - HIP, 0.003), hand, Vector3(side * 0.63, -1.0, 0.2))
		arms[i].tip.rotation = weapon.rotation
	data.flash.visible = flash_time > 0.0
	recoil = move_toward(recoil, 0.0, delta * 7.8)
	flash_time = maxf(0.0, flash_time - delta)
	swap = maxf(0.0, swap - delta)

static func _body(node: Node3D, cloth: Color, heavy: bool, accessory: String) -> void:
	var w := Fabric.Batch.new()
	_box(w, Vector3(0, 1.175, 0.017), Vector3(0.405, 0.431, 0.239), cloth, 0.072)
	_box(w, Vector3(0, 1.272, 0.021), Vector3(0.433, 0.184, 0.251), cloth, 0.061)
	_box(w, Vector3(0, 1.220, -0.095), Vector3(0.363, 0.338, 0.128), PLATE if heavy else WEBBING, 0.034)
	_box(w, Vector3(0, 1.175, 0.148), Vector3(0.271, 0.372, 0.152), cloth.darkened(0.25), 0.042)
	_box(w, Vector3(0, 1.287, 0.217), Vector3(0.236, 0.057, 0.023), WEBBING, 0.009)
	_box(w, Vector3(-0.112, 1.245, -0.164), Vector3(0.094, 0.105, 0.033), cloth.darkened(0.25), 0.009)
	_box(w, Vector3(-0.112, 1.276, -0.183), Vector3(0.064, 0.014, 0.008), PLATE, 0.002)
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

static func _arm(node: Node3D, side: float, cloth: Color, heavy: bool) -> Limb:
	var limb := _limb(node, 0.262, 0.269)
	var upper := Fabric.Batch.new()
	_box(upper, Vector3(0, -0.105, 0.0), Vector3(0.155, 0.263, 0.172), cloth, 0.043)
	if heavy:
		_box(upper, Vector3(side * 0.030, -0.026, 0.0), Vector3(0.141, 0.125, 0.198), PLATE, 0.029)
	upper.commit(limb.upper)
	var lower := Fabric.Batch.new()
	_box(lower, Vector3(0, -0.128, 0), Vector3(0.121, 0.266, 0.129), cloth, 0.033)
	_box(lower, Vector3(0, -0.224, 0), Vector3(0.132, 0.062, 0.142), WEBBING, 0.021)
	lower.commit(limb.lower)
	var hand := Fabric.Batch.new()
	_box(hand, Vector3(0, 0, -0.010), Vector3(0.085, 0.083, 0.103), BOOT, 0.024)
	hand.commit(limb.tip)
	return limb

static func _leg(parent: Node3D, cloth: Color) -> Limb:
	var limb := _limb(parent, 0.415, 0.401)
	var thigh := Fabric.Batch.new()
	_box(thigh, Vector3(0, -0.178, 0.010), Vector3(0.175, 0.418, 0.204), cloth, 0.049)
	thigh.commit(limb.upper)
	var shin := Fabric.Batch.new()
	_box(shin, Vector3(0, -0.167, -0.006), Vector3(0.145, 0.380, 0.159), cloth.darkened(0.07), 0.035)
	_box(shin, Vector3(0, -0.045, -0.089), Vector3(0.152, 0.125, 0.059), WEBBING, 0.018)
	_box(shin, Vector3(0, -0.316, 0.016), Vector3(0.147, 0.165, 0.164), BOOT, 0.027)
	shin.commit(limb.lower)
	var boot := Fabric.Batch.new()
	_box(boot, Vector3(0, -0.047, -0.047), Vector3(0.153, 0.107, 0.257), BOOT, 0.026)
	boot.commit(limb.tip)
	return limb

static func _limb(parent: Node3D, upper: float, lower: float) -> Limb:
	var limb := Limb.new()
	limb.upper = Node3D.new()
	limb.lower = Node3D.new()
	limb.tip = Node3D.new()
	limb.upper_length = upper
	limb.lower_length = lower
	for part in [limb.upper, limb.lower, limb.tip]:
		parent.add_child(part)
	return limb

static func _box(w: Fabric.Batch, at: Vector3, size: Vector3, color: Color, cut: float,
		rotation := Vector3.ZERO) -> void:
	w.put(Fabric.bevel(size, cut), Materials.finish(color, "canvas", 7.5), at, rotation, false)
