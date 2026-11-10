extends RefCounted

const BUFFER_SECONDS := 0.120
const DISCONTINUITY_SQUARED := 36.0
var samples: Array[Dictionary] = []

func append(at: Vector3, yaw: float, pitch: float, speed: float, stamp: float) -> void:
	if not samples.is_empty() and samples.back().at.distance_squared_to(at) > DISCONTINUITY_SQUARED:
		samples.clear()
	if not samples.is_empty() and stamp <= samples.back().stamp:
		stamp = samples.back().stamp + 0.001
	samples.append({"at": at, "yaw": yaw, "pitch": pitch, "speed": speed, "stamp": stamp})
	if samples.size() > 6:
		samples.pop_front()

func pose(now: float) -> Dictionary:
	var playback := now - BUFFER_SECONDS
	while samples.size() > 2 and samples[1].stamp <= playback:
		samples.pop_front()
	if samples.size() < 2:
		return {} if samples.is_empty() else samples[0]
	var a := samples[0]
	var b := samples[1]
	var blend := clampf((playback - a.stamp) / (b.stamp - a.stamp), 0.0, 1.0)
	return {"at": a.at.lerp(b.at, blend), "yaw": lerp_angle(a.yaw, b.yaw, blend),
		"pitch": lerpf(a.pitch, b.pitch, blend), "speed": lerpf(a.speed, b.speed, blend)}
