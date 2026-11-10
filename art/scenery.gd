extends RefCounted

const Fabric := preload("res://game/fabric.gd")
const Materials := preload("res://art/materials.gd")
const LEAVES := [Color("#59664c"), Color("#465542"), Color("#657156"), Color("#758064")]
const BARK := Color("#6d5a43")

static func build(arena: Node3D) -> Node3D:
	var scenery := Node3D.new()
	scenery.name = "Landscape"
	arena.structure.add_child(scenery)
	var ground := PlaneMesh.new()
	ground.size = Vector2(174, 174)
	var terrain := Materials.finish(Color("#767b63"), "gravel", 0.42)
	Fabric.place(scenery, ground, terrain, Vector3(0, -0.23, 0), Vector3.ZERO, false)
	var vegetation := Fabric.Batch.new()
	vegetation.world_materials = true
	var edge: Vector2 = arena.half_size
	var rng := RandomNumberGenerator.new()
	rng.seed = String(arena.map_id).hash()
	for side in [-1, 1]:
		for i in (7 if arena.map_id == "grove" else 4):
			var at := Vector3(side * (edge.x + rng.randf_range(4.0, 11.5)), -0.23, -23.5 + i * 12.3)
			tree(vegetation, at, rng.randf_range(5.3, 8.7), rng)
	vegetation.commit(scenery, false)
	return scenery

static func tree(work: Fabric.Batch, at: Vector3, height: float, rng: RandomNumberGenerator) -> void:
	var wood := Materials.finish(BARK, "timber", 0.62)
	work.put(Fabric.tube(height * 0.038, height * 0.90, 8, height * 0.011), wood,
		at + Vector3.UP * height * 0.45, Vector3(0, 0, -0.027))
	for i in 7:
		var angle := TAU * i * 0.38197 + rng.randf_range(-0.16, 0.16)
		var reach := height * rng.randf_range(0.10, 0.18) * (1.0 - float(i) * 0.066)
		var base := at + Vector3.UP * height * (0.49 + i * 0.065)
		var tip := base + Vector3(cos(angle) * reach, height * 0.18, sin(angle) * reach)
		var branch := tip - base
		work.put(Fabric.tube(height * 0.013, branch.length(), 6, height * 0.004), wood, (base + tip) * 0.5,
			Basis(Quaternion(Vector3.UP, branch.normalized())).get_euler())
		var scale := rng.randf_range(0.145, 0.219) * height * (1.0 - float(i) * 0.035)
		var leaves := Materials.finish(LEAVES[i % LEAVES.size()], "concrete", 2.8)
		var crown := Fabric.orb(scale, scale * rng.randf_range(1.19, 1.70), 8)
		work.put(crown, leaves, tip, Vector3(rng.randf_range(-0.51, 0.51), angle, rng.randf_range(-0.45, 0.45)))
	work.put(Fabric.orb(height * 0.119, height * 0.24, 8), Materials.finish(LEAVES[2], "concrete", 3.2),
		at + Vector3.UP * height * 0.961)

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
