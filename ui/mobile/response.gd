extends RefCounted

const LOOK_DEGREES := 0.16
const REFERENCE_HEIGHT := 720.0

static func steering(displacement: Vector2, radius: float, dead: float, curve: float) -> Vector2:
	var length := displacement.length()
	if length <= 0.0:
		return Vector2.ZERO
	var linear := clampf((length / maxf(1.0, radius) - dead) / (1.0 - dead), 0.0, 1.0)
	return displacement / length * lerpf(linear, linear * linear, curve)

static func look(relative: Vector2, velocity: Vector2, extent: Vector2, axes: Vector2,
		curve: float, limit: float) -> Vector2:
	var density := REFERENCE_HEIGHT / maxf(1.0, minf(extent.x, extent.y))
	var displacement := relative * density * axes
	var rate := (velocity * density * axes).length()
	var gain := 1.0
	if rate > 0.0:
		gain = lerpf(1.0, lerpf(0.60, 1.35, smoothstep(180.0, 2000.0, rate)), curve)
		if limit > 0.0:
			gain = minf(gain, limit / (rate * LOOK_DEGREES))
	return displacement * gain
