extends Control

const Layout := preload("res://ui/mobile/layout.gd")
const Surface := preload("res://ui/mobile/touch_layer.gd")
const Palette := preload("res://ui/skin.gd")

var back: Callable
var diagram: Surface
var selection: OptionButton
var sliders := {}
var edit_id := "stick"
var inspector: Control
var expand_button: Button
var return_button: Button
var full_preview := false
const PREVIEW_RECT := Rect2(57, 207, 719, 404)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	diagram = Surface.new()
	diagram.preview = true
	diagram.preview_image = load("res://assets/maps/skyline.jpg")
	Palette.at(self, diagram, PREVIEW_RECT)
	diagram.selected.connect(_select)
	diagram.moved.connect(_move)
	inspector = Control.new()
	inspector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inspector)
	Palette.panel(inspector, Rect2(804, 207, 419, 404), Palette.PANEL)
	selection = OptionButton.new()
	for id in Layout.CONTROLS:
		selection.add_item(Layout.CONTROLS[id][3])
	selection.item_selected.connect(func(index: int): _select(Layout.CONTROLS.keys()[index]))
	Palette.at(inspector, selection, Rect2(823, 225, 381, 44))
	_slider("x", "Position horizontale", 282, 0.04, 0.96)
	_slider("y", "Position verticale", 347, 0.04, 0.96)
	_slider("size", "Taille", 412, 0.70, 1.48)
	_slider("opacity", "Opacité", 477, 0.35, 1.0)
	Palette.button(inspector, Rect2(823, 549, 186, 44), "Rétablir ce bouton", _reset_one)
	Palette.button(inspector, Rect2(1017, 549, 187, 44), "Rétablir tout", func():
		Prefs.set_touch_layout(Layout.defaults())
		_select(edit_id)
	)
	return_button = Palette.button(self, Rect2(57, 620, 214, 43), "Retour", back, true)
	expand_button = Palette.button(self, Rect2(289, 620, 272, 43), "Aperçu plein écran", _expand)
	return_button.grab_focus()
	get_parent().resized.connect(_fit_preview)
	_fit_preview()
	_select(edit_id)

func _expand() -> void:
	full_preview = not full_preview
	inspector.visible = not full_preview
	return_button.visible = not full_preview
	expand_button.text = "Terminer l’aperçu" if full_preview else "Aperçu plein écran"
	expand_button.position = Vector2(24, 22) if full_preview else Vector2(289, 620)
	_fit_preview()
	expand_button.grab_focus()

func _fit_preview() -> void:
	var available := (get_parent() as Control).size
	position.x = 0.0 if full_preview else maxf(0.0, (available.x - 1280.0) * 0.5)
	diagram.position = Vector2.ZERO if full_preview else PREVIEW_RECT.position
	diagram.size = available if full_preview else PREVIEW_RECT.size

func _reset_one() -> void:
	var layout := Prefs.active_touch_layout().duplicate(true)
	layout[edit_id] = Layout.defaults()[edit_id]
	Prefs.set_touch_layout(layout)
	_select(edit_id)

func _slider(key: String, label: String, y: int, low: float, high: float) -> void:
	Palette.label(inspector, Rect2(824, y, 380, 28), label, 15, Palette.MUTED, Palette.MONO)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01
	slider.value_changed.connect(_change.bind(key))
	Palette.at(inspector, slider, Rect2(824, y + 31, 375, 26))
	sliders[key] = slider

func _select(id: String) -> void:
	edit_id = id
	diagram.active_edit = id
	selection.select(Layout.CONTROLS.keys().find(id))
	for key in sliders:
		sliders[key].set_value_no_signal(Prefs.active_touch_layout()[id][key])
	diagram.queue_redraw()

func _change(amount: float, key: String) -> void:
	var layout := Prefs.active_touch_layout().duplicate(true)
	layout[edit_id][key] = amount
	Prefs.set_touch_layout(layout)

func _move(id: String, x: float, y: float) -> void:
	var layout := Prefs.active_touch_layout().duplicate(true)
	layout[id].x = x
	layout[id].y = y
	Prefs.set_touch_layout(layout)
	_select(id)
