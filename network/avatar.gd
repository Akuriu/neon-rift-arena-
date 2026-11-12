extends Node3D

const Operator := preload("res://art/operator.gd")
const COLORS := [Color("#9fb3be"), Color("#c5a87a"), Color("#a7b289"), Color("#bc8c71")]
var tint := COLORS[0]
var skin := ""
var pilot_name := "Pilote"
var rig := Operator.new()
var body: Node3D
var nameplate: Label3D
var standing := true
var fall: Tween

func _ready() -> void:
	var uniform := Color("#747864")
	match skin:
		"skin_copper": uniform = Color("#876f59")
		"skin_glacier": uniform = Color("#6c797b")
		"skin_ash": uniform = Color("#a89c83")
		"skin_aurora": uniform = Color("#707b55")
	body = Node3D.new()
	add_child(body)
	rig.skin = skin
	rig.build(body, uniform, tint)
	rig.set_weapon(0)
	rig.animate(0.016, Vector3.ZERO, 0.0, 0.0, 0, 0.0)
	nameplate = Label3D.new()
	nameplate.text = pilot_name
	nameplate.pixel_size = 0.0045
	nameplate.font_size = 34
	nameplate.outline_size = 6
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.modulate = tint
	nameplate.position = Vector3.UP * 1.93
	add_child(nameplate)

func kick() -> void:
	if standing:
		rig.kick(Prefs.values.flashes > 0.15)

func present_alive(active: bool) -> void:
	if active == standing:
		return
	standing = active
	if fall != null:
		fall.kill()
	nameplate.visible = active
	if active:
		body.rotation = Vector3.ZERO
		body.position = Vector3.ZERO
		rig.reset_motion()
		rig.animate(0.0, Vector3.ZERO, 0.0, 0.0, 0, 0.0)
		body.show()
		body.reset_physics_interpolation()
	else:
		fall = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_property(body, "rotation", Vector3(-1.43, 0.14, 0.20), 0.39)
		fall.tween_property(body, "position:y", -0.09, 0.39)
		fall.chain().tween_interval(0.25)
		fall.tween_callback(body.hide)

func animate(delta: float, velocity: Vector3, pitch: float, height: float, flags: int, index: int, reload: float) -> void:
	if not standing:
		return
	var low := clampf((1.78 - height) / 0.67, 0.0, 1.0)
	rig.set_weapon(index)
	rig.animate(delta, global_basis.inverse() * velocity, pitch, low, flags, reload)
	nameplate.position.y = 1.93 - low * 0.33 - rig.slide_weight * 0.12
