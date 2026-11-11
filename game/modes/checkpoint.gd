extends Area3D

const Fabric := preload("res://game/fabric.gd")
var index := 0
var width := 4.0
var label: Label3D
var bars: Array[MeshInstance3D] = []

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 2.6, 1.1)
	collider.shape = box
	collider.position.y = 1.1
	add_child(collider)
	for side in [-1.0, 1.0]:
		bars.append(Fabric.place(self, Fabric.cube(Vector3(0.09, 2.55, 0.11)),
			Fabric.paint(Color("#c8ad83")), Vector3(side * (width * 0.5 - 0.07), 1.27, 0)))
	label = Label3D.new()
	label.font = preload("res://assets/fonts/OpenSans-CondBold.ttf")
	label.font_size = 44
	label.pixel_size = 0.008
	label.position.y = 2.6
	label.outline_size = 4
	add_child(label)
	mark(0)

func mark(next: int, last := false) -> void:
	var color := Color("#728b73") if index < next else (Color("#e4c99e") if index == next else Color("#6e7a73"))
	for bar in bars:
		bar.material_override = Fabric.paint(color)
	label.modulate = color
	label.text = "DÉPART" if index == 0 else ("ARRIVÉE" if last else "%02d" % index)
