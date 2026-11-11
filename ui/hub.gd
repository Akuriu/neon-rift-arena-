extends Control

const Palette := preload("res://ui/skin.gd")
const Arms := preload("res://game/weapons/catalog.gd")
const Profile := preload("res://services/profile.gd")
const Career := preload("res://services/career.gd")
const WeaponPreview := preload("res://ui/weapon_preview.gd")
const MotionButton := preload("res://ui/design/components/motion_button.gd")
const Tokens := preload("res://ui/design/tokens.gd")
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
var viewer: WeaponPreview
var class_filter: OptionButton
var category_buttons := {}
var item_buttons := {}
var list: VBoxContainer
var detail: Control
var information: Control
var balance: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Palette.panel(self, Rect2(56, 189, 1168, 431), Palette.PANEL)
	var x := 70
	for group in GROUPS:
		var button := Palette.button(self, Rect2(x, 203, 154, 43), group, _category.bind(group))
		button.theme_type_variation = &"SelectedTab" if group == category else &""
		category_buttons[group] = button
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		x += 164
	balance = Palette.label(self, Rect2(910, 203, 296, 43), "", 18, Palette.AMBER, Palette.BOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	var classes := OptionButton.new()
	class_filter = classes
	classes.add_item("Toutes")
	for kind in ["Automatique", "Fusil à pompe", "Pistolet", "Lance-grenades", "Précision", "Mitraillette"]:
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
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	Palette.at(self, scroll, Rect2(70, 307, 366, 296))
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	scroll.add_child(list)
	detail = Control.new()
	Palette.at(self, detail, Rect2(459, 256, 746, 347))
	Palette.panel(detail, Rect2(0, 0, 746, 347), Tokens.RAISED)
	information = Control.new()
	information.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Palette.at(detail, information, Rect2(0, 0, 746, 347))
	Palette.button(self, Rect2(56, 630, 136, 40), "Retour", app.menu).grab_focus()
	Palette.button(self, Rect2(205, 630, 190, 40), "Boutique" if page == "arsenal" else "Arsenal",
		app.open_hub.bind("shop" if page == "arsenal" else "arsenal"))
	Palette.button(self, Rect2(407, 630, 175, 40), "Profil du pilote", app.show_profile.bind("profile"))
	var presets := OptionButton.new()
	presets.add_item("Configuration rapide")
	var ids: Array = Career.Presets.keys() + ["save", "own"]
	for id in ids:
		presets.add_item(Career.Presets[id].name if Career.Presets.has(id)
			else ("Enregistrer mes choix" if id == "save" else "Rétablir mes choix"))
	presets.set_item_disabled(0, true)
	presets.item_selected.connect(func(i: int):
		var result := Prefs.profile_action(Prefs.profile.loadout.bind(ids[i - 1]))
		notice = result.message
		presets.select(0)
		_rebuild()
	)
	Palette.at(self, presets, Rect2(597, 630, 265, 40))
	Palette.button(self, Rect2(875, 630, 160, 40), "Transactions", app.show_career.bind("ledger"))
	_rebuild()

func _category(group: String) -> void:
	if category == group:
		return
	category_buttons[category].theme_type_variation = &""
	category = group
	category_buttons[category].theme_type_variation = &"SelectedTab"
	class_filter.disabled = category != "Armes"
	_rebuild()

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
	var focused := get_viewport().gui_get_focus_owner()
	var restore := is_instance_valid(focused) and list.is_ancestor_of(focused)
	_empty(list)
	item_buttons.clear()
	var ids := _entries()
	if selected not in ids:
		selected = ids.front() if not ids.is_empty() else ""
	for id in ids:
		var item := Profile.item(id)
		var label := MotionButton.new()
		var cost := "Vague %d" % item.wave if item.has("wave") else "%d pièces" % item.price
		label.text = "%s   ·   %s" % [item.name, "Acquis" if Prefs.profile.owns(id) else cost]
		label.alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.custom_minimum_size.y = 40
		label.theme_type_variation = &"SelectedTab" if id == selected else &""
		label.bind_action(_select.bind(id))
		list.add_child(label)
		item_buttons[id] = label
		if restore and id == selected:
			label.grab_focus()
	_show_detail()

func _select(id: String) -> void:
	if id == selected:
		return
	if item_buttons.has(selected):
		item_buttons[selected].theme_type_variation = &""
	selected = id
	item_buttons[selected].theme_type_variation = &"SelectedTab"
	_show_detail()

func _show_detail() -> void:
	preview = null
	_empty(information)
	if is_instance_valid(viewer):
		viewer.hide()
	if selected.is_empty():
		Palette.label(information, Rect2(24, 23, 685, 38), "Aucun article dans cette classe", 24, Palette.TEXT, Palette.HEAD)
		return
	var item := Profile.item(selected)
	var index := Arms.index_of(selected)
	var owned: bool = Prefs.profile.owns(selected)
	Palette.label(information, Rect2(23, 12, 694, 49), item.name, 34, Palette.TEXT, Palette.HEAD)
	var text_width := 440 if index >= 0 else 688
	var description := RichTextLabel.new()
	description.text = item.info
	description.scroll_active = false
	description.mouse_filter = MOUSE_FILTER_IGNORE
	description.add_theme_font_override("normal_font", Palette.BODY)
	description.add_theme_font_size_override("normal_font_size", 16)
	description.add_theme_color_override("default_color", Palette.MUTED)
	Palette.at(information, description, Rect2(24, 71, text_width, 59))
	if index >= 0:
		_preview(index)
		Palette.label(information, Rect2(24, 133, 455, 26),
			"%d dégâts  ·  %d cartouches  ·  %d m" % [roundi(item.damage), item.mag, roundi(item.range)], 14, item.tint, Palette.MONO)
		var points: int = Prefs.profile.data.mastery.get(selected, 0)
		var mastery := mini(30, 1 + floori(sqrt(float(points) / 45.0)))
		Palette.label(information, Rect2(24, 161, 450, 25), "Maîtrise %d  ·  %d tirs" % [mastery, points], 13, Palette.MUTED, Palette.MONO)
		var active_id: String = Prefs.profile.data.slots[slot]
		var active := Profile.item(active_id)
		Palette.label(information, Rect2(24, 185, 445, 36),
			"S%d  %s   %+d dégâts  ·  %+d cartouches  ·  %+.2fs" % [slot + 1, active.name,
			roundi(item.damage - active.damage), int(item.mag) - int(active.mag), item.cadence - active.cadence],
			12, Palette.TEXT, Palette.MONO)
		var slots := OptionButton.new()
		for name in ["Principale  1", "Secondaire  2", "Appui  3", "Lourde  4"]:
			slots.add_item(name)
		slots.select(slot)
		slots.item_selected.connect(func(i: int):
			slot = i
			_show_detail()
		)
		Palette.at(information, slots, Rect2(24, 223, 205, 42))
		Palette.button(information, Rect2(455, 274, 265, 44), "Tester au stand", app.practice_weapon.bind(selected))
	if not owned:
		var text := "Récompense · vague %d" % item.wave if item.has("wave") else "Débloquer · %d pièces" % item.price
		var buy := Palette.button(information, Rect2(24, 274, 280, 44), text, _buy.bind(selected), true)
		buy.disabled = Prefs.profile.data.coins < int(item.price) or Prefs.profile.data.stats.best_wave < item.get("wave", 0)
		if buy.disabled and not item.has("wave"):
			Palette.label(information, Rect2(312, 274, 139, 44), "Solde insuffisant", 13, Palette.MUTED)
	elif index >= 0 or not selected.begins_with("perk_"):
		var equipped: bool = selected in Prefs.profile.data.slots or selected in [
			Prefs.profile.data.gadget, Prefs.profile.data.module, Prefs.profile.data.skin]
		var action := "Équiper / retirer" if equipped and selected.begins_with("mod_") else "Équiper"
		Palette.button(information, Rect2(24, 274, 280, 44), action, _equip.bind(selected), true)
		if equipped:
			Palette.label(information, Rect2(313, 274, 133, 44), "EN SERVICE", 12, Palette.CYAN, Palette.MONO)
	else:
		Palette.label(information, Rect2(24, 274, 330, 43), "AVANTAGE ACTIF", 15, Palette.CYAN, Palette.MONO)
	Palette.label(information, Rect2(24, 319, 688, 23), notice, 13, Palette.AMBER)

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

func _preview(index: int) -> void:
	if not is_instance_valid(viewer):
		viewer = WeaponPreview.new()
		viewer.name = "WeaponPreview"
		viewer.equipment = index
		viewer.skin = Prefs.profile.data.skin
		Palette.at(detail, viewer, Rect2(466, 69, 254, 172))
	else:
		viewer.show_equipment(index, Prefs.profile.data.skin)
		viewer.show()
	preview = viewer.model
	Palette.label(information, Rect2(466, 242, 254, 25), "Glisser · pincer / molette", 12, Palette.MUTED)
