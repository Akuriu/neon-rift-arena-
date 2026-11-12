extends RefCounted

const Palette := preload("res://ui/skin.gd")
const Tokens := preload("res://ui/design/tokens.gd")
const Metrics := preload("res://ui/design/components/metric_row.gd")
const Link := preload("res://ui/design/components/navigation_link.gd")
const Catalog := preload("res://game/catalog.gd")
const Profile := preload("res://services/profile.gd")
const Career := preload("res://services/career.gd")

static func overview(view: Control, data: Dictionary, rename: Callable, reset: Callable) -> void:
	var level := Profile.level(data.xp)
	var next_level := level * level * 80
	var current_level := (level - 1) * (level - 1) * 80
	var rank := Palette.panel(view, Rect2(57, 207, 685, 183), Tokens.RAISED)
	Palette.label(rank, Rect2(23, 11, 380, 32), "Niveau", 16, Tokens.ACCENT, Palette.BOLD)
	Palette.label(rank, Rect2(21, 38, 360, 62), "%02d" % level, 48, Tokens.TEXT, Palette.MONO)
	var rank_caption := "Niveau maximum" if level == 500 else "%d XP avant le niveau %d" % [next_level - data.xp, level + 1]
	Palette.label(rank, Rect2(23, 137, 638, 31), rank_caption, 17, Tokens.TEXT)
	_progress_bar(rank, Rect2(23, 112, 639, 8),
		1.0 if level == 500 else float(data.xp - current_level) / (next_level - current_level), rank_caption)

	var wallet := Palette.panel(view, Rect2(755, 207, 468, 183))
	Palette.label(wallet, Rect2(23, 11, 422, 32), "Pièces du pilote", 16, Tokens.ACCENT, Palette.BOLD)
	Palette.label(wallet, Rect2(21, 38, 425, 62), str(data.coins), 44, Tokens.TEXT, Palette.MONO)
	Palette.rule(wallet, Rect2(23, 115, 422, 1))
	Palette.label(wallet, Rect2(23, 137, 422, 31), "%d XP au total" % data.xp, 17, Tokens.MUTED)

	var stats: Dictionary = data.stats
	Metrics.build(view, Rect2(57, 405, 1166, 83), [
		["Parties", str(stats.runs)], ["Victoires", str(stats.wins)], ["Neutralisations", str(stats.kills)],
		["Boss", str(stats.bosses)], ["Meilleure vague", str(stats.best_wave)],
		["Précision", "%d %%" % roundi(100.0 * stats.hits / maxi(1, stats.shots))],
	])
	Palette.label(view, Rect2(57, 493, 1166, 32), "%d tirs  ·  %d CR dépensés" % [stats.shots, stats.spent],
		15, Tokens.MUTED)
	var name := LineEdit.new()
	name.text = data.name
	name.max_length = 18
	name.accessibility_name = "Nom du pilote"
	Palette.at(view, name, Rect2(57, 535, 305, 45))
	Palette.button(view, Rect2(374, 535, 256, 45), "Enregistrer le nom", rename.bind(name))
	Palette.button(view, Rect2(907, 535, 316, 45), "Réinitialiser la progression", reset)

static func contracts(view: Control, data: Dictionary, claim_daily: Callable, claim_week: Callable) -> void:
	var y := 205
	for id in Profile.CONTRACTS:
		var item: Dictionary = Profile.CONTRACTS[id]
		_contract(view, y, item.name, data.contracts.progress[id], item, data.contracts.claimed[id], claim_daily.bind(id))
		y += 94
	var weekly: Dictionary = data.career.weekly
	var challenge := Career.challenge(weekly.period)
	_contract(view, y, challenge[0], weekly.value, {"goal": challenge[2], "coins": 70, "xp": 150},
		weekly.claimed, claim_week, true)

