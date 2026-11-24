extends Control

var confirmation: ConfirmationDialog
var status: Label

func _ready() -> void:
	get_tree().auto_accept_quit = true
	var background := TextureRect.new()
	background.texture = preload("res://art/ui/valle_astral.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var landscape := ShaderMaterial.new()
	landscape.shader = preload("res://shaders/title_landscape.gdshader")
	background.material = landscape
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.anchor_right = 0.52
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 380
	column.add_theme_constant_override("separation",14)
	center.add_child(column)
	var title := Label.new()
	title.text = "ASTRAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lettering := SystemFont.new()
	lettering.font_names = PackedStringArray(["Georgia","DejaVu Serif","serif"])
	title.add_theme_font_override("font",lettering)
	title.add_theme_font_size_override("font_size",88)
	title.add_theme_color_override("font_color",Color("#fff0c1"))
	title.add_theme_color_override("font_outline_color",Color("#2b2033"))
	title.add_theme_constant_override("outline_size",6)
	column.add_child(title)
	var resume := _button(column, "Continuar partida", _start.bind(false))
	var saved: Variant = null
	if FileAccess.file_exists("user://save.json"):
		saved = JSON.parse_string(FileAccess.get_file_as_string("user://save.json"))
	resume.disabled = not preload("res://scripts/main.gd").valid_save(saved)
	var fresh := _button(column, "Nueva partida", _new_game)
	_button(column, "Salir", func() -> void: get_tree().quit())
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.visible = false
	if resume.disabled and FileAccess.file_exists("user://save.json"):
		status.visible = true
		status.text = "La partida guardada no se pudo leer."
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
	preload("res://scripts/menu.gd").style_button(button)
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
		status.visible = true
		status.text = "No se pudo abrir el juego. Inténtalo de nuevo."
