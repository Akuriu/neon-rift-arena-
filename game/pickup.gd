extends Node3D

const Fabric := preload("res://game/fabric.gd")
const Materials := preload("res://art/materials.gd")
var kind := "repair"
var serial := 0
var age := 0.0
var tint: Color

func _ready() -> void:
	var repair := kind == "repair"
	var finish := Color("#848472") if repair else Color("#6e7354")
	tint = Color("#a95743") if repair else Color("#c2a37a")
	var metal := Materials.finish(finish, "steel", 5.0, 0.24)
	var trim := Materials.finish(finish.darkened(0.28), "steel", 5.0, 0.27)
	var turn := Vector3(0.0, 0.21 * float(serial % 7), 0.0)
	var box := Node3D.new()
	box.rotation = turn
	add_child(box)
	Fabric.place(box, Fabric.bevel(Vector3(0.46, 0.25, 0.32), 0.031), metal, Vector3.UP * 0.129)
	Fabric.place(box, Fabric.bevel(Vector3(0.48, 0.056, 0.34), 0.034), trim, Vector3.UP * 0.248)
	Fabric.place(box, Fabric.cube(Vector3(0.141, 0.036, 0.071)), trim, Vector3.UP * 0.283)
	for x in [-0.151, 0.151]:
		Fabric.place(box, Fabric.bevel(Vector3(0.053, 0.082, 0.023), 0.005), trim, Vector3(x, 0.205, 0.172))
	Fabric.place(box, Fabric.cube(Vector3(0.176, 0.008, 0.041)), Fabric.paint(tint), Vector3(0, 0.279, 0.071))
	if repair:
		Fabric.place(box, Fabric.cube(Vector3(0.041, 0.008, 0.143)), Fabric.paint(tint), Vector3(0, 0.279, 0.071))
	else:
		for x in [-0.046, 0.0, 0.046]:
			Fabric.place(box, Fabric.cube(Vector3(0.015, 0.009, 0.059)), Fabric.paint(tint), Vector3(x, 0.279, -0.05))

func _physics_process(delta: float) -> void:
	age += delta
	if age >= 24.0:
		queue_free()
