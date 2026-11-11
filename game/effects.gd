extends Node3D

const LIMITS := [96, 108, 120, 64]
enum Kind { TRACE, SPARK, RING, DUST }

var slots: Array[Dictionary] = []
var active: Array[int] = []
var palette := {}
var next_slot := 0
var cube: BoxMesh
var ring: TorusMesh
var dust_mesh: SphereMesh
var limit := 64

func _ready() -> void:
	cube = BoxMesh.new()
	cube.size = Vector3.ONE
	ring = TorusMesh.new()
	ring.inner_radius = 0.98
	ring.outer_radius = 1.02
	ring.rings = 20
	ring.ring_segments = 5
	dust_mesh = SphereMesh.new()
	dust_mesh.radius = 0.5
	dust_mesh.height = 1.0
	dust_mesh.radial_segments = 6
	dust_mesh.rings = 3
	_apply_limit()
	Prefs.changed.connect(_preferences)
	set_process(false)

func _apply_limit() -> void:
	limit = LIMITS[Prefs.values.quality]
	next_slot %= limit
	for index in range(active.size() - 1, -1, -1):
		var id := active[index]
		if id >= limit:
			slots[id].time = 0.0
			slots[id].node.hide()
			active.remove_at(index)
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

func _preferences(key: String) -> void:
	if key in ["quality", "all"]:
		_apply_limit()

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

func sparks(at: Vector3, tint: Color, count: int, power := 3.0, normal := Vector3.UP) -> void:
	var density: float = [0.46, 0.74, 1.0, 0.24][Prefs.values.quality] * Prefs.values.particles
	for _particle in roundi(count * density):
		var slot := _acquire(tint, randf_range(0.13, 0.38))
		var node: MeshInstance3D = slot.node
		node.position = at
		node.rotation = Vector3(randf(), randf(), randf()) * TAU
		var scatter := Vector3(randf_range(-0.8, 0.8), randf_range(0.0, 0.9), randf_range(-0.8, 0.8))
		slot.velocity = (scatter + normal * 0.65) * power
		slot.size = Vector3(0.047, 0.047, randf_range(0.07, 0.18))
		slot.kind = Kind.SPARK
		node.scale = slot.size

func impact(at: Vector3, normal: Vector3, tint: Color, terrain: String, armor: bool) -> void:
	var shade := tint if armor else Color("#e7c2a0")
	var dust := not armor and terrain in ["grove", "bastion", "district"] and normal.y > 0.6
	if dust:
		shade = Color("#b5a28b")
	sparks(at + normal * 0.042, shade, 5 if dust else 7, 1.25 if dust else 2.3, normal)
	if dust and Prefs.values.quality in [1, 2]:
		for _grain in roundi(4.0 * Prefs.values.particles):
			var slot := _acquire(shade.darkened(0.26), randf_range(0.24, 0.39))
			var node: MeshInstance3D = slot.node
			node.mesh = dust_mesh
			node.position = at + Vector3(randf_range(-0.08, 0.08), 0.035, randf_range(-0.08, 0.08))
			node.rotation = Vector3.ZERO
			node.scale = Vector3.ONE * 0.05
			slot.kind = Kind.DUST
			slot.velocity = Vector3(randf_range(-0.35, 0.35), randf_range(0.09, 0.23), randf_range(-0.35, 0.35))
			slot.size = Vector3(0.18, 0.13, 0.18) * randf_range(0.7, 1.15)

func wave(at: Vector3, tint: Color, radius: float) -> void:
	var slot := _acquire(tint, 0.23)
	var node: MeshInstance3D = slot.node
	node.mesh = ring
	node.position = at
	node.rotation = Vector3.ZERO
	node.scale = Vector3(0.21, 0.10, 0.21)
	slot.size = Vector3(radius, 0.10, radius)
	slot.kind = Kind.RING

func _acquire(tint: Color, lifetime: float) -> Dictionary:
	var slot := slots[next_slot]
	if slot.time <= 0.0:
		active.append(next_slot)
	next_slot = (next_slot + 1) % limit
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
	slot.kind = Kind.TRACE
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
		if slot.kind == Kind.SPARK:
			slot.velocity.y -= 5.0 * delta
			node.position += slot.velocity * delta
			node.scale = slot.size * fade
		elif slot.kind == Kind.RING:
			var spread := lerpf(0.12, 1.0, 1.0 - fade * fade)
			node.scale = slot.size * Vector3(spread, fade, spread)
		elif slot.kind == Kind.DUST:
			node.position += slot.velocity * delta
			var age := 1.0 - fade
			node.scale = slot.size * sin(PI * age)
		else:
			node.scale = slot.size * Vector3(fade, fade, 1.0)
	if active.is_empty():
		set_process(false)
