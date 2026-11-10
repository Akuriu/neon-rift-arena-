extends Control

signal pause_requested
signal selected(id: String)
signal moved(id: String, x: float, y: float)

const Layout := preload("res://ui/mobile/layout.gd")
const Palette := preload("res://ui/skin.gd")
const AXES := ["left", "right", "forward", "back"]

var pilot: CharacterBody3D
var stage: Node3D
var preview := false
var fingers := {}
var actions := {}
var analog := Vector2.ZERO
var joystick_at := Vector2.ZERO
var active_edit := "stick"
var dragging := false
var redraw_left := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if preview else Control.MOUSE_FILTER_IGNORE
	Prefs.changed.connect(_prefs_changed)

func _prefs_changed(key: String) -> void:
	if key == "all" or key.begins_with("touch"):
		if not preview:
			release_all()
		queue_redraw()

func _process(delta: float) -> void:
	if preview:
		return
	if not is_visible_in_tree() or not is_instance_valid(pilot) or not pilot.alive or pilot.input_blocked:
		if not fingers.is_empty():
			release_all()
		return
	if not Prefs.values.touch_compact:
		return
	redraw_left -= delta
	if redraw_left <= 0.0:
		redraw_left = 0.15
		queue_redraw()

func _exit_tree() -> void:
	if not preview:
		release_all()

func release_all() -> void:
	for action in actions:
		Input.action_release(action)
	actions.clear()
	fingers.clear()
	analog = Vector2.ZERO
	queue_redraw()

func _radius(id: String) -> float:
	return Layout.CONTROLS[id][2] * Prefs.touch_layout[id].size * minf(size.x / 1280.0, size.y / 720.0)

func _center(id: String) -> Vector2:
	var entry: Dictionary = Prefs.touch_layout[id]
	var x: float = 1.0 - entry.x if Prefs.values.touch_left else entry.x
	var radius := _radius(id)
	return Vector2(clampf(x * size.x, radius, size.x - radius),
		clampf(entry.y * size.y, radius, size.y - radius))

func _available(id: String) -> bool:
	if preview or not Prefs.values.touch_compact:
		return true
	match id:
		"zoom":
			return is_instance_valid(pilot) and pilot.arsenal.scope > 0.13 and pilot.arsenal.spec().has("zoom")
		"interact":
			return is_instance_valid(stage) and not stage.pickup_hint.is_empty()
	return true

func _hit(at: Vector2) -> String:
	var hit := ""
	var best := 1.0
	for id in Layout.CONTROLS:
		if not _available(id):
			continue
		var distance := at.distance_to(_center(id)) / maxf(1.0, _radius(id))
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
			_end(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and fingers.has(event.index):
		var finger: String = fingers[event.index]
		if finger == "stick":
			_move(get_global_transform_with_canvas().affine_inverse() * event.position)
		elif finger == "look" and pilot.alive:
			var extent := Vector2(DisplayServer.window_get_size())
			var density := 720.0 / maxf(540.0, minf(extent.x, extent.y))
			pilot.look_input(event.screen_relative * density,
				Vector2(Prefs.values.touch_x, Prefs.values.touch_y), true)
		get_viewport().set_input_as_handled()

func _begin(index: int, at: Vector2) -> void:
	if fingers.has(index):
		_end(index)
	var id := _hit(at)
	if id == "pause":
		pause_requested.emit()
		return
	if not pilot.alive:
		return
	var move_side: bool = at.x >= size.x * 0.5 if Prefs.values.touch_left else at.x < size.x * 0.5
	if id.is_empty() and Prefs.values.touch_float and move_side and at.y > size.y * 0.48:
		id = "stick"
	if id.is_empty():
		id = "look"
	if id in fingers.values():
		return
	fingers[index] = id
	match id:
		"stick":
			joystick_at = at if Prefs.values.touch_float else _center(id)
			_move(at)
		"look":
			pass
		"next":
			var gun = pilot.arsenal
			gun.select_slot(posmod(gun.rack.find(gun.active) + 1, gun.rack.size()))
		"zoom":
			if pilot.arsenal.aiming():
				pilot.arsenal.wheel(-1 if pilot.arsenal.aim_step > 0 else 1)
		_:
			_strength(id, 1.0)
	if OS.has_feature("android") and Prefs.values.touch_haptic and id in ["jump", "gadget", "next"]:
		Input.vibrate_handheld(24)
	queue_redraw()

func _end(index: int) -> void:
	if not fingers.has(index):
		return
	var id: String = fingers[index]
	fingers.erase(index)
	if id == "stick":
		analog = Vector2.ZERO
		for action in AXES:
			_strength(action, 0.0)
	elif actions.has(id):
		_strength(id, 0.0)
	queue_redraw()

func _move(at: Vector2) -> void:
	analog = ((at - joystick_at) / maxf(1.0, _radius("stick"))).limit_length(1.0)
	var dead: float = Prefs.values.touch_dead
	var scaled := analog.normalized() * clampf((analog.length() - dead) / (1.0 - dead), 0.0, 1.0)
	_strength("left", maxf(0.0, -scaled.x))
	_strength("right", maxf(0.0, scaled.x))
	_strength("forward", maxf(0.0, -scaled.y))
	_strength("back", maxf(0.0, scaled.y))
	queue_redraw()

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
		moved.emit(active_edit, 1.0 - point.x if Prefs.values.touch_left else point.x, point.y)
		accept_event()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	if preview:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#17252a"))
		draw_line(Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, size.y), Color("#536168"), 1.0)
	var held: Array = fingers.values()
	for id in Layout.CONTROLS:
		if not _available(id):
			continue
		var opacity: float = Prefs.touch_layout[id].opacity
		var ink := Color(Art.hud_color(), opacity)
		var hot: bool = id in held or (preview and id == active_edit)
		var at := joystick_at if id == "stick" and id in held else _center(id)
		var radius := _radius(id)
		draw_circle(at, radius, Color(0.035, 0.068, 0.09, (0.74 if hot else 0.39) * opacity), true, -1, true)
		draw_arc(at, radius, 0.0, TAU, 32, ink, 2.2 if hot else 1.4, true)
		if id == "stick":
			draw_circle(at + analog * radius * 0.61, radius * 0.32, Color(ink, opacity * 0.65), true, -1, true)
		else:
			var font := Palette.BOLD
			var text: String = Layout.CONTROLS[id][4]
			var px := maxi(8, roundi(radius * 0.46))
			var line := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
			draw_string(font, at + Vector2(-line.x * 0.5, px * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(Palette.TEXT, opacity))
