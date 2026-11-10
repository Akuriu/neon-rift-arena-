extends Control

const Palette := preload("res://ui/skin.gd")
const Catalog := preload("res://game/catalog.gd")
const Director := preload("res://game/wave_director.gd")
const Rules := preload("res://game/modes/rules.gd")
const CYAN := Palette.CYAN
const AMBER := Palette.AMBER
const TEXT := Palette.TEXT
const MUTE := Palette.MUTED
const PINK := Palette.PINK
const INK := Color(0.07, 0.079, 0.064, 0.86)

var session: Node3D
var sample_time := 0.0
var frame_samples := PackedFloat32Array()
var diagnostic := ""
var render_wait := 0.0
var scope_mesh: ArrayMesh
var scope_extent := Vector2.ZERO
var signal_ink := CYAN
var status_panel := Palette.box(INK, Color("#626357"), 5)
var status_contrast := Palette.box(Color("#141611"), Color("#77776a"), 5)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(session) or not is_instance_valid(session.player):
		return
	if Prefs.values.telemetry:
		_sample(delta)
	render_wait -= delta
	if render_wait <= 0.0 or session.last_hit > 0.0 or session.player.arsenal.scope > 0.02:
		render_wait = 1.0 / (25.0 if Prefs.values.quality == 3 else 36.0)
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(session) or not is_instance_valid(session.player):
		return
	var pilot = session.player
	var gun = pilot.arsenal
	signal_ink = Art.hud_color()
	var director = session.director
	var match_mode := is_instance_valid(session.classic)
	var mobile := Prefs.mobile()
	var tint: Color = gun.spec().tint
	var center := size * 0.5
	if gun.spec().has("zoom") and gun.scope > 0.05 and Prefs.values.scope_overlay:
		_scope(center, gun.scope, gun.magnification(), tint)
	var damage: float = maxf(pilot.shield_flash, pilot.hull_flash) * Prefs.values.flashes
	if damage > 0.001:
		var edge := Color(PINK if pilot.hull_flash > pilot.shield_flash else signal_ink, damage * 0.25)
		draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), edge, false, 7.0)
	var objective := "Vague %d / %d" % [director.wave, director.total_waves] if director.total_waves > 0 else "Vague %d" % director.wave
	if match_mode:
		objective = {"classic": "Chacun pour soi", "teams": "Équipes", "capture": "Capture",
			"domination": "Domination"}[session.mode]
	elif session.mode == "training":
		objective = "Entraînement"
	elif session.mode == "explore":
		objective = "Exploration"
	elif session.mode == "trial":
		objective = "Défi chronométré"
	var time: float = director.time_left() if match_mode else director.elapsed
	if session.mode == "trial":
		time = Director.TRIAL_TIME - director.elapsed
	elif session.mode == "training" and session.training_options.time > 0:
		time = maxf(0.0, session.training_options.time - director.elapsed)
	var score := "%d  –  %d" % [director.score, director.rival_score()] if match_mode else str(director.score)
	if mobile:
		_mobile_status(pilot, objective, score, time)
	else:
		_desktop_status(pilot, gun, objective, score, time, tint)
	_crosshair(center, tint)
	if (pilot.hull_flash > 0.0 or pilot.shield_flash > 0.0) and pilot.damage_from.is_finite():
		var direction: Vector3 = pilot.damage_from - pilot.global_position
		var screen_dir := Vector2(direction.dot(pilot.global_basis.x), direction.dot(pilot.global_basis.z)).normalized()
		var at := center + screen_dir * 61.0
		draw_line(at + screen_dir.orthogonal() * 8.0, at - screen_dir.orthogonal() * 8.0, Color(PINK, 0.75), 2.4, true)
	if match_mode:
		_classic(center, director, pilot)
	elif director.phase == Director.Phase.PREP:
		_notice(Vector2(center.x, 159), "Préparez-vous", ("Défi dans %.1f s" % director.clock if session.mode == "trial"
			else "Vague %02d dans %.1f s" % [director.wave, director.clock]), AMBER)
	if not match_mode and director.notice > 0.0 and director.phase in [Director.Phase.ACTIVE, Director.Phase.TRIAL]:
		var title := "Défi lancé" if session.mode == "trial" else "Vague %d" % director.wave
		var sub: String = director.current_wave.get("theme", "Les adversaires arrivent.")
		var major: String = director.current_wave.get("boss", "")
		if not major.is_empty():
			sub = Catalog.UNITS[major].name + " détecté"
		_notice(Vector2(center.x, 164), title, sub, CYAN)
	if is_instance_valid(session.boss) and session.boss.alive:
		var boss = session.boss
		var pos := Vector2(center.x - 180, 74 if mobile else 25)
		_frame(Rect2(pos, Vector2(360, 55)), AMBER)
		_print(pos + Vector2(12, 20), boss.spec.name.to_upper(), 14, Palette.MONO, TEXT)
		if boss.kind in ["warden", "colossus", "architect"]:
			_print(pos + Vector2(274, 20), "PHASE %d" % boss.phase, 12, Palette.MONO, AMBER)
		_meter(pos + Vector2(12, 34), Vector2(336, 6), boss.health / boss.maximum, AMBER)
	if session.radio_time > 0.0:
		_mid(Vector2(center.x, size.y - 101), session.radio, 16, Palette.BOLD, AMBER)
	elif director.combo > 1 and director.combo_left > 0.0:
		_mid(Vector2(center.x, size.y - 101), "SÉRIE ×%d" % director.combo, 16, Palette.MONO, CYAN)
	if session.pickup_hint != "":
		var hint: String = session.pickup_hint
		if not mobile:
			hint = "[%s]  %s" % [OS.get_keycode_string(Prefs.keys.interact), hint]
		_mid(Vector2(center.x, size.y - 72), hint, 16, Palette.BOLD, TEXT)
	if session.relay_state == 1 and director.phase == Director.Phase.ACTIVE:
		_mid(Vector2(center.x, size.y - 122), "RELAIS   %.1f / 6 s   ·   +48 CR" % session.relay_progress, 13, Palette.MONO, signal_ink)
	if Prefs.values.telemetry and not diagnostic.is_empty():
		_frame(Rect2(26, 120, 345, 39), CYAN)
		_print(Vector2(36, 145), diagnostic, 12, Palette.MONO, TEXT)
	if is_instance_valid(session.net):
		_team(Vector2(26, 170 if Prefs.values.telemetry else 117))
		if not pilot.alive:
			_notice(Vector2(center.x, 244), "HORS COMBAT", "Retour à l’intermission si l’équipe tient la vague.", AMBER)
	if Input.is_action_pressed("stats"):
		_stats()
	if session.mode == "training":
		var accuracy := roundi(100.0 * session.hits / maxi(1, session.shots))
		var hint := "%d NEUTRALISÉS  /  %d %% DE PRÉCISION  /  %d TIRS" % [director.kills, accuracy, session.shots]
		_mid(Vector2(center.x, size.y - 41), hint, 13, Palette.BODY, TEXT)

