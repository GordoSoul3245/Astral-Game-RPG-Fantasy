extends CanvasLayer
# Ventana de una estación de creación: forja de Bram, fogata o mesa de alquimia. Pausa el juego como la tienda y se cierra con Esc.
# Aloja craft_panel.gd (forja y cocina) o alchemy_panel.gd (alquimia).

const GOLD := Color("#d9a441")

var main: Node
var station := ""
var holder: PanelContainer
var title: Label
var content: Control
var body: VBoxContainer
var info: Label

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.07, 0.72)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	holder = PanelContainer.new()
	holder.custom_minimum_size = Vector2(1120, 660)
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#0d1020")
	s.border_color = GOLD
	s.set_border_width_all(2)
	s.set_corner_radius_all(12)
	s.set_content_margin_all(20)
	s.shadow_size = 24
	s.shadow_color = Color(0, 0, 0, 0.5)
	holder.add_theme_stylebox_override("panel", s)
	center.add_child(holder)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	holder.add_child(body)
	var head := HBoxContainer.new()
	body.add_child(head)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "Cerrar  [Esc]"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	head.add_child(close_btn)
	body.add_child(HSeparator.new())

func is_open() -> bool:
	return visible

func open(st: String) -> void:
	station = st
	if content:
		content.queue_free()
	var stn: Dictionary = main.crafting.cfg["stations"][st]
	title.text = stn["name"]
	if st == "alchemy":
		content = preload("res://scripts/alchemy_panel.gd").new()
		content.main = main
		content.setup(main)
	else:
		content = preload("res://scripts/craft_panel.gd").new()
		content.setup(main, st)
	body.add_child(content)
	visible = true
	main.get_tree().paused = true

func close() -> void:
	if content and content.get("busy"):
		return  # no se cierra a mitad de la animación: ya se habrían gastado los materiales
	visible = false
	main.get_tree().paused = false

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
