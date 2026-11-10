extends "res://game/modes/classic.gd"

const Courses := preload("res://game/modes/parkour_routes.gd")
const Gate := preload("res://game/modes/checkpoint.gd")
var route := "yard"
var next := 0
var started := false
var eligible := true
var retries := 0
var penalty := 0.0
var splits: Array[float] = []
var checkpoints: Array[Area3D] = []
var previous_position := Vector3.ZERO

func configure(session: Node3D, variant: String, raw: Dictionary) -> void:
	stage = session
	mode = variant
	route = Courses.normalize(raw.get("route"))
	options = {"route": route}
	var course: Dictionary = Courses.ROUTES[route]
	for i in course.points.size():
		var gate := Gate.new()
		gate.index = i
		gate.width = course.width - 0.2
		gate.position = course.points[i]
		gate.body_entered.connect(_crossed.bind(i))
		stage.add_child(gate)
		checkpoints.append(gate)
	restart()

func restart() -> void:
	phase = Wave.Phase.ACTIVE
	elapsed = 0.0
	penalty = 0.0
	retries = 0
	next = 0
	started = false
	eligible = true
	splits.clear()
	outcome = ""
	stage.run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	stage.credited_result = {}
	stage.player.respawn(stage.arena.start_at)
	stage.player.rotation.y = 0.0
	stage.player.head.rotation.x = 0.0
	previous_position = stage.player.position
	_markers()
	stage.show_radio("Traversez le portique DÉPART pour lancer le chrono", 3.0)
	changed.emit()

func _physics_process(delta: float) -> void:
	if phase != Wave.Phase.ACTIVE:
		return
	if stage.player.position.y < -2.5:
		retry_checkpoint()
		return
	_validate_motion(delta)
	previous_position = stage.player.position
	if started:
		elapsed += delta
	stage.pickup_hint = "Revenir au checkpoint (+2 s)" if started else "Revenir au départ"

func _validate_motion(delta: float) -> void:
	if stage.player.position.distance_to(previous_position) > 20.0 * delta + 0.14:
		eligible = false

func _crossed(body: Node3D, index: int) -> void:
	if body != stage.player or phase != Wave.Phase.ACTIVE or index < next:
		return
	_validate_motion(get_physics_process_delta_time())
	if index > next:
		eligible = false
		stage.show_radio("Checkpoint %02d requis · recommencez pour un record" % next, 2.3)
		return
	var point: Vector3 = Courses.ROUTES[route].points[index]
	if absf(stage.player.position.y - point.y) > 1.25:
		return
	if index == 0:
		started = true
		elapsed = 0.0
		splits.clear()
		stage.show_radio("C’est parti", 1.0)
	else:
		splits.append(elapsed + penalty)
	next += 1
	_markers()
	stage.sound("charged")
	if next == checkpoints.size():
		finish(true)
	changed.emit()

func _markers() -> void:
	for i in checkpoints.size():
		checkpoints[i].mark(next, i == checkpoints.size() - 1)

func retry_checkpoint() -> void:
	if phase != Wave.Phase.ACTIVE:
		return
	if started:
		retries += 1
		penalty += 2.0
	var at: Vector3 = Courses.ROUTES[route].points[maxi(0, next - 1)] if started else stage.arena.start_at
	stage.player.respawn(at + Vector3(0, 0.04, 0.75) if started else at)
	previous_position = stage.player.position
	stage.show_radio("Checkpoint · +2 s" if started else "Prêt au départ", 1.1)

func milliseconds() -> int:
	return roundi((elapsed + penalty) * 1000.0)

func finish(victory: bool) -> void:
	if phase == Wave.Phase.DONE or not victory or next != checkpoints.size():
		return
	outcome = "Parcours terminé"
	phase = Wave.Phase.DONE
	finished.emit(true)

func report() -> Dictionary:
	return {"route": route, "milliseconds": milliseconds(), "elapsed_ms": roundi(elapsed * 1000),
		"penalty_ms": roundi(penalty * 1000), "retries": retries, "checkpoints": next,
		"valid": eligible and started and phase == Wave.Phase.DONE and next == checkpoints.size() and elapsed > 1.0}
