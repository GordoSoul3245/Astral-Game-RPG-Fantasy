extends CanvasLayer

var main: Node
var startup := true
var title: Label
var play_button: Button
var back_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.07, 0.88)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	panel.add_theme_stylebox_override("panel", main.menu._box(Color("#0d1020"), Color("#d9a441"), 2, 12, 32, 24))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	title = main.menu._label("", column, 32, Color("#d9a441"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_button = _button(column, "", _resume)
	back_button = _button(column, "Volver al inicio", _return_to_title)
	_button(column, "Guardar y salir", _quit)
	title.text = "Pausa"
	play_button.text = "Reanudar"
	startup = false
	visible = false

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 54
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _show(at_start: bool) -> void:
	startup = at_start
	title.text = "Ecos de la Ruina" if startup else "Pausa"
	play_button.text = "Jugar / Continuar" if startup else "Reanudar"
	back_button.visible = not startup
	visible = true
	get_tree().paused = true
	play_button.grab_focus()

func _resume() -> void:
	visible = false
	startup = false
	get_tree().paused = false

func _quit() -> void:
	main.save_game()
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if visible:
			if not startup:
				_resume()
		elif not get_tree().paused and not main.transitioning:
			main._cancel_aim()
			_show(false)
		else:
			return # El inventario, el comercio o el diálogo gestionan su propio cierre.
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.physical_keycode in [KEY_I, KEY_TAB]:
		get_viewport().set_input_as_handled()

func _return_to_title() -> void:
	main.save_game()
	get_tree().paused = false
	var error := get_tree().change_scene_to_file("res://scenes/title_menu.tscn")
	if error != OK:
		_show(false)
