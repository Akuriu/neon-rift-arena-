extends Node

signal state_changed(value: State)

enum State { BOOT, PROFILE_CHECK, RESOURCE_LOADING, SCENE_READY, REVEAL_MENU, ERROR, RETRY }

const APP := "res://scenes/App.tscn"
const DEDICATED := "res://scenes/Dedicated.tscn"
const VIEW := "res://ui/boot/boot_view.gd"
const Loader := preload("res://services/threaded_scene.gd")
const Tokens := preload("res://ui/design/tokens.gd")

var app_path := APP
var state := State.BOOT
var loader := Loader.new()
var splash
var app: Node

func _ready() -> void:
	set_process(false)
	set_process_input(false)
	if "--server" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred(DEDICATED)
		return
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	splash = load(VIEW).new()
	layer.add_child(splash)
	splash.retry.connect(_retry)
	splash.exit_requested.connect(_quit)
	set_process_input(true)
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(_quit)
	_start()

func _start() -> void:
	await _frame()
	_change(State.PROFILE_CHECK, "Vérification du profil", Prefs.profile_notice)
	await get_tree().process_frame
	loader.request(app_path)
	if loader.status == Loader.Status.FAILED:
		_fail()
		return
	_change(State.RESOURCE_LOADING, "Chargement des ressources", Prefs.profile_notice)
	set_process(true)

func _process(_delta: float) -> void:
	var previous := loader.progress
	loader.poll()
	match loader.status:
		Loader.Status.LOADING:
			if previous != loader.progress:
				splash.status("Chargement des ressources", Prefs.profile_notice, loader.progress)
		Loader.Status.LOADED:
			set_process(false)
			_prepare()
		Loader.Status.FAILED:
			_fail()

func _prepare() -> void:
	_change(State.SCENE_READY, "Préparation de l’interface", Prefs.profile_notice)
	await _frame()
	app = loader.scene.instantiate()
	if app == null or not app.has_method("menu"):
		if app != null:
			app.free()
		_fail()
		return
	var tree := get_tree()
	app.staged_loading = true
	tree.root.add_child(app)
	if tree.current_scene == self:
		tree.current_scene = app
	get_window().close_requested.disconnect(_quit)
	await _frame()
	_change(State.REVEAL_MENU, "Prêt", Prefs.profile_notice, 1.0)
	set_process_input(false)
	splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	print("RIFLE_BOOT ready")
	if Prefs.values.ui_motion and DisplayServer.get_name() != "headless":
		var reveal := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		reveal.tween_property(splash, "modulate:a", 0.0, Tokens.REVEAL_SECONDS)
		await reveal.finished
	queue_free()

func _frame() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw

func _change(next: State, caption: String, notice: String, fraction := -1.0) -> void:
	state = next
	splash.status(caption, notice, fraction, next == State.ERROR)
	state_changed.emit(state)

func _fail() -> void:
	set_process(false)
	_change(State.ERROR, "Chargement interrompu", "Impossible d’ouvrir l’interface de Rifle Arena.")

func _retry() -> void:
	if state == State.ERROR:
		_change(State.RETRY, "Nouvelle tentative", Prefs.profile_notice)
		_start()

func _quit() -> void:
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if state != State.ERROR and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion):
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and state == State.ERROR:
		_quit()
