extends Range
## Marco y relleno en una cuadrícula de píxeles a escala 2×.

const GHOST := preload("res://art/ui/fantasma_vida.png")
const OUTLINE := Color("#33232b")
const GOLD := Color("#bd8742")
const LIGHT := Color("#f3cf7a")

const FLASK := preload("res://art/ui/frasco_mana.png")
const BOLT := preload("res://art/ui/rayo_estamina.png")
const STAR := preload("res://art/ui/estrella_xp.png")
const HUD_SCALE := 1.15
enum Kind { HEALTH, MANA, STAMINA, XP }
var kind: Kind

func _init(resource_kind := Kind.HEALTH) -> void:
	kind = resource_kind

func _ready() -> void:
	size = Vector2(260, 38)
	scale = Vector2.ONE * HUD_SCALE
	if kind == Kind.XP:
		set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
		offset_left = -16 - size.x * HUD_SCALE
		offset_right = offset_left + 260
		offset_top = -16 - size.y * HUD_SCALE
		offset_bottom = offset_top + 38
	else:
		position = Vector2(16, 1 + kind * (roundi(size.y * HUD_SCALE) + 2))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	value_changed.connect(func(_v: float) -> void: queue_redraw())
	var caption := Label.new()
	caption.name = "Label"
	caption.position = Vector2(34, 0)
	caption.size = Vector2(216, 40)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_color_override("font_outline_color", OUTLINE)
	caption.add_theme_constant_override("outline_size", 3)
	add_child(caption)

func _band(left: int, right: int, top: int, bottom: int, tip: int, color: Color) -> void:
	var mid := (top + bottom) * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(left, top), Vector2(right, top),
		Vector2(right + tip, mid), Vector2(right, bottom), Vector2(left, bottom)]), color)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(2, 2))
	_band(9, 123, 3, 17, 7, OUTLINE)
	_band(9, 123, 4, 16, 5, GOLD)
	draw_rect(Rect2(12, 4, 111, 1), LIGHT)
	_band(10, 122, 6, 14, 4, OUTLINE)
	_band(10, 122, 7, 13, 3, Color("#494153"))
	var fraction := get_as_ratio()
	if fraction > 0:
		var end := 19 + roundi(103 * fraction)
		var hue := lerpf(0.005, 0.295, fraction)
		var fill := Color.from_hsv(hue, 0.70, 0.86)
		if kind == Kind.MANA:
			fill = Color("#546fb9")
		elif kind == Kind.XP:
			fill = Color("#9972c1")
		elif kind == Kind.STAMINA:
			fill = Color("#64a454")
		_band(17, end, 7, 13, 3, fill)
		draw_rect(Rect2(17, 7, end - 17, 1), fill.lightened(0.28))
		draw_rect(Rect2(17, 12, end - 17, 1), fill.darkened(0.24))
	if kind == Kind.XP:
		draw_texture_rect(STAR, Rect2(2, 0, 19, 19), false)
	elif kind == Kind.STAMINA:
		draw_texture_rect(BOLT, Rect2(2, 0, 19, 19), false)
	elif kind == Kind.MANA:
		draw_texture_rect(FLASK, Rect2(2, 1, 18, 18), false)
	else:
		draw_texture_rect(GHOST, Rect2(2, 0, 19, 19), false)
