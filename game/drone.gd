extends CharacterBody3D

signal eliminated(drone: CharacterBody3D, points: int)

const Catalog := preload("res://game/catalog.gd")
const Models := preload("res://game/robot_models.gd")

enum State { ARRIVAL, CHASE, TELL, RECOVER, DEAD }
var state := State.ARRIVAL
var kind := "scout"
var spec: Dictionary
var tuning: Dictionary
var target: CharacterBody3D
var session: Node3D
var health := 0.0
var maximum := 1.0
var alive := true
var timer := 0.48
var decision := 0.0
var hit_flash := 0.0
var path := PackedVector3Array()
var aim_at := Vector3.ZERO
var patrol_origin := Vector3.ZERO
var hull: Node3D
var lens: MeshInstance3D
var paint: StandardMaterial3D
var lens_energy := -1.0
var lens_color := Color.TRANSPARENT
var gaze := Vector3.FORWARD
var strafe := 1.0
var phase := 1
var training := false
var serial := 0
var attack_number := 0
var wave_attack := false
var age := 0.0
var dodge_left := 0.0
var dodge_direction := Vector3.ZERO
var patient: CharacterBody3D
var repairs_left := 3
var hover_home := 0.04
var last_check := Vector3.ZERO
var check_left := 0.6
var stuck := 0.0
var relocations := 0
var replica := false
var replica_at := Vector3.ZERO
var replica_yaw := 0.0

func major() -> bool:
	return kind in ["warden", "colossus", "architect"]

func _ready() -> void:
	spec = Catalog.UNITS[kind]
	maximum = spec.health * tuning.hp
	hover_home = position.y + (0.57 if kind == "skimmer" else 0.0)
	if kind == "skimmer" and not replica:
		position.y = hover_home
	last_check = position
	health = maximum
	strafe = -1.0 if serial % 2 == 0 else 1.0
	decision = float(serial % 8) * 0.034
	collision_layer = 0 if replica else 4
	collision_mask = 0 if replica else 1 | 2 | 4
	var collider := CollisionShape3D.new()
	var volume := CapsuleShape3D.new()
	volume.radius = spec.radius
	volume.height = maxf(1.51, volume.radius * 2.0 + 0.05)
	if major():
		volume.height = 2.70
	collider.shape = volume
	collider.position.y = volume.height * 0.5 + 0.12
	add_child(collider)
	hull = Node3D.new()
	add_child(hull)
	lens = Models.build(hull, kind, spec.tint)
	paint = lens.material_override.duplicate()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	paint.emission_enabled = true
	paint.emission = spec.tint
	lens.material_override = paint

func center() -> Vector3:
	return global_position + Vector3.UP * (1.53 if major() else 1.02)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	age += delta
	hit_flash = maxf(0.0, hit_flash - delta * 6.0)
	if replica:
		position = position.lerp(replica_at, 1.0 - exp(-17.0 * delta))
		rotation.y = lerp_angle(rotation.y, replica_yaw, 1.0 - exp(-17.0 * delta))
		_animate()
		return
	if not is_instance_valid(target) or not target.alive:
		target = session.nearest_pilot(position)
		if not is_instance_valid(target):
			return
	timer -= delta
	var step := Vector3.ZERO
	var offset := target.global_position - global_position
	offset.y = 0.0
	var toward := offset.normalized()
	if toward != Vector3.ZERO and state != State.TELL:
		var turning := 5.4 if major() or kind in ["bulwark", "elite"] else 13.0
		rotation.y = lerp_angle(rotation.y, atan2(-toward.x, -toward.z), 1.0 - exp(-turning * delta))
		gaze = -global_basis.z
	match state:
		State.ARRIVAL, State.RECOVER:
			if timer <= 0.0:
				state = State.CHASE
				decision = 0.0
		State.CHASE:
			step = _pursuit(delta, offset.length(), toward)
		State.TELL:
			if timer <= 0.0:
				attack()
				state = State.RECOVER
				timer = spec.rest * tuning.tempo * (0.74 if major() and phase == 3 else 1.0)
	if dodge_left > 0.0:
		dodge_left -= delta
		step = dodge_direction * 8.4
	if kind == "skimmer":
		step.y = clampf((hover_home + sin(age * 1.7) * 0.28 - position.y) * 4.0, -2.0, 2.0)
	velocity = velocity.move_toward(step, delta * 29.0)
	move_and_slide()
	if not training:
		_check_stall(delta, offset.length())
	_animate()

