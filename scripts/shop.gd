extends CanvasLayer
# Tienda del pueblo (data/shop.json): Tomás vende pociones y equipo; Bram compra los materiales de los monstruos.
# La lógica (buy/sell) no depende de la interfaz; el panel pausa el juego como el menú y se cierra con Esc.

var main: Node
var cfg := {}
var role := "merchant"
var panel: Control           # ventana de PixelLab (art/ui/tienda_ventana.png) en sus píxeles nativos, escalada entera
var list: GridContainer      # casillas de objetos
var title: Label
var info: Label
var coins_l: Label
var d_icon: TextureRect      # ficha del objeto elegido (columna derecha)
var d_name: Label
var d_desc: Label
var d_price: Label
var d_extra: Label
var act_btn: TextureButton
var act_l: Label
var d_coin: TextureRect
var entries: Array = []      # {id, name, desc, price, can, extra, act, verb}
var sel := 0
var armed := -1              # casilla ya elegida con el ratón: el siguiente clic confirma
const INK := Color("#322b28")
const INK_RED := Color("#72423c")

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
		if main.WEAPONS.has(s["id"]):
			if not main.prog.books.has(s["id"]):
				out.append(s)
		elif _stackable(s["id"]) or (not main.prog.owned.has(s["id"]) and not main.crafting.knows(s["id"])):
			out.append(s)
	return out

func _stackable(id: String) -> bool:  # lo que se compra una y otra vez: pociones, cebos, nasas...
	return id == "pocion_vida" or main.crafting.cfg["materials"].has(id) or main.crafting.is_consumable(id)

func qty_of(id: String) -> int:
	for s: Dictionary in cfg["merchant"]["stock"]:
		if s["id"] == id:
			return int(s.get("qty", 1))
	return 1

func price_of(id: String) -> int:  # con el descuento que da la amistad de Tomás
	for s: Dictionary in cfg["merchant"]["stock"]:
		if s["id"] == id:
			return roundi(float(s["price"]) * (1.0 - main.social.discount("tomas")))
	return 0

func buy(id: String) -> String:  # devuelve el aviso para el jugador
	var price := price_of(id)
	if price <= 0:
		return "Eso no está en venta."
	if main.prog.coins < price:
		return "Te faltan monedas (%d / %d)." % [main.prog.coins, price]
	if main.WEAPONS.has(id):
		if main.prog.books.has(id):
			return "Ya tenés ese grimorio."
		main.prog.coins -= price
		main.prog.books.append(id)
		main.save_game()
		return "¡%s! Ya lo llevas contigo." % main.name_of(id)
	if main.crafting.is_blueprint(id):
		if main.crafting.knows(id):
			return "Ya conoces ese plano."
		main.prog.coins -= price
		main.crafting.learn(id)
		main.save_game()
		return "Plano aprendido: %s" % main.crafting.item_name(main.crafting.cfg["blueprints"][id]["output"])
	if not _stackable(id) and main.prog.owned.has(id):
		return "Ya tienes eso."
	main.prog.coins -= price
	var msg: String
	if id == "pocion_vida":
		main.prog.potions += 1
		msg = "+1 poción de vida"
	elif _stackable(id):
		main.crafting.add(id, qty_of(id))
		msg = "+%d %s" % [qty_of(id), main.crafting.item_name(id)]
	else:
		msg = main.give_item(id)
	main.save_game()
	return msg

func sell_value(id: String) -> int:  # la calidad paga más: plata +25 %, oro +50 %
	var st: Array = main.crafting.stars_of(id)
	var n := int(main.prog.materials.get(id, 0))
	return roundi(float(cfg["smith"]["buys"].get(id, 0)) * (float(n) + 0.25 * float(st[0]) + 0.5 * float(st[1])) * (1.0 + main.social.sell_bonus("bram")))

func sell(id: String) -> String:  # vende todas las unidades de un material
	var n := int(main.prog.materials.get(id, 0))
	var unit := int(cfg["smith"]["buys"].get(id, 0))
	if n <= 0 or unit <= 0:
		return "No tienes eso para vender."
	var value := sell_value(id)
	main.crafting.take(id, n)
	main.prog.coins += value
	main.save_game()
	return "Vendiste %d × %s por %d monedas." % [n, main.prog.material_names[id], value]

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

