extends Control

const Palette := preload("res://ui/skin.gd")
const KeyLabels := {
	"forward": "Avancer", "back": "Reculer", "left": "Aller à gauche", "right": "Aller à droite",
	"jump": "Sauter", "sprint": "Sprinter", "crouch": "S’accroupir et glisser", "reload": "Recharger",
	"interact": "Interagir", "stats": "Journal du pilote", "gadget": "Activer le gadget",
	"inspect": "Inspecter l’arme", "slot_1": "Arme · emplacement 1", "slot_2": "Arme · emplacement 2",
	"slot_3": "Arme · emplacement 3", "slot_4": "Arme · emplacement 4",
}

var close: Callable
var edit_touch: Callable
var active := 0
var scroll: ScrollContainer
var entries: VBoxContainer
var tabs: Array[Button] = []
var capture_action := ""
var capture_box: Panel
var capture_hint: Label
var button_by_action := {}
var status: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Palette.label(self, Rect2(57, 32, 480, 34), "Rifle Arena", 14, Palette.CYAN, Palette.MONO)
	Palette.label(self, Rect2(54, 78, 600, 74), "Paramètres", 59, Palette.TEXT, Palette.HEAD)
	Palette.panel(self, Rect2(55, 167, 248, 410), Palette.PANEL)
	Palette.panel(self, Rect2(326, 167, 899, 410), Palette.PANEL)
	var labels := ["Vidéo", "Audio", "Jeu et confort", "Clavier"]
	labels.append("Tactile")
	for index in labels.size():
		var tab := Palette.button(self, Rect2(67, 180 + index * 53, 222, 44),
			labels[index], show_tab.bind(index))
		tabs.append(tab)
	Palette.label(self, Rect2(73, 452, 204, 89), "Les réglages s’appliquent pendant que vous jouez.", 15, Palette.MUTED,
		Palette.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
	scroll = ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	Palette.at(self, scroll, Rect2(343, 181, 863, 382))
	status = Palette.label(self, Rect2(329, 599, 474, 46), "Enregistrement automatique", 14, Palette.MUTED, Palette.MONO)
	Palette.button(self, Rect2(831, 600, 225, 43), "Réinitialiser", _reset)
	Palette.button(self, Rect2(1069, 600, 155, 43), "Retour", _back, true)
	Prefs.saved.connect(_saved)
	var initial := 4 if Prefs.mobile() else 0
	show_tab(initial)
	tabs[initial].grab_focus()

func show_tab(index: int) -> void:
	active = index
	for i in tabs.size():
		tabs[i].add_theme_color_override("font_color", Palette.CYAN if i == active else Palette.TEXT)
	if is_instance_valid(entries):
		scroll.remove_child(entries)
		entries.queue_free()
	entries = VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 5)
	scroll.add_child(entries)
	scroll.set_deferred("scroll_vertical", 0)
	button_by_action.clear()
	match active:
		0:
			_toggle("Brume de profondeur", "fog")
			_toggle("Météo légère", "weather")
			var low := "Mobile Ultra Léger · 64 %" if Prefs.mobile() else "Ultra faible · 64 %"
			_choice("Qualité graphique", "quality", [low, "Faible · 76 %", "Moyenne · 89 %", "Élevée · 100 %"], [3, 0, 1, 2])
			if not Prefs.mobile():
				_choice("Résolution fenêtrée", "resolution", ["960 × 540", "1280 × 720", "1600 × 900", "1920 × 1080"], [0, 1, 2, 3])
				_toggle("Plein écran", "fullscreen")
				_toggle("Fenêtre sans bordure", "borderless")
				_toggle("Synchronisation verticale", "vsync")
			_toggle("Télémétrie détaillée", "telemetry")
			var limits: Array = Prefs.MOBILE_FPS if Prefs.mobile() else Prefs.FPS_OPTIONS
			var labels := limits.map(func(limit: int): return "%d FPS" % limit if limit > 0 else "Illimitée")
			_choice("Limite d’images par seconde", "fps_limit", labels, limits)
			_toggle("Afficher le compteur FPS", "fps_counter")
			_slider("Taille du HUD", "hud_scale", 0.8, 1.2, 0.05, true)
			_note("Les ombres s’activent en qualité Moyenne. Le mode Élevée ajoute l’anticrénelage 2×.")
		1:
			_slider("Volume général", "master", 0, 1, 0.01, true)
			_slider("Musique", "music", 0, 1, 0.01, true)
			_slider("Effets sonores", "sfx", 0, 1, 0.01, true)
			_slider("Ambiance", "ambience", 0, 1, 0.01, true)
			_toggle("Alarmes sonores", "audio_alerts")
			_toggle("Confirmation des impacts", "audio_hits")
			_toggle("Variation de musique en combat", "audio_dynamic")
			var sample := Button.new()
			sample.text = "Écouter un tir"
			sample.pressed.connect(Sounds.play.bind("pulse"))
			entries.add_child(sample)
		2:
			_choice("Teinte du HUD", "hud_tone", ["Ivoire", "Ardoise", "Sable", "Olive"], [0, 1, 2, 3])
			_toggle("Contraste renforcé du HUD", "high_contrast")
			_slider("Sensibilité souris", "sensitivity", 0.035, 0.7, 0.005)
			_slider("Sensibilité en visée", "ads_sensitivity", 0.25, 1.0, 0.05)
			_toggle("Masque de lunette", "scope_overlay")
			_slider("Ombre autour de la lunette", "scope_shade", 0.10, 0.85, 0.05, true)
			_choice("Forme du réticule", "reticle", ["Croix", "Point", "Cercle"], [0, 1, 2])
			_choice("Couleur du réticule", "reticle_tint", ["Selon l’arme", "Ivoire", "Cyan", "Ambre"], [0, 1, 2, 3])
			_slider("Champ de vision vertical", "fov", 66, 108, 1)
			_toggle("Inverser l’axe vertical", "invert_y")
			_toggle("Oscillation légère en marche", "head_bob")
			_toggle("Caméra stable", "steady_cam")
			_slider("Mouvements de la caméra", "motion_strength", 0, 1, 0.05, true)
			_slider("Réaction à l’atterrissage", "shake", 0, 1, 0.05, true)
			_toggle("Champ de vision dynamique en sprint", "sprint_fov")
			_toggle("Recul visuel de l’équipement", "recoil")
			_slider("Intensité des flashes", "flashes", 0, 1, 0.05, true)
			_slider("Densité des particules", "particles", 0, 1, 0.05, true)
			_toggle("Chiffres de dégâts", "damage_numbers")
			_toggle("Animations des menus", "ui_motion")
		3:
			_choice("Disposition du clavier", "layout", ["AZERTY · ZQSD", "QWERTY · WASD"], [0, 1])
			_toggle("Sprint en bascule", "sprint_toggle")
			_toggle("Accroupissement en bascule", "crouch_toggle")
			_toggle("Glissade à pleine vitesse", "auto_slide")
			_note("Changer de disposition rétablit les touches du profil sélectionné.")
			for action in KeyLabels:
				_binding(action)
			_note("Clic gauche pour tirer, clic droit pour viser. En visant avec le DMR-762, la molette change le grossissement.")
		4:
			var edit := Button.new()
			edit.text = "Modifier la disposition des commandes"
			edit.custom_minimum_size.y = 45
			edit.pressed.connect(edit_touch)
			entries.add_child(edit)
			_toggle("Aide légère à la visée", "touch_aim_assist")
			_choice("Disposition", "touch_preset", ["Personnalisé", "Simple", "Complet", "Gaucher"], [0, 1, 2, 3])
			if Prefs.values.touch_preset == 0:
				_toggle("Interface tactile simplifiée", "touch_compact")
				_toggle("Disposition gaucher", "touch_left")
			_slider("Sensibilité horizontale", "touch_x", 0.25, 3.0, 0.05, true)
			_slider("Sensibilité verticale", "touch_y", 0.25, 3.0, 0.05, true)
			_slider("Courbe de visée", "touch_look_curve", 0.0, 0.75, 0.05, true)
			_choice("Vitesse maximale de visée", "touch_look_limit",
				["Sans limite", "360 °/s", "540 °/s", "720 °/s", "900 °/s"], [0, 360, 540, 720, 900])
			_slider("Zone morte du joystick", "touch_dead", 0.04, 0.35, 0.01, true)
			_slider("Course du joystick", "touch_travel", 0.75, 1.25, 0.05, true)
			_slider("Douceur du joystick", "touch_response", 0.0, 0.75, 0.05, true)
			_toggle("Inverser l’axe vertical", "touch_invert")
			_toggle("Joystick flottant", "touch_float")
			_toggle("Sprint au bout du joystick", "touch_auto_sprint")
			_toggle("Vibrations facultatives", "touch_haptic")
			_note("Touchez Sprint pour l’activer, puis touchez-le à nouveau pour marcher. Le bouton prend la main sur le sprint automatique du joystick jusqu’à la fin de la partie.")
			_note("Glissez sur la flèche vers le bas pour vous accroupir, ou sur le côté pour utiliser le gadget. L’aide à la visée ralentit légèrement le glissement près d’un adversaire visible.")

