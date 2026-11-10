extends Node3D

const CAPACITY := 120
var slots: Array[Dictionary] = []
var active: Array[int] = []
var palette := {}
var next_slot := 0
var cube: BoxMesh
var ring: TorusMesh

func _ready() -> void:
	cube = BoxMesh.new()
	cube.size = Vector3.ONE
	ring = TorusMesh.new()
	ring.inner_radius = 0.98
	ring.outer_radius = 1.02
	ring.rings = 20
	ring.ring_segments = 5
	var limit := 64 if Prefs.values.quality == 3 else CAPACITY
	_build(limit)
	set_process(false)

func _build(limit: int) -> void:
	for index in range(slots.size(), limit):
		var node := MeshInstance3D.new()
		node.name = "FX%d" % index
		node.mesh = cube
		node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.hide()
		add_child(node)
		slots.append({"node": node, "time": 0.0, "total": 1.0, "kind": 0,
			"velocity": Vector3.ZERO, "size": Vector3.ONE})

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
	var density: float = [0.46, 0.74, 1.0, 0.24][Prefs.values.quality] * Prefs.values.particles
	for _particle in roundi(count * density):
		var slot := _acquire(tint, randf_range(0.13, 0.38))
		var node: MeshInstance3D = slot.node
		node.position = at
		node.rotation = Vector3(randf(), randf(), randf()) * TAU
		slot.velocity = Vector3(randf_range(-1, 1), randf_range(0, 1.4), randf_range(-1, 1)) * power
		slot.size = Vector3(0.047, 0.047, randf_range(0.07, 0.18))
		slot.kind = 1
		node.scale = slot.size

func impact(at: Vector3, normal: Vector3, tint: Color, terrain: String, armor: bool) -> void:
	var shade := tint if armor else Color("#e7c2a0")
	var dust := not armor and terrain in ["grove", "bastion", "district"] and normal.y > 0.6
	if dust:
		shade = Color("#b5a28b")
	sparks(at + normal * 0.042, shade, 8 if dust else 6, 1.35 if dust else 2.2)

func wave(at: Vector3, tint: Color, radius: float) -> void:
	var slot := _acquire(tint, 0.23)
	var node: MeshInstance3D = slot.node
	node.mesh = ring
	node.position = at
	node.rotation = Vector3.ZERO
	node.scale = Vector3(0.21, 0.10, 0.21)
	slot.size = Vector3(radius, 0.10, radius)
	slot.kind = 2

func _acquire(tint: Color, lifetime: float) -> Dictionary:
	if Prefs.values.quality != 3 and slots.size() < CAPACITY:
		_build(CAPACITY)
	var slot := slots[next_slot]
	if slot.time <= 0.0:
		active.append(next_slot)
	next_slot = (next_slot + 1) % (64 if Prefs.values.quality == 3 else CAPACITY)
	var color: Color = Art.effect_color(tint)
	if not palette.has(color):
		if palette.size() >= 96:
			palette.clear()
		var paint := StandardMaterial3D.new()
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		paint.albedo_color = color
		palette[color] = paint
	var node: MeshInstance3D = slot.node
	node.mesh = cube
	node.material_override = palette[color]
	node.show()
	slot.time = lifetime
	slot.total = lifetime
	slot.kind = 0
	slot.velocity = Vector3.ZERO
	set_process(true)
	return slot

func _process(delta: float) -> void:
	for index in range(active.size() - 1, -1, -1):
		var slot := slots[active[index]]
		slot.time -= delta
		var node: MeshInstance3D = slot.node
		if slot.time <= 0.0:
			node.hide()
			active[index] = active.back()
			active.pop_back()
			continue
		var fade := clampf(slot.time / slot.total, 0.15, 1.0)
		if slot.kind == 1:
			slot.velocity.y -= 5.0 * delta
			node.position += slot.velocity * delta
			node.scale = slot.size * fade
		elif slot.kind == 2:
			node.scale = slot.size * Vector3(1.0 - fade, fade, 1.0 - fade)
		else:
			node.scale = slot.size * Vector3(fade, fade, 1.0)
	if active.is_empty():
		set_process(false)
