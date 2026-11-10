extends RefCounted

const TEXT := Color("#e8efdf")
const MUTED := Color("#a3b8b9")
const QUIET := Color("#729094")
const CYAN := Color("#69ece7")
const AMBER := Color("#ffba73")
const PINK := Color("#ff799d")
const PANEL := Color("#122229")
const BASE := Color("#0b161e")
const LINE := Color("#2a4750")
const BODY := preload("res://assets/fonts/OpenSans-Regular.ttf")
const BOLD := preload("res://assets/fonts/OpenSans-Bold.ttf")
const HEAD := preload("res://assets/fonts/OpenSans-CondBold.ttf")
const BRAND := preload("res://assets/fonts/OpenSans-ExtraBoldItalic.ttf")
const MONO := preload("res://assets/fonts/DejaVuSansMono.ttf")

static func box(fill: Color, edge: Color = Color.TRANSPARENT, corner := 5, border := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(border)
	style.set_corner_radius_all(corner)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

static func theme() -> Theme:
	var skin := Theme.new()
	skin.default_font = BODY
	skin.default_font_size = 17
	for kind in ["Button", "OptionButton", "CheckButton"]:
		skin.set_stylebox("normal", kind, box(PANEL, LINE))
		skin.set_stylebox("hover", kind, box(Color("#1e373d"), CYAN))
		skin.set_stylebox("pressed", kind, box(Color("#284749"), CYAN))
		skin.set_stylebox("hover_pressed", kind, box(Color("#284749"), CYAN))
		skin.set_stylebox("focus", kind, box(Color.TRANSPARENT, AMBER))
		skin.set_stylebox("disabled", kind, box(BASE, LINE))
		skin.set_color("font_color", kind, TEXT)
		skin.set_color("font_hover_color", kind, Color.WHITE)
		skin.set_color("font_focus_color", kind, TEXT)
		skin.set_color("font_pressed_color", kind, TEXT)
		skin.set_color("font_disabled_color", kind, QUIET)
		skin.set_font("font", kind, BOLD)
	skin.set_color("font_color", "Label", TEXT)
	skin.set_stylebox("panel", "PanelContainer", box(PANEL, LINE))
	skin.set_stylebox("panel", "PopupMenu", box(BASE, LINE))
	skin.set_stylebox("hover", "PopupMenu", box(Color("#285354"), CYAN))
	skin.set_color("font_color", "PopupMenu", TEXT)
	skin.set_stylebox("slider", "HSlider", box(Color("#2b4047"), Color.TRANSPARENT, 2, 0))
	skin.set_stylebox("grabber_area", "HSlider", box(Color("#378983"), Color.TRANSPARENT, 2, 0))
	skin.set_stylebox("grabber_area_highlight", "HSlider", box(CYAN, Color.TRANSPARENT, 2, 0))
	skin.set_stylebox("focus", "HSlider", box(Color.TRANSPARENT, AMBER, 3, 1))
	skin.set_stylebox("panel", "AcceptDialog", box(BASE, LINE, 7, 2))
	return skin

static func clock(seconds: float) -> String:
	var time := maxi(0, int(seconds))
	return "%02d:%02d" % [time / 60, time % 60]

static func opacity(color: Color, alpha: float) -> Color:
	return Color(color, alpha)

static func at(parent: Node, node: Control, rect: Rect2) -> Control:
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size
	return node

static func label(parent: Node, rect: Rect2, value: String, pixels := 16,
		color := TEXT, font: Font = BODY, align := HORIZONTAL_ALIGNMENT_LEFT,
		wrap := false) -> Label:
	var node := Label.new()
	node.text = value
	node.horizontal_alignment = align
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", pixels)
	node.add_theme_color_override("font_color", color)
	at(parent, node, rect)
	return node

static func button(parent: Node, rect: Rect2, caption: String, action: Callable,
		primary := false, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Button:
	var node := Button.new()
	node.text = caption
	node.alignment = alignment
	node.custom_minimum_size = Vector2(0, 38)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		var ink: Color = Art.palette().ui
		node.add_theme_stylebox_override("normal", box(ink, ink.lightened(0.32), 4))
		node.add_theme_stylebox_override("hover", box(ink.lightened(0.22), ink.lightened(0.52), 4))
		node.add_theme_stylebox_override("pressed", box(ink.darkened(0.13), ink.lightened(0.28), 4))
		node.add_theme_stylebox_override("focus", box(Color.TRANSPARENT, AMBER, 4, 2))
		for key in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
			node.add_theme_color_override(key, Color("#112b2e"))
	node.pressed.connect(Sounds.play.bind("click"))
	node.pressed.connect(action)
	at(parent, node, rect)
	return node

static func panel(parent: Node, rect: Rect2, fill: Color = PANEL, outline: Color = LINE) -> Panel:
	var node := Panel.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", box(fill, outline, 5))
	at(parent, node, rect)
	return node

static func rule(parent: Node, rect: Rect2, color := LINE) -> ColorRect:
	var node := ColorRect.new()
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	at(parent, node, rect)
	return node
