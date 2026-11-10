extends Control

const Layout := preload("res://ui/mobile/layout.gd")
const Surface := preload("res://ui/mobile/touch_layer.gd")
const Palette := preload("res://ui/skin.gd")

var back: Callable
var diagram: Surface
var selection: OptionButton
var sliders := {}
var edit_id := "stick"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	diagram = Surface.new()
	diagram.preview = true
	Palette.at(self, diagram, Rect2(57, 207, 719, 404))
	diagram.selected.connect(_select)
	diagram.moved.connect(_move)
	Palette.panel(self, Rect2(804, 207, 419, 404), Palette.PANEL)
	selection = OptionButton.new()
	for id in Layout.CONTROLS:
		selection.add_item(Layout.CONTROLS[id][3])
	selection.item_selected.connect(func(index: int): _select(Layout.CONTROLS.keys()[index]))
	Palette.at(self, selection, Rect2(823, 225, 381, 44))
	_slider("x", "Position horizontale", 282, 0.04, 0.96)
	_slider("y", "Position verticale", 347, 0.04, 0.96)
	_slider("size", "Taille", 412, 0.70, 1.48)
	_slider("opacity", "Opacité", 477, 0.35, 1.0)
	Palette.button(self, Rect2(823, 549, 381, 44), "Réinitialiser la disposition", func():
		Prefs.set_touch_layout(Layout.defaults())
		_select(edit_id)
	)
	Palette.button(self, Rect2(57, 620, 214, 43), "Retour", back, true).grab_focus()
	_select(edit_id)

func _slider(key: String, label: String, y: int, low: float, high: float) -> void:
	Palette.label(self, Rect2(824, y, 380, 28), label, 15, Palette.MUTED, Palette.MONO)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01
	slider.value_changed.connect(_change.bind(key))
	Palette.at(self, slider, Rect2(824, y + 31, 375, 26))
	sliders[key] = slider

func _select(id: String) -> void:
	edit_id = id
	diagram.active_edit = id
	selection.select(Layout.CONTROLS.keys().find(id))
	for key in sliders:
		sliders[key].set_value_no_signal(Prefs.touch_layout[id][key])
	diagram.queue_redraw()

func _change(amount: float, key: String) -> void:
	var layout: Dictionary = Prefs.touch_layout.duplicate(true)
	layout[edit_id][key] = amount
	Prefs.set_touch_layout(layout)

func _move(id: String, x: float, y: float) -> void:
	var layout: Dictionary = Prefs.touch_layout.duplicate(true)
	layout[id].x = x
	layout[id].y = y
	Prefs.set_touch_layout(layout)
	_select(id)