func _mobile_status(pilot: CharacterBody3D, objective: String, score: String, time: float) -> void:
	var factor: float = Prefs.values.hud_scale
	var left_handed: bool = Prefs.values.touch_left
	var width := 184.0 * factor
	var corner := Vector2(size.x - 24.0 - width if left_handed else 24.0, 21.0)
	draw_set_transform(corner, 0, Vector2.ONE * factor)
	var plate := status_contrast if Prefs.values.high_contrast else status_panel
	draw_style_box(plate, Rect2(0, 0, 184, 61))
	draw_rect(Rect2(0, 11, 3, 39), AMBER)
	_print(Vector2(14, 22), Catalog.MAPS[session.map_id].name.to_upper(), 11, Palette.MONO, MUTE)
	_print(Vector2(13, 47), objective, 21, Palette.HEAD, TEXT)
	draw_set_transform(Vector2(size.x * 0.5 - 112.0 * factor, 18), 0, Vector2.ONE * factor)
	draw_style_box(plate, Rect2(0, 0, 224, 54))
	draw_line(Vector2(123, 9), Vector2(123, 45), Color(MUTE, 0.34), 1.0)
	_mid(Vector2(62, 17), "SCORE", 10, Palette.MONO, AMBER)
	_mid(Vector2(174, 17), "TEMPS", 10, Palette.MONO, MUTE)
	_mid(Vector2(62, 42), score, 23, Palette.HEAD, TEXT)
	_mid(Vector2(174, 41), Palette.clock(time), 17, Palette.MONO, TEXT)
	draw_set_transform(Vector2(corner.x, size.y - 24.0 - 65.0 * factor), 0, Vector2.ONE * factor)
	draw_style_box(plate, Rect2(0, 0, 184, 65))
	_mid(Vector2(47, 17), "SANTÉ", 10, Palette.MONO, MUTE)
	_mid(Vector2(136, 17), "PROTECTION", 10, Palette.MONO, MUTE)
	_mid(Vector2(47, 44), str(ceili(pilot.health)), 26, Palette.HEAD, TEXT)
	_mid(Vector2(136, 44), str(ceili(pilot.shield)), 26, Palette.HEAD, Color("#b3c1b1"))
	_meter(Vector2(13, 52), Vector2(69, 4), pilot.health / 100.0, TEXT)
	_meter(Vector2(102, 52), Vector2(69, 4), pilot.shield / pilot.shield_max, Color("#a7b2a3"))
	draw_set_transform(Vector2.ZERO)
	if Prefs.values.fps_counter:
		_mid(Vector2(size.x * 0.5, 80), "%d FPS" % Engine.get_frames_per_second(), 12, Palette.MONO, TEXT)

