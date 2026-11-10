extends Node

const Arms := preload("res://game/weapons/catalog.gd")
const Models := preload("res://game/weapon_models.gd")
const SPREAD := [Vector2.ZERO, Vector2(-0.094, 0), Vector2(0.094, 0),
	Vector2(-0.046, 0.057), Vector2(0.046, 0.057), Vector2(-0.046, -0.057), Vector2(0.046, -0.057)]

var pilot: CharacterBody3D
var active := 0
var rack: Array[int] = []
var magazines: Array[int] = []
var reserves: Array[int] = []
var heat: Array[float] = []
var capacity_bonus := 0
var reserve_bonus := 0
var cooldown := 0.0
var reload_left := 0.0
var cycle_length := 1.0
var swap_left := 0.0
var shot_kick := 0.0
var charge := 0.0
var reload_boost := 1.0
var damage_boost := 1.0
var view: Node3D
var core: MeshInstance3D
var held := false
var burst_left := 0
var burst_timer := 0.0
var clock := 0.0
var aim_step := 0
var scope := 0.0
var inspecting := 0.0
var last_audio := -1.0

func _ready() -> void:
	var loadout: Array = pilot.gear.get("slots", Arms.DEFAULT_LOADOUT)
	for id in loadout:
		var index := Arms.index_of(id)
		if index >= 0 and index not in rack:
			rack.append(index)
	if rack.is_empty():
		rack.assign([0, 1, 2, 3])
	if pilot.session.mode == "training":
		for index in Arms.WEAPONS.size():
			if index not in rack:
				rack.append(index)
	if pilot.gear.get("module") == "mod_rack":
		capacity_bonus = 1
	if pilot.gear.get("module") == "mod_cycle":
		reload_boost += 0.12
	reserve_bonus = 2 if pilot.gear.get("reserve", false) else 0
	active = rack[0]
	var trial_weapon := Arms.index_of(pilot.session.get("test_weapon"))
	if pilot.session.mode == "training" and trial_weapon >= 0:
		active = trial_weapon
	for index in Arms.WEAPONS.size():
		magazines.append(capacity(index))
		reserves.append(capacity(index) * (5 + reserve_bonus))
		heat.append(0.0)
	if pilot.local_view:
		view = Node3D.new()
		view.position = Vector3(0.28, -0.25, -0.52)
		view.scale = Vector3.ONE * 0.92
		pilot.head.add_child(view)
		make_view()

func spec() -> Dictionary:
	return Arms.WEAPONS[active]

func capacity(index := -1) -> int:
	return int(Arms.WEAPONS[active if index < 0 else index].mag) + capacity_bonus

func rounds() -> int:
	return magazines[active]

func reserve() -> int:
	return -1 if pilot.session.mode in ["training", "trial"] else reserves[active]

func select_slot(index: int) -> void:
	if index >= 0 and index < rack.size():
		select(rack[index])

func wheel(direction: int) -> void:
	if aiming():
		if spec().mode == "rail":
			aim_step = 1 if direction > 0 else 0
		return
	select_slot(posmod(rack.find(active) + direction, rack.size()))

func select(index: int) -> void:
	if not rack.has(index) or active == index:
		return
	active = index
	reload_left = 0.0
	charge = 0.0
	burst_left = 0
	aim_step = 0
	scope = 0.0
	inspecting = 0.0
	held = pilot.down("fire")
	swap_left = 0.29
	cooldown = maxf(cooldown, 0.23)
	make_view()
	pilot.session.sound("switch", Vector3.INF if pilot.local_view else pilot.global_position)

func make_view() -> void:
	if not is_instance_valid(view):
		return
	for child in view.get_children():
		view.remove_child(child)
		child.queue_free()
	core = Models.make(view, active, spec().tint, pilot.gear.get("skin", ""))

func aiming() -> bool:
	return spec().has("zoom") and pilot.down("ads") and reload_left <= 0.0 and swap_left <= 0.0

func magnification() -> float:
	if not aiming():
		return 1.0
	var zoom: Array = spec().zoom
	if spec().mode == "lance":
		return lerpf(zoom[0], zoom[1], charge)
	return zoom[aim_step]

func aim_fov(normal: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(normal) * 0.5) / magnification()))

