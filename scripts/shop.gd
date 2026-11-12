extends CanvasLayer
# Tienda del pueblo (data/shop.json): Tomás vende pociones y equipo; Bram compra los materiales de los monstruos.
# La lógica (buy/sell) no depende de la interfaz; el panel pausa el juego como el menú y se cierra con Esc.

var main: Node
var cfg := {}
var role := "merchant"
var panel: PanelContainer
var list: VBoxContainer
var title: Label
var info: Label

func _ready() -> void:
	cfg = main._read_json("res://data/shop.json")
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue vivo con el juego en pausa
	visible = false

func is_open() -> bool:
	return visible

# --- lógica
func stock() -> Array:  # lo que vende el mercader y aún no tienes (el equipo no se repite)
	var out: Array = []
	for s: Dictionary in cfg["merchant"]["stock"]:
		if s["id"] == "pocion_vida" or (not main.prog.owned.has(s["id"]) and not main.crafting.knows(s["id"])):
			out.append(s)
	return out

func price_of(id: String) -> int:
	for s: Dictionary in cfg["merchant"]["stock"]:
		if s["id"] == id:
			return int(s["price"])
	return 0

func buy(id: String) -> String:  # devuelve el aviso para el jugador
	var price := price_of(id)
	if price <= 0:
		return "Eso no está en venta."
	if main.prog.coins < price:
		return "Te faltan monedas (%d / %d)." % [main.prog.coins, price]
	if main.crafting.is_blueprint(id):
		if main.crafting.knows(id):
			return "Ya conoces ese plano."
		main.prog.coins -= price
		main.crafting.learn(id)
		main.save_game()
		return "Plano aprendido: %s" % main.crafting.item_name(main.crafting.cfg["blueprints"][id]["output"])
	if id != "pocion_vida" and main.prog.owned.has(id):
		return "Ya tienes eso."
	main.prog.coins -= price
	var msg: String
	if id == "pocion_vida":
		main.prog.potions += 1
		msg = "+1 poción de vida"
	else:
		msg = main.give_item(id)
	main.save_game()
	return msg

func sell_value(id: String) -> int:
	return int(cfg["smith"]["buys"].get(id, 0)) * int(main.prog.materials.get(id, 0))

func sell(id: String) -> String:  # vende todas las unidades de un material
	var n := int(main.prog.materials.get(id, 0))
	var unit := int(cfg["smith"]["buys"].get(id, 0))
	if n <= 0 or unit <= 0:
		return "No tienes eso para vender."
	main.prog.materials.erase(id)
	main.prog.coins += n * unit
	main.save_game()
	return "Vendiste %d × %s por %d monedas." % [n, main.prog.material_names[id], n * unit]

# --- interfaz
func open(who: String) -> void:
	role = who
	_build()
	_refresh("")
	visible = true
	main.get_tree().paused = true

func close() -> void:
	visible = false
	main.get_tree().paused = false

func _build() -> void:
	if panel:
		return
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(620, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH  # crece desde el centro en las dos direcciones
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.12, 0.94)
	style.border_color = Color(0.85, 0.65, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	box.add_child(title)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	box.add_child(list)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 20)
	box.add_child(info)
	var close_btn := Button.new()
	close_btn.text = "Cerrar  [Esc]"
	close_btn.pressed.connect(close)
	box.add_child(close_btn)

func _refresh(msg: String) -> void:
	for c in list.get_children():
		c.queue_free()
	var t: Dictionary = cfg[role]
	title.text = "%s  ·  %d monedas" % [t["title"], main.prog.coins]
	var first: Button = null
	if role == "merchant":
		for s: Dictionary in stock():
			var id: String = s["id"]
			var is_bp: bool = main.crafting.is_blueprint(id)
			var label: String = "Poción de vida" if id == "pocion_vida" else (main.crafting.item_name(id) if is_bp else main.prog.equipment[id]["name"])
			var desc: String = "Cura 40 de vida" if id == "pocion_vida" else ("para la mesa de alquimia" if is_bp else _mods_text(main.prog.equipment[id]))
			var b := _button("%s  —  %d monedas   (%s)" % [label, s["price"], desc], func() -> void: _refresh(buy(id)))
			b.disabled = main.prog.coins < int(s["price"])
			first = first if first else b
	else:
		for id: String in t["buys"]:
			if main.prog.materials.get(id, 0) > 0:
				var mid: String = id
				var b := _button("Vender todo: %s ×%d  —  %d monedas" % [main.prog.material_names[id], main.prog.materials[id], sell_value(id)], func() -> void: _refresh(sell(mid)))
				first = first if first else b
		if first == null:
			_label("No tienes materiales para vender. Los monstruos los sueltan.")
	info.text = msg if msg != "" else ("Elige qué comprar." if role == "merchant" else "Bram paga por lo que sueltan los monstruos.")
	if first:
		first.grab_focus()

func _button(text: String, on: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(on)
	list.add_child(b)
	return b

func _label(text: String) -> void:
	var l := Label.new()
	l.text = text
	list.add_child(l)

func _mods_text(item: Dictionary) -> String:
	var parts: Array[String] = []
	for k: String in item["mods"]:
		parts.append("+%d %s" % [item["mods"][k], main.prog.STAT_NAMES.get(k, "Vida máx.")])
	return ", ".join(parts)

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
