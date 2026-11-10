extends CharacterBody3D

signal eliminated
const Arsenal := preload("res://game/arsenal.gd")
const Avatar := preload("res://network/avatar.gd")
const WALK := 6.4
const RUN := 10.3
const STAND := 1.78
const LOW := 1.11
const INPUT_BITS := {"fire": 1, "jump": 2, "sprint": 4, "crouch": 8, "ads": 16,
	"reload": 32, "interact": 64, "gadget": 128, "inspect": 256}

var head: Camera3D
var collider: CollisionShape3D
var arsenal: Arsenal
var session: Node3D
var health := 100.0
var shield := 55.0
var shield_max := 55.0
var speed_bonus := 1.0
var damage_lock := 0.8
var shield_wait := 0.0
var shield_flash := 0.0
var hull_flash := 0.0
var alive := true
var sprinting := false
var low_profile := false
var crouch_was_pressed := false
var slide := 0.0
var slide_dir := Vector3.ZERO
var height := STAND
var jump_buffer := 0.0
var floor_grace := 0.0
var walk_phase := 0.0
var wall_pull := 0.0
var round_lock := false
var input_blocked := false
var gear: Dictionary = {}
var local_view := true
var remote_input := false
var net_move := Vector2.ZERO
var net_buttons := 0
var net_edges := 0
var peer_id := 1
var seat := 0
var gadget_left := 0.0
var dash_left := 0.0
var dash_dir := Vector3.ZERO
var slowed := 0.0
var damage_from := Vector3.INF
var pilot_name := "Pilote"
var avatar: Node3D
var replica := false
var replica_pos := Vector3.ZERO
var replica_yaw := 0.0
var replica_pitch := 0.0
var replica_speed := 0.0
var modules: Array[int] = [0, 0, 0, 0, 0, 0]
var module_selected := false
var stats := {"shots": 0, "hits": 0, "support": 0.0, "mastery": {}}

func _ready() -> void:
	collision_layer = 0 if replica else 2
	collision_mask = 0 if replica else 1 | 4
	floor_snap_length = 0.33
	floor_max_angle = deg_to_rad(47)
	floor_constant_speed = true
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = STAND
	collider = CollisionShape3D.new()
	collider.position.y = STAND * 0.5
	collider.shape = capsule
	add_child(collider)
	head = Camera3D.new()
	head.current = local_view
	head.near = 0.05
	head.far = 135.0 if Prefs.values.quality == 3 else 170.0
	head.position.y = 1.49
	head.fov = Prefs.values.fov
	add_child(head)
	arsenal = Arsenal.new()
	arsenal.pilot = self
	add_child(arsenal)
	replica_pos = position
	if not local_view:
		avatar = Avatar.new()
		avatar.tint = Avatar.COLORS[seat]
		avatar.skin = gear.get("skin", "")
		avatar.pilot_name = pilot_name
		add_child(avatar)

