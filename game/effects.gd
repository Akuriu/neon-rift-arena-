extends Node3D

const CAPACITY := 120
var slots: Array[Dictionary] = []
var palette := {}
var next_slot := 0

func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	for index in CAPACITY:
		var node := MeshInstance3D.new()
		node.name = "FX%d" % index
		node.mesh = mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.hide()
		add_child(node)
		slots.append({"node": node, "time": 0.0, "total": 1.0,
			"velocity": Vector3.ZERO, "size": Vector3.ONE, "spark": false})

func beam(origin: Vector3, end: Vector3, tint: Color, width := 0.045, lifetime := 0.08) -> void:
	var length := origin.distance_to(end)
	if length < 0.03:
		return
	var slot := _acquire(tint, lifetime)
	var node: MeshInstance3D = slot.node
	node.position = (origin + end) * 0.5
	var forward := (end - origin).normalized()
	node.basis = Basis.looking_at(forward, Vector3.RIGHT if absf(forward.y) > 0.98 else Vector3.UP)
	slot.size = Vector3(width, width, length)
	node.scale = slot.size

func sparks(at: Vector3, tint: Color, count: int, power := 3.0) -> void:
	var density := [0.46, 0.74, 1.0, 0.24][Prefs.values.quality] as float
	for _particle in maxi(1, roundi(count * density)):
		var slot := _acquire(tint, randf_range(0.13, 0.38))
		var node: MeshInstance3D = slot.node
		node.position = at
		node.rotation = Vector3(randf(), randf(), randf()) * TAU
		slot.velocity = Vector3(randf_range(-1, 1), randf_range(0, 1.4), randf_range(-1, 1)) * power
		slot.size = Vector3(0.047, 0.047, randf_range(0.07, 0.18))
		slot.spark = true
		node.scale = slot.size

func _acquire(tint: Color, lifetime: float) -> Dictionary:
	var slot := slots[next_slot]
	next_slot = (next_slot + 1) % CAPACITY
	if not palette.has(tint):
		var paint := StandardMaterial3D.new()
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.albedo_color = tint
		palette[tint] = paint
	var node: MeshInstance3D = slot.node
	node.material_override = palette[tint]
	node.show()
	slot.time = lifetime
	slot.total = lifetime
	slot.spark = false
	slot.velocity = Vector3.ZERO
	return slot

func _process(delta: float) -> void:
	for slot in slots:
		if slot.time <= 0.0:
			continue
		slot.time -= delta
		var node: MeshInstance3D = slot.node
		if slot.time <= 0.0:
			node.hide()
			continue
		var fade := clampf(slot.time / slot.total, 0.15, 1.0)
		if slot.spark:
			slot.velocity.y -= 5.0 * delta
			node.position += slot.velocity * delta
			node.scale = slot.size * fade
		else:
			node.scale = slot.size * Vector3(fade, fade, 1.0)
