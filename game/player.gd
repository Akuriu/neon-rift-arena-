extends CharacterBody3D

const Track := preload("res://network/snapshot_track.gd")

signal eliminated
const Arsenal := preload("res://game/arsenal.gd")
const Avatar := preload("res://network/avatar.gd")
const Motion := preload("res://game/player/locomotion.gd")
const CameraRig := preload("res://game/player/camera_rig.gd")
const TouchAim := preload("res://game/player/touch_aim.gd")
const TouchResponse := preload("res://ui/mobile/response.gd")
const WALK := Motion.WALK
const RUN := Motion.RUN
const STAND := Motion.STAND
const LOW := Motion.LOW
const INPUT_BITS := {"fire": 1, "jump": 2, "sprint": 4, "crouch": 8, "ads": 16,
	"reload": 32, "interact": 64, "gadget": 128, "inspect": 256}

var head: Camera3D
var presentation: CameraRig
var locomotion := Motion.new()
var touch_aim := TouchAim.new()
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
var wall_target := 0.0
var landing := 0.0
var sprint_latched := false
var touch_sprint := false
var touch_move := Vector2.ZERO
var previous_walk_phase := 0.0
var crouch_latched := false
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
var arena_slot := 0
var arena_side := 0
var last_attacker: CharacterBody3D
var last_credit_slot := -1
var life_generation := 0
var gadget_left := 0.0
var dash_left := 0.0
var dash_dir := Vector3.ZERO
var slowed := 0.0
var damage_from := Vector3.INF
var pilot_name := "Pilote"
var avatar: Node3D
var replica := false
var replica_pos := Vector3.ZERO
var replica_velocity := Vector3.ZERO
var replica_poses := Track.new()
var replica_flags := 0
var replica_weapon := 0
var replica_reload := 0.0
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
	locomotion.setup(self)
	head = Camera3D.new()
	head.name = "AimReference"
	head.near = 0.05
	head.far = 135.0 if Prefs.values.quality == 3 else 170.0
	head.position.y = STAND - 0.16
	head.fov = Prefs.values.fov
	add_child(head)
	if local_view:
		presentation = CameraRig.new()
		presentation.name = "CameraRig"
		presentation.pilot = self
		add_child(presentation)
		get_global_transform_interpolated()
		reset_physics_interpolation()
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
		look_input(event.screen_relative)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			arsenal.wheel(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			arsenal.wheel(-1)

func look_input(movement: Vector2, scale := Vector2.ONE, tactile := false) -> void:
	if not local_view or not alive or input_blocked:
		return
	var sensitivity: float = TouchResponse.LOOK_DEGREES if tactile else Prefs.values.sensitivity
	var factor: float = deg_to_rad(sensitivity * (Prefs.values.ads_sensitivity if arsenal.aiming() else 1.0))
	if tactile and Prefs.mobile() and Prefs.values.touch_aim_assist:
		factor *= touch_aim.on_drag()
	rotation.y = wrapf(rotation.y - movement.x * scale.x * factor, -PI, PI)
	var inverted: bool = Prefs.values.touch_invert if tactile else Prefs.values.invert_y
	var sign_y := 1.0 if inverted else -1.0
	head.rotation.x = clampf(head.rotation.x + movement.y * scale.y * factor * sign_y, -1.51, 1.51)

func _process(delta: float) -> void:
	if is_instance_valid(presentation):
		presentation.present(delta)

func _physics_process(delta: float) -> void:
	previous_walk_phase = walk_phase
	if local_view and Prefs.mobile():
		touch_aim.update(self, delta)
	if local_view and alive and not input_blocked:
		if Prefs.values.sprint_toggle and Input.is_action_just_pressed("sprint"):
			sprint_latched = not sprint_latched
		if Prefs.values.crouch_toggle and Input.is_action_just_pressed("crouch"):
			crouch_latched = not crouch_latched
	if replica:
		_client_step(delta)
		return
	if not alive:
		return
	gadget_left = maxf(0.0, gadget_left - delta)
	slowed = maxf(0.0, slowed - delta)
	if session.mode != "parkour" and not round_lock and just("gadget"):
		use_gadget()
	move_pilot(delta)
	damage_lock = maxf(damage_lock - delta, 0.0)
	shield_wait = maxf(0.0, shield_wait - delta)
	shield_flash = move_toward(shield_flash, 0.0, delta * 3.6)
	hull_flash = move_toward(hull_flash, 0.0, delta * 2.8)
	if shield_wait == 0.0:
		shield = minf(shield_max, shield + 11.0 * delta)
	if session.mode != "parkour" and not round_lock:
		arsenal.tick(delta)
	if just("interact"):
		session.interact(self)
	net_edges = 0
	if is_instance_valid(avatar):
		avatar.animate(delta, velocity, head.rotation.x, height,
			pose_flags(), arsenal.active, reload_progress())

func _client_step(delta: float) -> void:
	if not local_view:
		var pose := replica_poses.pose(Time.get_ticks_msec() * 0.001)
		if not pose.is_empty():
			var teleport: bool = position.distance_squared_to(pose.at) > Track.DISCONTINUITY_SQUARED
			position = pose.at
			rotation.y = pose.yaw
			head.rotation.x = pose.pitch
			if teleport:
				reset_physics_interpolation()
			if is_instance_valid(avatar):
				avatar.present_alive(alive)
				avatar.animate(delta, pose.velocity, pose.pitch, height, pose.flags, replica_weapon, replica_reload)
		return
	var gap := position.distance_squared_to(replica_pos)
	if gap > Track.DISCONTINUITY_SQUARED:
		position = replica_pos
		reset_physics_interpolation()
	else:
		position = position.lerp(replica_pos, 1.0 - exp(-20.0 * delta))
	var planar := Vector2(replica_velocity.x, replica_velocity.z)
	if (replica_flags & Track.AIR) == 0:
		walk_phase = fposmod(walk_phase + planar.length() * delta * 2.55, TAU)
	shield_flash = move_toward(shield_flash, 0.0, delta * 3.6)
	hull_flash = move_toward(hull_flash, 0.0, delta * 2.8)
	if not alive:
		return
	for index in 4:
		if just("slot_%d" % (index + 1)):
			arsenal.select_slot(index)
	arsenal.swap_left = maxf(0.0, arsenal.swap_left - delta)
	head.position.y = height - 0.16

func pose_flags() -> int:
	return (Track.RUN if sprinting else 0) | (Track.SLIDE if slide > 0.0 else 0) \
		| (Track.DASH if dash_left > 0.0 else 0) | (Track.AIM if arsenal.aiming() else 0) \
		| (Track.AIR if not is_on_floor() and absf(velocity.y) > 0.10 else 0)

func reload_progress() -> float:
	return clampf(arsenal.reload_left / maxf(0.001, arsenal.cycle_length), 0.0, 1.0)

func rendered_step_phase() -> float:
	return lerp_angle(previous_walk_phase, walk_phase, Engine.get_physics_interpolation_fraction())

func move_pilot(delta: float) -> void:
	locomotion.step(self, delta)

func aim_point() -> Vector3:
	return head.global_position - Vector3.UP * 0.21

func respawn(at: Vector3) -> void:
	life_generation += 1
	position = at
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	health = 100.0
	shield = shield_max
	damage_lock = 1.2
	shield_wait = 0.0
	alive = true
	round_lock = false
	collision_layer = 2
	dash_left = 0.0
	slide = 0.0
	last_attacker = null
	last_credit_slot = -1
	arsenal.reset_supply()
	arsenal.animator = Arsenal.ViewMotion.new()
	if is_instance_valid(presentation):
		presentation.resync()
	if is_instance_valid(avatar):
		avatar.present_alive(true)

func take_damage(amount: float, source := Vector3.INF, attacker: CharacterBody3D = null, credit := -1) -> void:
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
		last_attacker = attacker
		last_credit_slot = attacker.arena_slot if is_instance_valid(attacker) else credit
		collision_layer = 0
		arsenal.cancel_trigger()
		if is_instance_valid(avatar):
			avatar.present_alive(false)
		eliminated.emit()

func steering() -> Vector2:
	if input_blocked:
		return Vector2.ZERO
	if remote_input:
		return net_move
	return touch_move if not touch_move.is_zero_approx() else Input.get_vector("left", "right", "forward", "back")

func down(action: String) -> bool:
	if input_blocked:
		return false
	if local_view:
		if action == "sprint":
			if touch_sprint:
				return true
			if Prefs.values.sprint_toggle:
				return sprint_latched
		if action == "crouch" and Prefs.values.crouch_toggle:
			return crouch_latched
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
