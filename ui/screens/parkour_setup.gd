extends RefCounted

const Palette := preload("res://ui/skin.gd")
const Courses := preload("res://game/modes/parkour_routes.gd")

func build(parent: Control, launch: Callable) -> void:
	var ghost := CheckButton.new()
	ghost.text = "Fantôme du record"
	ghost.button_pressed = true
	ghost.tooltip_text = "Afficher votre trajectoire lors du meilleur temps si elle a été enregistrée."
	Palette.at(parent, ghost, Rect2(932, 581, 290, 53))
	for i in Courses.IDS.size():
		var id: String = Courses.IDS[i]
		var route: Dictionary = Courses.ROUTES[id]
		var x := 57 + i * 396
		Palette.panel(parent, Rect2(x, 218, 374, 337), Palette.PANEL)
		Palette.label(parent, Rect2(x + 21, 237, 330, 27), "0%d / %s" % [i + 1, route.level], 13, Palette.AMBER, Palette.MONO)
		Palette.label(parent, Rect2(x + 19, 284, 338, 46), route.name, 29, Palette.TEXT, Palette.HEAD)
		Palette.label(parent, Rect2(x + 22, 331, 327, 90), route.copy, 17, Palette.MUTED,
			Palette.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
		var best: int = Prefs.profile.data.career.parkour.get(id, 0)
		var medal := Courses.medal(id, best)
		var record := Courses.clock(best) if best > 0 else "Premier passage"
		if not medal.is_empty():
			record += " · " + medal
		var progress: Dictionary = Prefs.profile.data.career.parkour_progress.get(id, {})
		Palette.label(parent, Rect2(x + 22, 421, 327, 33), record, 17, Palette.AMBER, Palette.MONO)
		Palette.label(parent, Rect2(x + 22, 454, 327, 29), "%d arrivée(s) · Or ≤ %s" % [
			progress.get("finishes", 0), Courses.clock(Courses.MEDAL_TIMES[id][0])], 14, Palette.MUTED, Palette.MONO)
		var button := Palette.button(parent, Rect2(x + 20, 493, 334, 47), "Lancer le parcours",
			func(): launch.call(id, ghost.button_pressed), i == 0)
		button.accessibility_name = route.name
		if i == 0:
			button.grab_focus()
