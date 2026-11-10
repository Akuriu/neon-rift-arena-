extends Control

signal pause_requested
signal selected(id: String)
signal moved(id: String, x: float, y: float)

const Layout := preload("res://ui/mobile/layout.gd")
const Response := preload("res://ui/mobile/response.gd")
const Palette := preload("res://ui/skin.gd")
const INK := Color("#f1ede3")

var pilot: CharacterBody3D
var stage: Node3D
var preview := false
var fingers := {}
var actions := {}
var analog := Vector2.ZERO
var joystick_at := Vector2.ZERO
var joystick_origin := Vector2.ZERO
var active_edit := "stick"
var dragging := false
var redraw_left := 0.0
var ads_latched := false
var gesture_start := Vector2.ZERO
var gesture_action := ""
var auto_sprinting := false
var sprint_latched := false
var sprint_manual := false
var pulses := {}
var ammo_style := Palette.box(Color("#171a16"), Color("#57594b"), 6)
var preview_image: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if preview else Control.MOUSE_FILTER_IGNORE
	Prefs.changed.connect(_prefs_changed)
	resized.connect(_bounds_changed)
	if is_instance_valid(pilot):
		pilot.eliminated.connect(_on_eliminated)

func _bounds_changed() -> void:
	if not preview:
		release_all()
	queue_redraw()

func _on_eliminated() -> void:
	sprint_latched = false
	sprint_manual = false
	release_all()

func _prefs_changed(key: String) -> void:
	if key == "all" or key.begins_with("touch"):
		if not preview:
			release_all()
		queue_redraw()

func _process(delta: float) -> void:
	if preview:
		return
	if not is_instance_valid(pilot):
		return
	if not pilot.alive:
		if sprint_latched or sprint_manual or not fingers.is_empty() or not actions.is_empty():
			_on_eliminated()
		return
	if not is_visible_in_tree() or pilot.input_blocked:
		if not fingers.is_empty() or not actions.is_empty() or pilot.touch_sprint:
			release_all()
		return
	_sync_sprint()
	redraw_left -= delta
	if redraw_left <= 0.0:
		redraw_left = 0.075
		queue_redraw()

func _physics_process(delta: float) -> void:
	for action in pulses.keys():
		pulses[action] -= delta
		if pulses[action] <= 0.0:
			pulses.erase(action)
			_strength(action, 0.0)

func _exit_tree() -> void:
	if not preview:
		release_all()

func release_all() -> void:
	for action in actions:
		Input.action_release(action)
	actions.clear()
	fingers.clear()
	analog = Vector2.ZERO
	ads_latched = false
	gesture_action = ""
	auto_sprinting = false
	if is_instance_valid(pilot):
		pilot.touch_sprint = false
		pilot.touch_move = Vector2.ZERO
	pulses.clear()
	queue_redraw()

func _sync_sprint() -> void:
	pilot.touch_sprint = sprint_latched or auto_sprinting

func _radius(id: String) -> float:
	return Layout.radius(id, Prefs.active_touch_layout()[id], size)

func _center(id: String) -> Vector2:
	return Layout.center(id, Prefs.active_touch_layout()[id], size, Prefs.left_touch())

func _available(id: String) -> bool:
	if preview:
		return id not in Layout.SECONDARY or not Prefs.compact_touch() or active_edit == id
	if id == "pause":
		return true
	if not is_instance_valid(pilot) or not pilot.alive:
		return false
	match id:
		"crouch", "stats":
			return not Prefs.compact_touch()
		"gadget":
			return not Prefs.compact_touch() and pilot.gadget_left <= 0.0
		"zoom":
			return pilot.arsenal.aiming() and pilot.arsenal.spec().mode == "rail"
		"interact":
			return is_instance_valid(stage) and not stage.pickup_hint.is_empty()
	return true

func _hit(at: Vector2) -> String:
	var hit := ""
	var best := 1.0
	for id in Layout.CONTROLS:
		if not _available(id):
			continue
		var distance := Layout.hit_distance(id, at - _center(id), _radius(id))
		if distance < best:
			best = distance
			hit = id
	return hit