func _unhandled_input(event: InputEvent) -> void:
	if not alive or not local_view or input_blocked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var factor: float = deg_to_rad(Prefs.values.sensitivity * (Prefs.values.ads_sensitivity if arsenal.aiming() else 1.0))
		rotate_y(-event.screen_relative.x * factor)
		var sign_y := 1.0 if Prefs.values.invert_y else -1.0
		head.rotation.x = clampf(head.rotation.x + event.screen_relative.y * factor * sign_y, -1.51, 1.51)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			arsenal.wheel(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			arsenal.wheel(-1)

func _physics_process(delta: float) -> void:
	if replica:
		_client_step(delta)
		return
	if not alive:
		return
	gadget_left = maxf(0.0, gadget_left - delta)
	slowed = maxf(0.0, slowed - delta)
	if not round_lock and just("gadget"):
		use_gadget()
	move_pilot(delta)
	damage_lock = maxf(damage_lock - delta, 0.0)
	shield_wait = maxf(0.0, shield_wait - delta)
	shield_flash = move_toward(shield_flash, 0.0, delta * 3.6)
	hull_flash = move_toward(hull_flash, 0.0, delta * 2.8)
	if shield_wait == 0.0:
		shield = minf(shield_max, shield + 11.0 * delta)
	if not round_lock:
		arsenal.tick(delta)
	if just("interact"):
		session.interact(self)
	net_edges = 0
	if is_instance_valid(avatar):
		avatar.animate(delta, Vector2(velocity.x, velocity.z).length(), head.rotation.x)

func _client_step(delta: float) -> void:
	position = position.lerp(replica_pos, 1.0 - exp(-20.0 * delta))
	if is_instance_valid(avatar):
		avatar.visible = alive
		avatar.animate(delta, replica_speed, replica_pitch)
	if not local_view:
		rotation.y = lerp_angle(rotation.y, replica_yaw, 1.0 - exp(-18.0 * delta))
		head.rotation.x = lerpf(head.rotation.x, replica_pitch, 1.0 - exp(-18.0 * delta))
		return
	shield_flash = move_toward(shield_flash, 0.0, delta * 3.6)
	hull_flash = move_toward(hull_flash, 0.0, delta * 2.8)
	if not alive:
		return
	for index in 4:
		if just("slot_%d" % (index + 1)):
			arsenal.select_slot(index)
	arsenal.swap_left = maxf(0.0, arsenal.swap_left - delta)
	head.position.y = lerpf(head.position.y, height - 0.16, 1.0 - exp(-22.0 * delta))
	head.fov = lerpf(head.fov, arsenal.aim_fov(Prefs.values.fov), 1.0 - exp(-12.0 * delta))
	arsenal.pose(delta, clampf(replica_speed / RUN, 0.0, 1.0), replica_speed > WALK + 0.5, 0.0)

func move_pilot(delta: float) -> void:
	var grounded := is_on_floor()
	var steer := steering()
	var heading := (basis * Vector3(steer.x, 0, steer.y)).normalized()
	var wants_low := down("crouch")
	var crouch_started := wants_low and not crouch_was_pressed
	crouch_was_pressed = wants_low
	var horizontal_speed := Vector3(velocity.x, 0, velocity.z)
	if grounded and sprinting and horizontal_speed.length() > WALK * 1.03 and crouch_started:
		slide = 0.49
		slide_dir = horizontal_speed.normalized()
		session.sound("slide")
	slide = maxf(0.0, slide - delta)
	if not wants_low and slide <= 0.0 and low_profile:
		wants_low = not _can_stand()
	low_profile = wants_low or slide > 0.0
	sprinting = not low_profile and steer.length() > 0.1 and down("sprint")
	var speed := RUN if sprinting else (3.75 if low_profile else WALK)
	var target := heading * speed * speed_bonus * (0.79 if arsenal.aiming() else 1.0)
	target *= 0.64 if slowed > 0.0 else 1.0
	dash_left = maxf(0.0, dash_left - delta)
	if dash_left > 0.0:
		target = dash_dir * 17.8
	if slide > 0.0:
		target = slide_dir * (6.0 + slide * 13.0) * speed_bonus
	var acceleration := (42.0 if heading != Vector3.ZERO else 53.0) if grounded else 16.0
	if slide > 0.0:
		acceleration = 27.0
	if dash_left > 0.0:
		acceleration = 92.0
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	if just("jump"):
		jump_buffer = 0.13
	else:
		jump_buffer = maxf(0.0, jump_buffer - delta)
	floor_grace = 0.11 if grounded else maxf(0.0, floor_grace - delta)
	if floor_grace > 0.0 and jump_buffer > 0.0:
		velocity.y = 6.7
		floor_grace = 0.0
		jump_buffer = 0.0
		slide = 0.0
		session.sound("jump")
	elif not grounded:
		velocity.y -= 22.0 * delta
	height = move_toward(height, LOW if low_profile else STAND, delta * 4.5)
	var capsule := collider.shape as CapsuleShape3D
	capsule.height = height
	collider.position.y = height * 0.5
	move_and_slide()
	if not grounded and is_on_floor():
		session.sound("land")
	var motion := clampf(Vector2(velocity.x, velocity.z).length() / RUN, 0.0, 1.0)
	walk_phase += delta * motion * 16.0
	var bob := sin(walk_phase) * motion * 0.026 if Prefs.values.head_bob and is_on_floor() else 0.0
	head.position.y = lerpf(head.position.y, height - 0.16 + bob, 1.0 - exp(-22.0 * delta))
	var target_fov: float = Prefs.values.fov + (5.0 if sprinting and Prefs.values.sprint_fov else 0.0)
	head.fov = lerpf(head.fov, arsenal.aim_fov(target_fov), 1.0 - exp(-12.0 * delta))
	if local_view:
		var obstruction: Dictionary = session.ray(head.global_position,
			head.global_position - head.global_basis.z * 0.8, 1)
		wall_pull = lerpf(wall_pull, float(not obstruction.is_empty()), 1.0 - exp(-18.0 * delta))
	arsenal.pose(delta, motion, sprinting, wall_pull)

func _can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.372
	shape.height = STAND - 0.08
	query.shape = shape
	query.transform.origin = global_position + Vector3.UP * (STAND * 0.5 + 0.035)
	query.collision_mask = 1 | 4
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func take_damage(amount: float, source := Vector3.INF) -> void:
	if not alive or replica or damage_lock > 0.0 or session.mode == "training":
		return
	damage_lock = 0.16
	damage_from = source
	shield_wait = 4.2
	var absorbed := minf(shield, amount)
	shield -= absorbed
	if absorbed > 0.0:
		shield_flash = 0.9
		session.sound("shield" if shield > 0.0 else "break")
	if amount > absorbed:
		hull_flash = 1.0
		session.sound("hull")
	health = maxf(0.0, health - (amount - absorbed))
	if health <= 0.0:
		alive = false
		collision_layer = 0
		if is_instance_valid(avatar):
			avatar.hide()
		eliminated.emit()

func steering() -> Vector2:
	if input_blocked:
		return Vector2.ZERO
	return net_move if remote_input else Input.get_vector("left", "right", "forward", "back")

func down(action: String) -> bool:
	if input_blocked:
		return false
	return (net_buttons & int(INPUT_BITS.get(action, 0))) != 0 if remote_input else Input.is_action_pressed(action)

func just(action: String) -> bool:
	if input_blocked:
		return false
	return (net_edges & int(INPUT_BITS.get(action, 0))) != 0 if remote_input else Input.is_action_just_pressed(action)

func accept_input(move: Vector2, yaw: float, pitch: float, buttons: int, gun: int) -> void:
	net_move = move.limit_length()
	net_edges |= buttons & ~net_buttons
	net_buttons = buttons
	rotation.y = wrapf(yaw, -PI, PI)
	head.rotation.x = clampf(pitch, -1.51, 1.51)
	arsenal.select(gun)

func use_gadget() -> void:
	if gadget_left > 0.0:
		return
	if gear.get("gadget") == "gd_aegis":
		session.repair_pulse(self)
		gadget_left = 13.0
	else:
		var move := steering()
		var direction := Vector3(move.x, 0, move.y) if move.length_squared() > 0.01 else Vector3.FORWARD
		dash_dir = (basis * direction).normalized()
		dash_left = 0.24
		slide = 0.0
		gadget_left = 7.0
	session.sound("boost", global_position)
