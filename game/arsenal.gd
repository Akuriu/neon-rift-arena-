extends Node

const Arms := preload("res://game/weapons/catalog.gd")
const Models := preload("res://game/weapon_models.gd")
const ViewMotion := preload("res://game/weapons/view_animation.gd")
const SLOT_KEYS := ["slot_1", "slot_2", "slot_3", "slot_4"]
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
var core: Node3D
var cell: Node3D
var mechanism: Node3D
var flash: Node3D
var models := {}
var visual_index := -1
var animator := ViewMotion.new()
var pose_clock := 0.0
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
		for index in rack:
			_cache_model(index)
		show_model(active)

func spec() -> Dictionary:
	return Arms.WEAPONS[active]

func assign_stage(index: int) -> void:
	# Match-only equipment never writes the permanent profile/loadout.
	capacity_bonus = 0
	reserve_bonus = 0
	reload_boost = 1.0
	damage_boost = 1.0
	rack.assign([index])
	active = index
	reset_supply()
	aim_step = 0
	swap_left = ViewMotion.SWAP
	cooldown = ViewMotion.SWAP
	if pilot.local_view and visual_index < 0:
		show_model(index)

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
	inspecting = 0.0
	held = pilot.down("fire")
	swap_left = ViewMotion.SWAP
	cooldown = maxf(cooldown, ViewMotion.SWAP)
	pilot.session.sound("switch", Vector3.INF if pilot.local_view else pilot.global_position)

func _cache_model(index: int) -> void:
	var model := Node3D.new()
	model.name = "Weapon_" + Arms.WEAPONS[index].id
	model.scale = Vector3.ONE * 0.92
	pilot.presentation.add_child(model)
	var parts := Models.build(model, index, pilot.gear.get("skin", ""), true)
	model.hide()
	models[index] = [model, parts.muzzle, parts.magazine, parts.bolt, parts.flash]

func show_model(index: int) -> void:
	if is_instance_valid(view):
		view.hide()
	if not models.has(index):
		_cache_model(index)
	var parts: Array = models[index]
	view = parts[0]
	core = parts[1]
	cell = parts[2]
	mechanism = parts[3]
	flash = parts[4]
	flash.hide()
	view.show()
	visual_index = index

func sight_height() -> float:
	return Models.SIGHT_HEIGHTS[visual_index]

func aiming() -> bool:
	return pilot.session.mode != "parkour" and pilot.down("ads") and reload_left <= 0.0 and swap_left <= 0.0

func magnification() -> float:
	if not aiming():
		return 1.0
	var zoom: Array = spec().get("zoom", [1.19])
	if spec().mode == "lance":
		return lerpf(zoom[0], zoom[1], charge)
	return zoom[aim_step]

func aim_fov(normal: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(normal) * 0.5) / magnification()))

func cycle() -> void:
	if swap_left > 0.0 or reload_left > 0.0 or (reserve() == 0 and heat[active] < 0.12):
		return
	if rounds() == capacity() and heat[active] < 0.12:
		return
	cycle_length = spec().reload / reload_boost
	reload_left = cycle_length
	charge = 0.0
	burst_left = 0
	inspecting = 0.0
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
	clock += delta
	for index in mini(rack.size(), 4):
		if pilot.just(SLOT_KEYS[index]):
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
	if swap_left > 0.0:
		return
	if pilot.just("inspect") and not trigger and not aiming() and not pilot.sprinting and reload_left <= 0.0:
		inspecting = ViewMotion.inspection_time(active)
	if trigger or aiming() or pilot.sprinting:
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
	if pilot.session.mode == "parkour":
		view.hide()
		return
	pose_clock = fmod(pose_clock + delta, TAU * 10.0)
	animator.tick(self, delta, motion, running, wall_pull, Prefs.values)
