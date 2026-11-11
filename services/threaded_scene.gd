extends RefCounted

enum Status { IDLE, LOADING, LOADED, FAILED }

class RetryLoad extends RefCounted:
	var scene: PackedScene

	func read(path: String) -> void:
		scene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene

var status := Status.IDLE
var progress := -1.0
var scene: PackedScene
var _path := ""
var _failed_path := ""
var _retry: RetryLoad
var _task := -1

func request(path: String) -> void:
	if status == Status.LOADING:
		return
	progress = -1.0
	scene = null
	_path = path
	if not ResourceLoader.exists(path, "PackedScene"):
		status = Status.FAILED
	elif path == _failed_path:
		# A failed Godot request keeps its token until collected. Retry off-thread with a fresh read.
		_retry = RetryLoad.new()
		_task = WorkerThreadPool.add_task(_retry.read.bind(path))
		status = Status.LOADING
	else:
		status = Status.LOADING if ResourceLoader.load_threaded_request(path, "PackedScene") == OK else Status.FAILED

func poll() -> void:
	if status != Status.LOADING:
		return
	if _task != -1:
		if WorkerThreadPool.is_task_completed(_task):
			WorkerThreadPool.wait_for_task_completion(_task)
			scene = _retry.scene
			_retry = null
			_task = -1
			status = Status.LOADED if scene != null else Status.FAILED
		return
	var sample := []
	match ResourceLoader.load_threaded_get_status(_path, sample):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not sample.is_empty() and is_finite(float(sample[0])) and float(sample[0]) < 1.0:
				progress = maxf(progress, clampf(float(sample[0]), 0.0, 0.999))
		ResourceLoader.THREAD_LOAD_LOADED:
			scene = ResourceLoader.load_threaded_get(_path) as PackedScene
			status = Status.LOADED if scene != null else Status.FAILED
		_:
			_failed_path = _path
			status = Status.FAILED

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
