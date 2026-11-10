extends Node3D

const Fabric := preload("res://game/fabric.gd")
var kind := "repair"
var serial := 0
var age := 0.0
var rig: Node3D
var tint: Color

func _ready() -> void:
	tint = Color("#7dffcc") if kind == "repair" else Color("#ffbf77")
	rig = Node3D.new()
	add_child(rig)
	Fabric.place(rig, Fabric.bevel(Vector3(0.52, 0.28, 0.52), 0.10),
		Fabric.paint(Color("#202d34")), Vector3.ZERO, Vector3.ZERO, false)
	Fabric.place(rig, Fabric.ring(0.34, 0.047, 12), Fabric.paint(tint, true),
		Vector3(0, 0.025, 0), Vector3.ZERO, false)
	Fabric.place(rig, Fabric.cube(Vector3(0.31, 0.04, 0.075)), Fabric.paint(tint, true),
		Vector3.UP * 0.153, Vector3.ZERO, false)
	if kind == "repair":
		Fabric.place(rig, Fabric.cube(Vector3(0.075, 0.04, 0.31)), Fabric.paint(tint, true),
			Vector3.UP * 0.153, Vector3.ZERO, false)
	else:
		Fabric.place(rig, Fabric.cube(Vector3(0.077, 0.044, 0.13)), Fabric.paint(tint, true),
			Vector3(0.09, 0.154, 0.055), Vector3.ZERO, false)

func _physics_process(delta: float) -> void:
	age += delta
	rig.position.y = 0.33 + sin(age * 4.0) * 0.09
	rig.rotate_y(delta * 1.48)
	if age >= 24.0:
		queue_free()
