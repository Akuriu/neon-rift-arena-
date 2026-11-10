extends Node3D

const Fabric := preload("res://game/fabric.gd")
const COLORS := [Color("#6eeae8"), Color("#ffc58c"), Color("#d598fb"), Color("#a3f5a4")]
var tint := COLORS[0]
var skin := ""
var pilot_name := "Pilote"
var right: Node3D
var left: Node3D
var weapon: Node3D
var rotor := 0.0
var recoil := 0.0

func _ready() -> void:
	var slate := Fabric.paint(Color("#2a3c49"))
	var shell := Fabric.paint(Color("#c9835f") if skin == "skin_copper" else (Color("#7ea7c7") if skin == "skin_glacier" else Color("#9aafb9")))
	var light := Fabric.paint(tint, true)
	Fabric.place(self, Fabric.bevel(Vector3(0.69, 0.58, 0.35), 0.12), shell, Vector3(0, 1.13, 0))
	Fabric.place(self, Fabric.bevel(Vector3(0.46, 0.30, 0.41), 0.085), slate, Vector3(0, 1.62, -0.02))
	Fabric.place(self, Fabric.bevel(Vector3(0.36, 0.084, 0.033), 0.025), light, Vector3(0, 1.64, -0.229))
	Fabric.place(self, Fabric.bevel(Vector3(0.35, 0.42, 0.15), 0.064), slate, Vector3(0, 1.11, 0.237))
	Fabric.place(self, Fabric.bevel(Vector3(0.055, 0.30, 0.018), 0.007), light, Vector3(0, 1.11, 0.316))
	for side in [-1.0, 1.0]:
		Fabric.place(self, Fabric.bevel(Vector3(0.22, 0.39, 0.23), 0.05), slate, Vector3(side * 0.37, 1.12, -0.03))
	var gun := Fabric.place(self, Fabric.bevel(Vector3(0.19, 0.19, 0.64), 0.054), slate, Vector3(0.32, 1.14, -0.38))
	weapon = gun
	Fabric.place(gun, Fabric.bevel(Vector3(0.124, 0.048, 0.19), 0.022), light, Vector3(0, 0.06, -0.31))
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

func animate(delta: float, speed: float, pitch: float) -> void:
	rotor += delta * (3.0 + speed * 1.1)
	var sweep := sin(rotor) * minf(0.65, speed * 0.065)
	left.rotation.x = sweep
	right.rotation.x = -sweep
	recoil = move_toward(recoil, 0.0, delta * 9.0)
	weapon.rotation.x = pitch * 0.68 + recoil * 0.08
	weapon.position.z = -0.38 + recoil * 0.045