func _desktop_status(pilot: CharacterBody3D, gun: Node, objective: String, score: String, time: float, tint: Color) -> void:
	var factor: float = Prefs.values.hud_scale
	draw_set_transform(Vector2(25, 23), 0, Vector2.ONE * factor)
	_frame(Rect2(0, 0, 216, 62), signal_ink)
	_print(Vector2(12, 23), Catalog.MAPS[session.map_id].name, 15, Palette.BOLD, MUTE)
	_print(Vector2(12, 48), objective, 22, Palette.HEAD, TEXT)
	draw_set_transform(Vector2(size.x - 25.0 - 186.0 * factor, 23), 0, Vector2.ONE * factor)
	_frame(Rect2(0, 0, 186, 62), AMBER)
	_print(Vector2(12, 22), "Score", 13, Palette.BOLD, MUTE)
	_print(Vector2(104, 22), Palette.clock(time), 15, Palette.MONO, MUTE)
	_print(Vector2(11, 49), score, 25, Palette.BOLD, TEXT)
	var match_mode := is_instance_valid(session.classic)
	if match_mode:
		_print(Vector2(101, 48), "/ %d" % session.director.options.target, 13, Palette.MONO, MUTE)
	elif session.mode not in ["training", "explore"]:
		_print(Vector2(101, 48), "%d crédits" % session.wallet.balance, 13, Palette.BODY, MUTE)
	if Prefs.values.fps_counter:
		_print(Vector2(100, 80), "%d FPS" % Engine.get_frames_per_second(), 13, Palette.MONO, TEXT)
	draw_set_transform(Vector2(25, size.y - 24.0 - 73.0 * factor), 0, Vector2.ONE * factor)
	_frame(Rect2(0, 0, 209, 73), signal_ink)
	_print(Vector2(12, 28), "%d" % ceili(pilot.health), 23, Palette.BOLD, TEXT)
	_print(Vector2(67, 26), "Santé", 14, Palette.BODY, MUTE)
	_meter(Vector2(118, 17), Vector2(78, 5), pilot.health / 100.0, TEXT)
	_print(Vector2(12, 55), "%d" % ceili(pilot.shield), 19, Palette.BOLD, MUTE)
	_print(Vector2(67, 54), "Protection", 13, Palette.BODY, MUTE)
	_meter(Vector2(141, 46), Vector2(55, 5), pilot.shield / pilot.shield_max, Color("#a7b2a3"))
	draw_set_transform(Vector2(size.x - 25.0 - 215.0 * factor, size.y - 24.0 - 73.0 * factor), 0, Vector2.ONE * factor)
	_frame(Rect2(0, 0, 215, 73), tint)
	_print(Vector2(12, 25), gun.spec().name, 17, Palette.BOLD, TEXT)
	var reserve := "∞" if gun.reserve() < 0 else str(gun.reserve())
	_print(Vector2(12, 55), "%d / %s" % [gun.rounds(), reserve], 24, Palette.BOLD, TEXT)
	if gun.reload_left > 0.0:
		_print(Vector2(110, 54), "Recharge", 12, Palette.BOLD, AMBER)
		_meter(Vector2(12, 65), Vector2(190, 3), 1.0 - gun.reload_left / gun.cycle_length, AMBER)
	elif gun.charge > 0.0:
		_meter(Vector2(12, 65), Vector2(190, 3), gun.charge, tint)
	draw_set_transform(Vector2.ZERO)

