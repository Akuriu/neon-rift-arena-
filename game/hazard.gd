extends Node3D

const Fabric := preload("res://game/fabric.gd")
var session: Node3D
var duration := 1.0
var age := 0.0
var radius := 3.0
var power := 20.0
var tint := Color("#ff9e67")
var inner: MeshInstance3D
var source: CharacterBody3D
var source_required := false
var slow := false
var visual_only := false

func _ready() -> void:
	source_required = is_instance_valid(source)
	var ring_segments := 24 if Prefs.values.quality == 3 else 40
	Fabric.place(self, Fabric.ring(radius, 0.055, ring_segments), Fabric.paint(tint, true),
		Vector3.ZERO, Vector3.ZERO, false)
	inner = Fabric.place(self, Fabric.ring(radius, 0.039, ring_segments), Fabric.paint(tint.lightened(0.2), true),
		Vector3.ZERO, Vector3.ZERO, false)

func _physics_process(delta: float) -> void:
	if source_required and (not is_instance_valid(source) or not source.alive):
		queue_free()
		return
	age += delta
	inner.scale = Vector3.ONE * lerpf(0.08, 1.0, clampf(age / duration, 0, 1))
	if age < duration:
		return
	if visual_only:
		queue_free()
		return
	for pilot in session.living_pilots():
		var offset: Vector3 = pilot.global_position - global_position
		if absf(offset.y) < 0.80 and Vector2(offset.x, offset.z).length() < radius \
				and session.ray(global_position + Vector3.UP * 0.15, pilot.head.global_position, 1).is_empty():
			pilot.take_damage(power, global_position)
			if slow:
				pilot.slowed = maxf(pilot.slowed, 1.8)
	for index in 12:
		var angle := index * TAU / 12.0
		var at := global_position + Vector3(sin(angle), 0.12, cos(angle)) * radius
		session.effects.sparks(at, tint, 2, 2.8)
	session.sound("wave_hit", global_position)
	queue_free()
