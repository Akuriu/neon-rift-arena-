extends CharacterBody3D

const Track := preload("res://network/snapshot_track.gd")

signal eliminated(drone: CharacterBody3D, points: int)

const Catalog := preload("res://game/catalog.gd")
const Models := preload("res://game/robot_models.gd")
const Operator := preload("res://art/operator.gd")

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
var replica_poses := Track.new()
var visual_velocity := Vector3.ZERO
var visual_pitch := 0.0
var visual_flags := 0
var fired := 0
var rotors: Array[Node3D] = []
var arena_slot := -1
var arena_side := 1
var last_attacker: CharacterBody3D
var operator: Operator
var visual_wait := 0.0

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
	if kind == "skimmer":
		lens = Models.drone(hull, rotors)
	elif training:
		lens = Models.target(hull)
	else:
		operator = Operator.new()
		var rig := Node3D.new()
		rig.scale = Vector3(1.40, 1.51, 1.35) if major() else (Vector3(1.24, 1.02, 1.18) if kind in ["bulwark", "elite", "artillery"] else Vector3(1, 0.96, 1))
		hull.add_child(rig)
		var cloth: Color = Color("#747567") if arena_side == 0 else spec.tint
		operator.build(rig, cloth, Color("#a6bac2") if arena_side == 0 else Color("#ac775e"),
			major() or kind in ["bulwark", "elite", "artillery"], kind)
		operator.set_weapon(int({"scout": 2, "sentinel": 0, "bulwark": 1, "specter": 6, "elite": 0,
			"warden": 7, "medic": 2, "disruptor": 6, "artillery": 3, "colossus": 1, "architect": 4}[kind]))
		lens = operator.mark
		operator.animate(0.016, Vector3.ZERO, 0.0, 0.0, 0, 0.0)
	paint = lens.material_override.duplicate()
	lens.material_override = paint
	if arena_slot >= 0 and session.mode != "classic":
		var badge := Label3D.new()
		badge.position.y = 1.8
		badge.font_size = 21
		badge.pixel_size = 0.009
		badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		badge.outline_size = 5
		badge.text = "◇ ALLIÉ" if arena_side == 0 else "△ ADV."
		badge.modulate = Color("#91c8f0") if arena_side == 0 else Color("#e9ad7e")
		add_child(badge)

func center() -> Vector3:
	return global_position + Vector3.UP * (1.53 if major() else 1.02)

func aim_point() -> Vector3:
	return center()

func _physics_process(delta: float) -> void:
	if not alive:
		return
	age += delta
	hit_flash = maxf(0.0, hit_flash - delta * 6.0)
	if replica:
		var pose := replica_poses.pose(Time.get_ticks_msec() * 0.001)
		if not pose.is_empty():
			var teleported := position.distance_squared_to(pose.at) > Track.DISCONTINUITY_SQUARED
			position = pose.at
			rotation.y = pose.yaw
			visual_velocity = pose.velocity
			visual_pitch = pose.pitch
			visual_flags = pose.flags
			if teleported:
				reset_physics_interpolation()
		timer = maxf(0.0, timer - delta)
		_animate(delta)
		return
	if not is_instance_valid(target) or not target.alive:
		target = session.target_for(self)
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
	_animate(delta)

func _animate(delta: float) -> void:
	visual_wait += delta
	if state not in [State.TELL, State.ARRIVAL] and hit_flash == 0.0 and is_instance_valid(session.player):
		var distance: float = position.distance_squared_to(session.player.position)
		if distance > 784.0 and visual_wait < (0.085 if Prefs.values.quality == 3 else 0.055):
			return
	var step := visual_wait
	visual_wait = 0.0
	var time := age + serial * 0.57
	var motion := visual_velocity if replica else velocity
	var local := basis.inverse() * motion
	var telling := state == State.TELL
	var prep := 1.0 - clampf(timer / maxf(0.01, spec.tell * tuning.tempo), 0.0, 1.0) if telling else 0.0
	var weight := 1.0 - exp(-14.0 * step)
	if operator != null:
		var flags := visual_flags if replica else pose_flags()
		var pitch := visual_pitch if replica else aim_pitch()
		operator.animate(step, local, pitch, prep * 0.18, flags, 0.0)
	elif kind == "skimmer":
		hull.position.y = sin(time * 4.3) * 0.055
		hull.rotation.z = lerpf(hull.rotation.z, -local.x * 0.036, weight)
		for i in rotors.size():
			rotors[i].rotate_y(step * (27.0 if i % 2 == 0 else -27.0))
	hull.rotation.x = lerpf(hull.rotation.x, -prep * 0.065 + hit_flash * 0.052, weight)
	var base := Color("#95a9b2") if arena_side == 0 else Color("#a8775d")
	var color := base.lerp(Color("#e6c79a"), maxf(prep * 0.61, hit_flash * 0.45))
	if color != lens_color:
		lens_color = color
		paint.albedo_color = color

