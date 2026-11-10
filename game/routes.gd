extends RefCounted

const STEP := 1.5
var grid := AStarGrid2D.new()
var obstacles: Array[Rect2]

func setup(footprints: Array[Rect2], half_size: Vector2) -> void:
	obstacles = footprints
	var extent := Vector2i((half_size - Vector2.ONE) / STEP)
	grid.region = Rect2i(-extent, extent * 2 + Vector2i.ONE)
	grid.cell_size = Vector2.ONE * STEP
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(grid.region.position.y, grid.region.end.y):
		for x in range(grid.region.position.x, grid.region.end.x):
			var point := Vector2i(x, y)
			if not clear_segment(Vector2(point) * STEP, Vector2(point) * STEP, 0.73):
				grid.set_point_solid(point, true)

func clear_segment(from: Vector2, to: Vector2, clearance := 0.68) -> bool:
	for footprint in obstacles:
		var padded := footprint.grow(clearance)
		if padded.has_point(from) or padded.has_point(to):
			return false
		var a := padded.position
		var b := Vector2(padded.end.x, padded.position.y)
		var c := padded.end
		var d := Vector2(padded.position.x, padded.end.y)
		if Geometry2D.segment_intersects_segment(from, to, a, b) != null \
				or Geometry2D.segment_intersects_segment(from, to, b, c) != null \
				or Geometry2D.segment_intersects_segment(from, to, c, d) != null \
				or Geometry2D.segment_intersects_segment(from, to, d, a) != null:
			return false
	return true

func find(from: Vector3, to: Vector3) -> PackedVector3Array:
	var start := Vector2(from.x, from.z)
	var goal := Vector2(to.x, to.z)
	if grid.region.has_point(Vector2i((goal / STEP).round())) and clear_segment(start, goal):
		return PackedVector3Array([Vector3(goal.x, 0.0, goal.y)])
	var first := _nearest(start, true)
	if not grid.is_in_boundsv(first):
		first = _nearest(start, false)
	var last := _nearest(goal, false)
	if not grid.is_in_boundsv(first) or not grid.is_in_boundsv(last):
		return PackedVector3Array()
	var cells := grid.get_id_path(first, last, true)
	var waypoints := PackedVector3Array()
	for cell in cells:
		var point := Vector2(cell) * STEP
		if waypoints.is_empty() and point.distance_to(start) < 0.55:
			continue
		waypoints.append(Vector3(point.x, 0, point.y))
	# Smooth the initial turn where two or more grid steps are visible.
	while waypoints.size() > 1:
		var second := Vector2(waypoints[1].x, waypoints[1].z)
		if not clear_segment(start, second):
			break
		waypoints.remove_at(0)
	return waypoints

func _nearest(point: Vector2, needs_access: bool) -> Vector2i:
	var cell := Vector2i((point / STEP).round())
	var chosen := Vector2i(10000, 10000)
	var best := INF
	for radius in range(5):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var candidate := cell + Vector2i(x, y)
				if not grid.is_in_boundsv(candidate) or grid.is_point_solid(candidate):
					continue
				var target := Vector2(candidate) * STEP
				var distance := point.distance_squared_to(target)
				if distance < best and (not needs_access or clear_segment(point, target, 0.49)):
					best = distance
					chosen = candidate
		if best < INF:
			break
	return chosen