func _animate() -> void:
	var time := age + serial * 0.57
	hull.position.y = sin(time * 4.3) * (0.12 if kind == "skimmer" else 0.065)
	hull.rotation.z = lerpf(hull.rotation.z, -velocity.dot(global_basis.x) * 0.034, 0.19)
	hull.scale = Vector3.ONE * (0.55 + 0.45 * clampf(1.0 - timer / 0.48, 0.0, 1.0)) \
		if state == State.ARRIVAL else Vector3.ONE
	var warning := 0.0
	if state == State.TELL:
		warning = (0.65 + 0.33 * sin(time * 20.0)) * Prefs.values.flashes + 0.45
	var base: Color = spec.tint
	if major() and phase > 1:
		base = base.lerp(Color("#ff7297") if phase == 2 else Color("#fff0b2"), 0.52)
	var energy: float = 0.42 + warning + hit_flash * Prefs.values.flashes
	var color := base.lerp(Color.WHITE, hit_flash * 0.55)
	if absf(lens_energy - energy) > 0.015:
		lens_energy = energy
		paint.emission_energy_multiplier = energy
	if color != lens_color:
		lens_color = color
		paint.emission = base
		paint.albedo_color = color

func _check_stall(delta: float, distance: float) -> void:
	check_left -= delta
	if check_left > 0.0:
		return
	check_left = 0.6
	if state == State.CHASE and position.distance_squared_to(last_check) < 0.11 and distance > 4.5:
		stuck += 0.6
		if stuck > 9.0:
			stuck = 0.0
			session.resolve_stall(self)
		elif stuck > 2.2:
			decision = 0.0
			strafe *= -1.0
	else:
		stuck = maxf(0.0, stuck - 1.2)
	last_check = position

func _pursuit(delta: float, distance: float, toward: Vector3) -> Vector3:
	decision -= delta
	if decision <= 0.0:
		decision = (0.27 if distance < 20.0 else 0.47) + (serial % 4) * 0.043
		if not training:
			var nearest: CharacterBody3D = session.nearest_pilot(position)
			if is_instance_valid(nearest):
				target = nearest
		if kind == "medic" and not training and repairs_left > 0:
			patient = session.find_patient(self)
			if is_instance_valid(patient):
				_begin_tell()
				session.effects.beam(center(), patient.center(), spec.tint, 0.045, timer)
				return Vector3.ZERO
		var clear: bool = session.ray(center(), target.head.global_position, 1).is_empty()
		var elevation: float = absf(target.head.global_position.y - center().y)
		var withdraw := kind in ["sentinel", "medic", "artillery"] and distance < 5.8
		if not training and not withdraw and distance < spec.range and (kind != "scout" or elevation < 1.65) and clear:
			_begin_tell()
			return Vector3.ZERO
		var goal: Vector3 = target.global_position
		var tangent := Vector3(-toward.z, 0, toward.x)
		if training:
			var step := sin(age * 0.72 + serial * 0.5) * 2.8
			goal = patrol_origin + Vector3(step, 0, cos(age * 0.6 + serial) * 0.76)
		elif withdraw and clear:
			goal = global_position - toward * 4.0 + tangent * 2.8 * strafe
			if not _can_route(goal):
				_begin_tell()
				return Vector3.ZERO
		elif kind in ["scout", "specter", "skimmer"] and distance < 13.0 and clear:
			var flank := goal + tangent * (3.5 if kind in ["specter", "skimmer"] else 1.4) * strafe
			if _can_route(flank):
				goal = flank
		path = session.arena.routes.find(global_position, goal)
	while not path.is_empty() and Vector2(path[0].x - position.x, path[0].z - position.z).length() < 0.40:
		path.remove_at(0)
	if path.is_empty():
		return Vector3.ZERO
	var step := path[0] - global_position
	step.y = 0.0
	return step.normalized() * (spec.speed as float)

func _can_route(to: Vector3) -> bool:
	var here := Vector2(global_position.x, global_position.z)
	var there := Vector2(to.x, to.z)
	return session.arena.routes.grid.region.has_point(Vector2i((there / 1.5).round())) \
		and session.arena.routes.clear_segment(here, there)

