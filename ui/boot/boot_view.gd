extends Control

signal retry
signal exit_requested

const Tokens := preload("res://ui/design/tokens.gd")
const Palette := preload("res://ui/skin.gd")
const Meter := preload("res://ui/loading/load_meter.gd")
const SafeLayout := preload("res://ui/design/safe_layout.gd")
const Mark := preload("res://assets/art/rift.svg")
const Panorama := preload("res://assets/maps/skyline.jpg")

var composition: Control
var title: Label
var stage: Label
var detail: Label
var count: Label
var meter: Meter
var retry_button: Button
var quit_button: Button
var safe_override := Rect2()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Palette.theme()
	composition = Control.new()
	composition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(composition)
	composition.size = Tokens.FRAME
	_build()
	resized.connect(_fit)
	get_window().size_changed.connect(_fit)
	_fit()
	if Prefs.values.ui_motion:
		title.position.y += 9.0
		title.modulate.a = 0.72
		var entrance := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		entrance.tween_property(title, "position:y", 217.0, Tokens.PAGE_SECONDS)
		entrance.tween_property(title, "modulate:a", 1.0, Tokens.PAGE_SECONDS)

func _build() -> void:
	var hero := Control.new()
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.clip_contents = true
	Palette.at(composition, hero, Rect2(644, 106, 570, 486))
	var picture := TextureRect.new()
	picture.texture = Panorama
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.modulate = Color("#9ea194")
	Palette.at(hero, picture, Rect2(0, 0, 570, 486))
	var wash := GradientTexture2D.new()
	var colors := Gradient.new()
	colors.colors = PackedColorArray([Color("#141d1a"), Color("#141d1a66"), Color("#141d1a0a")])
	colors.offsets = PackedFloat32Array([0.0, 0.52, 1.0])
	wash.gradient = colors
	wash.width = 192
	wash.height = 8
	var shading := TextureRect.new()
	shading.texture = wash
	shading.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Palette.at(hero, shading, Rect2(0, 0, 570, 486))
	Palette.rule(composition, Rect2(644, 106, 570, 1), Color(Tokens.ACCENT, 0.52))
	Palette.rule(composition, Rect2(644, 591, 570, 1), Color(Tokens.ACCENT, 0.38))
	Palette.rule(composition, Rect2(1213, 106, 1, 486), Color(Tokens.ACCENT, 0.30))
	Palette.rule(composition, Rect2(1170, 106, 44, 3), Tokens.ACCENT)
	Palette.rule(composition, Rect2(1170, 589, 44, 3), Tokens.ACCENT)

	var mark := TextureRect.new()
	mark.texture = Mark
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Palette.at(composition, mark, Rect2(66, 57, 53, 53))
	var version: String = ProjectSettings.get_setting("application/config/version", "")
	Palette.label(composition, Rect2(912, 64, 302, 39), "V" + version.to_upper().replace("-ALPHA", " ALPHA"),
		14, Tokens.MUTED, Palette.MONO, HORIZONTAL_ALIGNMENT_RIGHT)
	Palette.rule(composition, Rect2(69, 203, 49, 3), Tokens.ACCENT)
	title = Palette.label(composition, Rect2(64, 217, 741, 142), "RIFLE ARENA", 118, Tokens.TEXT, Palette.BRAND)

	stage = Palette.label(composition, Rect2(70, 403, 501, 40), "Initialisation", 27, Tokens.TEXT, Palette.HEAD)
	count = Palette.label(composition, Rect2(460, 413, 108, 24), "", 14, Tokens.ACCENT,
		Palette.MONO, HORIZONTAL_ALIGNMENT_RIGHT)
	meter = Meter.new()
	Palette.at(composition, meter, Rect2(70, 460, 498, 3))
	detail = Palette.label(composition, Rect2(70, 478, 498, 62), "", 17, Tokens.MUTED, Palette.BODY,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	retry_button = Palette.button(composition, Rect2(70, 553, 178, 52), "Réessayer", retry.emit, true)
	quit_button = Palette.button(composition, Rect2(262, 553, 144, 52), "Quitter", exit_requested.emit)
	retry_button.hide()
	quit_button.hide()
	Palette.rule(composition, Rect2(70, 647, 1144, 1), Color(Tokens.EDGE, 0.85))

func status(caption: String, notice: String, fraction := -1.0, error := false) -> void:
	stage.text = caption
	stage.modulate = Tokens.DANGER if error else Color.WHITE
	detail.text = notice
	count.text = "%d %%" % floori(fraction * 100.0) if fraction >= 0.0 else ""
	meter.update(fraction, not error)
	retry_button.visible = error
	quit_button.visible = error
	if error:
		retry_button.grab_focus()

func _fit() -> void:
	SafeLayout.center(composition, SafeLayout.area(get_window(), size, safe_override), Tokens.FRAME)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#141d1a"))