func cycle() -> void:
	if reload_left > 0.0 or (reserve() == 0 and heat[active] < 0.12):
		return
	if rounds() == capacity() and heat[active] < 0.12:
		return
	cycle_length = spec().reload / reload_boost
	reload_left = cycle_length
	charge = 0.0
	burst_left = 0
	pilot.session.sound("reload", Vector3.INF if pilot.local_view else pilot.global_position)

func refill(amount: int) -> void:
	magazines[active] = mini(capacity(), magazines[active] + amount)
	reserves[active] = mini(capacity() * (6 + reserve_bonus), reserves[active] + amount)
	heat[active] = maxf(0.0, heat[active] - 0.10 * amount)

func expand_magazines() -> void:
	capacity_bonus += 1
	for index in rack:
		magazines[index] = mini(capacity(index), magazines[index] + 1)

func reset_supply() -> void:
	for index in Arms.WEAPONS.size():
		magazines[index] = capacity(index)
		reserves[index] = capacity(index) * (5 + reserve_bonus)
		heat[index] = 0.0
	reload_left = 0.0
	cancel_trigger()

func supply_at_intermission() -> void:
	for index in rack:
		var limit := capacity(index)
		magazines[index] = limit
		reserves[index] = mini(limit * (6 + reserve_bonus), maxi(limit, reserves[index] + limit / 2))
		heat[index] = 0.0
	reload_left = 0.0
	cancel_trigger()

func cancel_trigger() -> void:
	charge = 0.0
	burst_left = 0
	scope = 0.0
	inspecting = 0.0
	held = pilot.down("fire")

func tick(delta: float) -> void:
	for index in mini(rack.size(), 4):
		if pilot.just("slot_%d" % (index + 1)):
			select_slot(index)
	for index in rack:
		heat[index] = maxf(0.0, heat[index] - delta * (0.29 * reload_boost))
	cooldown = maxf(0.0, cooldown - delta)
	swap_left = maxf(0.0, swap_left - delta)
	inspecting = maxf(0.0, inspecting - delta)
	var trigger: bool = pilot.down("fire")
	var pressed := trigger and not held
	var released := not trigger and held
	held = trigger
	if pilot.just("inspect") and not trigger and not aiming():
		inspecting = 1.0
	if trigger:
		inspecting = 0.0
	if pilot.just("reload"):
		cycle()
	if reload_left > 0.0:
		reload_left = maxf(0.0, reload_left - delta)
		if reload_left <= 0.0:
			var refill_count := capacity() - rounds()
			if reserve() >= 0:
				refill_count = mini(refill_count, reserves[active])
				reserves[active] -= refill_count
			magazines[active] += refill_count
			heat[active] = 0.0
			pilot.session.sound("charged", Vector3.INF if pilot.local_view else pilot.global_position)
		return
	if rounds() == 0:
		cycle()
		return
	if spec().mode == "burst" and burst_left > 0:
		burst_timer -= delta
		if burst_timer <= 0.0:
			burst_left -= 1
			burst_timer = 0.077
			fire_ray(false)
		return
	if cooldown > 0.0:
		return
	match spec().mode:
		"auto", "stream":
			if trigger:
				fire_ray(true)
		"spread", "rail":
			if pressed:
				fire_ray(true)
		"burst":
			if pressed:
				burst_left = mini(2, rounds() - 1)
				burst_timer = 0.077
				fire_ray(true)
		"nova", "lance":
			if trigger:
				if charge == 0.0:
					pilot.session.sound("charge_up", Vector3.INF if pilot.local_view else pilot.global_position)
				charge = minf(1.0, charge + delta / (1.10 if spec().mode == "lance" else 0.95))
			elif released and charge > 0.0:
				if spec().mode == "nova":
					fire_orb(true)
				else:
					var strength := lerpf(0.35, 1.0, charge)
					charge = 0.0
					fire_ray(true, strength)
		"mortar":
			if pressed:
				fire_orb(false)

func _muzzle() -> Vector3:
	if is_instance_valid(core):
		return core.global_position
	return pilot.head.global_position + pilot.global_basis.x * 0.21 - pilot.head.global_basis.z * 0.48 - Vector3.UP * 0.20

