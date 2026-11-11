extends Node3D

const INTERVAL_MS := 100
const MAX_TIME_MS := 180000
const STRIDE := 4
const MAX_VALUES := 8000
const POSITION_LIMIT := 10000

var trace: Array = []
var cursor := 0

func _ready() -> void:
	var shell := CapsuleMesh.new()
	shell.radius = 0.26
	shell.height = 1.48
	shell.radial_segments = 12
	shell.rings = 4
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.54, 0.72, 0.65, 0.50)
	var marker := MeshInstance3D.new()
	marker.mesh = shell
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.position.y = shell.height * 0.5
	add_child(marker)
	hide()

static func sanitize(raw: Variant, duration: int) -> Array:
	if not raw is Array or raw.size() < STRIDE * 2 or raw.size() > MAX_VALUES \
		or raw.size() % STRIDE != 0 or duration > MAX_TIME_MS:
		return []
	var clean: Array[int] = []
	var previous := -1
	for index: int in raw.size():
		var value: Variant = raw[index]
		var timestamp: bool = index % STRIDE == 0
		var limit := MAX_TIME_MS if timestamp else POSITION_LIMIT
		if not (value is int or value is float) or not is_finite(float(value)) \
			or absf(float(value)) > limit or floorf(float(value)) != float(value):
			return []
		var integer := int(value)
		if timestamp:
			if integer <= previous or integer > duration or (index == 0 and integer != 0):
				return []
			previous = integer
		clean.append(integer)
	return clean if previous == duration else []

func reset(samples: Array) -> void:
	trace = samples
	cursor = 0
	hide()

func show_at(milliseconds: float) -> void:
	if trace.is_empty() or milliseconds > trace[-STRIDE]:
		hide()
		return
	while cursor + STRIDE * 2 < trace.size() and trace[cursor + STRIDE] <= milliseconds:
		cursor += STRIDE
	var end := cursor + STRIDE
	var gap: int = trace[end] - trace[cursor]
	# A checkpoint return leaves a two-second gap and moves the marker only at its end.
	var blend := clampf((milliseconds - trace[cursor]) / gap, 0.0, 1.0)
	if gap > INTERVAL_MS * 2 and blend < 1.0:
		blend = 0.0
	position = _point(cursor).lerp(_point(end), blend)
	show()

func _point(index: int) -> Vector3:
	return Vector3(trace[index + 1], trace[index + 2], trace[index + 3]) * 0.01
