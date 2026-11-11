extends Node

signal changed(key: String)
signal saved(success: bool)

const SAVE := "user://pilot_profile.json"
const BACKUP := "user://pilot_profile.json.bak"
const TEMP := "user://pilot_profile.json.tmp"
const VERSION := 6
const Profile := preload("res://services/profile.gd")
const Rules := preload("res://game/modes/rules.gd")
const Courses := preload("res://game/modes/parkour_routes.gd")
const ParkourReplay := preload("res://game/modes/parkour_ghost.gd")
const TouchLayout := preload("res://ui/mobile/layout.gd")
const LEGACY_BACKUP := "user://pilot_profile.v1.json"
const V2_BACKUP := "user://pilot_profile.v2.json"
const RESET_BACKUP := "user://pilot_profile.before_reset.json"
const LOCK := "user://pilot_profile.lock"
const RESOLUTIONS := [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const FPS_OPTIONS := [30, 60, 90, 120, 0]
const MOBILE_FPS := [30, 45, 60]
const SCALES := [0.76, 0.89, 1.0, 0.64]
const AZERTY := {
	"forward": KEY_Z, "back": KEY_S, "left": KEY_Q, "right": KEY_D,
	"jump": KEY_SPACE, "sprint": KEY_SHIFT, "crouch": KEY_CTRL, "reload": KEY_R,
	"interact": KEY_E, "stats": KEY_TAB, "slot_1": KEY_1, "slot_2": KEY_2,
	"slot_3": KEY_3, "slot_4": KEY_4, "gadget": KEY_G, "inspect": KEY_I,
}
const DEFAULTS := {
	"layout": 0, "sensitivity": 0.18, "fov": 82.0, "invert_y": false,
	"head_bob": false, "sprint_fov": true, "recoil": true, "damage_numbers": true,
	"flashes": 0.8, "quality": 0, "resolution": 1, "fullscreen": false,
	"ads_sensitivity": 0.66, "scope_overlay": true, "vsync": true, "borderless": false,
	"telemetry": false, "reticle": 0, "reticle_tint": 0,
	"fps_limit": 60, "fps_counter": false, "hud_scale": 1.0,
	"master": 0.8, "music": 0.45, "sfx": 0.8, "ambience": 0.6,
	"steady_cam": false, "motion_strength": 0.62, "shake": 0.50, "sprint_toggle": false,
	"crouch_toggle": false, "auto_slide": false, "scope_shade": 0.54, "ui_motion": true,
	"hud_tone": 0, "fog": true, "weather": false, "high_contrast": false,
	"touch_x": 1.05, "touch_y": 0.95, "touch_dead": 0.13, "touch_invert": false,
	"touch_left": false, "touch_float": true, "touch_haptic": false, "touch_compact": true,
	"touch_aim_assist": true, "touch_auto_sprint": false,
	"touch_travel": 1.0, "touch_response": 0.28, "touch_look_curve": 0.0, "touch_look_limit": 0,
	"touch_preset": 0,
	"particles": 0.85, "audio_alerts": true, "audio_hits": true, "audio_dynamic": true, "audio_ui": true,
}
const RANGES := {
	"layout": [0, 1], "sensitivity": [0.035, 0.70], "fov": [66.0, 108.0],
	"ads_sensitivity": [0.25, 1.0], "reticle": [0, 2], "reticle_tint": [0, 3], "flashes": [0.0, 1.0], "quality": [0, 3], "resolution": [0, 3], "hud_scale": [0.80, 1.20],
	"master": [0.0, 1.0], "music": [0.0, 1.0], "sfx": [0.0, 1.0], "ambience": [0.0, 1.0],
	"motion_strength": [0.0, 1.0], "shake": [0.0, 1.0], "scope_shade": [0.1, 0.85],
	"hud_tone": [0, 3],
	"touch_x": [0.25, 3.0], "touch_y": [0.25, 3.0], "touch_dead": [0.04, 0.35],
	"touch_travel": [0.75, 1.25], "touch_response": [0.0, 0.75], "touch_look_curve": [0.0, 0.75],
	"touch_look_limit": [0, 900],
	"touch_preset": [0, 3],
	"particles": [0.0, 1.0],
}
const BUSES := {"master": "Master", "music": "Musique", "sfx": "SFX", "ambience": "Ambiance"}
const MODES := ["survival", "short", "endless", "trial", "coop", "boss_rush", "classic", "teams", "capture", "domination", "gungame"]
const DIFFICULTIES := ["discovery", "standard", "expert"]
const MAPS := ["reactor", "skyline", "cryo", "bastion", "district", "grove", "station"]

var values := DEFAULTS.duplicate()
var touch_layout := TouchLayout.defaults()
var default_touch_layout := TouchLayout.defaults()
var keys := AZERTY.duplicate()
var records: Dictionary = {}
var profile := Profile.new()
var disk_stamp := ""
var save_error := ""
var profile_notice := ""
var dirty := false
var save_in := 0.0
var test_profile_dir := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("editor") and OS.get_environment("NEON_QA_ISOLATED") == "1":
		var candidate := OS.get_environment("NEON_QA_PROFILE_PATH")
		if candidate.is_absolute_path() and DirAccess.dir_exists_absolute(candidate):
			test_profile_dir = candidate
	load_disk()
	apply_video()

func _process(delta: float) -> void:
	if dirty:
		save_in -= delta
		if save_in <= 0.0:
			save_disk()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED] and dirty:
		save_disk()

