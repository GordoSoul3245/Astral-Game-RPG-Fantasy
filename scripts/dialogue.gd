extends CanvasLayer
# Cuadro de conversación: pausa el juego, escribe el texto poco a poco y avanza con E / Espacio / Intro / clic.
# Esc lo cierra. open(nombre, líneas) lo muestra; al cerrarse reanuda el juego.

const SPEED := 60.0   # caracteres por segundo

var main: Node
var lines: Array = []
var idx := 0
var shown := 0.0
var panel: PanelContainer
var name_label: Label
var text_label: Label
var hint: Label
var on_close: Callable   # se llama una vez al cerrarse (escenas de amistad)

func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -120.0
	panel.custom_minimum_size = Vector2(900, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.11, 0.95)
	style.border_color = Color(0.85, 0.65, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	v.add_child(name_label)
	text_label = Label.new()
	text_label.add_theme_font_size_override("font_size", 22)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.custom_minimum_size = Vector2(860, 66)
	v.add_child(text_label)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)

func is_open() -> bool:
	return visible

func open(who: String, text_lines: Array) -> void:
	if text_lines.is_empty():
		return
	lines = text_lines
	idx = 0
	name_label.text = who
	_show_line()
	visible = true
	main.get_tree().paused = true

func close() -> void:
	visible = false
	main.get_tree().paused = false
	if on_close.is_valid():
		var cb := on_close
		on_close = Callable()
		cb.call()

func _show_line() -> void:
	text_label.text = str(lines[idx])
	text_label.visible_characters = 0
	shown = 0.0
	hint.text = "[E] siguiente   ·   [Esc] cerrar" if idx < lines.size() - 1 else "[E] cerrar"

func advance() -> void:
	if int(shown) < text_label.text.length():  # primer toque: completa la línea
		shown = text_label.text.length()
		text_label.visible_characters = -1
		return
	idx += 1
	if idx >= lines.size():
		close()
	else:
		_show_line()

func _process(delta: float) -> void:
	if visible and int(shown) < text_label.text.length():
		shown += SPEED * delta
		text_label.visible_characters = int(shown)
		if int(shown) >= text_label.text.length():
			text_label.visible_characters = -1

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var go := false
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
			return
		go = k == KEY_E or k == KEY_SPACE or k == KEY_ENTER
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		go = true
	if go:
		advance()
		get_viewport().set_input_as_handled()