func _build() -> void:  # todo en píxeles de la ventana (600×448); la raíz se escala para llenar la pantalla
	if panel:
		_fit()
		return
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	panel = Control.new()
	panel.size = Vector2(600, 448)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(panel)
	var bg := TextureRect.new()
	bg.texture = load("res://art/ui/tienda_ventana.png")
	panel.add_child(bg)
	title = _text(Rect2(212, 16, 176, 34), 15, Color("#f4d29c"), HORIZONTAL_ALIGNMENT_CENTER, true)
	var coin_tex: Texture2D = load("res://art/ui/moneda.png")
	var coin := TextureRect.new()
	coin.texture = coin_tex
	coin.position = Vector2(470, 41)
	panel.add_child(coin)
	coins_l = _text(Rect2(490, 38, 90, 22), 13, Color("#f4d29c"), HORIZONTAL_ALIGNMENT_LEFT, true)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(56, 84)
	scroll.size = Vector2(320, 318)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	list = GridContainer.new()
	list.columns = 5
	list.add_theme_constant_override("h_separation", 5)
	list.add_theme_constant_override("v_separation", 5)
	scroll.add_child(list)
	d_icon = TextureRect.new()
	d_icon.position = Vector2(450, 90)
	d_icon.size = Vector2(64, 64)
	d_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	d_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(d_icon)
	d_name = _text(Rect2(414, 158, 138, 30), 11, Color("#5d3138"), HORIZONTAL_ALIGNMENT_CENTER)
	d_desc = _text(Rect2(416, 190, 134, 92), 9, INK, HORIZONTAL_ALIGNMENT_CENTER)
	d_coin = TextureRect.new()
	d_coin.texture = coin_tex
	d_coin.position = Vector2(446, 289)
	panel.add_child(d_coin)
	d_price = _text(Rect2(466, 286, 80, 22), 13, INK)
	d_extra = _text(Rect2(414, 308, 138, 18), 8, INK_RED, HORIZONTAL_ALIGNMENT_CENTER)
	act_btn = TextureButton.new()
	act_btn.texture_normal = load("res://art/ui/tienda_boton.png")
	act_btn.position = Vector2(430, 330)
	act_btn.focus_mode = Control.FOCUS_NONE  # el foco queda en las casillas: Enter compra la elegida
	act_btn.pressed.connect(func() -> void: _act(sel))
	panel.add_child(act_btn)
	act_l = _text(Rect2(0, 0, 106, 40), 12, Color("#f4d29c"), HORIZONTAL_ALIGNMENT_CENTER, true, act_btn)
	act_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info = _text(Rect2(412, 376, 142, 30), 8, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Rect2(24, 416, 420, 16), 9, Color("#e4d2aa")).text = "Clic: ver  ·  Otro clic, Enter o el botón: confirmar  ·  Esc: salir"
	_fit()

func _fit() -> void:  # escala de medio en medio (píxeles nítidos) que entra en la pantalla, centrada
	var vp: Vector2 = panel.get_viewport_rect().size
	var k := maxf(1.0, floorf(minf(vp.x * 0.95 / 600.0, vp.y * 0.95 / 448.0) * 2.0) / 2.0)
	panel.scale = Vector2(k, k)
	panel.position = ((vp - Vector2(600, 448) * k) / 2.0).round()

func _text(r: Rect2, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, outline := false, parent: Control = null) -> Label:
	var l := Label.new()
	l.position = r.position
	l.size = r.size
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	if outline:  # texto claro sobre madera
		l.add_theme_color_override("font_outline_color", Color("#141013"))
		l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(parent if parent else panel).add_child(l)
	return l

func _entries() -> Array:  # lo que se muestra en las casillas, con su acción
	var out: Array = []
	var o: Dictionary = main.angler.order(role)  # encargo de pesca del día
	if not o.is_empty():
		var item := str(o["item"])
		var done: bool = main.angler.order_done(role)
		out.append({"id": item, "name": "Encargo de hoy", "desc": "Trae %d × %s" % [int(o["qty"]), main.crafting.item_name(item)], "price": int(o["coins"]),
			"can": not done and main.crafting.count(item) >= int(o["qty"]), "extra": "Entregado" if done else "Tienes %d / %d" % [main.crafting.count(item), int(o["qty"])],
			"verb": "Entregar", "order": true, "act": func() -> String: return main.angler.deliver(role)})
	if role == "merchant":
		for s: Dictionary in stock():
			var id: String = s["id"]
			var is_bp: bool = main.crafting.is_blueprint(id)
			var stack: bool = (_stackable(id) and id != "pocion_vida") or main.WEAPONS.has(id)
			var nm: String = "Poción de vida" if id == "pocion_vida" else (main.name_of(id) if is_bp or stack else main.prog.equipment[id]["name"])
			var desc: String = "Cura 40 de vida" if id == "pocion_vida" else ("Plano para la mesa de alquimia" if is_bp else (str(main.items[id].get("desc", "Grimorio nuevo")) if main.WEAPONS.has(id) else (main.crafting.item_desc(id) if stack else _mods_text(main.prog.equipment[id]))))
			var price := price_of(id)
			out.append({"id": id, "name": nm + (" ×%d" % qty_of(id) if stack and qty_of(id) > 1 else ""), "desc": desc, "price": price,
				"can": main.prog.coins >= price, "extra": "" if main.prog.coins >= price else "Te faltan %d" % (price - main.prog.coins),
				"verb": "Comprar", "act": func() -> String: return buy(id)})
	else:
		for id: String in cfg[role]["buys"]:
			var n := int(main.prog.materials.get(id, 0))
			if n > 0:
				out.append({"id": id, "name": str(main.prog.material_names[id]), "desc": "Bram se lleva las %d unidades" % n, "price": sell_value(id),
					"can": true, "extra": "Tienes %d" % n, "verb": "Vender", "act": func() -> String: return sell(id)})
	return out

