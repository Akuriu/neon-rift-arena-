extends Node3D

const Fabric := preload("res://game/fabric.gd")
static var pellet: Mesh
static var shell: Mesh
var session: Node3D
var velocity := Vector3.ZERO
var damage := 0.0
var tint := Color.WHITE
var life := 0.0
var splash := 0.0
var friendly := false
var trail_timer := 0.0
var gravity := 0.0
var shooter: CharacterBody3D
var weapon := ""
var model: MeshInstance3D

func _ready() -> void:
	if pellet == null:
		pellet = Fabric.tube(0.027, 0.13, 8, 0.012)
		shell = Fabric.tube(0.078, 0.17, 12, 0.059)
	model = Fabric.place(self, pellet, Fabric.paint(Color("#948577")), Vector3.ZERO, Vector3.ZERO, false)
	sleep()

func arm(at: Vector3, impulse: Vector3, power: float, color: Color, allied: bool,
		radius: float, curve: float, owner_pilot: CharacterBody3D, equipment: String) -> void:
	global_position = at
	reset_physics_interpolation()
	velocity = impulse
	damage = power
	tint = color
	friendly = allied
	splash = radius
	gravity = curve
	shooter = owner_pilot
	weapon = equipment
	life = 2.8 if gravity > 0.0 else 4.0
	trail_timer = 0.0
	model.mesh = shell if friendly or radius > 1.0 else pellet
	model.material_override = Fabric.paint(Color("#7b8068") if model.mesh == shell else Color("#bc9a60"))
	_orient()
	show()
	set_physics_process(true)

func sleep() -> void:
	hide()
	set_physics_process(false)
	shooter = null

func _physics_process(delta: float) -> void:
	var start := global_position
	velocity.y -= gravity * delta
	var end := start + velocity * delta
	var mask := (1 | 4) if friendly else (1 | 2)
	var exclude: Array[RID] = []
	if is_instance_valid(session.classic) and not friendly:
		mask = 1 | 2 | 4
		if is_instance_valid(shooter):
			exclude.append(shooter.get_rid())
	var hit: Dictionary = session.ray(start, end, mask, exclude)
	life -= delta
	var heading := velocity.normalized()
	if not hit.is_empty() or life <= 0.0:
		var at: Vector3 = hit.get("position", end)
		session.projectile_impact(self, hit.get("collider"), at, heading)
		session.recycle_bolt(self)
		return
	global_position = end
	_orient()
	trail_timer -= delta
	if trail_timer <= 0.0:
		if model.mesh == pellet:
			session.effects.beam(end, end - heading * 0.61, Color("#e3c28a"), 0.015, 0.06)
		trail_timer = 0.075 if Prefs.values.quality == 3 else 0.047

func _orient() -> void:
	var heading := velocity.normalized()
	if heading != Vector3.ZERO:
		model.basis = Basis(Quaternion(Vector3.UP, heading))
