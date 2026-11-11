extends Node3D

const Fabric := preload("res://game/fabric.gd")
const Materials := preload("res://art/materials.gd")
const BASE := Vector3(13.7, 0.14, 10.65)
const GROUND_CALL := Vector3(11.72, 1.0, 12.4)
const UPPER_CALL := Vector3(14.74, 3.25, 7.9)
const FOOTPRINT := Rect2(11.35, 9.1, 3.95, 4.45)
const SIZE := Vector2(2.8, 3.0)
const HEIGHT := 2.12
const TRAVEL_SECONDS := 2.7
const STEEL := Color("#596963")
const SAND := Color("#c8ad83")
enum ControlPoint { NONE, CABIN, GROUND, UPPER }

var stage: Node3D
var deck: AnimatableBody3D
var lamp: StandardMaterial3D
var work_light: OmniLight3D
var progress := 0.0
var target := 0.0
var moving := false
var stopped := false
var obstructed := false

func _ready() -> void:
	name = "CargoLift"
	deck = AnimatableBody3D.new()
	deck.position = BASE
	deck.collision_layer = 1
	deck.collision_mask = 0
	add_child(deck)
	_solid(deck, Vector3(0, -0.1, 0), Vector3(SIZE.x, 0.2, SIZE.y), STEEL)
	for side in [-1.0, 1.0]:
		var x: float = side * (SIZE.x * 0.5 - 0.07)
		_solid(deck, Vector3(x, 0.45, 0), Vector3(0.12, 0.9, SIZE.y), STEEL)
		Fabric.place(deck, Fabric.cube(Vector3(0.16, 0.08, SIZE.y)), Fabric.paint(SAND), Vector3(x, 0.92, 0))
	for end in [-1.0, 1.0]:
		Fabric.place(deck, Fabric.cube(Vector3(2.4, 0.015, 0.13)), Fabric.paint(SAND), Vector3(0, 0.01, 1.38 * end))
	var ramp := StaticBody3D.new()
	ramp.position = BASE + Vector3(0, -0.13, 2.16)
	ramp.rotation.x = atan2(BASE.y, 1.34)
	add_child(ramp)
	_solid(ramp, Vector3.ZERO, Vector3(2.55, 0.12, 1.37), STEEL)
	_terminal(GROUND_CALL, "APPEL · SOL")
	_terminal(UPPER_CALL, "APPEL · QUAI")
	var panel := Vector3(1.12, 1.0, 0.68)
	Fabric.place(deck, Fabric.bevel(Vector3(0.27, 0.36, 0.30), 0.03), Fabric.paint(STEEL), panel)
	lamp = StandardMaterial3D.new()
	lamp.emission_enabled = true
	Fabric.place(deck, Fabric.cube(Vector3(0.16, 0.10, 0.025)), lamp, panel + Vector3(0, 0.07, 0.16))
	work_light = OmniLight3D.new()
	work_light.position = BASE + Vector3(-0.35, 3.5, -0.9)
	work_light.light_color = Color("#e2bc82")
	work_light.light_energy = 0.0
	work_light.omni_range = 4.2
	work_light.shadow_enabled = false
	add_child(work_light)
	_update_lamp()

func _solid(body: PhysicsBody3D, at: Vector3, size: Vector3, tint: Color) -> void:
	var collider := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = size
	collider.shape = volume
	collider.position = at
	body.add_child(collider)
	Fabric.place(body, Fabric.bevel(size, 0.04), Materials.finish(tint, "steel", 0.82), at)

func _terminal(at: Vector3, caption: String) -> void:
	var body := StaticBody3D.new()
	body.position = at - Vector3.UP * 0.5
	add_child(body)
	_solid(body, Vector3.ZERO, Vector3(0.38, 1, 0.35), STEEL)
	var label := Label3D.new()
	label.text = caption
	label.font = preload("res://assets/fonts/OpenSans-CondBold.ttf")
	label.font_size = 38
	label.pixel_size = 0.005
	label.modulate = SAND
	label.position = at + Vector3(0, 0.14, 0.185)
	add_child(label)

