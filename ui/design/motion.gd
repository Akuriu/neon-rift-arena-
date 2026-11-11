extends RefCounted

static func retarget(node: Control, previous: Tween, curve := Tween.TRANS_CUBIC) -> Tween:
	stop(previous)
	if not Prefs.values.ui_motion or not node.is_inside_tree():
		return null
	return node.create_tween().set_trans(curve).set_ease(Tween.EASE_OUT)

static func stop(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
