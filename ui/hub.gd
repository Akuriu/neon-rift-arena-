extends Control

const Palette := preload("res://ui/skin.gd")
const Arms := preload("res://game/weapons/catalog.gd")
const Profile := preload("res://services/profile.gd")
const Models := preload("res://game/weapon_models.gd")
const GROUPS := ["Armes", "Gadgets", "Modules", "Apparences", "Améliorations"]

var app: Node
var page := "shop"
var category := "Armes"
var selected := ""
var filtering := "Toutes"
var sorting := 0
var slot := 0
var notice := ""
var preview: Node3D
var container: Control
var list: VBoxContainer
var detail: Control
var balance: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Palette.panel(self, Rect2(56, 189, 1168, 431), Color("#101e27"))
	var x := 70
	for group in GROUPS:
		var button := Palette.button(self, Rect2(x, 203, 154, 43), group, _category.bind(group), group == category)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		x += 164
	balance = Palette.label(self, Rect2(910, 203, 296, 43), "", 18, Palette.AMBER, Palette.BOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	var classes := OptionButton.new()
	classes.add_item("Toutes")
	for kind in ["Automatique", "Dispersion", "Rafale", "Zone", "Précision", "Soutien"]:
		classes.add_item(kind)
		if kind == filtering:
			classes.select(classes.item_count - 1)
	classes.disabled = category != "Armes"
	classes.item_selected.connect(func(i: int):
		filtering = classes.get_item_text(i)
		_rebuild()
	)
	Palette.at(self, classes, Rect2(70, 255, 178, 41))
	var sort := OptionButton.new()
	for name in ["Nom", "Prix croissant", "À débloquer"]:
		sort.add_item(name)
	sort.select(sorting)
	sort.item_selected.connect(func(i: int):
		sorting = i
		_rebuild()
	)
	Palette.at(self, sort, Rect2(256, 255, 180, 41))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	Palette.at(self, scroll, Rect2(70, 307, 366, 296))
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	scroll.add_child(list)
	detail = Control.new()
	Palette.at(self, detail, Rect2(459, 256, 746, 347))
	Palette.button(self, Rect2(56, 630, 136, 40), "Retour", app.menu).grab_focus()
	Palette.button(self, Rect2(205, 630, 190, 40), "Contrats locaux", app.show_profile.bind("contracts"))
	Palette.button(self, Rect2(407, 630, 175, 40), "Profil du pilote", app.show_profile.bind("profile"))
	_rebuild()

func _category(group: String) -> void:
	app.open_hub(page, group, "", notice)

func _entries() -> Array[String]:
	var ids: Array[String] = []
	if category == "Armes":
		for item in Arms.WEAPONS:
			if filtering == "Toutes" or item.class == filtering:
				ids.append(item.id)
	else:
		for id in Profile.GEAR:
			if Profile.GEAR[id].class == category:
				ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		if sorting == 1 and Profile.item(a).price != Profile.item(b).price:
			return int(Profile.item(a).price) < int(Profile.item(b).price)
		if sorting == 2 and Prefs.profile.owns(a) != Prefs.profile.owns(b):
			return not Prefs.profile.owns(a)
		return String(Profile.item(a).name) < String(Profile.item(b).name)
	)
	return ids