func _input(event: InputEvent) -> void:
	if preview or not is_visible_in_tree() or not is_instance_valid(pilot) or pilot.input_blocked:
		return
	if event is InputEventScreenTouch:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed and not event.canceled:
			_begin(event.index, local)
		else:
			_end(event.index, event.canceled, local)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and fingers.has(event.index):
		var finger: String = fingers[event.index]
		var at: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if finger == "stick":
			_move(at)
		elif finger == "jump" and Prefs.compact_touch():
			_gesture(at)
		elif pilot.alive and (finger == "look" or (finger == "fire" and "look" not in fingers.values())):
			var prefs: Dictionary = Prefs.values
			var extent := Vector2(get_window().size)
			var axes := Vector2(prefs.touch_x, prefs.touch_y)
			var movement := Response.look(event.screen_relative, event.screen_velocity, extent, axes,
				prefs.touch_look_curve, prefs.touch_look_limit)
			pilot.look_input(movement, Vector2.ONE, true)
		get_viewport().set_input_as_handled()

func _begin(index: int, at: Vector2) -> void:
	if fingers.has(index):
		_end(index, true, at)
	if not Rect2(Vector2.ZERO, size).has_point(at):
		return
	var id := _hit(at)
	if id == "pause":
		pause_requested.emit()
		return
	if not pilot.alive:
		return
	var anchor := _center("stick")
	var radius := _radius("stick")
	if id.is_empty() and Prefs.values.touch_float and at.distance_to(anchor) <= radius * 1.7:
		id = "stick"
	if id.is_empty():
		id = "look"
	if id in fingers.values():
		return
	fingers[index] = id
	match id:
		"stick":
			var margin := Vector2.ONE * radius
			joystick_origin = at if Prefs.values.touch_float else anchor
			joystick_at = (anchor + (joystick_origin - anchor).limit_length(radius * 0.72)).clamp(margin, size - margin)
			_move(at)
		"look", "sprint", "ads":
			pass
		"next":
			var gun = pilot.arsenal
			gun.select_slot(posmod(gun.rack.find(gun.active) + 1, gun.rack.size()))
		"zoom":
			pilot.arsenal.wheel(-1 if pilot.arsenal.aim_step > 0 else 1)
		"reload", "interact", "gadget":
			_pulse(id)
		"jump":
			if Prefs.compact_touch():
				gesture_start = at
				gesture_action = ""
			else:
				_strength("jump", 1.0)
		_:
			_strength(id, 1.0)
	if OS.has_feature("android") and Prefs.values.touch_haptic and id in ["jump", "gadget", "next"]:
		Input.vibrate_handheld(24)
	queue_redraw()

func _gesture(at: Vector2) -> void:
	if not gesture_action.is_empty():
		return
	var travel := at - gesture_start
	var threshold := _radius("jump") * 0.76
	if travel.y > threshold and travel.y > absf(travel.x) * 1.12:
		gesture_action = "crouch"
	elif absf(travel.x) > threshold and absf(travel.x) > absf(travel.y) * 1.12:
		gesture_action = "gadget" if pilot.gadget_left <= 0.0 else "cancel"
	elif travel.length() > threshold * 1.6:
		gesture_action = "cancel"
	if gesture_action == "gadget":
		_pulse("gadget")
	elif gesture_action == "crouch":
		_strength("crouch", 1.0)

func _end(index: int, canceled: bool, at: Vector2) -> void:
	if not fingers.has(index):
		return
	var id: String = fingers[index]
	fingers.erase(index)
	if id == "stick":
		analog = Vector2.ZERO
		pilot.touch_move = Vector2.ZERO
		auto_sprinting = false
		_sync_sprint()
	elif id == "jump" and Prefs.compact_touch():
		if gesture_action == "crouch" or (canceled and gesture_action == "gadget"):
			pulses.erase(gesture_action)
			_strength(gesture_action, 0.0)
		elif gesture_action.is_empty() and not canceled:
			_pulse("jump")
		gesture_action = ""
	elif id in ["ads", "sprint"]:
		if not canceled and pilot.alive and Layout.hit_distance(id, at - _center(id), _radius(id)) < 1.2:
			if id == "ads":
				ads_latched = not ads_latched
				_strength("ads", 1.0 if ads_latched else 0.0)
			else:
				sprint_manual = true
				sprint_latched = not sprint_latched
				auto_sprinting = false
				_sync_sprint()
	elif actions.has(id) and (canceled or not pulses.has(id)):
		pulses.erase(id)
		_strength(id, 0.0)
	queue_redraw()