func mobile() -> bool:
	return OS.has_feature("android") or "--touch" in OS.get_cmdline_user_args()

func default_values() -> Dictionary:
	var base := DEFAULTS.duplicate()
	if mobile():
		base.merge({"quality": 3, "fps_limit": 45, "fog": false, "weather": false,
			"hud_scale": 0.86, "damage_numbers": false, "motion_strength": 0.34}, true)
	return base

func set_touch_layout(layout: Variant) -> void:
	_activate_custom_touch()
	touch_layout = TouchLayout.normalize(layout)
	queue_save()
	changed.emit("touch_layout")

func active_touch_layout() -> Dictionary:
	return touch_layout if values.touch_preset == 0 else default_touch_layout

func compact_touch() -> bool:
	return values.touch_compact if values.touch_preset == 0 else values.touch_preset != 2

func left_touch() -> bool:
	return values.touch_left if values.touch_preset == 0 else values.touch_preset == 3

func _activate_custom_touch() -> void:
	if values.touch_preset != 0:
		values.touch_compact = compact_touch()
		values.touch_left = left_touch()
		values.touch_preset = 0

func keyboard(layout: int) -> Dictionary:
	var result := AZERTY.duplicate()
	if layout == 1:
		result.forward = KEY_W
		result.left = KEY_A
	return result

func change_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	var next: Variant = _valid_value(key, value)
	if next == values[key]:
		return
	values[key] = next
	if key == "layout":
		keys = keyboard(next)
		apply_keys()
	if key in ["quality", "resolution", "fullscreen", "borderless", "vsync", "fps_limit"]:
		apply_video()
	if BUSES.has(key):
		apply_audio()
	queue_save()
	changed.emit(key)

func bind_key(action: String, code: int) -> bool:
	if not keys.has(action) or not _key_ok(code):
		return false
	for other in keys:
		if other != action and keys[other] == code:
			keys[other] = keys[action]
	keys[action] = code
	apply_keys()
	queue_save()
	changed.emit("keys")
	return true

func _key_ok(code: int) -> bool:
	return code > 0 and code != KEY_ESCAPE and code != KEY_UNKNOWN and OS.get_keycode_string(code) != ""

func apply_keys() -> void:
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.keycode = keys[action]
		InputMap.action_add_event(action, event)
		if action.begins_with("slot_") and event.keycode == AZERTY[action]:
			var physical := InputEventKey.new()
			physical.physical_keycode = event.keycode
			InputMap.action_add_event(action, physical)
			var keypad := InputEventKey.new()
			keypad.keycode = KEY_KP_1 + (event.keycode - KEY_1)
			InputMap.action_add_event(action, keypad)
	for action in ["fire", "ads"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		if mobile():
			continue
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT if action == "fire" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, click)

