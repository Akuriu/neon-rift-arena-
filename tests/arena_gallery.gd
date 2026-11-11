extends SceneTree

const MAPS := ["reactor", "skyline", "cryo", "bastion", "district", "grove", "station"]
const ROUTES := ["yard", "gantry", "roofs"]

var output := OS.get_environment("RIFLE_QA_CAPTURE_DIR")
var app
var errors := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_environment("NEON_QA_ISOLATED") != "1" or output.is_empty():
		printerr("Ce banc exige une fenêtre, un profil isolé et un dossier de captures.")
		quit(2)
		return
	var prefs := root.get_node("Prefs")
	prefs.change_value("quality", 1)
	prefs.change_value("ui_motion", false)
	prefs.change_value("resolution", 1)
	app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	for id in MAPS:
		await render("explore", id, {})
	for route in ROUTES:
		await render("parkour", "skyline", {"route": route})
	root.get_node("Sounds").stop_all()
	app.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	quit(errors)

func render(mode: String, map_id: String, rules: Dictionary) -> void:
	app.begin(mode, "standard", map_id, 64071, "", false, rules)
	app._freeze()
	var stage = app.session
	stage.player.hide()
	var camera := Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.fov = 67.0
	stage.add_child(camera)
	var extent: Vector2 = stage.arena.half_size
	var position := Vector3(extent.x * 0.39, 5.2, extent.y * 0.70)
	if mode == "parkour":
		position = Vector3(extent.x * 0.68, 8.8, extent.y * 0.64)
	camera.look_at_from_position(position, Vector3(-2.5, 2.0, -4.0), Vector3.UP)
	camera.current = true
	for _index in 8:
		await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var name: String = "parkour-" + rules.route if mode == "parkour" else map_id
	var path := output.path_join(name + ".jpg")
	var saved := frame.save_jpg(path, 0.88) == OK
	print(("PASS " if saved else "FAIL "), "Capture ", name,
		" · ", frame.get_size(), " · appels de dessin ",
		roundi(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	if not saved:
		errors += 1
