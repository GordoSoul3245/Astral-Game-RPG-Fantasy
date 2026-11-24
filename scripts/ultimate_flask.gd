extends Range

const GLASS := preload("res://art/ui/frasco_ultimate.png")
const LIQUID := preload("res://art/ui/carga_ultimate.png")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 16
	offset_right = 144
	scale = Vector2.ONE * 1.15
	offset_top = -190
	offset_bottom = -62
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	value_changed.connect(func(_value: float) -> void: queue_redraw())
	var caption := Label.new()
	caption.name = "Label"
	caption.position = Vector2(0, 122)
	caption.size = Vector2(140, 26)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_outline_color", Color("#151322"))
	caption.add_theme_constant_override("outline_size", 4)
	add_child(caption)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(2, 2))
	draw_texture(GLASS, Vector2.ZERO)
	var height := roundi(get_as_ratio() * LIQUID.get_height())
	if height > 0:
		var source := Rect2(0, LIQUID.get_height() - height, LIQUID.get_width(), height)
		draw_texture_rect_region(LIQUID, Rect2(Vector2(18, 12) + source.position, source.size), source)
