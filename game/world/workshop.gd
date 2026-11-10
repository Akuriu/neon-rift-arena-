extends Node3D

const Fabric := preload("res://game/fabric.gd")
const Materials := preload("res://art/materials.gd")
enum State { INACTIVE, ACTIVATING, ACTIVE, COOLDOWN }
const TERMINAL := Vector3(7.6, 1.0, 22.2)
const DOOR := Vector3(10.5, 1.4, 22.0)
const FOOTPRINT := Rect2(8.9, 21.7, 3.2, 0.6)
var stage: Node3D
var state := State.INACTIVE
var opening := true
var progress := 0.0
var hold := 0.0
var activations := 0
var obstructed := false
var door: AnimatableBody3D
var collider: CollisionShape3D
var indicator: MeshInstance3D
var clearance := PhysicsShapeQueryParameters3D.new()
var base_footprints: Array[Rect2] = []

func _ready() -> void:
	name = "MaintenanceWorkshop"
	base_footprints.assign(stage.arena.footprints)
	for at in [Vector3(7.8, 1.6, 18.8), Vector3(13.2, 1.6, 18.8), Vector3(10.5, 1.6, 15.8)]:
		var size := Vector3(0.3, 3.2, 6.7) if at.x != 10.5 else Vector3(5.7, 3.2, 0.3)
		_solid(at, size, Color("#5c6d65"))
		base_footprints.append(Rect2(Vector2(at.x, at.z) - Vector2(size.x, size.z) * 0.5, Vector2(size.x, size.z)))
	_solid(Vector3(10.5, 3.25, 18.8), Vector3(5.8, 0.23, 6.8), Color("#737d73"))
	for x in [8.4, 12.6]:
		_solid(Vector3(x, 1.4, 22), Vector3(1.0, 2.8, 0.55), Color("#727c72"))
		base_footprints.append(Rect2(x - 0.5, 21.7, 1.0, 0.6))
	_solid(TERMINAL - Vector3.UP * 0.35, Vector3(0.5, 1.3, 0.5), Color("#4a554c"))
	indicator = Fabric.place(self, Fabric.cube(Vector3(0.31, 0.20, 0.028)), Fabric.paint(Color("#c8ad83")), TERMINAL + Vector3(0, 0.2, 0.265))
	var sign := Label3D.new()
	sign.font = preload("res://assets/fonts/OpenSans-CondBold.ttf")
	sign.font_size = 42
	sign.text = "ATELIER / MAINTENANCE"
	sign.position = Vector3(10.5, 3.8, 22.05)
	sign.pixel_size = 0.009
	add_child(sign)
	for z in [17.0, 18.1, 19.2, 20.3]:
		Fabric.place(self, Fabric.cube(Vector3(2.8, 0.025, 0.1)), Fabric.paint(Color("#c4ad85")), Vector3(10.5, 0.025, z))
	door = AnimatableBody3D.new()
	door.collision_layer = 1
	door.collision_mask = 0
	door.position = DOOR
	add_child(door)
	collider = CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(3.2, 2.8, 0.5)
	collider.shape = volume
	door.add_child(collider)
	Fabric.place(door, Fabric.bevel(volume.size, 0.07), Materials.finish(Color("#8c8e78"), "steel", 0.65), Vector3.ZERO)
	for y in [-0.9, -0.3, 0.3, 0.9]:
		Fabric.place(door, Fabric.cube(Vector3(3.03, 0.045, 0.04)), Fabric.paint(Color("#535f53")), Vector3(0, y, 0.27))
	var query_shape := BoxShape3D.new()
	query_shape.size = Vector3(3.5, 3.15, 1.0)
	clearance.shape = query_shape
	clearance.collision_mask = 2 | 4
	clearance.transform.origin = DOOR
	_routes(false)

func _solid(at: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	Fabric.place(body, Fabric.bevel(size, 0.04), Materials.finish(color, "steel", 0.9), Vector3.ZERO)

func can_reach(actor: CharacterBody3D) -> bool:
	return is_instance_valid(actor) and actor.alive and actor.position.distance_to(TERMINAL - Vector3.UP) <= 2.6 \
		and not is_instance_valid(stage.net) and stage.mode in ["explore", "training"] \
		and stage.ray(actor.aim_point(), TERMINAL + Vector3(0, 0.22, 0.32), 1).is_empty()

func hint() -> String:
	if obstructed:
		return "Passage occupé · fermeture suspendue"
	match state:
		State.INACTIVE: return "Ouvrir l’atelier"
		State.ACTIVE: return "Fermer l’atelier"
		State.COOLDOWN: return "Atelier · patientez"
	return "Porte en mouvement"

func activate(actor: CharacterBody3D) -> bool:
	if not can_reach(actor) or state not in [State.INACTIVE, State.ACTIVE]:
		return false
	opening = state == State.INACTIVE
	state = State.ACTIVATING
	activations += int(opening)
	stage.sound("switch", TERMINAL)
	return true

func _physics_process(delta: float) -> void:
	obstructed = false
	if state == State.ACTIVE:
		hold -= delta
		if hold <= 0.0:
			opening = false
			state = State.ACTIVATING
	elif state == State.COOLDOWN:
		hold -= delta
		if hold <= 0.0:
			state = State.INACTIVE
	if state != State.ACTIVATING:
		return
	if not opening:
		obstructed = _occupied()
		if obstructed:
			return
		collider.set_deferred("disabled", false)
	progress = move_toward(progress, 1.0 if opening else 0.0, delta / 0.85)
	door.position = DOOR + Vector3.UP * (3.0 * smoothstep(0, 1, progress))
	if opening and progress == 1.0:
		state = State.ACTIVE
		hold = 8.0
		collider.set_deferred("disabled", true)
		_routes(true)
		indicator.material_override = Fabric.paint(Color("#728b73"))
	elif not opening and progress == 0.0:
		state = State.COOLDOWN
		hold = 1.5
		_routes(false)
		indicator.material_override = Fabric.paint(Color("#c8ad83"))

func _occupied() -> bool:
	# Read logical positions too: the broad phase can lag a newly teleported body.
	var actors: Array = stage.living_pilots() + stage.units
	for actor in actors:
		var at: Vector3 = actor.position - DOOR
		if absf(at.x) < 2.15 and absf(at.z) < 0.95 and actor.position.y < 6.0 and actor.position.y > -1.8:
			return true
	return not get_world_3d().direct_space_state.intersect_shape(clearance, 1).is_empty()

func _routes(open: bool) -> void:
	stage.arena.footprints.assign(base_footprints)
	if not open:
		stage.arena.footprints.append(FOOTPRINT)
	stage.arena.routes.setup(stage.arena.footprints, stage.arena.half_size)