func apply_video() -> void:
	Engine.max_fps = values.fps_limit
	var window := get_tree().root
	window.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	window.scaling_3d_scale = SCALES[values.quality]
	window.msaa_3d = Viewport.MSAA_2X if values.quality == 2 else Viewport.MSAA_DISABLED
	if DisplayServer.get_name() == "headless" or OS.has_feature("android"):
		return
	var desired_mode := Window.MODE_FULLSCREEN if values.fullscreen else Window.MODE_WINDOWED
	if DisplayServer.window_get_vsync_mode() != (DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	window.borderless = values.borderless
	if window.mode != desired_mode:
		window.mode = desired_mode
	if desired_mode == Window.MODE_WINDOWED:
		var bounds := DisplayServer.screen_get_usable_rect()
		var requested: Vector2i = RESOLUTIONS[values.resolution]
		if bounds.size.x >= 640 and bounds.size.y >= 360:
			var ratio := minf(1.0, minf(float(bounds.size.x) / requested.x, float(bounds.size.y - 30) / requested.y))
			requested = Vector2i(Vector2(requested) * ratio)
		if window.size != requested or DisplayServer.window_get_size() != requested:
			window.size = requested
			if bounds.size != Vector2i.ZERO:
				window.position = bounds.position + (bounds.size - requested) / 2

func apply_audio() -> void:
	for key in BUSES:
		var bus := AudioServer.get_bus_index(BUSES[key])
		if bus >= 0:
			AudioServer.set_bus_mute(bus, values[key] <= 0.001)
			AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.0001, values[key])))

func reset_settings() -> void:
	values = default_values()
	touch_layout = TouchLayout.defaults()
	keys = keyboard(0)
	apply_keys()
	apply_audio()
	apply_video()
	changed.emit("all")
	save_disk()

func _valid_value(key: String, value: Variant) -> Variant:
	var fallback: Variant = DEFAULTS[key]
	if typeof(fallback) == TYPE_BOOL:
		return value if typeof(value) == TYPE_BOOL else fallback
	if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)):
		return fallback
	if key == "fps_limit":
		return int(value) if int(value) in (MOBILE_FPS if mobile() else FPS_OPTIONS) else (45 if mobile() else fallback)
	var range_for_key: Array = RANGES[key]
	var number := clampf(float(value), range_for_key[0], range_for_key[1])
	return roundi(number) if typeof(fallback) == TYPE_INT else number

func profile_file(filename: String) -> String:
	return test_profile_dir.path_join(filename.get_file()) if not test_profile_dir.is_empty() else filename

func _read(filename: String) -> Dictionary:
	var path := profile_file(filename)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	return parser.data

func load_disk() -> void:
	disk_stamp = _stamp()
	profile_notice = ""
	var document := _read(SAVE)
	if not _recognizable(document):
		document = _read(BACKUP)
		if _recognizable(document):
			profile_notice = "Profil chargé depuis la copie de secours."
		elif FileAccess.file_exists(profile_file(SAVE)) or FileAccess.file_exists(profile_file(BACKUP)):
			profile_notice = "Profil illisible. Une session de secours a été ouverte."
	var version := _profile_version(document)
	if version < 0 and profile_notice.is_empty():
		profile_notice = "Version du profil illisible. Les données compatibles ont été chargées."
	profile.restore(document.get("progression", {}))
	values = default_values()
	var stored: Variant = document.get("settings", document.get("prefs", {}))
	if stored is Dictionary:
		for key in DEFAULTS:
			if stored.has(key):
				values[key] = _valid_value(key, stored[key])
	if version >= 0 and version < 5:
		touch_layout = TouchLayout.defaults()
		values.touch_compact = true
	else:
		touch_layout = TouchLayout.normalize(document.get("touch_layout"))
	keys = keyboard(values.layout)
	var bindings: Variant = document.get("bindings", {})
	if bindings is Dictionary:
		_load_bindings(bindings)
	records = {}
	var stored_records: Variant = document.get("records", {})
	if stored_records is Dictionary:
		for mode in MODES:
			for difficulty in DIFFICULTIES:
				for map_id in MAPS:
					var key := category(mode, difficulty, map_id)
					var entry: Variant = stored_records.get(key, stored_records.get(mode + "|" + difficulty, []))
					var rows := _record_rows(entry)
					if not rows.is_empty():
						records[key] = rows
		for key in stored_records:
			var parts := String(key).split("|")
			if parts.size() == 4 and Rules.LABELS.has(parts[0]) and parts[1] in DIFFICULTIES \
				and parts[2] in MAPS and Rules.valid_key(parts[3], parts[0]) and records.size() < 430:
				var rows := _record_rows(stored_records[key])
				if not rows.is_empty():
					records[key] = rows
	dirty = false
	apply_keys()
	apply_audio()