func _move(at: Vector2) -> void:
	var travel := at - joystick_origin
	var radius: float = _radius("stick") * Prefs.values.touch_travel
	analog = (travel / maxf(1.0, radius)).limit_length(1.0)
	var scaled := Response.steering(travel, radius, Prefs.values.touch_dead, Prefs.values.touch_response)
	pilot.touch_move = scaled
	if Prefs.values.touch_auto_sprint and not sprint_manual:
		auto_sprinting = scaled.y < (-0.69 if auto_sprinting else -0.89)
		_sync_sprint()
	queue_redraw()

func _pulse(action: String) -> void:
	_strength(action, 1.0)
	pulses[action] = 0.09

func _strength(id: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(id, strength)
		actions[id] = true
	elif actions.has(id):
		Input.action_release(id)
		actions.erase(id)

func _gui_input(event: InputEvent) -> void:
	if not preview:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var hit := _hit(event.position)
			if not hit.is_empty():
				active_edit = hit
				selected.emit(hit)
				dragging = true
		else:
			dragging = false
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		var point: Vector2 = event.position / size
		moved.emit(active_edit, 1.0 - point.x if Prefs.left_touch() else point.x, point.y)
		accept_event()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if preview:
		_draw_preview()
	var held: Array = fingers.values()
	for id in Layout.CONTROLS:
		if not _available(id):
			continue
		var opacity: float = Prefs.active_touch_layout()[id].opacity
		var latched: bool = (id == "sprint" and (sprint_latched or auto_sprinting)) or (id == "ads" and ads_latched)
		var hot: bool = id in held or latched or pulses.has(id) or (preview and id == active_edit)
		var at := joystick_at if id == "stick" and id in held else _center(id)
		var radius := _radius(id)
		var ink := Color(Palette.AMBER if hot else INK, opacity)
		if id == "reload":
			_ammo(at, radius, ink, opacity)
			continue
		var fill := Color(0.072, 0.081, 0.067, (0.80 if hot else 0.49) * opacity)
		if Prefs.compact_touch() and id not in Layout.PRIMARY and not hot:
			fill.a *= 0.66
		if latched:
			fill = Color(Palette.AMBER, maxf(0.65, opacity))
			ink = Color(Palette.BASE, 0.96)
		draw_circle(at, radius, fill, true, -1, true)
		draw_arc(at, radius, 0.0, TAU, 40, Color(ink, opacity * (0.83 if hot or id == "fire" else 0.55)), 1.65, true)
		if id == "stick":
			draw_circle(at + analog * radius * 0.59, radius * 0.31, Color(ink, opacity * 0.48), true, -1, true)
		else:
			_icon(id, at, radius, ink)

func _draw_preview() -> void:
	var frame := Rect2(Vector2.ZERO, size)
	draw_rect(frame, Color("#292c26"))
	if preview_image != null:
		var image_size := preview_image.get_size()
		var scale_factor := maxf(size.x / image_size.x, size.y / image_size.y)
		var crop := size / scale_factor
		draw_texture_rect_region(preview_image, frame, Rect2((image_size - crop) * 0.5, crop), Color(0.68, 0.68, 0.65))
	var center := size * 0.5
	draw_line(center - Vector2.RIGHT * 9.0, center + Vector2.RIGHT * 9.0, Color(INK, 0.75), 1.6, true)
	draw_line(center - Vector2.DOWN * 9.0, center + Vector2.DOWN * 9.0, Color(INK, 0.75), 1.6, true)
	draw_rect(frame.grow(-2.0), Color(Palette.AMBER, 0.52), false, 2.0)

func _icon(id: String, at: Vector2, radius: float, ink: Color) -> void:
	var step := radius * 0.28
	match id:
		"fire":
			draw_arc(at, step, 0, TAU, 28, ink, 2.25, true)
			draw_circle(at, step * 0.33, ink, true, -1, true)
			for axis in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_line(at + axis * step * 1.25, at + axis * step * 1.67, ink, 2.1, true)
		"ads":
			draw_circle(at, step * 1.28, ink, false, 1.8, true)
			for axis in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_line(at + axis * step * 0.57, at + axis * step * 1.58, ink, 1.7, true)
		"jump":
			draw_polyline(PackedVector2Array([at + Vector2(-step, step * 0.3), at + Vector2(0, -step * 0.7),
				at + Vector2(step, step * 0.3)]), ink, 2.35, true)
			draw_line(at + Vector2(0, -step * 0.65), at + Vector2(0, step * 1.08), ink, 2.2, true)
		"next":
			draw_line(at + Vector2(-step, -step * 0.54), at + Vector2(step, -step * 0.54), ink, 2.0, true)
			draw_line(at + Vector2(step * 0.43, -step * 1.10), at + Vector2(step, -step * 0.54), ink, 2.0, true)
			draw_line(at + Vector2(-step, step * 0.54), at + Vector2(step, step * 0.54), ink, 2.0, true)
			draw_line(at + Vector2(-step * 0.43, step * 1.10), at + Vector2(-step, step * 0.54), ink, 2.0, true)
		"pause":
			for x in [-step * 0.38, step * 0.38]:
				draw_line(at + Vector2(x, -step), at + Vector2(x, step), ink, maxf(2.0, step * 0.29), true)
		"sprint":
			for y in [-step * 0.73, 0.0]:
				var tip := at + Vector2(0, y - step * 0.73)
				draw_polyline(PackedVector2Array([tip + Vector2(-step, step), tip,
					tip + Vector2(step, step)]), ink, 2.0, true)
			_caption(at + Vector2(0, radius * 0.45), "SPRINT", maxi(8, roundi(radius * 0.34)), ink)
		_:
			var label: String = Layout.CONTROLS[id][4]
			if id == "zoom" and not preview:
				label = "×%d" % roundi(pilot.arsenal.magnification())
			_caption(at, label, maxi(9, roundi(radius * 0.40)), ink)

func _ammo(at: Vector2, radius: float, ink: Color, opacity: float) -> void:
	var rect := Rect2(at - Vector2(radius * 1.65, radius * 0.86), Vector2(radius * 3.30, radius * 1.72))
	ammo_style.bg_color = Color(0.077, 0.083, 0.070, opacity * 0.88)
	ammo_style.border_color = Color(ink, opacity * 0.52)
	draw_style_box(ammo_style, rect)
	var value := "24 / 120"
	var name := "AR-24"
	var progress := 0.0
	if not preview:
		var gun = pilot.arsenal
		var reserve: int = gun.reserve()
		value = "%d / %s" % [gun.rounds(), "∞" if reserve < 0 else str(reserve)]
		name = "Recharge" if gun.reload_left > 0.0 else gun.spec().name
		progress = 1.0 - gun.reload_left / maxf(gun.cycle_length, 0.001) if gun.reload_left > 0.0 else 0.0
	_caption(at - Vector2(0, radius * 0.29), value, maxi(9, roundi(radius * 0.63)), ink)
	_caption(at + Vector2(0, radius * 0.39), name, maxi(8, roundi(radius * 0.36)), Color(ink, opacity * 0.74))
	if progress > 0.0:
		draw_rect(Rect2(rect.position + Vector2(4, rect.size.y - 3), Vector2((rect.size.x - 8) * progress, 2)), Palette.AMBER)

func _caption(at: Vector2, value: String, pixels: int, ink: Color) -> void:
	var font := Palette.BOLD
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	draw_string(font, at + Vector2(-width * 0.5, pixels * 0.35), value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, ink)
