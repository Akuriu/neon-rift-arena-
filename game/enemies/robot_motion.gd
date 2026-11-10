extends RefCounted

const Fabric := preload("res://game/fabric.gd")
static var joint_mesh: Mesh
var left: Node3D
var right: Node3D
var cycle := 0.0
var weight := 0.0
var pose := 0.0
var hovering := false

func build(hull: Node3D, kind: String) -> void:
	hovering = kind in ["skimmer", "specter", "architect"]
	var heavy := kind in ["elite", "warden", "colossus", "artillery", "bulwark"]
	var stance := 0.64 if heavy else 0.39
	if joint_mesh == null:
		var mesh := SurfaceTool.new()
		mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
		mesh.append_from(Fabric.bevel(Vector3(0.21, 0.44, 0.26), 0.068), 0,
			Transform3D(Basis.IDENTITY, Vector3(0, -0.21, 0)))
		mesh.append_from(Fabric.bevel(Vector3(0.25, 0.16, 0.37), 0.067), 0,
			Transform3D(Basis.IDENTITY, Vector3(0, -0.46, -0.047)))
		mesh.index()
		joint_mesh = mesh.commit()
	left = _joint(hull, -stance, heavy)
	right = _joint(hull, stance, heavy)

func _joint(hull: Node3D, x: float, heavy: bool) -> Node3D:
	var joint := Node3D.new()
	joint.position = Vector3(x, 0.84 if heavy else 0.80, 0.14)
	hull.add_child(joint)
	var finish := Fabric.paint(Color("#454f54"))
	var segment := Fabric.place(joint, joint_mesh, finish, Vector3.ZERO, Vector3.ZERO, false)
	segment.visibility_range_end = 29.0 if Prefs.values.quality == 3 else 39.0
	segment.visibility_range_end_margin = 4.0
	if hovering:
		joint.scale.y = 0.46
	return joint

func step(delta: float, speed: float, telling: bool, impact: float, armor: bool) -> void:
	var energy := clampf(speed / 4.9, 0.0, 1.0)
	cycle = fposmod(cycle + speed * delta * (1.5 if hovering else 3.8), TAU)
	weight = lerpf(weight, energy, 1.0 - exp(-9.0 * delta))
	pose = lerpf(pose, 1.0 if telling else 0.0, 1.0 - exp(-10.0 * delta))
	var walk := sin(cycle) * weight * (0.22 if hovering else 0.46) * (1.0 - pose * 0.58)
	var crouch := pose * (0.20 if armor else 0.09)
	left.rotation.x = walk - crouch + impact * 0.10
	right.rotation.x = -walk - crouch + impact * 0.10
	left.rotation.z = pose * 0.16
	right.rotation.z = -pose * 0.16