func _load_bindings(stored: Dictionary) -> void:
	var assigned := {}
	var used := {}
	for action in keys:
		var code: Variant = stored.get(action)
		if typeof(code) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(code)) and _key_ok(int(code)) and not used.has(int(code)):
			assigned[action] = int(code)
			used[int(code)] = true
	var alternatives := keys.values() + [KEY_X, KEY_V, KEY_K, KEY_U, KEY_Y, KEY_O, KEY_M, KEY_N,
		KEY_P, KEY_B, KEY_C, KEY_F, KEY_H, KEY_J, KEY_L, KEY_T, KEY_5, KEY_6]
	for action in keys:
		if assigned.has(action):
			continue
		var code: int = keys[action]
		if used.has(code):
			for candidate in alternatives:
				if not used.has(candidate):
					code = candidate
					break
		assigned[action] = code
		used[code] = true
	keys = assigned

func _record_rows(raw: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if typeof(raw) in [TYPE_INT, TYPE_FLOAT]:
		raw = [{"score": raw}]
	if not raw is Array:
		return rows
	for entry in raw.slice(0, 20):
		if not entry is Dictionary:
			continue
		var score: int = _bounded_number(entry.get("score"), 1000000000)
		var win: Variant = entry.get("victory", false)
		var wave := _bounded_number(entry.get("wave"), 1000000)
		if score > 0 or wave > 0:
			rows.append({"score": score, "wave": wave, "seconds": _bounded_number(entry.get("seconds"), 86400),
				"kills": _bounded_number(entry.get("kills"), 9999),
				"accuracy": _bounded_number(entry.get("accuracy"), 100),
				"victory": typeof(win) == TYPE_BOOL and win})
	rows.sort_custom(_better)
	if rows.size() > 5:
		rows.resize(5)
	return rows

func _bounded_number(value: Variant, limit: int) -> int:
	if typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)):
		return roundi(clampf(float(value), 0.0, limit))
	return 0

func _better(a: Dictionary, b: Dictionary) -> bool:
	var left: int = a.get("wave", 0)
	var right: int = b.get("wave", 0)
	if left != right and left > 0 and right > 0:
		return left > right
	if a.score != b.score:
		return a.score > b.score
	if a.victory != b.victory:
		return a.victory
	return a.seconds < b.seconds

func category(mode: String, difficulty: String, map_id: String, rules := "") -> String:
	var base := "%s|%s|%s" % [mode, difficulty, map_id]
	return base + "|" + rules if Rules.LABELS.has(mode) and Rules.valid_key(rules, mode) else base

func leaderboard(mode: String, difficulty: String, map_id: String, rules := "") -> Array:
	return records.get(category(mode, difficulty, map_id, rules), [])

func log_result(mode: String, difficulty: String, map_id: String, report: Dictionary) -> bool:
	if not mode in MODES or not difficulty in DIFFICULTIES or not map_id in MAPS or report.score <= 0:
		return false
	var key := category(mode, difficulty, map_id)
	var rows: Array = records.get(key, []).duplicate()
	var best := rows.is_empty() or _better(report, rows[0])
	rows.append(report)
	records[key] = _record_rows(rows)
	save_disk()
	return best