static func _contract(view: Control, y: int, title: String, value: int, reward: Dictionary,
		claimed: bool, claim: Callable, weekly := false) -> void:
	var card := Palette.panel(view, Rect2(57, y, 1166, 85))
	var caption := "%d / %d" % [value, reward.goal]
	Palette.label(card, Rect2(19, 8, 437, 38), title, 24, Tokens.TEXT, Palette.HEAD)
	Palette.label(card, Rect2(19, 47, 437, 25), "Hebdomadaire  ·  " + caption if weekly else caption,
		14, Tokens.MUTED)
	_progress_bar(card, Rect2(470, 55, 341, 6), float(value) / reward.goal, caption)
	Palette.label(card, Rect2(470, 17, 360, 32), "+%d pièces  ·  +%d XP" % [reward.coins, reward.xp],
		16, Tokens.ACCENT, Palette.MONO)
	var action := Palette.button(card, Rect2(872, 18, 274, 48),
		"Encaissé" if claimed else ("Encaisser la semaine" if weekly else "Encaisser"), claim)
	action.disabled = claimed or value < reward.goal
	action.accessibility_name = "%s · %s" % [action.text, title]

static func records(view: Control, saved: Dictionary, mode_name: Callable) -> void:
	Palette.panel(view, Rect2(57, 207, 1166, 370))
	var entries := []
	for key in saved:
		var parts: PackedStringArray = key.split("|")
		var rows: Array = saved[key]
		if rows.is_empty():
			continue
		var label := "%s  ·  %s  ·  %s" % [mode_name.call(parts[0]), Catalog.MAPS[parts[2]].name, Catalog.DIFFICULTIES[parts[1]].name]
		if parts.size() == 4:
			var options := parts[3].split("-")
			label += "  ·  %s bots / %d min / %s pts" % [options[0], int(options[1]) / 60, options[2]]
			if options.size() == 4:
				label += "  ·  Armes mélangées"
		entries.append({"label": label, "score": int(rows[0].score), "wave": int(rows[0].wave)})
	if entries.is_empty():
		Link.add_icon(view, Rect2(609, 288, 62, 62), "progress", Tokens.ACCENT)
		Palette.label(view, Rect2(207, 357, 866, 51), "Aucun score enregistré", 30, Tokens.TEXT, Palette.HEAD,
			HORIZONTAL_ALIGNMENT_CENTER)
		Palette.label(view, Rect2(207, 414, 866, 41), "Terminez une opération classée pour afficher votre premier score.",
			17, Tokens.MUTED, Palette.BODY, HORIZONTAL_ALIGNMENT_CENTER)
		return
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return a.score > b.score)
	Palette.label(view, Rect2(80, 222, 163, 32), "Score", 15, Tokens.ACCENT, Palette.BOLD)
	Palette.label(view, Rect2(255, 222, 789, 32), "Opération", 15, Tokens.ACCENT, Palette.BOLD)
	Palette.label(view, Rect2(1050, 222, 133, 32), "Vagues", 15, Tokens.ACCENT, Palette.BOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	Palette.rule(view, Rect2(80, 258, 1118, 1))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	Palette.at(view, scroll, Rect2(80, 268, 1118, 289))
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)
	for entry in entries:
		var row := Panel.new()
		row.custom_minimum_size.y = 43
		row.tooltip_text = entry.label
		row.add_theme_stylebox_override("panel", Palette.box(Tokens.RAISED, Color.TRANSPARENT))
		rows.add_child(row)
		Palette.label(row, Rect2(12, 0, 150, 43), str(entry.score), 17, Tokens.TEXT, Palette.MONO)
		var label := Palette.label(row, Rect2(175, 0, 783, 43), entry.label, 15, Tokens.TEXT)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		Palette.label(row, Rect2(970, 0, 133, 43), str(entry.wave) if entry.wave > 0 else "—", 16,
			Tokens.MUTED, Palette.MONO, HORIZONTAL_ALIGNMENT_RIGHT)

static func _progress_bar(parent: Control, area: Rect2, progress: float, caption: String) -> void:
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.0
	bar.value = clampf(progress, 0.0, 1.0)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.accessibility_name = caption
	for role in ["background", "fill"]:
		var ink := Tokens.ACCENT if role == "fill" else Tokens.BACKGROUND
		var style := Palette.box(ink, Color.TRANSPARENT, 3, 0)
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			style.set_content_margin(side, 0.0)
		bar.add_theme_stylebox_override(role, style)
	Palette.at(parent, bar, area)