func _row(caption: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.custom_minimum_size = Vector2(0, 60 if Prefs.mobile() else 49)
	line.add_theme_constant_override("separation", 17)
	var text := Label.new()
	text.text = caption
	text.custom_minimum_size.x = 378
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(text)
	entries.add_child(line)
	return line

func _choice(caption: String, key: String, names: Array, values: Array) -> void:
	var row := _row(caption)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(265, 0)
	for title in names:
		option.add_item(title)
	option.select(values.find(Prefs.values[key]))
	option.item_selected.connect(func(index: int):
		Prefs.change_value(key, values[index])
		if key == "layout":
			_refresh_keys()
		elif key == "touch_preset":
			show_tab.call_deferred(active)
	)
	row.add_child(option)

func _toggle(caption: String, key: String) -> void:
	var row := _row(caption)
	var toggle := CheckButton.new()
	toggle.text = "Activé" if Prefs.values[key] else "Désactivé"
	toggle.button_pressed = Prefs.values[key]
	toggle.custom_minimum_size.x = 158
	toggle.toggled.connect(func(enabled: bool):
		toggle.text = "Activé" if enabled else "Désactivé"
		Prefs.change_value(key, enabled)
	)
	row.add_child(toggle)

func _slider(caption: String, key: String, low: float, high: float, step: float, percent := false) -> void:
	var row := _row(caption)
	var meter := HSlider.new()
	meter.min_value = low
	meter.max_value = high
	meter.step = step
	meter.value = Prefs.values[key]
	meter.custom_minimum_size.x = 210
	var value := Label.new()
	value.custom_minimum_size.x = 72
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_override("font", Palette.MONO)
	value.add_theme_color_override("font_color", Palette.CYAN)
	var format_value := func(amount: float) -> String:
		if percent:
			return "%d %%" % roundi(amount * 100.0)
		return "%d°" % roundi(amount) if key == "fov" else "%.3f" % amount
	value.text = format_value.call(meter.value)
	meter.value_changed.connect(func(amount: float):
		Prefs.change_value(key, amount)
		value.text = format_value.call(amount)
	)
	row.add_child(meter)
	row.add_child(value)

func _note(text: String) -> void:
	var note := Label.new()
	note.text = text
	note.custom_minimum_size.y = 37
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Palette.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entries.add_child(note)

func _binding(action: String) -> void:
	var row := _row(KeyLabels[action])
	var key := Button.new()
	key.custom_minimum_size.x = 154
	key.text = OS.get_keycode_string(Prefs.keys[action])
	key.pressed.connect(_start_binding.bind(action))
	row.add_child(key)
	button_by_action[action] = key

func _refresh_keys() -> void:
	for action in button_by_action:
		button_by_action[action].text = OS.get_keycode_string(Prefs.keys[action])

func _start_binding(action: String) -> void:
	if capture_action != "":
		return
	capture_action = action
	capture_box = Palette.panel(self, Rect2(339, 248, 602, 205), Color("#10232c"), Palette.AMBER)
	capture_box.mouse_filter = Control.MOUSE_FILTER_STOP
	Palette.label(capture_box, Rect2(26, 15, 534, 65), "Affecter une touche", 35, Palette.TEXT, Palette.HEAD)
	capture_hint = Palette.label(capture_box, Rect2(27, 81, 540, 59),
		"Appuyez sur la nouvelle touche pour « %s »." % KeyLabels[action], 17, Palette.MUTED)
	Palette.button(capture_box, Rect2(30, 148, 158, 42), "Annuler · Échap", _cancel_binding)

func _cancel_binding() -> void:
	if capture_action == "":
		return
	var former := capture_action
	capture_action = ""
	capture_box.queue_free()
	capture_box = null
	if button_by_action.has(former):
		button_by_action[former].grab_focus()

func _input(event: InputEvent) -> void:
	if capture_action == "" or not event is InputEventKey or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.keycode == KEY_ESCAPE:
		_cancel_binding()
	elif Prefs.bind_key(capture_action, event.keycode):
		_cancel_binding()
		_refresh_keys()
	else:
		capture_hint.text = "Choisissez une autre touche. Échap annule la saisie."

func _reset() -> void:
	_cancel_binding()
	Prefs.reset_settings()
	show_tab(active)
	status.text = "Réglages d’origine restaurés"

func _saved(success: bool) -> void:
	status.text = "Profil enregistré" if success else "Écriture du profil impossible"

func _back() -> void:
	_cancel_binding()
	if Prefs.dirty:
		Prefs.save_disk()
	close.call()
