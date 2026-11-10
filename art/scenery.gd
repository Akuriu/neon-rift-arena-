extends RefCounted

const Fabric := preload("res://game/fabric.gd")

static func build(arena: Node3D) -> Node3D:
	var scenery := Node3D.new()
	scenery.name = "DaylightScenery"
	arena.structure.add_child(scenery)
	var ground := PlaneMesh.new()
	ground.size = Vector2(160, 160)
	Fabric.place(scenery, ground, Fabric.paint(Color("#737c69"), false, 0.0), Vector3(0, -0.23, 0), Vector3.ZERO, false)
	var vegetation := Fabric.Batch.new()
	var bark := Fabric.paint(Color("#635744"), false, 0.0)
	var leaves := Fabric.paint(Color("#526c54"), false, 0.0)
	var crown := Fabric.paint(Color("#71805c"), false, 0.0)
	var origin: Vector2 = arena.half_size
	var rng := RandomNumberGenerator.new()
	rng.seed = String(arena.map_id).hash()
	var trunk := Fabric.tube(0.33, 6.0, 6, 0.15)
	var tree := Fabric.tube(2.7, 5.5, 7, 0.08)
	for side in [-1, 1]:
		for i in 4:
			var at := Vector3(side * (origin.x + 6.0 + rng.randf_range(1.0, 5.0)), 0.0, -23.5 + i * 14.8)
			vegetation.put(trunk, bark, at + Vector3.UP * 3.0, Vector3.ZERO, false)
			vegetation.put(tree, leaves, at + Vector3.UP * 6.6, Vector3.ZERO, false)
			vegetation.put(tree, crown, at + Vector3.UP * 8.15, Vector3.ZERO, false)
	vegetation.commit(scenery, false)
	return scenery

static func weather(arena: Node3D, snow: bool) -> CPUParticles3D:
	var field := CPUParticles3D.new()
	field.name = "AirborneSnow" if snow else "AirborneDust"
	field.amount = 72 if snow else 42
	field.lifetime = 6.0
	field.local_coords = true
	field.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	field.emission_box_extents = Vector3(arena.half_size.x * 0.96, 2.0, arena.half_size.y * 0.96)
	field.direction = Vector3(0.4, -0.76 if snow else -0.07, 0.16)
	field.spread = 18.0
	field.gravity = Vector3(0.05, -0.08 if snow else -0.02, 0.0)
	field.initial_velocity_min = 0.28
	field.initial_velocity_max = 0.95
	field.position.y = 4.0
	var flakes := BoxMesh.new()
	flakes.size = Vector3(0.038, 0.052 if snow else 0.029, 0.03)
	flakes.material = Fabric.paint(Color("#c2d6db") if snow else Color("#bfad87"), true)
	field.mesh = flakes
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.structure.add_child(field)
	return field