func pose_flags() -> int:
	var running := Vector2(velocity.x, velocity.z).length_squared() > 25.0
	return (Track.RUN if running else 0) | (Track.DASH if dodge_left > 0.0 else 0) \
		| (Track.AIM if state == State.TELL else 0)

func aim_pitch() -> float:
	if state != State.TELL:
		return 0.0
	var aim := aim_at - center()
	return clampf(atan2(aim.y, Vector2(aim.x, aim.z).length()), -0.80, 0.80)

func flash_attack() -> void:
	if operator != null:
		operator.kick(kind not in ["scout", "medic"] and not wave_attack and Prefs.values.flashes > 0.15)

func collapse() -> void:
	alive = false
	state = State.DEAD
	collision_layer = 0
	collision_mask = 0
	var shutdown := create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	shutdown.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	shutdown.tween_property(hull, "rotation", Vector3(-PI * 0.48, 0.12, strafe * 0.20), 0.40)
	shutdown.tween_property(hull, "position:y", -0.12, 0.40)
	shutdown.chain().tween_interval(0.27)
	shutdown.tween_callback(queue_free)

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
			var nearest: CharacterBody3D = session.target_for(self)
			if is_instance_valid(nearest):
				target = nearest
		if kind == "medic" and not training and repairs_left > 0:
			patient = session.find_patient(self)
			if is_instance_valid(patient):
				_begin_tell()
				session.effects.beam(center(), patient.center(), spec.tint, 0.045, timer)
				return Vector3.ZERO
		var target_at: Vector3 = target.aim_point()
		var clear: bool = session.ray(center(), target_at, 1).is_empty()
		var elevation: float = absf(target_at.y - center().y)
		var withdraw := kind in ["sentinel", "medic", "artillery"] and distance < 5.8
		if not training and not withdraw and distance < spec.range and (kind != "scout" or elevation < 1.65) and clear:
			_begin_tell()
			return Vector3.ZERO
		var goal: Vector3 = target.global_position
		if is_instance_valid(session.classic) and not clear:
			var objective: Vector3 = session.classic.objective_for(self)
			if objective.is_finite() and position.distance_squared_to(objective) > 4.0:
				goal = objective
		var tangent := Vector3(-toward.z, 0, toward.x)
		if training:
			if session.training_options.targets == "fixed":
				return Vector3.ZERO
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
	aim_at = target.aim_point()
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
	fired += 1
	flash_attack()
	if kind == "medic" and is_instance_valid(patient) and patient.alive and repairs_left > 0:
		if center().distance_to(patient.center()) < 12.0 and session.ray(center(), patient.center(), 1).is_empty():
			patient.health = minf(patient.maximum, patient.health + 37.0)
			repairs_left -= 1
			session.effects.beam(center(), patient.center(), spec.tint, 0.13, 0.31)
			session.sound("repair", patient.center())
		patient = null
		return
	if kind == "scout":
		var at: Vector3 = target.aim_point()
		var distance := center().distance_to(at)
		session.effects.sparks(center(), spec.tint, 12, 2.0)
		session.sound("slash", center())
		if distance < 3.05 and session.ray(center(), at, 1).is_empty() and session.can_damage(self, target):
			if target.has_method("take_damage"):
				target.take_damage(spec.damage * tuning.power, global_position, self)
			else:
				target.take_hit(spec.damage * tuning.power, at, (at - center()).normalized(), self)
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
			spec.tint, false, 0.0, 0.0, self)
	session.sound("heavy" if (major() or kind in ["elite", "bulwark"]) else "enemy", start)

func _dodge() -> void:
	var tangent := global_basis.x * strafe
	if not _can_route(global_position + tangent * 2.8):
		tangent *= -1
	if _can_route(global_position + tangent * 2.8):
		dodge_direction = tangent
		dodge_left = 0.23

func take_hit(amount: float, at: Vector3, direction: Vector3, attacker: CharacterBody3D = null) -> float:
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
		last_attacker = attacker
		collapse()
		eliminated.emit(self, spec.points)
	return amount