func _begin_tell() -> void:
	state = State.TELL
	attack_number += 1
	timer = spec.tell * tuning.tempo
	aim_at = target.head.global_position - Vector3.UP * 0.21
	wave_attack = kind in ["disruptor", "artillery"] or (major() and (phase >= 2 or kind == "architect") and attack_number % 2 == 0)
	if wave_attack:
		var floor_at: Vector3 = target.global_position
		var support: Dictionary = session.ray(floor_at + Vector3.UP * 0.15, floor_at - Vector3.UP * 4.0, 1)
		if not support.is_empty():
			floor_at = support.position
		var radius := 3.3 if major() else (2.3 if kind == "disruptor" else 2.9)
		var strength: float = spec.damage * tuning.power * (1.21 if major() else 1.0)
		session.make_hazard(floor_at + Vector3.UP * 0.046, radius, timer, strength, self, kind == "disruptor")
		if kind == "architect" and phase >= 2:
			var flank := global_basis.x * (3.0 * strafe)
			session.make_hazard(floor_at + flank + Vector3.UP * 0.05, 2.45, timer + 0.35, strength, self)
			strafe *= -1.0
	session.telegraph(self)

func attack() -> void:
	if training:
		return
	if kind == "medic" and is_instance_valid(patient) and patient.alive and repairs_left > 0:
		if center().distance_to(patient.center()) < 12.0 and session.ray(center(), patient.center(), 1).is_empty():
			patient.health = minf(patient.maximum, patient.health + 37.0)
			repairs_left -= 1
			session.effects.beam(center(), patient.center(), spec.tint, 0.13, 0.31)
			session.sound("repair", patient.center())
		patient = null
		return
	if kind == "scout":
		var distance: float = center().distance_to(target.head.global_position)
		session.effects.sparks(center(), spec.tint, 12, 2.0)
		session.sound("slash", center())
		if distance < 3.05 and session.ray(center(), target.head.global_position, 1).is_empty():
			target.take_damage(spec.damage * tuning.power, global_position)
		return
	if wave_attack:
		return
	var start := center() + gaze * 0.45
	var direction := (aim_at - start).normalized()
	var angles := [0.0]
	var speed := 22.0
	match kind:
		"specter":
			speed = 27.0
			strafe *= -1.0
			_dodge()
		"bulwark":
			speed = 17.0
			angles = [-0.14, 0.0, 0.14]
		"elite":
			speed = 19.0
			angles = [-0.28, -0.14, 0.0, 0.14, 0.28]
		"skimmer":
			speed = 24.0
			strafe *= -1.0
			_dodge()
		"colossus":
			speed = 15.0 + phase * 2.0
			angles = [-0.47, -0.30, -0.14, 0.0, 0.14, 0.30, 0.47]
		"architect":
			speed = 25.0
			angles = [-0.22, 0.0, 0.22] if phase < 3 else [-0.33, -0.12, 0.0, 0.12, 0.33]
		"warden":
			speed = 20.0 + phase * 2.0
			angles = [-0.35, -0.23, -0.12, 0.0, 0.12, 0.23, 0.35] if phase == 3 else [-0.22, -0.11, 0.0, 0.11, 0.22]
	for angle in angles:
		session.launch(start, direction.rotated(Vector3.UP, angle), speed, spec.damage * tuning.power,
			spec.tint, false)
	session.sound("heavy" if (major() or kind in ["elite", "bulwark"]) else "enemy", start)

func _dodge() -> void:
	var tangent := global_basis.x * strafe
	if not _can_route(global_position + tangent * 2.8):
		tangent *= -1
	if _can_route(global_position + tangent * 2.8):
		dodge_direction = tangent
		dodge_left = 0.23

func take_hit(amount: float, at: Vector3, direction: Vector3) -> float:
	if not alive or replica:
		return 0.0
	hit_flash = 1.0
	if kind in ["bulwark", "elite", "warden", "colossus"]:
		var front := gaze.dot(-direction)
		var guarding := state != State.RECOVER and (not major() or phase < (3 if kind == "colossus" else 2))
		if guarding and front > 0.53:
			amount *= 0.48 if kind != "warden" else 0.70
			session.effects.sparks(at, Color("#70cbff"), 10, 1.7)
			session.sound("armor", at)
		elif absf(front) < 0.58 or state == State.RECOVER:
			amount *= 1.40 if kind == "warden" else 1.55
			session.effects.sparks(at, Color("#ffe4a2"), 9, 2.7)
	if kind == "specter" and state == State.CHASE and dodge_left <= 0.0:
		_dodge()
	health = maxf(0.0, health - amount)
	if major() and health > 0.0:
		var next := 3 if health < maximum * 0.33 else (2 if health < maximum * 0.68 else 1)
		if next != phase:
			phase = next
			session.effects.sparks(center(), spec.tint, 36, 4.6)
			session.sound("phase", center())
	if health == 0.0:
		alive = false
		state = State.DEAD
		eliminated.emit(self, spec.points)
		queue_free()
	return amount
