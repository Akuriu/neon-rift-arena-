extends Control

signal cancelled
signal retry

const Palette := preload("res://ui/skin.gd")
const Tokens := preload("res://ui/design/tokens.gd")
const SafeLayout := preload("res://ui/design/safe_layout.gd")
const Meter := preload("res://ui/loading/load_meter.gd")
const Reveal := preload("res://ui/loading/map_reveal.gdshader")

var title := ""
var mode := ""
var tip := ""
var image: Texture2D
var page: Control
var curtain: ShaderMaterial
var stage: Label
var percent: Label
var meter: Meter
var cancel_button: Button
var retry_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Palette.theme()
	var fill := ColorRect.new()
	fill.color = Tokens.BACKGROUND
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Prefs.values.ui_motion and DisplayServer.get_name() != "headless":
		curtain = ShaderMaterial.new()
		curtain.shader = Reveal
		fill.material = curtain
	add_child(fill)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page = Control.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	page.size = Tokens.FRAME
	if image != null:
		var crop := Palette.panel(page, Rect2(570, 105, 638, 510), Tokens.SURFACE, Tokens.EDGE)
		crop.clip_contents = true
		var picture := TextureRect.new()
		picture.texture = image
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.modulate = Color("#c3c8b8")
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Palette.at(crop, picture, Rect2(2, 2, 634, 506))
		Palette.rule(page, Rect2(570, 105, 45, 3), Tokens.ACCENT)
	var width := 960.0 if image == null else 474.0
	Palette.label(page, Rect2(70, 132, width, 31), mode, 16, Tokens.ACCENT, Palette.MONO)
	Palette.label(page, Rect2(66, 169, width, 151), title, 64, Tokens.TEXT, Palette.HEAD,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	Palette.label(page, Rect2(70, 325, width, 72), tip, 18, Tokens.MUTED, Palette.BODY,
		HORIZONTAL_ALIGNMENT_LEFT, true)
	stage = Palette.label(page, Rect2(70, 457, width, 32), "Préparation de la carte", 20, Tokens.TEXT)
	percent = Palette.label(page, Rect2(410, 457, 133, 32), "", 13, Tokens.ACCENT, Palette.MONO,
		HORIZONTAL_ALIGNMENT_RIGHT)
	meter = Meter.new()
	Palette.at(page, meter, Rect2(70, 503, 474, 3))
	cancel_button = Palette.button(page, Rect2(70, 546, 202, 48), "Annuler", cancelled.emit)
	retry_button = Palette.button(page, Rect2(286, 546, 164, 48), "Réessayer", retry.emit, true)
	retry_button.hide()
	cancel_button.grab_focus()
	resized.connect(_fit)
	get_window().size_changed.connect(_fit)
	_fit()

func show_status(caption: String, fraction := -1.0, cancellable := true, error := false) -> void:
	stage.text = caption
	stage.modulate = Tokens.DANGER if error else Color.WHITE
	percent.text = "%d %%" % floori(fraction * 100.0) if fraction >= 0.0 else ""
	meter.update(fraction, not error)
	cancel_button.visible = cancellable
	retry_button.visible = error
	if error:
		retry_button.grab_focus()

func _fit() -> void:
	SafeLayout.center(page, SafeLayout.area(get_window(), size), Tokens.FRAME)

func reveal() -> Tween:
	var animation := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	animation.tween_property(page, "modulate:a", 0.0, Tokens.REVEAL_SECONDS * 0.70)
	animation.tween_property(page, "position:y", page.position.y - 8.0 * page.scale.y, Tokens.REVEAL_SECONDS)
	if curtain != null:
		animation.tween_method(func(opening: float): curtain.set_shader_parameter("opening", opening),
			-0.04, 1.05, Tokens.REVEAL_SECONDS)
	else:
		animation.tween_property(self, "modulate:a", 0.0, Tokens.REVEAL_SECONDS)
	return animation