func _classic(center: Vector2, match_state: Node, pilot: CharacterBody3D) -> void:
	if match_state.phase == Director.Phase.PREP:
		_notice(Vector2(center.x, 156), Rules.LABELS[session.mode].to_upper(), "Départ dans %.1f s" % match_state.clock, AMBER)
	if not pilot.alive and match_state.respawns.has(0):
		_notice(Vector2(center.x, 245), "HORS COMBAT", "Redéploiement dans %.1f s" % maxf(0.0, match_state.respawns[0]), AMBER)
	var width: float = match_state.zones.size() * 115.0
	for i in match_state.zones.size():
		var zone: Node3D = match_state.zones[i]
		var at := Vector2(center.x - width * 0.5 + i * 115.0, 92.0 if Prefs.mobile() else 25.0)
		var color := signal_ink if zone.owner_side == 0 else (AMBER if zone.owner_side == 1 else MUTE)
		_frame(Rect2(at, Vector2(108, 48)), color)
		var status := "NEUTRE" if zone.owner_side < 0 else ("ALLIÉS" if zone.owner_side == 0 else "ADVERSES")
		_print(at + Vector2(9, 19), "%s  %s" % [zone.badge, "LUTTE" if zone.contested else status], 12, Palette.MONO, color)
		_meter(at + Vector2(9, 31), Vector2(88, 5), absf(zone.control), color)

func _team(at: Vector2) -> void:
	var row := 0
	for ally in session.pilots.values():
		if ally == session.player:
			continue
		var pos := at + Vector2(0, row * 35)
		var color: Color = ally.avatar.tint if ally.alive else MUTE
		_frame(Rect2(pos, Vector2(197, 32)), color)
		_print(pos + Vector2(9, 14), String(ally.pilot_name).left(18), 11, Palette.MONO, color)
		if ally.alive:
			_meter(pos + Vector2(9, 20), Vector2(84, 3), ally.health / 100.0, TEXT)
			_meter(pos + Vector2(103, 20), Vector2(84, 3), ally.shield / ally.shield_max, color)
		else:
			_print(pos + Vector2(9, 26), "HORS COMBAT", 9, Palette.MONO, MUTE)
		row += 1

func _scope(center: Vector2, opacity: float, zoom: float, tint: Color) -> void:
	var radius := minf(size.x, size.y) * 0.375
	if scope_extent != size or scope_mesh == null:
		_build_scope(center, radius)
	draw_mesh(scope_mesh, null, Transform2D.IDENTITY, Color(0.018, 0.043, 0.060, opacity * Prefs.values.scope_shade))
	draw_arc(center, radius, 0, TAU, 60, Color(tint, opacity * 0.72), 2.0, true)
	for axis in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		draw_line(center + axis * 25, center + axis * (radius - 9), Color(TEXT, opacity * 0.40), 1.0, true)
		for notch in 3:
			var mark: Vector2 = center + axis * (42.0 + notch * 21.0)
			var width: Vector2 = axis.orthogonal() * (3.0 + notch)
			draw_line(mark - width, mark + width, Color(TEXT, opacity * 0.48), 1.0, true)
	_mid(center + Vector2(0, radius - 21), "OPTIQUE  ×%.1f" % zoom, 13, Palette.MONO, tint)

