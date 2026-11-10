extends RefCounted

enum Pose { IDLE, WALK, SPRINT, STOW, EQUIP, RELOAD_OPEN, RELOAD_CELL, RELOAD_CLOSE,
	INSPECT, AIM, CHARGE, FIRE, EMPTY, HOT }

const SWAP := 0.29
const HANDOFF := 0.16
const REST := Vector3(0.225, -0.217, -0.66)
const TUNES := [
	# Recul linéaire, rotation, durée d’inspection, inclinaison du mécanisme.
	Vector4(0.057, 0.066, 1.03, 0.14), Vector4(0.092, 0.119, 1.16, 0.30),
	Vector4(0.041, 0.049, 0.94, 0.09), Vector4(0.105, 0.092, 1.38, 0.28),
	Vector4(0.077, 0.048, 1.29, 0.17), Vector4(0.083, 0.073, 1.45, 0.21),
	Vector4(0.027, 0.031, 0.98, 0.52), Vector4(0.117, 0.138, 1.36, 0.38),
]

var state := Pose.IDLE
var stride := 0.0
var sprint := 0.0
var travel := Vector3.ZERO
var attitude := Vector3.ZERO
var warmed := false
var stow := 0.0
var cell_weight := 0.0

static func inspection_time(index: int) -> float:
	return TUNES[index].z

func tick(gun: Node, delta: float, motion: float, running: bool, wall: float, settings: Dictionary) -> void:
	if delta > 0.25:
		delta = 0.05
	gun.scope = lerpf(gun.scope, 1.0 if gun.aiming() else 0.0, 1.0 - exp(-14.0 * delta))
	gun.shot_kick = move_toward(gun.shot_kick, 0.0, delta * 8.9)
	if not gun.pilot.alive:
		gun.view.hide()
		return
	if gun.swap_left <= HANDOFF and gun.visual_index != gun.active:
		gun.show_model(gun.active)
		cell_weight = 0.0
	var tune: Vector4 = TUNES[gun.visual_index]
	var comfort: float = 0.24 if settings.steady_cam else settings.motion_strength
	var heat: float = gun.heat[gun.active]
	var kick: float = gun.shot_kick * (1.0 if settings.recoil else 0.22)
	if settings.steady_cam:
		kick *= 0.32
	stride = lerpf(stride, motion, 1.0 - exp(-10.0 * delta))
	var sprint_pose: bool = running and not gun.aiming() and gun.reload_left <= 0.0 and gun.swap_left <= 0.0
	sprint = lerpf(sprint, 1.0 if sprint_pose else 0.0, 1.0 - exp(-12.0 * delta))
	var walk: float = gun.pilot.rendered_step_phase()
	var base := REST + Vector3(0.0, -0.009, -0.10) if gun.visual_index == 2 else REST
	var target := base + Vector3(sin(walk) * 0.016, (absf(cos(walk)) - 0.58) * 0.016, 0.0) * stride * comfort
	target += Vector3(0, sin(gun.pose_clock * 2.2) * 0.003 * comfort, kick * tune.x)
	target += Vector3(0.041, -0.087, 0.038) * sprint
	var angle := Vector3(-kick * tune.y, -0.071, -0.22 * sprint)
	var cell := 0.0
	state = Pose.SPRINT if running else (Pose.WALK if motion > 0.07 else Pose.IDLE)
	if gun.rounds() <= 0:
		state = Pose.EMPTY
	if gun.shot_kick > 0.15:
		state = Pose.FIRE
	if heat > 0.83:
		state = Pose.HOT
	if gun.inspecting > 0.0:
		state = Pose.INSPECT
		var phase: float = 1.0 - gun.inspecting / inspection_time(gun.active)
		var turn := sin(PI * clampf(phase, 0.0, 1.0))
		target += Vector3(-0.096, 0.044, -0.044) * turn
		angle += Vector3(0.15, (0.58 + tune.w) * turn, -0.40) * turn
	if gun.charge > 0.0:
		state = Pose.CHARGE
		angle.x -= gun.charge * 0.056
	if gun.reload_left > 0.0:
		var phase: float = 1.0 - gun.reload_left / maxf(0.05, gun.cycle_length)
		var opening := smoothstep(0.0, 0.20, phase) * (1.0 - smoothstep(0.70, 1.0, phase))
		cell = smoothstep(0.18, 0.42, phase) * (1.0 - smoothstep(0.57, 0.79, phase))
		target += Vector3(-0.036, -0.148, 0.036) * opening
		angle += Vector3(-0.62, 0.23, -0.29) * opening
		state = Pose.RELOAD_OPEN if phase < 0.21 else (Pose.RELOAD_CELL if phase < 0.72 else Pose.RELOAD_CLOSE)
	if gun.scope > 0.01 and gun.reload_left <= 0.0 and gun.swap_left <= 0.0:
		var aim_weight: float = gun.scope
		var sight: float = gun.sight_height()
		var aim := Vector3(0.0, -sight * gun.view.scale.y - 0.007, base.z)
		target = target.lerp(aim + Vector3(0, -0.003, kick * tune.x * 0.63), aim_weight)
		angle = angle.lerp(Vector3(-kick * tune.y * 0.38, 0, 0), aim_weight)
		if gun.aiming() and state != Pose.CHARGE and state != Pose.FIRE:
			state = Pose.AIM
	var stow_target := smoothstep(0.0, HANDOFF, gun.swap_left)
	stow = lerpf(stow, stow_target, 1.0 - exp(-26.0 * delta))
	target += Vector3(0.075, -0.34, 0.115) * stow
	angle += Vector3(-0.82, tune.w * 0.48, -0.46) * stow
	if gun.swap_left > 0.0:
		state = Pose.STOW if gun.swap_left > HANDOFF else Pose.EQUIP
	target += Vector3(0.042, -0.046, 0.19) * wall
	angle.x -= wall * 0.67
	if not warmed:
		travel = target
		attitude = angle
		warmed = true
	travel = travel.lerp(target, 1.0 - exp(-26.0 * delta))
	attitude = attitude.lerp(angle, 1.0 - exp(-23.0 * delta))
	gun.view.position = travel
	gun.view.rotation = attitude
	gun.view.visible = not gun.spec().has("zoom") or gun.scope < 0.90
	cell_weight = lerpf(cell_weight, cell, 1.0 - exp(-32.0 * delta))
	var home: Vector3 = gun.cell.get_meta("home")
	gun.cell.position = home + Vector3(-0.035, -(0.19 + tune.w * 0.06), 0.035) * cell_weight
	gun.cell.rotation.z = -cell_weight * 0.48
	var travel_distance := 0.10 if gun.visual_index == 1 else 0.036
	gun.mechanism.position.z = (kick * 0.65 + cell_weight * 0.35) * travel_distance
	var intensity: float = settings.flashes
	gun.flash.visible = intensity > 0.03 and gun.shot_kick > 0.77
	gun.flash.scale = Vector3.ONE * (0.55 + gun.shot_kick * intensity * 0.56)
