extends Node3D

const Fabric := preload("res://game/fabric.gd")
const Arms := preload("res://game/weapons/catalog.gd")
const COLORS := [Color("#6eeae8"), Color("#ffc58c"), Color("#d598fb"), Color("#a3f5a4")]
var tint := COLORS[0]
var skin := ""
var pilot_name := "Pilote"
var right: Node3D
var left: Node3D
var weapon: Node3D
var torso: Node3D
var barrel: MeshInstance3D
var trim: MeshInstance3D
var arms: Array[Node3D] = []
var rotor := 0.0
var recoil := 0.0
var last_weapon := -1

func _ready() -> void:
	var slate := Fabric.paint(Color("#2a3c49"))
	var shell := Fabric.paint(Color("#c9835f") if skin == "skin_copper" else (Color("#7ea7c7") if skin == "skin_glacier" else Color("#9aafb9")))
	if skin == "skin_ash":
		shell = Fabric.paint(Color("#d9d0b9"))
	elif skin == "skin_aurora":
		shell = Fabric.paint(Color("#428878"))
	var light := Fabric.paint(tint, true)
	torso = Node3D.new()
	add_child(torso)
	Fabric.place(torso, Fabric.bevel(Vector3(0.69, 0.58, 0.35), 0.12), shell, Vector3(0, 1.13, 0))
	Fabric.place(torso, Fabric.bevel(Vector3(0.46, 0.30, 0.41), 0.085), slate, Vector3(0, 1.62, -0.02))
	Fabric.place(torso, Fabric.bevel(Vector3(0.36, 0.084, 0.033), 0.025), light, Vector3(0, 1.64, -0.229))
	Fabric.place(torso, Fabric.bevel(Vector3(0.35, 0.42, 0.15), 0.064), slate, Vector3(0, 1.11, 0.237))
	Fabric.place(torso, Fabric.bevel(Vector3(0.055, 0.30, 0.018), 0.007), light, Vector3(0, 1.11, 0.316))
	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.36, 1.30, -0.04)
		torso.add_child(arm)
		arms.append(arm)
		Fabric.place(arm, Fabric.bevel(Vector3(0.22, 0.33, 0.23), 0.05), slate, Vector3(0, -0.12, -0.02))
		Fabric.place(arm, Fabric.bevel(Vector3(0.18, 0.16, 0.29), 0.04), shell, Vector3(0, -0.25, -0.16))
	weapon = Node3D.new()
	weapon.position = Vector3(0.29, 1.14, -0.38)
	torso.add_child(weapon)
	Fabric.place(weapon, Fabric.bevel(Vector3(0.19, 0.19, 0.44), 0.045), slate, Vector3.ZERO)
	barrel = Fabric.place(weapon, Fabric.bevel(Vector3(0.10, 0.10, 0.36), 0.024), slate, Vector3(0, 0, -0.30))
	trim = Fabric.place(weapon, Fabric.bevel(Vector3(0.124, 0.040, 0.19), 0.022), light, Vector3(0, 0.072, -0.19))
	right = _leg(0.16, slate, shell)
	left = _leg(-0.16, slate, shell)
	var nameplate := Label3D.new()
	nameplate.text = pilot_name
	nameplate.pixel_size = 0.0045
	nameplate.font_size = 34
	nameplate.outline_size = 6
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.modulate = tint
	nameplate.position = Vector3.UP * 2.04
	add_child(nameplate)

func _leg(x: float, dark: Material, light: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, 0.83, 0)
	add_child(pivot)
	Fabric.place(pivot, Fabric.bevel(Vector3(0.22, 0.61, 0.25), 0.06), dark, Vector3(0, -0.33, 0))
	Fabric.place(pivot, Fabric.bevel(Vector3(0.25, 0.15, 0.35), 0.05), light, Vector3(0, -0.69, -0.055))
	return pivot

func kick() -> void:
	recoil = 1.0

func animate(delta: float, speed: float, pitch: float, height: float, flags: int, index: int, reload: float) -> void:
	rotor += delta * (3.0 + speed * 1.1)
	var slide := (flags & 2) != 0
	var sprint := (flags & 1) != 0
	var dashing := (flags & 4) != 0
	var aiming := (flags & 8) != 0
	var low := clampf((1.78 - height) / 0.67, 0.0, 1.0)
	var blend := 1.0 - exp(-14.0 * delta)
	var sweep := sin(rotor) * minf(0.72, speed * 0.068) * (0.08 if slide else 1.0)
	left.rotation.x = lerpf(left.rotation.x, sweep - low * 0.44, blend)
	right.rotation.x = lerpf(right.rotation.x, -sweep - low * 0.51, blend)
	torso.position.y = lerpf(torso.position.y, -low * 0.53, blend)
	torso.rotation.x = lerpf(torso.rotation.x, -0.34 if slide else (0.15 if sprint or dashing else 0.0), blend)
	recoil = move_toward(recoil, 0.0, delta * 9.0)
	var service := sin(reload * PI)
	weapon.rotation.x = lerpf(weapon.rotation.x, pitch * 0.68 + recoil * 0.08 - service * 0.39, blend)
	weapon.rotation.z = lerpf(weapon.rotation.z, 0.35 * service + (0.17 if sprint else 0.0), blend)
	weapon.position.x = lerpf(weapon.position.x, 0.16 if aiming else 0.29, blend)
	weapon.position.z = -0.38 + recoil * 0.045
	for arm in arms:
		arm.rotation.x = lerpf(arm.rotation.x, -0.34 + weapon.rotation.x + 0.24 * service, blend)
	if index != last_weapon and index in range(Arms.WEAPONS.size()):
		last_weapon = index
		barrel.scale = [Vector3(1, 1, 1.0), Vector3(1.6, 1.2, 0.62), Vector3(0.9, 0.8, 1.15),
			Vector3(1.65, 1.7, 0.55), Vector3(0.65, 0.72, 1.73), Vector3(0.74, 0.82, 1.86),
			Vector3(1.12, 1.22, 1.18), Vector3(1.85, 1.66, 0.81)][index]
		trim.material_override = Fabric.paint(Arms.WEAPONS[index].tint, true)
