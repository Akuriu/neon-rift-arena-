extends Node3D

const Fabric := preload("res://game/fabric.gd")
const RADIUS := 3.3
const HOLD := 2.9
const COLORS := [Color("#9bb4be"), Color("#c5916a")]
var badge := "A"
var owner_side := -1
var control := 0.0
var contested := false
var edge: MeshInstance3D
var flag: Label3D

func _ready() -> void:
	edge = Fabric.place(self, Fabric.ring(RADIUS, 0.036, 36), Fabric.paint(Color("#bbbaa8")),
		Vector3.UP * 0.025, Vector3.ZERO, false)
	flag = Label3D.new()
	flag.position.y = 1.1
	flag.font_size = 34
	flag.pixel_size = 0.008
	flag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	flag.outline_size = 8
	add_child(flag)
	_refresh()

func advance(delta: float, members: Array) -> int:
	var counts := [0, 0]
	for actor in members:
		if contains(actor.position):
			counts[actor.arena_side] += 1
	var old_owner := owner_side
	var was_contested := contested
	contested = counts[0] > 0 and counts[1] > 0
	if not contested and counts[0] != counts[1]:
		var goal := 1.0 if counts[0] > counts[1] else -1.0
		control = move_toward(control, goal, delta / HOLD)
		if is_equal_approx(control, goal):
			owner_side = 0 if goal > 0.0 else 1
	if old_owner != owner_side or was_contested != contested:
		_refresh()
	return -1 if contested else owner_side

func contains(at: Vector3) -> bool:
	var offset := at - position
	return absf(offset.y) <= 2.2 and Vector2(offset.x, offset.z).length_squared() <= RADIUS * RADIUS

func _refresh() -> void:
	var shade: Color = Color("#f1d085") if contested else (Color("#c7c8b7") if owner_side < 0 else COLORS[owner_side])
	flag.modulate = shade
	flag.text = "%s · CONTESTÉ" % badge if contested else badge
	edge.material_override = Fabric.paint(shade)
