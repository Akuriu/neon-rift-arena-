extends Control

const Palette := preload("res://ui/skin.gd")
const Catalog := preload("res://game/catalog.gd")
const Profile := preload("res://services/profile.gd")
const Career := preload("res://services/career.gd")

var app: Node
var page := "history"
var rows: VBoxContainer
var statistics: Label
var data: Dictionary

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	data = Prefs.profile.data
	Palette.panel(self, Rect2(57, 210, 1166, 352), Palette.PANEL)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	Palette.at(self, scroll, Rect2(77, 224, 1126, 320))
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 5)
	scroll.add_child(rows)
	match page:
		"ledger": _ledger()
		"badges": _badges()
		"stats": _statistics()
		_: _history()
	Palette.button(self, Rect2(57, 607, 135, 48), "Profil", app.show_profile.bind("profile"), true).grab_focus()
	Palette.button(self, Rect2(207, 607, 175, 48), "Parties", app.show_career.bind("history"))
	Palette.button(self, Rect2(397, 607, 175, 48), "Transactions", app.show_career.bind("ledger"))
	Palette.button(self, Rect2(587, 607, 175, 48), "Succès", app.show_career.bind("badges"))
	Palette.button(self, Rect2(777, 607, 175, 48), "Statistiques", app.show_career.bind("stats"))

func _line(value: String, height := 48, color := Palette.TEXT) -> void:
	var label := Label.new()
	label.text = value
	label.custom_minimum_size.y = height
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 17)
	rows.add_child(label)

func _history() -> void:
	for run in data.career.history:
		if not Catalog.MAPS.has(run.map):
			continue
		var button := Button.new()
		button.custom_minimum_size.y = 47
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s  /  %s  /  %s   ·   %d pts   ·   %s   ·   +%d XP / +%d pièces   ›" % [
			app._mode_name(run.mode), Catalog.MAPS[run.map].name, Catalog.DIFFICULTIES[run.difficulty].name,
			run.score, Palette.clock(run.seconds), run.xp, run.coins]
		button.tooltip_text = "Rejouer la graine %d" % run.seed if run.mode != "coop" else "Ouvrir le salon coop"
		button.pressed.connect(app.replay_report.bind(run))
		rows.add_child(button)
	if rows.get_child_count() == 0:
		_line("Les prochaines opérations terminées apparaîtront ici.")

func _ledger() -> void:
	_line("SOLDE   %d PIÈCES DU PILOTE" % data.coins, 47, Palette.AMBER)
	for receipt in data.career.ledger:
		_line("%+4d   ·   %s   /   reçu %s" % [receipt.amount, receipt.label, receipt.id.left(8)], 38)
	if data.career.ledger.is_empty():
		_line("Les futurs achats et gains seront enregistrés ici.")

func _badges() -> void:
	for id in Career.Badges:
		var entry: Array = Career.Badges[id]
		var earned: bool = id in data.career.badges
		_line("%s   %s  ·  %s" % ["◆ OBTENU" if earned else "◇ À DÉBLOQUER", entry[0], entry[1]], 45,
			Palette.AMBER if earned else Palette.MUTED)

func _statistics() -> void:
	var select := OptionButton.new()
	select.add_item("Tous les modes")
	for mode in Career.Modes:
		select.add_item(app._mode_name(mode))
	select.custom_minimum_size.y = 47
	rows.add_child(select)
	statistics = Label.new()
	statistics.custom_minimum_size.y = 216
	statistics.add_theme_constant_override("line_spacing", 13)
	rows.add_child(statistics)
	select.item_selected.connect(_show_stats)
	_show_stats(0)

func _show_stats(index: int) -> void:
	var stats: Dictionary = data.stats if index == 0 else data.modes.get(Career.Modes[index - 1], {})
	if stats.is_empty():
		statistics.text = "Aucune opération enregistrée pour ce mode."
		return
	statistics.text = "%d opérations  /  %d victoires  /  %d défaites  /  %d égalités\n%d neutralisations  /  %d boss  /  %d vagues  /  record de vague %d\n%d %% de précision  /  %d tirs  /  %d réussis  /  %s en partie\n%d secondes d’objectif  /  %d mises hors combat\n%d arènes disputées au total" % [
		stats.runs, stats.wins, stats.losses, stats.ties, stats.kills, stats.bosses, stats.waves,
		stats.best_wave, roundi(100.0 * stats.hits / maxi(1, stats.shots)), stats.shots, stats.hits,
		Palette.clock(stats.seconds), stats.objectives, stats.deaths, data.career.maps.size()]
