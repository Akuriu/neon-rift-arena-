extends RefCounted

static func area(window: Window, extent: Vector2, override := Rect2()) -> Rect2:
	var available := Rect2(Vector2.ZERO, extent)
	var safe := override
	if not safe.has_area() and OS.has_feature("android"):
		var device := DisplayServer.get_display_safe_area()
		if device.has_area():
			safe = window.get_final_transform().affine_inverse() * Rect2(device)
	if safe.has_area():
		var intersection := available.intersection(safe)
		if intersection.has_area():
			return intersection
	return available

static func center(frame: Control, extent: Rect2, design_size: Vector2) -> void:
	var factor := minf(extent.size.x / design_size.x, extent.size.y / design_size.y)
	frame.scale = Vector2.ONE * factor
	frame.position = extent.get_center() - design_size * factor * 0.5
