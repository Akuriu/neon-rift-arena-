extends RefCounted

const RANGE := 32.0
const INTERVAL := 0.045
const IDLE_LIMIT := 0.14
const FRICTION := 0.27

var last_touch := 0.0
var until_sample := 0.0
var speed_scale := 1.0

func on_drag() -> float:
	last_touch = IDLE_LIMIT
	return speed_scale

func update(pilot: CharacterBody3D, delta: float) -> void:
	last_touch = maxf(0.0, last_touch - delta)
	if last_touch <= 0.0 or not Prefs.values.touch_aim_assist or pilot.input_blocked or not pilot.alive:
		speed_scale = 1.0
		until_sample = 0.0
		return
	until_sample -= delta
	if until_sample <= 0.0:
		speed_scale = _sample(pilot)
		until_sample = INTERVAL

func _sample(pilot: CharacterBody3D) -> float:
	var stage: Node3D = pilot.session
	var origin: Vector3 = pilot.head.global_position
	var forward: Vector3 = -pilot.head.global_basis.z
	var scoped: bool = pilot.arsenal.aiming() and pilot.arsenal.spec().has("zoom")
	var cone := cos(deg_to_rad(1.55 if scoped else 3.5))
	var best := cone
	for unit in stage.units:
		if not is_instance_valid(unit) or not unit.alive:
			continue
		if not stage.can_damage(pilot, unit):
			continue
		var point: Vector3 = unit.aim_point()
		var offset := point - origin
		var square := offset.length_squared()
		if square <= 0.25 or square > RANGE * RANGE:
			continue
		var alignment := forward.dot(offset / sqrt(square))
		if alignment > best and stage.ray(origin, point, 1).is_empty():
			best = alignment
	return 1.0 - FRICTION * smoothstep(cone, 1.0, best)
