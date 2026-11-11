extends "res://game/arena.gd"

const Courses := preload("res://game/modes/parkour_routes.gd")
var route := "yard"

func _init() -> void:
	map_id = "skyline"
	half_size = Vector2(13, 25)
	start_at = Vector3(0, 0.05, 20.0)
	terminal_at = Vector3(9, 1, 20)
	build_landscape = false

func _build_layout() -> void:
	var course: Dictionary = Courses.ROUTES[route]
	# The training extension is separate; the seven combat arenas are untouched.
	_box(Vector3(0, -5.6, 0), Vector3(150, 0.4, 130), Color("#88816f"))
	_skyline()
	for side in [-1.0, 1.0]:
		for z in [-20, -8, 4, 16]:
			_box(Vector3(side * 9, -1.6, z), Vector3(0.4, 7.0, 0.4), Color("#736854"), false, Vector3.ZERO, 0.04)
		_box(Vector3(side * 9, 1.65, -2), Vector3(0.22, 0.22, 39), Color("#a49a7a"))
	if route == "yard":
		_platform(Vector3(0, 0, 0), 6.0, 45.0)
		for z in [8.0, 0.0, -8.0]:
			_solid(Vector3(0, 0.23, z), Vector3(6.0, 0.46, 0.36), Color("#b19a74"), 0.045, false)
			_box(Vector3(0, 0.469, z), Vector3(6.0, 0.022, 0.30), Color("#e0d2af"))
	else:
		var points: Array = course.points
		for i in points.size():
			var point: Vector3 = points[i]
			_platform(Vector3(point.x, point.y - 0.04, point.z), course.width, 4.6 if route == "gantry" else 3.8)
		_platform(Vector3(0, 0, 20), 6.0, 4.5)
	_stencil("RIFLE / TERRAIN D’EXERCICE", Vector3(0, 3.2, -24), Vector3.ZERO, 0.019, Color("#d6ceb9"))
	_box(Vector3(0, 3.2, -24.2), Vector3(14, 2.0, 0.25), Color("#414c46"))
	for point in course.points:
		_box(point - Vector3.UP * 0.022, Vector3(course.width * 0.86, 0.025, 0.09), Color("#d7c196"))

func _platform(top: Vector3, width: float, depth: float) -> void:
	_solid(top - Vector3.UP * 0.35, Vector3(width, 0.7, depth), Color("#6f7971"), 0.08, false)
	_box(top + Vector3.UP * 0.008, Vector3(width - 0.22, 0.018, depth - 0.22), Color("#969788"))
	for side in [-1.0, 1.0]:
		_box(top + Vector3(side * (width * 0.5 - 0.1), 0.022, 0), Vector3(0.08, 0.025, depth - 0.18), Color("#c9b486"))
	_box(top - Vector3.UP * 2.9, Vector3(0.55, 5.2, minf(1.8, depth)), Color("#5f6863"))
