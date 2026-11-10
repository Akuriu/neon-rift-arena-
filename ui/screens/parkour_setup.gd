extends RefCounted

const Palette := preload("res://ui/skin.gd")
const Courses := preload("res://game/modes/parkour_routes.gd")

func build(parent: Control, launch: Callable) -> void:
	for i in Courses.IDS.size():
		var id: String = Courses.IDS[i]
		var route: Dictionary = Courses.ROUTES[id]
		var x := 57 + i * 396
		Palette.panel(parent, Rect2(x, 218, 374, 337), Palette.PANEL)
		Palette.label(parent, Rect2(x + 21, 237, 330, 27), "0%d / %s" % [i + 1, route.level], 13, Palette.AMBER, Palette.MONO)
		Palette.label(parent, Rect2(x + 19, 284, 338, 46), route.name, 29, Palette.TEXT, Palette.HEAD)
		Palette.label(parent, Rect2(x + 22, 349, 327, 102), route.copy, 18, Palette.MUTED,
			Palette.BODY, HORIZONTAL_ALIGNMENT_LEFT, true)
		var best: int = Prefs.profile.data.career.parkour.get(id, 0)
		Palette.label(parent, Rect2(x + 22, 454, 327, 33), "Record · " + Courses.clock(best) if best > 0 else "Premier passage", 16, Palette.AMBER, Palette.MONO)
		var button := Palette.button(parent, Rect2(x + 20, 493, 334, 47), "Lancer le parcours", launch.bind(id), i == 0)
		button.accessibility_name = route.name
		if i == 0:
			button.grab_focus()
