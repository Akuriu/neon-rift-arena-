extends SceneTree

const Rules := preload("res://game/modes/rules.gd")
const FIXTURE := "res://tests/fixtures/profile-v0.0.5.json"

var app
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("NEON_QA_ISOLATED") != "1" or "--touch" not in OS.get_cmdline_user_args():
		quit(2)
		return
	var prefs = root.get_node("Prefs")
	app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	check(app.screen == "menu" and app.version_label == "v0.0.6 Alpha" and prefs.profile.data.xp == 0,
		"Premier lancement vierge sur le nouvel accueil")
	app.show_profile()
	check(app.screen == "profile", "Progression accessible sur un profil neuf")
	var save: String = prefs.profile_file(prefs.SAVE)
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(FIXTURE), save) == OK,
		"Copie du profil produit par le code v0.0.5")
	prefs.load_disk()
	var expected_fire := {"x": 0.86, "y": 0.57, "size": 1.13, "opacity": 0.71}
	check(prefs.profile.data.xp == 725 and prefs.profile.data.coins == 790 and prefs.profile.owns("wp_eclipse")
		and prefs.values.touch_left and is_equal_approx(prefs.values.touch_x, 1.35)
		and prefs.touch_layout.fire == expected_fire
		and prefs.leaderboard("short", "standard", "skyline").size() == 1,
		"XP, achat, HUD, sensibilité et record du profil v0.0.5 chargés")
	prefs.change_value("touch_response", 0.45)
	check(prefs.save_disk(), "Réécriture sûre du profil antérieur")
	prefs.load_disk()
	check(prefs.profile.data.xp == 725 and prefs.touch_layout.fire == expected_fire
		and is_equal_approx(prefs.values.touch_response, 0.45), "Relecture des anciens et nouveaux réglages")
	prefs.change_value("touch_preset", 2)
	check(not prefs.compact_touch() and not prefs.left_touch() and prefs.active_touch_layout().fire != expected_fire,
		"Le préréglage Complet utilise ses propres positions")
	prefs.change_value("touch_preset", 3)
	check(prefs.compact_touch() and prefs.left_touch(), "Le préréglage Gaucher reflète les commandes")
	prefs.change_value("touch_preset", 0)
	check(prefs.active_touch_layout().fire == expected_fire and prefs.left_touch(), "Personnalisé restaure les positions antérieures")
	app.open_touch_editor()
	var editor = app.view.get_child(-1)
	var before: Dictionary = prefs.touch_layout.duplicate(true)
	editor._select("fire")
	editor._reset_one()
	check(prefs.touch_layout.fire != expected_fire and prefs.touch_layout.jump == before.jump
		and prefs.profile.data.xp == 725, "Réinitialiser Tir conserve les autres commandes et l’XP")
	prefs.set_touch_layout(before)
	check(Rules.valid_key("0-300-10") and Rules.valid_key("12-900-100") and not Rules.valid_key("13-300-10")
		and not Rules.valid_key("00-300-10"), "Bornes cohérentes des règles du classement")
	prefs.complete_run("qa-zero", "domination", "standard", "station",
		{"score": 10, "seconds": 130, "kills": 0, "rules": "0-300-10", "participated": true, "victory": true})
	prefs.load_disk()
	check(prefs.leaderboard("domination", "standard", "station", "0-300-10").size() == 1
		and prefs.leaderboard("domination", "standard", "station", "1-300-10").is_empty(),
		"Record à zéro bot relu séparément")
	await screens()
	app.begin("explore", "standard", "skyline", 140)
	for quality in [3, 0, 1, 2]:
		prefs.change_value("quality", quality)
		await process_frame
		check(is_equal_approx(root.scaling_3d_scale, prefs.SCALES[quality])
			and app.session.arena.sun.shadow_enabled == (quality in [1, 2]),
			"Preset %d appliqué en jeu" % quality)
	app.menu()
	root.get_node("Sounds").stop_all()
	await process_frame
	quit(failures)

func screens() -> void:
	var screens_to_open := [
		["Accueil", app.menu], ["Jouer", app.play_menu], ["Survie", app.select_session],
		["Classique", app.open_classic], ["Coop", app.open_lobby],
		["Arsenal", app.open_hub.bind("arsenal")], ["Boutique", app.open_hub.bind("shop")],
		["Progression", app.show_profile], ["Historique", app.show_career],
		["Options", app.open_settings.bind("menu")], ["Disposition", app.open_touch_editor],
		["Crédits", app.credits],
	]
	root.content_scale_size = Vector2i.ZERO
	for physical in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1560, 720), Vector2i(1600, 720)]:
		root.size = physical
		await process_frame
		var extent := root.get_visible_rect().size
		app._apply_safe_insets(Rect2(Vector2(52, 7), extent - Vector2(58, 27)), extent)
		await process_frame
		for entry in screens_to_open:
			entry[1].call()
			await process_frame
			var allowed: Rect2 = app.canvas.get_global_rect().grow(0.6)
			var escaped := outside(app.view, allowed)
			check(escaped.is_empty(), "%s sur %s, surface %s %s" % [entry[0], physical, extent, escaped])
			if entry[0] == "Disposition":
				var editor = app.view.get_child(-1)
				editor._expand()
				check(editor.diagram.size == app.view.size and outside(app.view, allowed).is_empty(),
					"Aperçu tactile plein écran dans la zone sûre " + str(physical))
				editor._expand()
		app._safe_canvas()
	root.content_scale_size = Vector2i(1280, 720)

func outside(node: Node, allowed: Rect2) -> Array[String]:
	var errors: Array[String] = []
	for child in node.get_children():
		if child is Control and not child.visible:
			continue
		if child is BaseButton or child is LineEdit or child is ScrollContainer or child is Slider:
			var rect: Rect2 = child.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, child.size)
			if not allowed.encloses(rect):
				errors.append(String(child.name))
		if not child is ScrollContainer and not child is Viewport:
			errors.append_array(outside(child, allowed))
	return errors

func check(ok: bool, description: String) -> void:
	print("PASS " if ok else "FAIL ", description)
	if not ok:
		failures += 1
