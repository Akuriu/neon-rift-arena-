extends RefCounted

const WALK := 6.4
const RUN := 10.3
const STAND := 1.78
const LOW := 1.11
const SLIDE_TIME := 0.49
const JUMP_BUFFER := 0.13
const COYOTE := 0.11

var clearance := PhysicsShapeQueryParameters3D.new()

func setup(pilot: CharacterBody3D) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.371
	shape.height = STAND - 0.075
	clearance.shape = shape
	clearance.collision_mask = 1 | 4
	clearance.exclude = [pilot.get_rid()]

func step(pilot: CharacterBody3D, delta: float) -> void:
	var grounded := pilot.is_on_floor()
	var steer: Vector2 = pilot.steering()
	var heading: Vector3 = pilot.basis * Vector3(steer.x, 0.0, steer.y)
	var wants_low: bool = pilot.down("crouch")
	var crouch_started: bool = wants_low and not pilot.crouch_was_pressed
	pilot.crouch_was_pressed = wants_low
	var horizontal := Vector3(pilot.velocity.x, 0.0, pilot.velocity.z)
	var may_slide: bool = pilot.sprinting or (pilot.local_view and Prefs.values.auto_slide)
	if grounded and may_slide and crouch_started and horizontal.length_squared() > pow(WALK * 1.03, 2.0):
		pilot.slide = SLIDE_TIME
		pilot.slide_dir = horizontal.normalized()
		pilot.session.sound("slide")
	pilot.slide = maxf(0.0, pilot.slide - delta)
	pilot.dash_left = maxf(0.0, pilot.dash_left - delta)
	if not wants_low and pilot.slide <= 0.0 and pilot.low_profile:
		clearance.transform.origin = pilot.global_position + Vector3.UP * (STAND * 0.5 + 0.04)
		wants_low = not pilot.get_world_3d().direct_space_state.intersect_shape(clearance, 1).is_empty()
	pilot.low_profile = wants_low or pilot.slide > 0.0
	pilot.sprinting = not pilot.low_profile and steer.length_squared() > 0.05 and pilot.down("sprint")
	var speed := RUN if pilot.sprinting else (3.75 if pilot.low_profile else WALK)
	var target: Vector3 = heading * speed * pilot.speed_bonus * (0.79 if pilot.arsenal.aiming() else 1.0)
	target *= 0.64 if pilot.slowed > 0.0 else 1.0
	var acceleration := (52.0 if steer.is_zero_approx() else 41.5) if grounded else 16.0
	if pilot.dash_left > 0.0:
		var tail := clampf(pilot.dash_left / 0.084, 0.0, 1.0)
		target = pilot.dash_dir * lerpf(speed, 17.8, smoothstep(0.0, 1.0, tail))
		acceleration = 92.0
	elif pilot.slide > 0.0:
		target = pilot.slide_dir * lerpf(5.7, 12.4, pilot.slide / SLIDE_TIME) * pilot.speed_bonus
		acceleration = 31.0
	var moved := horizontal.move_toward(target, delta * acceleration)
	pilot.velocity.x = moved.x
	pilot.velocity.z = moved.z
	pilot.jump_buffer = JUMP_BUFFER if pilot.just("jump") else maxf(0.0, pilot.jump_buffer - delta)
	pilot.floor_grace = COYOTE if grounded else maxf(0.0, pilot.floor_grace - delta)
	if pilot.floor_grace > 0.0 and pilot.jump_buffer > 0.0:
		pilot.velocity.y = 6.7
		pilot.floor_grace = 0.0
		pilot.jump_buffer = 0.0
		pilot.slide = 0.0
		pilot.session.sound("jump")
	elif not grounded:
		var gravity := 17.5 if pilot.session.director.current_wave.get("mutation") == "light" else 22.0
		pilot.velocity.y -= gravity * delta
	pilot.height = move_toward(pilot.height, LOW if pilot.low_profile else STAND, delta * 4.5)
	var capsule := pilot.collider.shape as CapsuleShape3D
	if not is_equal_approx(capsule.height, pilot.height):
		capsule.height = pilot.height
		pilot.collider.position.y = pilot.height * 0.5
	var fall: float = -pilot.velocity.y
	var before: Vector3 = pilot.position
	pilot.move_and_slide()
	if pilot.is_on_wall():
		var wall: Vector3 = pilot.get_wall_normal()
		if pilot.dash_left > 0.0 and wall.dot(pilot.dash_dir) < -0.42:
			pilot.dash_left = 0.0
		if pilot.slide > 0.0 and wall.dot(pilot.slide_dir) < -0.55:
			pilot.slide = 0.0
	if pilot.is_on_floor():
		var covered: Vector3 = pilot.position - before
		pilot.walk_phase = fposmod(pilot.walk_phase + Vector2(covered.x, covered.z).length() * 2.55, TAU)
		if not grounded:
			pilot.session.sound("land")
			pilot.landing = clampf(fall * 0.006, 0.0, 0.072)
	pilot.head.position.y = pilot.height - 0.16
	if pilot.local_view:
		var eye: Vector3 = pilot.head.global_position
		var obstruction: Dictionary = pilot.session.ray(eye, eye - pilot.head.global_basis.z * 0.88, 1)
		pilot.wall_target = 0.0 if obstruction.is_empty() else 1.0 - smoothstep(0.15, 0.88, eye.distance_to(obstruction.position))
