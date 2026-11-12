extends Button

const Motion := preload("res://ui/design/motion.gd")
const Tokens := preload("res://ui/design/tokens.gd")

var motion: Tween
var sound_cue := "ui_select"
var mouse_from_touch := false

func _ready() -> void:
	_center_pivot()
	resized.connect(_center_pivot)
	button_down.connect(_compress)
	button_up.connect(_release)
	visibility_changed.connect(_visibility)

func bind_action(action: Callable, cue := true) -> void:
	pressed.connect(func():
		if mouse_from_touch:
			# Godot still has to release the touch focus after the emulated mouse event.
			_invoke.call_deferred(action, cue)
		else:
			_invoke(action, cue)
	)

func _gui_input(event: InputEvent) -> void:
	mouse_from_touch = event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION

func _invoke(action: Callable, cue: bool) -> void:
	if not is_inside_tree() or not is_visible_in_tree() or disabled or not action.is_valid():
		return
	if cue:
		Sounds.play_ui(sound_cue)
	action.call()

func _center_pivot() -> void:
	pivot_offset = size * 0.5

func _compress() -> void:
	motion = Motion.retarget(self, motion)
	if motion == null:
		scale = Vector2.ONE
		return
	scale = Vector2.ONE * minf(scale.x, 0.988)
	motion.tween_property(self, "scale", Vector2.ONE * 0.972, Tokens.PRESS_SECONDS)

func _release() -> void:
	motion = Motion.retarget(self, motion, Tween.TRANS_BACK)
	if motion == null:
		scale = Vector2.ONE
		return
	motion.tween_property(self, "scale", Vector2.ONE, Tokens.RELEASE_SECONDS)

func _has_point(point: Vector2) -> bool:
	var unscaled := pivot_offset + (point - pivot_offset) * scale
	return Rect2(Vector2.ZERO, size).has_point(unscaled)

func finish_motion() -> void:
	Motion.stop(motion)
	motion = null
	scale = Vector2.ONE

func _visibility() -> void:
	if not is_visible_in_tree():
		finish_motion()

func _exit_tree() -> void:
	finish_motion()