func fire_ray(reset: bool, strength := 1.0) -> void:
	var data := spec()
	_consume(data, reset)
	var source: Vector3 = pilot.head.global_position
	var axes: Basis = pilot.head.global_basis
	var directions: Array[Vector3] = []
	if data.mode == "spread":
		for spread in SPREAD:
			directions.append((-axes.z + axes.x * spread.x + axes.y * spread.y).normalized())
	elif data.mode == "rail" and not aiming():
		var drift := sin(float(pilot.session.shots) * 8.7) * 0.019
		directions.append((-axes.z + axes.x * drift + axes.y * drift * 0.47).normalized())
	else:
		directions.append(-axes.z)
	pilot.session.fire_rays(source, directions, data, _muzzle(), damage_boost * strength, pilot)
	_check_supply()

func fire_orb(nova: bool) -> void:
	var data := spec()
	var strength := clampf(charge, 0.0, 1.0)
	var source: Vector3 = pilot.head.global_position
	var direction: Vector3 = -pilot.head.global_basis.z
	charge = 0.0
	_consume(data, true)
	pilot.session.record_shot(data.id, pilot)
	if nova:
		pilot.session.launch(source, direction, lerpf(25.0, 34.0, strength),
			data.damage * lerpf(0.42, 1.0, strength) * damage_boost, data.tint, true,
			lerpf(1.35, 3.25, strength), 0.0, pilot, data.id)
	else:
		pilot.session.launch(source, (direction + Vector3.UP * 0.24).normalized(), 19.0,
			data.damage * damage_boost, data.tint, true, 2.65, 12.0, pilot, data.id)
	if Prefs.values.flashes > 0.05:
		pilot.session.effects.sparks(_muzzle(), data.tint, 8, 2.4)
	_check_supply()

func _consume(data: Dictionary, reset: bool) -> void:
	magazines[active] -= 1
	heat[active] = minf(1.0, heat[active] + data.heat)
	if reset:
		cooldown = data.cadence
		shot_kick = 1.0
		if data.mode != "stream" or clock - last_audio > 0.094:
			pilot.session.sound(data.sound, Vector3.INF if pilot.local_view else pilot.global_position)
			if is_instance_valid(pilot.session.net) and pilot.session.net.hosting:
				pilot.session.net.shot(pilot.peer_id, data.sound, pilot.global_position)
			if is_instance_valid(pilot.avatar):
				pilot.avatar.kick()
			last_audio = clock

func _check_supply() -> void:
	if heat[active] >= 0.97:
		cycle()
	elif rounds() == 2:
		pilot.session.sound("low", Vector3.INF if pilot.local_view else pilot.global_position)

func pose(delta: float, motion: float, running: bool, wall_pull: float) -> void:
	clock += delta
	scope = move_toward(scope, 1.0 if aiming() else 0.0, delta * 8.0)
	shot_kick = move_toward(shot_kick, 0.0, delta * 8.5)
	if not is_instance_valid(view):
		return
	var change := swap_left / 0.29
	var dip := sin(PI * reload_left / cycle_length) if reload_left > 0.0 else 0.0
	var kick: float = shot_kick if Prefs.values.recoil else shot_kick * 0.3
	var sway := sin(clock * 12.0) * motion * 0.015
	var target := Vector3(0.274 + sway, -0.248 - dip * 0.16 - change * 0.22,
		-0.52 + kick * 0.072 + wall_pull * 0.12)
	target.y += sin(clock * 2.4) * 0.0025
	target += Vector3(0.045, -0.08, 0.025) if running else Vector3.ZERO
	target = target.lerp(Vector3(0.02, -0.30, -0.50), scope)
	view.position = view.position.lerp(target, 1.0 - exp(-23.0 * delta))
	view.visible = scope < 0.88
	core.visible = (shot_kick > 0.54 or charge > 0.2) and Prefs.values.flashes > 0.05
	core.scale = Vector3.ONE * (0.32 + maxf(shot_kick, charge) * Prefs.values.flashes)
	var glance := sin(PI * inspecting) * 0.55
	view.rotation = Vector3(-kick * 0.062 - dip * 0.68 - wall_pull * 0.72, -0.08 + glance,
		-dip * 0.34 - change * 0.25 - (0.22 if running else 0.0) + glance * 0.4)
