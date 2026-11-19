extends CanvasLayer
# Cuadro de conversación: pausa el juego, escribe el texto poco a poco y avanza con E / Espacio / Intro / clic.
# Esc lo cierra. open(nombre, líneas) lo muestra; al cerrarse reanuda el juego.

const SPEED := 60.0   # caracteres por segundo

const PORTRAITS := {"Elda": "elda", "Mara": "mara", "Teo": "teo", "El viejo": "gaucho",
	"Tomás": "tomas", "Bram": "bram", "Aldeano": "aldeano"}
var cast: Control
var conversation_name := ""

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
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.055, 0.045, 0.07, 0.65)
	add_child(shade)
	var hero := _portrait("heroe")
	hero.anchor_right = 0.32
	hero.anchor_top = 0.24
	hero.anchor_bottom = 1
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(hero)
	cast = Control.new()
	cast.anchor_left = 0.68
	cast.anchor_right = 1
	cast.anchor_top = 0.24
	cast.anchor_bottom = 1
	cast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cast)
	panel = PanelContainer.new()
	panel.anchor_left = 0.29
	panel.anchor_right = 0.71
	panel.anchor_top = 1
	panel.anchor_bottom = 1
	panel.offset_top = -236
	panel.offset_bottom = -44
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#30241ff5")
	style.border_color = Color(0.85, 0.65, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
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
	text_label.custom_minimum_size = Vector2(0, 78)
	v.add_child(text_label)
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(hint)

func is_open() -> bool:
	return visible

func _portrait(id: String) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.texture = load("res://art/dialogue/" + id + ".png")
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return portrait

func open(who: String, text_lines: Array, participants: Array = []) -> void:
	if text_lines.is_empty():
		return
	for previous in cast.get_children():
		cast.remove_child(previous)
		previous.queue_free()
	var speakers := participants.duplicate()
	if speakers.is_empty():
		if PORTRAITS.has(who):
			speakers.append(who)
		for line in text_lines:
			var speaker := str(line).get_slice(":", 0)
			if PORTRAITS.has(speaker) and not speakers.has(speaker):
				speakers.append(speaker)
	if speakers.is_empty() and who != "Jugador":
		speakers.append(who)
	var width := minf(1.0, 1.55 / maxi(1, speakers.size()))
	for i in speakers.size():
		var portrait := _portrait(PORTRAITS.get(speakers[i], "aldeano"))
		cast.add_child(portrait)
		portrait.anchor_left = (1.0 - width) * i / maxi(1, speakers.size() - 1)
		portrait.anchor_right = portrait.anchor_left + width
		portrait.anchor_bottom = 1
		portrait.offset_left = 0
		portrait.offset_right = 0
		portrait.offset_bottom = 0
	conversation_name = who
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
	var line := str(lines[idx])
	var speaker := line.get_slice(":", 0)
	var named := line.contains(":") and (speaker == "Jugador" or PORTRAITS.has(speaker))
	name_label.text = speaker if named else conversation_name
	text_label.text = line.substr(speaker.length() + 1).strip_edges() if named else line
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
