extends Control

var confirmation: ConfirmationDialog
var status: Label

func _ready() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("#080e20")
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 520
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)
	var title := Label.new()
	title.text = "ECOS DE LA RUINA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#d9a441"))
	column.add_child(title)
	var resume := _button(column, "Continuar partida", _start.bind(false))
	var saved: Variant = null
	if FileAccess.file_exists("user://save.json"):
		saved = JSON.parse_string(FileAccess.get_file_as_string("user://save.json"))
	resume.disabled = not saved is Dictionary
	var fresh := _button(column, "Nueva partida", _new_game)
	_button(column, "Salir", func() -> void: get_tree().quit())
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.text = "Tu aventura comienza aquí." if resume.disabled else "Continúa desde tu último progreso guardado."
	column.add_child(status)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Nueva partida"
	confirmation.dialog_text = "Se reemplazará el progreso guardado al comenzar. ¿Continuar?"
	confirmation.ok_button_text = "Crear nueva partida"
	confirmation.cancel_button_text = "Cancelar"
	confirmation.confirmed.connect(_start.bind(true))
	add_child(confirmation)
	if resume.disabled:
		fresh.grab_focus()
	else:
		resume.grab_focus()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 64
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _new_game() -> void:
	if FileAccess.file_exists("user://save.json"):
		confirmation.popup_centered()
	else:
		_start(true)

func _start(fresh: bool) -> void:
	get_tree().set_meta("new_game", fresh)
	var error := get_tree().change_scene_to_file("res://scenes/main.tscn")
	if error != OK:
		get_tree().remove_meta("new_game")
		status.text = "No se pudo abrir el juego. Inténtalo de nuevo."