func queue_save() -> void:
	dirty = true
	save_in = 0.42

func profile_action(action: Callable) -> Dictionary:
	var before := profile.data.duplicate(true)
	var pending := dirty
	var result: Dictionary = action.call()
	if not result.ok:
		return result
	if not save_disk():
		profile.restore(before)
		dirty = pending
		return {"ok": false, "message": save_error}
	changed.emit("profile")
	return result

func complete_run(id: String, mode: String, difficulty: String, map_id: String, report: Dictionary) -> Dictionary:
	if mode == "relax" or (Rules.LABELS.has(mode) and not report.get("participated", false)):
		return {"ok": true, "message": "Session libre · aucun gain permanent.", "best": false}
	if mode not in MODES or difficulty not in DIFFICULTIES or map_id not in MAPS:
		return {"ok": false, "message": "Session hors classement."}
	var old_records := records.duplicate(true)
	var before := profile.data.duplicate(true)
	var pending := dirty
	var detail := report.duplicate()
	detail.map = map_id
	var result := profile.settle(id, mode, difficulty, detail)
	if not result.ok:
		return result
	var key := category(mode, difficulty, map_id, report.get("rules", ""))
	var rows: Array = records.get(key, []).duplicate()
	result.best = report.score > 0 and (rows.is_empty() or _better(report, rows[0]))
	if report.score > 0 and (records.has(key) or records.size() < 430):
		rows.append(report)
		records[key] = _record_rows(rows)
	if not save_disk():
		records = old_records
		profile.restore(before)
		dirty = pending
		return {"ok": false, "message": save_error}
	changed.emit("profile")
	return result

func complete_parkour(id: String, report: Dictionary) -> Dictionary:
	if report.get("valid") != true or report.get("route") not in Courses.IDS:
		return {"ok": true, "best": false, "message": "Parcours hors record · recommencez sans raccourci."}
	var route: String = report.route
	var duration := Profile.number(report.get("milliseconds"), 7200000)
	if id.is_empty() or id.length() > 64 or duration < 1000 \
		or report.get("checkpoints") != Courses.ROUTES[route].points.size():
		return {"ok": false, "best": false, "message": "Parcours incomplet."}
	if id in profile.data.settled:
		return {"ok": true, "best": false, "message": "Parcours déjà enregistré."}
	return profile_action(func() -> Dictionary:
		var times: Dictionary = profile.data.career.parkour
		var best := not times.has(route) or duration < int(times[route])
		var progress: Dictionary = profile.data.career.parkour_progress
		var stats: Dictionary = progress.get(route, {"finishes": 0, "clean_finishes": 0})
		var retries := Profile.number(report.get("retries"), 99999)
		stats.finishes = mini(99999, int(stats.finishes) + 1)
		stats.clean_finishes = mini(99999, int(stats.clean_finishes) + int(retries == 0))
		if best:
			times[route] = duration
			stats.record_retries = retries
			stats.erase("ghost")
			var trace := ParkourReplay.sanitize(report.get("trace"), duration)
			if not trace.is_empty():
				stats.ghost = trace
		progress[route] = stats
		profile.data.settled.append(id)
		if profile.data.settled.size() > 128:
			profile.data.settled.pop_front()
		return {"ok": true, "best": best, "message": "Nouveau record personnel." if best else "Parcours enregistré."})

func reset_progression() -> Dictionary:
	if _recognizable(_read(SAVE)) and DirAccess.copy_absolute(profile_file(SAVE), profile_file(RESET_BACKUP)) != OK:
		return {"ok": false, "message": "Impossible de créer la copie de sécurité."}
	return profile_action(func() -> Dictionary:
		profile.restore({"id": profile.data.id, "name": profile.data.name, "career": {
			"parkour": profile.data.career.parkour, "parkour_progress": profile.data.career.parkour_progress}})
		return {"ok": true, "message": "Progression réinitialisée. Réglages et records conservés."})