func _icon_tex(id: String) -> Texture2D:  # icono del objeto; el equipo y la poción usan art/items/<id>.png
	for p: String in [main.icon_of(id) if (main.WEAPONS.has(id) or main.crafting.cfg["materials"].has(id) or main.crafting.is_blueprint(id)) else "", main.item_icon(id)]:
		if p != "" and ResourceLoader.exists(p):
			return load(p)
	return null

func _refresh(msg: String) -> void:
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	title.text = str(cfg[role]["title"])
	coins_l.text = str(main.prog.coins)
	entries = _entries()
	armed = -1
	var slot_tex: Texture2D = load("res://art/ui/tienda_casilla.png")
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("#e8c860")
	focus.set_border_width_all(2)
	for i in entries.size():
		var e: Dictionary = entries[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(58, 58)
		for st in ["focus", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, focus)
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_child(_part(TextureRect.new(), Vector2.ZERO, Vector2(58, 58), slot_tex))
		b.add_child(_part(TextureRect.new(), Vector2(12, 5), Vector2(34, 34), _icon_tex(str(e["id"]))))
		if not e["can"]:
			b.get_child(1).modulate = Color(1, 1, 1, 0.45)  # no alcanza o no se puede: atenuado, se puede mirar igual
		var pr := Label.new()
		pr.text = str(e["price"])
		pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pr.add_theme_font_size_override("font_size", 11)
		pr.add_theme_color_override("font_color", Color("#f4d29c") if e["can"] else Color("#ff8a70"))
		pr.add_theme_color_override("font_outline_color", Color("#141013"))
		pr.add_theme_constant_override("outline_size", 4)
		b.add_child(_part(pr, Vector2(2, 40), Vector2(54, 16)))
		if e.get("order", false):  # el encargo se distingue con un "!"
			var mk := Label.new()
			mk.text = "!"
			mk.add_theme_font_size_override("font_size", 12)
			mk.add_theme_color_override("font_color", Color("#e8c860"))
			mk.add_theme_color_override("font_outline_color", Color("#141013"))
			mk.add_theme_constant_override("outline_size", 3)
			b.add_child(_part(mk, Vector2(7, 2), Vector2(10, 14)))
		var idx := i
		b.focus_entered.connect(func() -> void: _select(idx))
		b.mouse_entered.connect(func() -> void: _select(idx))
		b.mouse_exited.connect(func() -> void: _select(armed if armed >= 0 else sel))
		b.pressed.connect(func() -> void:  # teclado/mando: confirma; ratón: el primer clic elige, el segundo confirma
			if Input.is_action_pressed("ui_accept") or armed == idx:
				_act(idx)
			else:
				armed = idx
				_select(idx))
		list.add_child(b)
	sel = clampi(sel, 0, maxi(0, entries.size() - 1))
	_select(sel if not entries.is_empty() else -1)
	if entries.is_empty():
		d_name.text = "Nada que vender" if role == "smith" else "Sin existencias"
		d_desc.text = "Los monstruos sueltan materiales: tráelos a Bram." if role == "smith" else "Vuelve más tarde."
	info.text = msg
	if not entries.is_empty():
		list.get_child(sel).grab_focus()

func _part(c: Control, p: Vector2, s: Vector2, tex: Texture2D = null) -> Control:  # pieza de una casilla: no capta el ratón
	c.position = p
	c.size = s
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if c is TextureRect:
		c.texture = tex
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return c

func _select(i: int) -> void:  # muestra la ficha del objeto en la columna derecha
	var has := i >= 0 and i < entries.size()
	for n: CanvasItem in [d_coin, d_price, d_extra, act_btn]:
		n.visible = has
	d_icon.texture = null
	d_name.text = ""
	d_desc.text = ""
	if not has:
		return
	sel = i
	var e: Dictionary = entries[i]
	d_icon.texture = _icon_tex(str(e["id"]))
	d_name.text = str(e["name"])
	d_desc.text = str(e["desc"])
	d_price.text = str(e["price"])
	d_extra.text = str(e["extra"])
	act_l.text = str(e["verb"])
	act_btn.disabled = not e["can"]
	act_btn.modulate = Color.WHITE if e["can"] else Color(0.55, 0.55, 0.55)

func _act(i: int) -> void:
	if i >= 0 and i < entries.size() and entries[i]["can"]:
		_refresh(entries[i]["act"].call())

func _mods_text(item: Dictionary) -> String:
	var parts: Array[String] = []
	for k: String in item["mods"]:
		parts.append("+%d %s" % [item["mods"][k], main.prog.STAT_NAMES.get(k, "Vida máx.")])
	return ", ".join(parts)

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
