extends Control

const Palette := preload("res://ui/skin.gd")
const Catalog := preload("res://game/catalog.gd")
const Director := preload("res://game/wave_director.gd")
const CYAN := Palette.CYAN
const AMBER := Palette.AMBER
const TEXT := Palette.TEXT
const MUTE := Palette.MUTED
const PINK := Palette.PINK
const INK := Color(0.028, 0.059, 0.079, 0.92)

var session: Node3D
var entering := 0.0
var sample_time := 0.0
var frame_samples := PackedFloat32Array()
var diagnostic := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	entering += delta
	if Prefs.values.telemetry:
		_sample(delta)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(session) or not is_instance_valid(session.player):
		return
	var pilot = session.player
	var gun = pilot.arsenal
	var director = session.director
	var tint: Color = gun.spec().tint
	var center := size * 0.5
	var zoom: float = Prefs.values.hud_scale
	var fade := 1.0 - clampf(entering / 0.62, 0.0, 1.0)
	if fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.025, 0.03, fade * 0.68))
	if gun.scope > 0.05 and Prefs.values.scope_overlay:
		_scope(center, gun.scope, gun.magnification(), tint)
	var damage: float = maxf(pilot.shield_flash, pilot.hull_flash) * Prefs.values.flashes
	if damage > 0.001:
		var edge := Color(PINK if pilot.hull_flash > pilot.shield_flash else CYAN, damage * 0.30)
		draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), edge, false, 12.0)
		draw_rect(Rect2(Vector2(11, 11), size - Vector2(22, 22)), Color(edge, edge.a * 0.42), false, 5.0)
	draw_set_transform(Vector2(26, 24), 0.0, Vector2.ONE * zoom)
	_frame(Rect2(0, 0, 244, 76), CYAN)
	_print(Vector2(14, 23), "NR // " + Catalog.MAPS[session.map_id].name.to_upper(), 13, Palette.MONO, CYAN)
	var objective := "VAGUE %02d / %02d" % [director.wave, director.total_waves] if director.total_waves > 0 else "VAGUE %02d  ·  ∞" % director.wave
	if session.mode == "training":
		objective = "ENTRAÎNEMENT"
	elif session.mode == "trial":
		objective = "DÉFI CHRONOMÉTRÉ"
	_print(Vector2(13, 56), objective, 27, Palette.HEAD, TEXT)
	draw_set_transform(Vector2(size.x - 26.0 - 216.0 * zoom, 24), 0.0, Vector2.ONE * zoom)
	_frame(Rect2(0, 0, 216, 76), AMBER)
	_print(Vector2(13, 23), "SCORE", 12, Palette.MONO, AMBER)
	_print(Vector2(137, 23), Palette.clock(Director.TRIAL_TIME - director.elapsed if session.mode == "trial" else director.elapsed), 13, Palette.MONO, MUTE)
	_print(Vector2(12, 58), "%06d" % director.score, 30, Palette.MONO, TEXT)
	var targets: int = director.remaining()
	_print(Vector2(138, 54), "%02d  BOT" % targets, 13, Palette.MONO, MUTE)
	if session.mode != "training":
		_frame(Rect2(0, 84, 216, 30), AMBER)
		_print(Vector2(13, 105), "%d CR" % session.wallet.balance, 14, Palette.MONO, AMBER)
		if Prefs.values.fps_counter:
			_print(Vector2(129, 105), "%d FPS" % Engine.get_frames_per_second(), 13, Palette.MONO, TEXT)
	elif Prefs.values.fps_counter:
		_print(Vector2(129, 96), "%d FPS" % Engine.get_frames_per_second(), 13, Palette.MONO, TEXT)
	draw_set_transform(Vector2(26, size.y - 27 - 112.0 * zoom), 0.0, Vector2.ONE * zoom)
	_frame(Rect2(0, 0, 272, 112), CYAN)
	var gadget := "GADGET PRÊT" if pilot.gadget_left <= 0.0 else "GADGET %.1f s" % pilot.gadget_left
	_print(Vector2(14, 25), "%s  ·  %s" % [OS.get_keycode_string(Prefs.keys.gadget), gadget], 12, Palette.MONO, MUTE)
	_meter(Vector2(14, 53), Vector2(197, 6), pilot.health / 100.0, TEXT)
	_print(Vector2(14, 46), "INTÉGRITÉ", 12, Palette.MONO, TEXT)
	_print(Vector2(219, 57), "%03d" % ceili(pilot.health), 18, Palette.MONO, TEXT)
	_meter(Vector2(14, 92), Vector2(197, 6), pilot.shield / pilot.shield_max, CYAN)
	_print(Vector2(14, 84), "BOUCLIER", 12, Palette.MONO, CYAN)
	_print(Vector2(219, 96), "%03d" % ceili(pilot.shield), 18, Palette.MONO, CYAN)
	draw_set_transform(Vector2(size.x - 26 - 280.0 * zoom, size.y - 27 - 112.0 * zoom), 0.0, Vector2.ONE * zoom)
	_frame(Rect2(0, 0, 280, 112), tint)
	_print(Vector2(13, 24), "%02d / %s" % [gun.rack.find(gun.active) + 1, gun.spec().tag], 12, Palette.MONO, tint)
	_print(Vector2(13, 57), gun.spec().name, 29, Palette.HEAD, TEXT)
	_print(Vector2(191, 62), "%02d" % gun.rounds(), 33, Palette.MONO, TEXT)
	var reserve := "∞" if gun.reserve() < 0 else str(gun.reserve())
	_print(Vector2(233, 62), "/%02d" % gun.capacity(), 14, Palette.MONO, MUTE)
	_print(Vector2(186, 84), "RÉSERVE " + reserve, 11, Palette.MONO, MUTE)
	var gauge: float = gun.heat[gun.active]
	var gauge_name := "CHALEUR"
	if gun.reload_left > 0.0:
		gauge = 1.0 - gun.reload_left / gun.cycle_length
		gauge_name = "RECHARGE"
	elif gun.charge > 0.0:
		gauge = gun.charge
		gauge_name = "CHARGE"
	_print(Vector2(13, 84), gauge_name, 11, Palette.MONO, MUTE)
	_meter(Vector2(13, 93), Vector2(254, 5), gauge, AMBER if gauge > 0.75 else tint)
	draw_set_transform(Vector2.ZERO)
	_crosshair(center, tint)
	if (pilot.hull_flash > 0.0 or pilot.shield_flash > 0.0) and pilot.damage_from.is_finite():
		var direction: Vector3 = pilot.damage_from - pilot.global_position
		var screen_dir := Vector2(direction.dot(pilot.global_basis.x), direction.dot(pilot.global_basis.z)).normalized()
		var at := center + screen_dir * 61.0
		draw_line(at + screen_dir.orthogonal() * 8.0, at - screen_dir.orthogonal() * 8.0, Color(PINK, 0.75), 2.4, true)
	if director.phase == Director.Phase.PREP:
		_notice(Vector2(center.x, 159), "CALIBRATION", ("Défi dans %.1f s" % director.clock if session.mode == "trial"
			else "Vague %02d dans %.1f s" % [director.wave, director.clock]), AMBER)
	if director.notice > 0.0 and director.phase in [Director.Phase.ACTIVE, Director.Phase.TRIAL]:
		var title := "PROTOCOLE LANCÉ" if session.mode == "trial" else "VAGUE %02d" % director.wave
		var sub: String = director.current_wave.get("theme", "Unités actives dans le secteur")
		var major: String = director.current_wave.get("boss", "")
		if not major.is_empty():
			sub = Catalog.UNITS[major].name + " détecté"
		_notice(Vector2(center.x, 164), title, sub, CYAN)
	if is_instance_valid(session.boss) and session.boss.alive:
		var boss = session.boss
		var pos := Vector2(center.x - 180, 25)
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
		var key := OS.get_keycode_string(Prefs.keys.interact)
		_mid(Vector2(center.x, size.y - 72), "[%s]  %s" % [key, session.pickup_hint], 16, Palette.BOLD, TEXT)
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
		var hint := "Tir • Changer avec 1–4 ou molette • Console de réarmement près du départ"
		_mid(Vector2(center.x, size.y - 41), hint, 13, Palette.BODY, TEXT)

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
	for i in 40:
		var a := TAU * i / 40.0
		var b := TAU * (i + 1) / 40.0
		var side := Vector2.from_angle(a)
		var next := Vector2.from_angle(b)
		draw_colored_polygon(PackedVector2Array([center + side * radius, center + side * size.x,
			center + next * size.x, center + next * radius]), Color(0.018, 0.043, 0.060, opacity * 0.82))
	draw_arc(center, radius, 0, TAU, 60, Color(tint, opacity * 0.72), 2.0, true)
	for axis in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		draw_line(center + axis * 25, center + axis * (radius - 9), Color(TEXT, opacity * 0.40), 1.0, true)
	_mid(center + Vector2(0, radius - 21), "OPTIQUE  ×%.1f" % zoom, 13, Palette.MONO, tint)

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
	var a := rect.position
	var b := rect.end
	var points := PackedVector2Array([a, Vector2(b.x - 9, a.y), Vector2(b.x, a.y + 9),
		b, Vector2(a.x + 9, b.y), Vector2(a.x, b.y - 9)])
	draw_colored_polygon(points, INK)
	points.append(a)
	draw_polyline(points, Color("#345058"), 1.0, true)
	draw_rect(Rect2(a, Vector2(24, 2)), accent)
	draw_rect(Rect2(b - Vector2(14, 2), Vector2(14, 2)), Color(accent, 0.60))

func _meter(at: Vector2, extent: Vector2, fraction: float, color: Color) -> void:
	draw_rect(Rect2(at, extent), Color("#2c4149"))
	draw_rect(Rect2(at, Vector2(extent.x * clampf(fraction, 0.0, 1.0), extent.y)), color)

func _print(at: Vector2, value: String, pixels: int, font: Font, color: Color) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, color)

func _mid(at: Vector2, value: String, pixels: int, font: Font, color: Color) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	_print(at - Vector2(width * 0.5, 0), value, pixels, font, color)
