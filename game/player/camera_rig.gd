extends Camera3D

const Track := preload("res://network/snapshot_track.gd")

var pilot: CharacterBody3D
var eye_height := 1.62
var travel := 0.0
var lean := 0.0
var spring := 0.0
var step_weight := 0.0

func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	near = pilot.head.near
	far = pilot.head.far
	fov = pilot.head.fov
	eye_height = pilot.head.position.y
	global_transform = pilot.head.global_transform
	make_current()

func present(delta: float) -> void:
	var stable: bool = Prefs.values.steady_cam
	var strength: float = 0.0 if stable else Prefs.values.motion_strength
	var velocity: Vector3 = pilot.replica_velocity if pilot.replica else pilot.velocity
	var speed := Vector2(velocity.x, velocity.z).length()
	var motion := clampf(speed / pilot.RUN, 0.0, 1.0)
	var flags: int = pilot.replica_flags if pilot.replica else pilot.pose_flags()
	var running := (flags & Track.RUN) != 0
	var grounded: bool = (flags & Track.AIR) == 0 if pilot.replica else pilot.is_on_floor()
	travel = lerpf(travel, motion, 1.0 - exp(-9.0 * delta))
	step_weight = lerpf(step_weight, motion if grounded else 0.0, 1.0 - exp(-11.0 * delta))
	eye_height = lerpf(eye_height, pilot.height - 0.16, 1.0 - exp(-23.0 * delta))
	spring = lerpf(spring, pilot.landing, 1.0 - exp(-27.0 * delta))
	pilot.landing = lerpf(pilot.landing, 0.0, 1.0 - exp(-16.0 * delta))
	var lateral: float = velocity.dot(pilot.global_basis.x) / pilot.RUN
	var slide: float = 0.38 * float((flags & Track.SLIDE) != 0) if pilot.replica else pilot.slide
	lean = lerpf(lean, clampf(-lateral * 0.023 - slide * 0.035, -0.044, 0.044) * strength,
		1.0 - exp(-10.0 * delta))
	var footfall := 0.0
	if Prefs.values.head_bob:
		footfall = (absf(sin(pilot.walk_phase)) - 0.54) * step_weight * 0.046 * strength
	var eye: Vector3 = pilot.get_global_transform_interpolated().origin
	var view_basis: Basis = pilot.head.global_basis * Basis(Vector3.BACK, lean)
	eye.y += eye_height + footfall - spring * Prefs.values.shake * strength
	global_transform = Transform3D(view_basis, eye)
	var sprint_extra := 5.0 * travel if running and Prefs.values.sprint_fov and not stable else 0.0
	fov = lerpf(fov, pilot.arsenal.aim_fov(Prefs.values.fov + sprint_extra), 1.0 - exp(-15.0 * delta))
	pilot.head.fov = fov
	pilot.wall_pull = lerpf(pilot.wall_pull, pilot.wall_target, 1.0 - exp(-19.0 * delta))
	pilot.arsenal.pose(delta, travel, running, pilot.wall_pull)
