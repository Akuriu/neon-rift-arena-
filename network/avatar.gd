extends Node3D

const Operator := preload("res://art/operator.gd")
const COLORS := [Color("#9fb3be"), Color("#c5a87a"), Color("#a7b289"), Color("#bc8c71")]
var tint := COLORS[0]
var skin := ""
var pilot_name := "Pilote"
var rig := Operator.new()

func _ready() -> void:
	var uniform := Color("#747864")
	match skin:
		"skin_copper": uniform = Color("#876f59")
		"skin_glacier": uniform = Color("#6c797b")
		"skin_ash": uniform = Color("#a89c83")
		"skin_aurora": uniform = Color("#707b55")
	rig.skin = skin
	rig.build(self, uniform, tint)
	rig.set_weapon(0)
	var nameplate := Label3D.new()
	nameplate.text = pilot_name
	nameplate.pixel_size = 0.0045
	nameplate.font_size = 34
	nameplate.outline_size = 6
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.modulate = tint
	nameplate.position = Vector3.UP * 1.93
	add_child(nameplate)

func kick() -> void:
	rig.recoil = 1.0

func animate(delta: float, speed: float, pitch: float, height: float, flags: int, index: int, reload: float) -> void:
	var low := clampf((1.78 - height) / 0.67, 0.0, 1.0)
	rig.set_weapon(index)
	rig.animate(delta, speed, pitch, low, (flags & 5) != 0, (flags & 8) != 0, reload)
