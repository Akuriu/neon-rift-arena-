extends Control

const Models := preload("res://game/weapon_models.gd")
var equipment := 0
var skin := ""
var model: Node3D
var camera: Camera3D
var heading := 1.14
var elevation := 0.0
var zoom := 1.0
var rest := 0.0
var dragging := false
var fingers := {}
var base_camera := Vector3.ONE
var focus_at := Vector3.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	accessibility_name = "Aperçu 3D de l’arme : glisser pour tourner, pincer ou molette pour zoomer"
	var surface := SubViewportContainer.new()
	surface.stretch = true
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	surface.add_child(viewport)
	model = Node3D.new()
	viewport.add_child(model)
	Models.build(model, equipment, skin)
	camera = Camera3D.new()
	camera.fov = 39
	var distance: float = [1.0, 1.12, 0.49, 0.87, 1.15, 1.21, 0.86, 1.05][equipment]
	base_camera = Vector3(0.74, 0.28, 1.03) * distance
	focus_at = Vector3(0, -0.022, -0.075 if equipment != 2 else -0.032)
	viewport.add_child(camera)
	for fill in [false, true]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-20, 150, 0) if fill else Vector3(-44, 27, 0)
		light.light_energy = 0.8 if fill else 1.5
		light.light_color = Color("#cac4ab") if fill else Color.WHITE
		viewport.add_child(light)
	_present()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.double_click:
				reset_view()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom * (1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1), 0.72, 1.6)
		_present()
		rest = 5.0
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		_orbit(event.relative)
		accept_event()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var at: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed and not event.canceled and Rect2(Vector2.ZERO, size).has_point(at):
			fingers[event.index] = at
		elif fingers.has(event.index):
			fingers.erase(event.index)
		else:
			return
		rest = 5.0
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and fingers.has(event.index):
		var at: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if fingers.size() >= 2:
			var points: Array = fingers.values()
			var before: float = points[0].distance_to(points[1])
			fingers[event.index] = at
			points = fingers.values()
			if before > 12.0:
				zoom = clampf(zoom * points[0].distance_to(points[1]) / before, 0.72, 1.6)
			_present()
		else:
			_orbit(at - fingers[event.index])
			fingers[event.index] = at
		get_viewport().set_input_as_handled()

func _orbit(offset: Vector2) -> void:
	heading = wrapf(heading + offset.x * 0.012, -PI, PI)
	elevation = clampf(elevation + offset.y * 0.008, -0.7, 0.55)
	rest = 5.0
	_present()

func _present() -> void:
	model.rotation = Vector3(elevation, heading, 0)
	camera.position = base_camera / zoom
	camera.look_at(focus_at)

func reset_view() -> void:
	heading = 1.14
	elevation = 0.0
	zoom = 1.0
	_present()

func _process(delta: float) -> void:
	rest = maxf(0, rest - delta)
	if Prefs.values.ui_motion and not dragging and fingers.is_empty() and rest == 0:
		heading = wrapf(heading + minf(delta, 0.05) * 0.27, -PI, PI)
		_present()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_VISIBILITY_CHANGED]:
		dragging = false
		fingers.clear()