func _build_scope(center: Vector2, radius: float) -> void:
	var vertices := PackedVector2Array()
	for i in 48:
		var side := Vector2.from_angle(TAU * i / 48.0)
		var next := Vector2.from_angle(TAU * (i + 1) / 48.0)
		var inner := center + side * radius
		var outer := center + side * size.length()
		var inner_next := center + next * radius
		var outer_next := center + next * size.length()
		vertices.append_array(PackedVector2Array([inner, outer, outer_next, inner, outer_next, inner_next]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	scope_mesh = ArrayMesh.new()
	scope_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	scope_extent = size

func _crosshair(center: Vector2, tint: Color) -> void:
	var colors := [tint, TEXT, CYAN, AMBER]
	var ink: Color = colors[Prefs.values.reticle_tint]
	var thin: float = 5.0 + session.player.arsenal.shot_kick * (4.0 if Prefs.values.recoil else 1.0)
	match int(Prefs.values.reticle):
		0:
			for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
				draw_line(center + direction * (thin - 1), center + direction * (thin + 7), Color(0.01, 0.04, 0.05, 0.90), 4, true)
				draw_line(center + direction * thin, center + direction * (thin + 6), Color(ink, 0.94), 1.5, true)
		2:
			draw_arc(center, thin + 4.0, 0, TAU, 22, ink, 1.4, true)
	draw_circle(center, 1.8, ink)
	if session.last_hit > 0.0:
		var marker := AMBER if session.critical else tint
		for direction in [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]:
			draw_line(center + direction * 9, center + direction * 14, marker, 2.1, true)
		if Prefs.values.damage_numbers:
			_print(center + Vector2(22, -16.0 - (0.25 - session.last_hit) * 31.0),
				"%s%d" % ["★ " if session.critical else "", roundi(session.last_damage)], 18, Palette.MONO, marker)

func _sample(delta: float) -> void:
	if frame_samples.size() < 180:
		frame_samples.append(delta * 1000.0)
	sample_time += delta
	if sample_time < 0.85 or not is_instance_valid(session):
		return
	frame_samples.sort()
	var p95 := frame_samples[floori((frame_samples.size() - 1) * 0.95)]
	var p99 := frame_samples[floori((frame_samples.size() - 1) * 0.99)]
	diagnostic = "%d FPS · P95 %.1f · P99 %.1f ms · %d MB" % [
		Engine.get_frames_per_second(), p95, p99, roundi(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)]
	frame_samples.clear()
	sample_time = 0.0

func _stats() -> void:
	var data = session.director
	var at := Vector2(26, 115)
	_frame(Rect2(at, Vector2(260, 222)), CYAN)
	_print(at + Vector2(13, 27), "JOURNAL DU PILOTE", 19, Palette.HEAD, CYAN)
	var accuracy := roundi(100.0 * session.hits / maxi(1, session.shots))
	var rows := [
		"Neutralisations   %d" % data.kills,
		"Précision         %d %%" % accuracy,
		"Bouclier max.     %d" % session.player.shield_max,
		"Mobilité         +%d %%" % roundi((session.player.speed_bonus - 1.0) * 100),
		"Recharge         +%d %%" % roundi((session.player.arsenal.reload_boost - 1.0) * 100),
	]
	for index in rows.size():
		_print(at + Vector2(13, 62 + 27 * index), rows[index], 13, Palette.MONO, TEXT)

func _notice(at: Vector2, title: String, sub: String, color: Color) -> void:
	_frame(Rect2(at - Vector2(144, 34), Vector2(288, 70)), color)
	_mid(at - Vector2(0, 5), title, 25, Palette.HEAD, color)
	_mid(at + Vector2(0, 20), sub, 15, Palette.BODY, TEXT)

func _frame(rect: Rect2, accent: Color) -> void:
	draw_rect(rect, Color("#141611") if Prefs.values.high_contrast else INK)
	draw_rect(rect, Color(accent, 0.28), false, 1.0)

func _meter(at: Vector2, extent: Vector2, fraction: float, color: Color) -> void:
	draw_rect(Rect2(at, extent), Color("#494b3f"))
	draw_rect(Rect2(at, Vector2(extent.x * clampf(fraction, 0.0, 1.0), extent.y)), color)

func _print(at: Vector2, value: String, pixels: int, font: Font, color: Color) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, color)

func _mid(at: Vector2, value: String, pixels: int, font: Font, color: Color) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	_print(at - Vector2(width * 0.5, 0), value, pixels, font, color)