func _recognizable(document: Dictionary) -> bool:
	return document.get("settings") is Dictionary or document.get("prefs") is Dictionary or document.get("records") is Dictionary

func _profile_version(document: Dictionary) -> int:
	var value: Variant = document.get("version", 0)
	if value is String and value.is_valid_int():
		return clampi(value.to_int(), -1, 1000)
	if typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) \
		and float(value) >= 0.0 and floorf(float(value)) == float(value):
		return int(minf(float(value), 1000.0))
	return -1

func _stamp() -> String:
	var path := profile_file(SAVE)
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""

func save_disk() -> bool:
	dirty = false
	var lock_path := profile_file(LOCK)
	var locked := DirAccess.make_dir_absolute(lock_path)
	if locked != OK:
		var modified := FileAccess.get_modified_time(lock_path)
		if modified > 0 and Time.get_unix_time_from_system() - modified > 30.0:
			DirAccess.remove_absolute(lock_path)
			locked = DirAccess.make_dir_absolute(lock_path)
	if locked != OK:
		return _failed_save("Profil occupé. Réessayez dans un instant.")
	var result := _write_locked()
	DirAccess.remove_absolute(lock_path)
	if not result.is_empty():
		return _failed_save(result)
	disk_stamp = _stamp()
	save_error = ""
	saved.emit(true)
	return true

func _write_locked() -> String:
	if _stamp() != disk_stamp:
		return "Profil modifié par une autre instance. Rouvrez le jeu."
	var previous := _read(SAVE)
	var version := _profile_version(previous)
	var path := profile_file(SAVE)
	var migration_source := path
	if not _recognizable(previous):
		var backup := _read(BACKUP)
		migration_source = profile_file(BACKUP) if _recognizable(backup) else ""
		if not migration_source.is_empty():
			version = _profile_version(backup)
	if version > VERSION:
		return "Ce profil appartient à une version plus récente du jeu."
	var healthy := migration_source == path and version >= 0
	if not healthy and FileAccess.file_exists(path) and not _archive_invalid_profile(path):
		return "Impossible de conserver le profil illisible avant de le remplacer."
	var legacy := profile_file("user://pilot_profile.v5.json" if version == 5 else (V2_BACKUP if version == 3 else LEGACY_BACKUP))
	if not migration_source.is_empty() and version >= 0 and version < VERSION and not FileAccess.file_exists(legacy):
		if DirAccess.copy_absolute(migration_source, legacy) != OK:
			return "Impossible de copier l’ancien profil avant migration."
	var temporary := profile_file(TEMP)
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "Impossible d’ouvrir le fichier temporaire."
	file.store_string(JSON.stringify({"version": VERSION, "settings": values, "bindings": keys,
		"records": records, "progression": profile.data, "touch_layout": touch_layout}, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or _read(TEMP).get("version") != VERSION:
		return "Écriture incomplète du profil."
	if healthy and DirAccess.copy_absolute(path, profile_file(BACKUP)) != OK:
		return "Impossible de créer la copie de secours."
	if DirAccess.rename_absolute(temporary, path) != OK:
		return "Impossible de remplacer le profil."
	return ""

func _archive_invalid_profile(path: String) -> bool:
	if disk_stamp.is_empty():
		return false
	var archive := profile_file("user://pilot_profile.corrupt-%s.json" % disk_stamp)
	if FileAccess.file_exists(archive):
		return FileAccess.get_sha256(archive) == disk_stamp
	var temporary := archive + ".tmp"
	if DirAccess.copy_absolute(path, temporary) == OK and FileAccess.get_sha256(temporary) == disk_stamp \
		and DirAccess.rename_absolute(temporary, archive) == OK:
		return true
	if FileAccess.file_exists(temporary):
		DirAccess.remove_absolute(temporary)
	return false

func _failed_save(message: String) -> bool:
	save_error = message
	push_warning("Rifle Arena • " + message)
	saved.emit(false)
	return false
