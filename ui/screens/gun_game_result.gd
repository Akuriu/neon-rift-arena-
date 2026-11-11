extends RefCounted

const Palette := preload("res://ui/skin.gd")

func build(view: Control, match_state: Node, record: int, best: bool, accuracy: int) -> void:
	Palette.panel(view, Rect2(57, 215, 420, 278), Palette.PANEL)
	Palette.label(view, Rect2(80, 227, 374, 34), "VOTRE SCORE", 14, Palette.MUTED, Palette.MONO)
	Palette.label(view, Rect2(75, 263, 374, 76), "%d / 8" % match_state.score, 62, Palette.TEXT, Palette.MONO)
	Palette.label(view, Rect2(80, 356, 374, 35), "%s · %d / 8" % [
		"Nouveau record" if best else "Record local", record], 21, Palette.AMBER, Palette.BOLD)
	Palette.label(view, Rect2(80, 400, 374, 30), "%s  ·  %d %% de précision" % [
		Palette.clock(match_state.elapsed), accuracy], 18, Palette.TEXT)
	Palette.label(view, Rect2(80, 442, 374, 30), "%d mise(s) hors combat" % match_state.deaths, 17, Palette.MUTED)

	Palette.panel(view, Rect2(493, 215, 730, 278), Palette.PANEL)
	Palette.label(view, Rect2(515, 227, 686, 32), "CLASSEMENT DU MATCH", 14, Palette.MUTED, Palette.MONO)
	var rows: Array[Dictionary] = match_state.standings()
	for index in rows.size():
		var entry := rows[index]
		var x := 515 if index < 7 else 867
		var y := 264 + (index % 7) * 30
		var player: bool = entry.slot == 0
		if player:
			Palette.panel(view, Rect2(x, y, 332, 28), Palette.BASE, Palette.AMBER)
		Palette.label(view, Rect2(x + 9, y, 217, 28), "%02d    %s" % [
			entry.rank, "Vous" if player else "Bot %02d" % entry.slot], 16, Palette.TEXT, Palette.MONO)
		Palette.label(view, Rect2(x + 226, y, 92, 28), "%d / 8" % entry.score, 16,
			Palette.AMBER if player else Palette.MUTED, Palette.MONO, HORIZONTAL_ALIGNMENT_RIGHT)
