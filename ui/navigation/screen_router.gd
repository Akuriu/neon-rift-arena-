extends RefCounted

const Motion := preload("res://ui/design/motion.gd")
const Tokens := preload("res://ui/design/tokens.gd")
const HISTORY_LIMIT := 12

var history: Array[String] = []
var animation: Tween

func enter(surface: Control, destination: String, treatment: String) -> void:
	if not history.is_empty() and history.back() == destination:
		return
	var previous := history.rfind(destination)
	if previous >= 0:
		history.resize(previous + 1)
	else:
		history.append(destination)
		if history.size() > HISTORY_LIMIT:
			history.pop_front()
	var interrupted := animation != null and animation.is_running()
	animation = Motion.retarget(surface, animation)
	if animation == null:
		finish(surface)
		return
	if not interrupted:
		var direction := -1.0 if previous >= 0 else 1.0
		surface.position = Vector2(0.0, 12.0) if treatment == "overlay" else Vector2(20.0 * direction, 0.0)
		surface.modulate.a = 0.82
	animation.set_parallel()
	animation.tween_property(surface, "position", Vector2.ZERO, Tokens.PAGE_SECONDS)
	animation.tween_property(surface, "modulate:a", 1.0, Tokens.PAGE_SECONDS * 0.78)

func reset(surface: Control, destination: String) -> void:
	history.assign([destination])
	finish(surface)

func finish(surface: Control) -> void:
	Motion.stop(animation)
	animation = null
	surface.position = Vector2.ZERO
	surface.modulate.a = 1.0