func _empty(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _rebuild() -> void:
	balance.text = "%d  PIÈCES DU PILOTE" % Prefs.profile.data.coins
	_empty(list)
	var ids := _entries()
	if selected not in ids:
		selected = ids.front() if not ids.is_empty() else ""
	for id in ids:
		var item := Profile.item(id)
		var label := Button.new()
		label.text = "%s   ·   %s" % [item.name, "Acquis" if Prefs.profile.owns(id) else "%d pièces" % item.price]
		label.alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.custom_minimum_size.y = 40
		if id == selected:
			label.add_theme_color_override("font_color", Palette.CYAN)
		label.pressed.connect(func():
			selected = id
			_rebuild()
		)
		list.add_child(label)
	_show_detail()

func _show_detail() -> void:
	preview = null
	_empty(detail)
	Palette.panel(detail, Rect2(0, 0, 746, 347), Color("#142b34"))
	if selected.is_empty():
		Palette.label(detail, Rect2(24, 23, 685, 38), "Aucun article dans cette classe", 24, Palette.TEXT, Palette.HEAD)
		return
	var item := Profile.item(selected)
	var index := Arms.index_of(selected)
	var owned: bool = Prefs.profile.owns(selected)
	Palette.label(detail, Rect2(23, 12, 694, 49), item.name, 34, Palette.TEXT, Palette.HEAD)
	var text_width := 440 if index >= 0 else 688
	var description := RichTextLabel.new()
	description.text = item.info
	description.scroll_active = false
	description.mouse_filter = MOUSE_FILTER_IGNORE
	description.add_theme_font_override("normal_font", Palette.BODY)
	description.add_theme_font_size_override("normal_font_size", 16)
	description.add_theme_color_override("default_color", Palette.MUTED)
	Palette.at(detail, description, Rect2(24, 71, text_width, 59))
	if index >= 0:
		_preview(index, item.tint)
		Palette.label(detail, Rect2(24, 133, 455, 26),
			"%d IMPACT  /  %d CHARGES  /  %d m" % [roundi(item.damage), item.mag, roundi(item.range)], 14, item.tint, Palette.MONO)
		var points: int = Prefs.profile.data.mastery.get(selected, 0)
		var mastery := mini(30, 1 + floori(sqrt(float(points) / 45.0)))
		Palette.label(detail, Rect2(24, 161, 450, 25), "MAÎTRISE %02d   /   %d IMPULSIONS" % [mastery, points], 13, Palette.MUTED, Palette.MONO)
		var active_id: String = Prefs.profile.data.slots[slot]
		var active := Profile.item(active_id)
		Palette.label(detail, Rect2(24, 191, 445, 28),
			"EMPLACEMENT %d  ·  %s  (%+d impact)" % [slot + 1, active.name, roundi(item.damage - active.damage)], 13, Palette.TEXT, Palette.MONO)
		var slots := OptionButton.new()
		for name in ["Principale  1", "Secondaire  2", "Appui  3", "Lourde  4"]:
			slots.add_item(name)
		slots.select(slot)
		slots.item_selected.connect(func(i: int):
			slot = i
			_show_detail()
		)
		Palette.at(detail, slots, Rect2(24, 223, 205, 42))
		Palette.button(detail, Rect2(455, 274, 265, 44), "Tester au stand", app.practice_weapon.bind(selected))
	if not owned:
		var buy := Palette.button(detail, Rect2(24, 274, 280, 44), "Débloquer · %d pièces" % item.price, _buy.bind(selected), true)
		buy.disabled = Prefs.profile.data.coins < int(item.price)
		if buy.disabled:
			Palette.label(detail, Rect2(312, 274, 139, 44), "Solde insuffisant", 13, Palette.MUTED)
	elif index >= 0 or not selected.begins_with("perk_"):
		var equipped: bool = selected in Prefs.profile.data.slots or selected in [
			Prefs.profile.data.gadget, Prefs.profile.data.module, Prefs.profile.data.skin]
		var action := "Équiper / retirer" if equipped and selected.begins_with("mod_") else "Équiper"
		Palette.button(detail, Rect2(24, 274, 280, 44), action, _equip.bind(selected), true)
		if equipped:
			Palette.label(detail, Rect2(313, 274, 133, 44), "EN SERVICE", 12, Palette.CYAN, Palette.MONO)
	else:
		Palette.label(detail, Rect2(24, 274, 330, 43), "AVANTAGE ACTIF", 15, Palette.CYAN, Palette.MONO)
	Palette.label(detail, Rect2(24, 319, 688, 23), notice, 13, Palette.AMBER)

func _buy(id: String) -> void:
	if int(Profile.item(id).price) >= 100:
		app.confirm("Débloquer %s ?" % Profile.item(id).name,
			"Le prix de %d pièces sera prélevé sur le profil." % Profile.item(id).price,
			app.buy_from_hub.bind(page, category, id), app.open_hub.bind(page, category, id, ""))
		return
	_apply_purchase(id)

func _apply_purchase(id: String) -> void:
	var receipt := Prefs.profile_action(Prefs.profile.buy.bind(id))
	notice = receipt.message
	if receipt.ok:
		Sounds.play("upgrade")
	_rebuild()

func _equip(id: String) -> void:
	var receipt := Prefs.profile_action(Prefs.profile.equip.bind(id, slot))
	notice = receipt.message
	_rebuild()

func _preview(index: int, color: Color) -> void:
	var surface := SubViewportContainer.new()
	surface.stretch = true
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Palette.at(detail, surface, Rect2(466, 69, 254, 190))
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	surface.add_child(viewport)
	preview = Node3D.new()
	viewport.add_child(preview)
	Models.make(preview, index, color, Prefs.profile.data.skin)
	preview.rotation.y = 0.66
	var camera := Camera3D.new()
	camera.fov = 39
	camera.position = Vector3(0.89, 0.49, 1.42)
	viewport.add_child(camera)
	camera.look_at(Vector3(0, 0.03, -0.08))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-44, 27, 0)
	light.light_energy = 1.5
	viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_color = Color("#9accee")
	fill.light_energy = 0.8
	viewport.add_child(fill)

func _process(delta: float) -> void:
	if is_instance_valid(preview):
		preview.rotate_y(delta * 0.48)