func _control_for(actor: CharacterBody3D) -> ControlPoint:
	if not is_instance_valid(actor) or actor != stage.player or not actor.alive \
		or is_instance_valid(stage.net) or stage.mode not in ["explore", "training"]:
		return ControlPoint.NONE
	var offset: Vector3 = actor.position - deck.position
	if absf(offset.x) < SIZE.x * 0.5 and absf(offset.z) < SIZE.y * 0.5 and absf(offset.y) < 0.34:
		return ControlPoint.CABIN
	if not moving or stopped:
		if progress > 0.0 and _near_terminal(actor, GROUND_CALL):
			return ControlPoint.GROUND
		if progress < 1.0 and _near_terminal(actor, UPPER_CALL):
			return ControlPoint.UPPER
	return ControlPoint.NONE

func _near_terminal(actor: CharacterBody3D, at: Vector3) -> bool:
	var offset: Vector3 = actor.position - (at - Vector3.UP)
	return absf(offset.y) < 0.48 and offset.length_squared() < 4.84 \
		and stage.ray(actor.aim_point(), at + Vector3(0, 0.09, 0.20), 1).is_empty()

func can_reach(actor: CharacterBody3D) -> bool:
	return _control_for(actor) != ControlPoint.NONE

func hint() -> String:
	if moving:
		if stopped:
			return "Reprendre le trajet" if _control_for(stage.player) == ControlPoint.CABIN else "Appeler le monte-charge"
		return "Arrêt d’urgence · passage occupé" if obstructed else "Arrêt d’urgence"
	if _control_for(stage.player) != ControlPoint.CABIN:
		return "Appeler le monte-charge"
	return "Monter au quai" if progress == 0.0 else "Redescendre au sol"

func activate(actor: CharacterBody3D) -> bool:
	var control := _control_for(actor)
	if control == ControlPoint.NONE:
		return false
	if moving and control == ControlPoint.CABIN:
		stopped = not stopped
	else:
		target = 1.0 if control == ControlPoint.UPPER or (control == ControlPoint.CABIN and progress == 0.0) else 0.0
		moving = true
		stopped = false
	_update_lamp()
	stage.sound("switch", deck.position)
	return true

func _physics_process(delta: float) -> void:
	if not moving or stopped:
		return
	var was_obstructed := obstructed
	obstructed = target == 0.0 and _blocked_below()
	if obstructed != was_obstructed:
		_update_lamp()
	if obstructed:
		return
	progress = move_toward(progress, target, delta / TRAVEL_SECONDS)
	deck.position = BASE + Vector3.UP * (HEIGHT * smoothstep(0.0, 1.0, progress))
	if progress == target:
		moving = false
		_update_lamp()

func _process(delta: float) -> void:
	var enabled: bool = Prefs.values.quality in [1, 2]
	var energy := 0.72 if moving and not stopped and not obstructed and enabled else 0.0
	work_light.light_energy = lerpf(work_light.light_energy, energy, 1.0 - exp(-7.0 * delta))
	work_light.visible = enabled and work_light.light_energy > 0.015

func _blocked_below() -> bool:
	if _under_deck(stage.player):
		return true
	for actor in stage.units:
		if _under_deck(actor):
			return true
	return false

func _under_deck(actor: CharacterBody3D) -> bool:
	if not is_instance_valid(actor) or not actor.alive:
		return false
	var offset: Vector3 = actor.position - deck.position
	return offset.y < -0.34 and absf(offset.x) < SIZE.x * 0.5 + 0.40 and absf(offset.z) < SIZE.y * 0.5 + 0.40

func _update_lamp() -> void:
	var tint := Color("#bf6e53") if stopped or obstructed else (SAND if moving else Color("#728b73"))
	lamp.albedo_color = tint
	lamp.emission = tint * 0.22
