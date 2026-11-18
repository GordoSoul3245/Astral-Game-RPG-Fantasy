extends CanvasLayer
# Menú (tecla I o Tab): Inventario (equipo, mochila en cuadrícula, detalle con comparación) y Estadísticas (gastar puntos).
# Pausa el juego mientras está abierto. Los marcos de los objetos se colorean por rareza (tier de data/equipment.json).

const TIER_COLORS := {1: Color("#8fa38f"), 2: Color("#4f8cff"), 3: Color("#e0a93a")}
const TIER_NAMES := {1: "Común", 2: "Raro", 3: "Épico"}
const GOLD := Color("#d9a441")
const MUTED := Color(0.6, 0.65, 0.75)
const GOOD := Color(0.45, 0.9, 0.5)
const BAD := Color(0.95, 0.4, 0.4)
const BACKPACK_SLOTS := 16

var main: Node
var tab := "inv"
var selected := ""               # objeto elegido: se muestra en el panel de detalle
var body: VBoxContainer
var tab_buttons := {}
var page := 0                    # página de la mochila (16 casillas por página)
var bar_row: HBoxContainer       # la barra de objetos, abierta bajo el panel: casillas donde soltar objetos arrastrados
var panel: PanelContainer        # el panel general (crafteo, pesca, magia, estadísticas, opciones)
var book: Control                # el inventario-libro
var book_items: Control
var book_bg: TextureRect
var craft_sel := ""              # receta elegida en el libro de crafteo
var craft_page := 0              # página de recetas (6 por página, como las filas del dibujo)
# libro de crafteo (art/ui/crafteo_libro.png, diseño de PixelLab con el estilo del inventario)
const CRAFT_ROWS_Y := [66, 88, 110, 132, 154, 176]
const CRAFT_INGR_X := [155, 176, 197]
const CRAFT_INGR_Y := 147
const BOOK_SCALE := 4.0
const BOOK_POS := Vector2(448, -60)  # centrado: (1920 - 256 x 4) / 2
const CRAFT_POS := BOOK_POS  # el libro de crafteo es el mismo del inventario (solo cambia el interior de las páginas)
var book_pos := BOOK_POS   # el libro (contenido de y 25 a 225 del arte) queda sobre la barra de objetos
const INK := Color("#2b1d12")
# casillas del diseño (px del arte de 256): equipo a izquierda y derecha del muñeco, mochila 4x4
const EQUIP_CELLS := {"sword": Rect2(33, 76, 20, 18), "armor": Rect2(33, 105, 20, 18), "amulet": Rect2(33, 135, 20, 18), "grimoire": Rect2(97, 76, 20, 18), "ring": Rect2(97, 135, 20, 18)}
const PACK_X := [144, 165, 187, 208]
const PACK_Y := [68, 98, 128, 158]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.07, 0.72)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(1180, 720)
	panel.add_theme_stylebox_override("panel", _box(Color("#0d1020"), GOLD, 2, 12, 22, 24))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	_label("Ecos de la Ruina", head, 28, GOLD)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	for pair in [["inv", "Inventario"], ["craft", "Crafteo"]]:  # Pesca, Magia, Estadísticas y Opciones se abren desde los botones del HUD
		var b := Button.new()
		b.text = pair[1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(124, 40)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_set_tab.bind(pair[0]))
		head.add_child(b)
		tab_buttons[pair[0]] = b
	_label("[I] cerrar", head, 16, MUTED)
	v.add_child(HSeparator.new())
	var bar_wrap := CenterContainer.new()
	bar_wrap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_wrap.offset_top = -128.0
	bar_wrap.offset_bottom = -14.0
	bar_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar_wrap)
	bar_row = HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 10)
	bar_wrap.add_child(bar_row)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	# inventario con el diseño de PixelLab: un libro abierto (art/ui/inventario_libro.png, 256 px a x4) con los datos encima
	book = Control.new()
	book.set_anchors_preset(Control.PRESET_FULL_RECT)
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(book)
	move_child(book, bar_wrap.get_index())  # la barra de objetos queda por encima del libro
	var bg := TextureRect.new()
	book_bg = bg
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.size = Vector2(256, 256) * BOOK_SCALE
	bg.position = BOOK_POS
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(bg)
	book_items = Control.new()
	book_items.set_anchors_preset(Control.PRESET_FULL_RECT)
	book_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(book_items)

func _box(bg: Color, border: Color, width := 2, radius := 8, margin := 8, shadow := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(width)
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	if shadow > 0:
		sb.shadow_size = shadow
		sb.shadow_color = Color(0, 0, 0, 0.6)
	return sb

func _label(text: String, parent: Node, size := 18, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if visible and tab == "craft" and k in [KEY_ENTER, KEY_KP_ENTER]:
			_craft_now()
			get_viewport().set_input_as_handled()
			return
		if k == KEY_I or k == KEY_TAB or (k == KEY_ESCAPE and visible):
			if main.transitioning:
				return
			visible = not visible if k != KEY_ESCAPE else false
			get_tree().paused = visible
			if visible:
				refresh()
			get_viewport().set_input_as_handled()

func _set_tab(t: String) -> void:
	tab = t
	refresh()

func open_tab(t: String) -> void:  # desde los botones del HUD
	if main.transitioning:
		return
	tab = t
	visible = true
	get_tree().paused = true
	refresh()

func refresh() -> void:
	var p = main.prog
	if selected != "" and not _has(selected):
		selected = ""
	for k: String in tab_buttons:
		var active: bool = k == tab
		var b: Button = tab_buttons[k]
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, _box(Color(0.35, 0.27, 0.1) if active else Color(0.1, 0.12, 0.2), GOLD if active else Color(0.3, 0.34, 0.45), 2, 8, 6))
		b.add_theme_color_override("font_color", Color.WHITE if active else MUTED)
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	for c in book_items.get_children():
		book_items.remove_child(c)
		c.queue_free()
	panel.get_parent().visible = tab not in ["inv", "craft"]
	book.visible = tab in ["inv", "craft"]
	if tab == "inv":
		book_bg.texture = load("res://art/ui/inventario_libro.png")
		book_pos = BOOK_POS
		book_bg.position = book_pos
		_build_book()
	elif tab == "craft":
		book_bg.texture = load("res://art/ui/crafteo_libro.png")
		book_pos = CRAFT_POS
		book_bg.position = book_pos
		_build_craft_book()
	elif tab == "fish":
		_build_fishing()
	elif tab == "magic":
		_build_magic()
	elif tab == "opt":
		_build_options()
	else:
		_build_stats()
	_build_bar()

func _has(id: String) -> bool:  # equipo conseguido, arma base o material/consumible con existencias
	return main.prog.owned.has(id) or main.WEAPONS.has(id) or (not main.prog.equipment.has(id) and main.crafting.count(id) > 0)

func _build_bar() -> void:  # barra de objetos: arrastra aquí desde la mochila; entre casillas se intercambian
	for c in bar_row.get_children():
		c.queue_free()
	for i in main.HOTBAR_MAX:
		var id: String = main.hotbar[i]
		var cnt: int = main.crafting.count(id) if id != "" and main.crafting.is_consumable(id) else 0
		var b := _slot_button(id, 84, false, cnt)
		b.index = i
		if i == main.selected:
			for st in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_stylebox_override(st, _box(Color(0.1, 0.12, 0.2), Color("#f2c14e"), 3, 8, 4))
		var num := Label.new()
		num.text = str(i + 1)
		num.add_theme_font_size_override("font_size", 14)
		num.add_theme_color_override("font_outline_color", Color.BLACK)
		num.add_theme_constant_override("outline_size", 5)
		num.position = Vector2(6, 2)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(num)
		bar_row.add_child(b)

func _backpack() -> Array:  # todo lo que llevas: equipo, consumibles y materiales (los planos ya se aprenden al recibirlos)
	var p = main.prog
	var out: Array = p.owned.duplicate()
	for w: String in main.WEAPONS:  # las armas base aparecen aquí cuando no están en la barra, para poder volver a ponerlas
		if not main.hotbar.has(w) and p.books.has(w):
			out.append(w)
	if p.potions > 0:
		out.append("pocion_vida")
	for id: String in p.materials:
		if p.materials[id] > 0 and not main.crafting.is_blueprint(id):
			out.append(id)
	return out

func _mods_lines(mods: Dictionary, vs: Dictionary = {}, compare := false) -> Array[String]:
	var out: Array[String] = []
	var keys := mods.keys()
	if compare:
		for k in vs:
			if not keys.has(k):
				keys.append(k)
	for k: String in keys:
		var name: String = main.prog.STAT_NAMES.get(k, "Vida máx.")
		var v: int = mods.get(k, 0)
		var line := "%+d %s" % [v, name] if v != 0 else "0 %s" % name
		if compare:
			var d: int = v - int(vs.get(k, 0))
			if d != 0:
				line += "   (%s%d)" % ["▲ +" if d > 0 else "▼ ", d]
		out.append(line)
	return out

# casilla cuadrada con el icono del objeto y marco del color de su rareza; id vacío = casilla vacía
func _slot_button(id: String, size: float, equipped := false, count := 0, page_cell := false) -> Button:
	var p = main.prog
	var b := _Slot.new()
	b.menu = self
	b.id = id
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	var is_eq: bool = id != "" and p.equipment.has(id)
	var tier := int(p.equipment[id]["tier"]) if is_eq else 0
	var col: Color = TIER_COLORS.get(tier, Color(0.2, 0.23, 0.32))
	var chosen := id != "" and id == selected
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := Color(0.07, 0.09, 0.15) if id == "" else col.darkened(0.82)
		if st == "hover" and id != "":
			bg = col.darkened(0.7)
		if page_cell:  # casilla dibujada en el libro: sin fondo ni borde, solo el objeto centrado en el cuadrado del arte
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
			continue
		b.add_theme_stylebox_override(st, _box(bg, Color.WHITE if chosen else col, 3 if chosen else 2, 8, 4))
	if id != "":
		var icon := TextureRect.new()
		icon.texture = load(main.icon_of(id))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		b.add_child(icon)
		if is_eq:  # el detalle aparece al pasar el ratón: estadísticas, comparación con lo puesto y qué hacer con él
			var it: Dictionary = p.equipment[id]
			var cur: String = p.equipped.get(it["slot"], "")
			var on := cur == id
			var lines: Array[String] = ["%s  (%s · %s)" % [it["name"], TIER_NAMES[int(it["tier"])], p.SLOT_NAMES[it["slot"]]]]
			lines.append_array(_mods_lines(it["mods"], {} if (cur == "" or on) else p.equipment[cur]["mods"], not on and cur != ""))
			lines.append(it["desc"])
			if cur != "" and not on:
				lines.append("Reemplaza: %s" % p.equipment[cur]["name"])
			lines.append("Doble clic: %s" % ("quitar" if on else "equipar"))
			if it.has("tool"):
				var cost: Dictionary = main.crafting.up_cost(id)
				if cost.is_empty():
					lines.append("Mejora al máximo (+%d)" % main.crafting.up_level(id))
				else:
					var parts: Array[String] = []
					for m: String in cost:
						parts.append("%s %d/%d" % [main.crafting.item_name(m), main.crafting.count(m), int(cost[m])])
					lines.append("Clic derecho junto al yunque de Bram: mejorar a +%d (%s)" % [main.crafting.up_level(id) + 1, ", ".join(parts)])
			b.tooltip_text = "\n".join(lines)
		else:
			b.tooltip_text = "%s\n%s" % [main.name_of(id), main.crafting.item_desc(id)]
			if count > 0:
				var n := Label.new()
				n.text = "×%d" % count
				n.add_theme_font_size_override("font_size", 14)
				n.add_theme_color_override("font_outline_color", Color.BLACK)
				n.add_theme_constant_override("outline_size", 5)
				n.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
				n.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(n)
		b.pressed.connect(func() -> void:
			selected = id
			refresh())
		b.gui_input.connect(func(ev: InputEvent) -> void:  # doble clic: equipar o quitar; clic derecho en la forja: mejorar la herramienta
			if not (is_eq and ev is InputEventMouseButton and ev.pressed):
				return
			var slot: String = p.equipment[id]["slot"]
			if ev.button_index == MOUSE_BUTTON_LEFT and ev.double_click:
				if p.equipped.get(slot, "") == id:
					p.unequip(slot)
				else:
					p.equip(id)
				main._apply_stats()
				refresh()
			elif ev.button_index == MOUSE_BUTTON_RIGHT and p.equipment[id].has("tool") and main._near_station().get("station", "") == "forge":
				var cost: Dictionary = main.crafting.up_cost(id)
				if not cost.is_empty() and main.crafting.missing(cost).is_empty():
					main.say(main.crafting.upgrade(id), 2.0)
					refresh())
		if equipped:
			var tag := Label.new()
			tag.text = "E"
			tag.add_theme_font_size_override("font_size", 13)
			tag.add_theme_color_override("font_color", Color.BLACK)
			tag.add_theme_stylebox_override("normal", _box(GOLD, GOLD, 0, 4, 2))
			tag.position = Vector2(size - 22, 4)
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(tag)
	return b

func _card(parent: Node, min_size: Vector2) -> VBoxContainer:  # panel con fondo para una columna
	var pc := PanelContainer.new()
	pc.custom_minimum_size = min_size
	pc.add_theme_stylebox_override("panel", _box(Color(0.065, 0.08, 0.14), Color(0.2, 0.24, 0.36), 1, 10, 14))
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	return v

func _book_rect(r: Rect2) -> Rect2:  # px del arte del libro -> pantalla
	return Rect2(book_pos + r.position * BOOK_SCALE, r.size * BOOK_SCALE)

func _place(c: Control, r: Rect2) -> void:
	var sr := _book_rect(r)
	c.position = sr.position
	c.size = sr.size
	c.custom_minimum_size = sr.size
	book_items.add_child(c)

func _build_book() -> void:  # el inventario sobre el libro de PixelLab
	var p = main.prog
	# pestañas dibujadas: «Inventory» (esta) y «Crafting»
	for t in [["inv", Rect2(30, 36, 52, 14)], ["craft", Rect2(175, 36, 52, 14)]]:
		var tb := Button.new()
		tb.flat = true
		tb.focus_mode = Control.FOCUS_NONE
		tb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tb.tooltip_text = "Inventario" if t[0] == "inv" else "Crafteo"
		tb.pressed.connect(_set_tab.bind(t[0]))
		_place(tb, t[1])
	var close := _label("[I] cerrar", book_items, 16, MUTED)
	close.position = book_pos + Vector2(222, 30) * BOOK_SCALE
	# equipo
	for slot: String in EQUIP_CELLS:
		var b := _slot_button(p.equipped.get(slot, ""), 72, true, 0, true)
		b.tooltip_text = b.tooltip_text if b.tooltip_text != "" else p.SLOT_NAMES[slot]
		_place(b, EQUIP_CELLS[slot])
	# barras de vida y maná sobre las del dibujo
	for row in [[175.0, float(main.hero_hp) / maxf(1.0, main.hero_max_hp), Color(0.87, 0.24, 0.14)], [183.0, main.mana / maxf(1.0, float(main.hero_data["mana"])), Color(0.14, 0.62, 0.87)]]:
		var fill := ColorRect.new()
		fill.color = row[2]
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(fill, Rect2(42, row[0], 76.0 * clampf(row[1], 0.0, 1.0), 4))
	# mochila: 16 casillas por página; soltar aquí un objeto de la barra lo quita de ella
	var zone := _Zone.new()
	zone.menu = self
	_place(zone, Rect2(140, 64, 90, 116))
	var all := _backpack()
	var pages := maxi(1, ceili(all.size() / float(BACKPACK_SLOTS)))
	page = clampi(page, 0, pages - 1)
	var equipped_ids: Array = p.equipped.values()
	for i in BACKPACK_SLOTS:
		var idx := page * BACKPACK_SLOTS + i
		var id: String = all[idx] if idx < all.size() else ""
		var b := _slot_button(id, 72, equipped_ids.has(id), 0 if p.equipment.has(id) or id == "" else main.crafting.count(id), true)
		_place(b, Rect2(PACK_X[i % 4], PACK_Y[i / 4], 18, 18))
	var coins := _label("Monedas: %d" % p.coins, book_items, 22, INK)
	coins.position = book_pos + Vector2(143, 179) * BOOK_SCALE
	if pages > 1:
		for dir in [-1, 1]:
			var ab := Button.new()
			ab.text = "◀" if dir < 0 else "▶"
			ab.focus_mode = Control.FOCUS_NONE
			ab.disabled = page + dir < 0 or page + dir >= pages
			ab.pressed.connect(func() -> void:
				page += dir
				refresh())
			_place(ab, Rect2(203 + (dir + 1) * 6, 180, 10, 9))

func _build_magic() -> void:
	var p = main.prog
	var data: Dictionary = p.skill_data
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	body.add_child(top)
	_label("Árbol de habilidades del grimorio", top, 24, GOLD)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	_label("Puntos de habilidad: %d   (1 por nivel y 1 por jefe)" % p.skill_points, top, 20, GOOD if p.skill_points > 0 else MUTED)
	var cost: int = int(data["respec_cost_per_level"]) * p.level
	var rb := Button.new()
	rb.text = "Reiniciar (%d monedas)" % cost
	rb.focus_mode = Control.FOCUS_NONE
	rb.disabled = p.skills.is_empty() or p.coins < cost
	rb.pressed.connect(func() -> void:
		p.coins -= cost
		p.respec()
		main._apply_stats()
		refresh())
	top.add_child(rb)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	body.add_child(cols)
	for br: Dictionary in data["branches"]:
		var card := _card(cols, Vector2(0, 0))
		card.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(str(br["name"]), card, 22, GOLD)
		_label(str(br["desc"]), card, 14, MUTED)
		card.add_child(HSeparator.new())
		for sid: String in br["skills"]:
			var d: Dictionary = data["skills"][sid]
			var rank: int = p.skill_rank(sid)
			var why: String = p.why_not_learn(sid)
			var b := Button.new()
			b.text = "%s   %d / %d" % [d["name"], rank, int(d["max"])]
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(0, 46)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.tooltip_text = str(d["desc"])
			b.disabled = why != ""
			var skill_id := sid
			b.pressed.connect(func() -> void:
				if p.learn(skill_id):
					main._apply_stats()
				refresh())
			card.add_child(b)
			var l := _label(d["desc"] if (why == "" or rank > 0) else why, card, 13, MUTED if why == "" or rank > 0 else BAD)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD

# --- pesca: libro de capturas, acuario y estado del día
func _build_fishing() -> void:
	var an = main.angler
	var cr = main.crafting
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	body.add_child(cols)
	var left := _card(cols, Vector2(520, 0))
	_label("Libro de capturas   %d / %d" % [an.book.size(), an.species_total()], left, 22, GOLD)
	for id: String in an.cfg["fish"]:
		var e: Variant = an.book.get(id)
		if e == null:
			_label("???", left, 16, MUTED)
		else:
			_label("%s  ·  ×%d  ·  récord %d cm%s" % [cr.item_name(id), int(e["count"]), int(e["best_cm"]), ("  " + "★".repeat(int(e["best_star"]))) if int(e["best_star"]) > 0 else ""], left, 16)
	left.add_child(HSeparator.new())
	for i: int in an.cfg["book"].size():
		var m: Dictionary = an.cfg["book"][i]
		_label("%s %d especies: %s" % ["✔" if an.claimed.has(i) else "○", int(m["species"]), ("%d monedas" % int(m["coins"])) if m.has("coins") else "%s ×%d" % [cr.item_name(str(m["item"])), int(m.get("qty", 1))]], left, 15, MUTED)
	var right := _card(cols, Vector2(0, 0))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(main.clock.text(), right, 18, GOLD)
	_label("Plato favorito de hoy: %s (efectos mayores)" % cr.item_name(cr.favorite_dish(main.clock.day)), right, 15, MUTED)
	_label("Cebo elegido: %s   ([B] con la caña en la barra)" % (cr.item_name(main.bait) if main.bait != "" else "ninguno"), right, 15, MUTED)
	right.add_child(HSeparator.new())
	_label("Mejoras de la caña (valen para cualquier caña)", right, 18, GOLD)
	for part: Array in [["reel", "carrete_pesca", "Carrete: barra más larga y más rápida"], ["line", "sedal_trenzado", "Sedal trenzado: +1 casilla y más tiempo para clavar"]]:
		var key: String = part[0]
		var pid: String = part[1]
		if main.prog.rod_parts.has(key):
			_label("✔ " + str(part[2]), right, 15, MUTED)
		else:
			var ib := Button.new()
			ib.text = "Instalar: %s  (tienes %d)" % [cr.item_name(pid), cr.count(pid)]
			ib.focus_mode = Control.FOCUS_NONE
			ib.disabled = cr.count(pid) <= 0
			ib.pressed.connect(func() -> void:
				cr.take(pid, 1)
				main.prog.rod_parts[key] = true
				main.say("Caña mejorada: " + str(part[2]), 2.5)
				refresh())
			right.add_child(ib)
	right.add_child(HSeparator.new())
	_label("Acuario  %d / %d   (cada día producen)" % [an.tank.size(), an.slots()], right, 20, GOLD)
	for i: int in an.tank.size():
		var idx: int = i
		var row := HBoxContainer.new()
		right.add_child(row)
		_label(cr.item_name(an.tank[i]), row, 16).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := Button.new()
		b.text = "Sacar"
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			main.say(an.release(idx), 1.5)
			refresh())
		row.add_child(b)
	var collect := Button.new()
	collect.text = "Recoger producción" + ("" if an.bin.is_empty() else " (lista)")
	collect.focus_mode = Control.FOCUS_NONE
	collect.disabled = an.bin.is_empty()
	collect.pressed.connect(func() -> void:
		main.say(an.collect(), 2.5)
		refresh())
	right.add_child(collect)
	right.add_child(HSeparator.new())
	_label("Meter un pez en el acuario:", right, 16, MUTED)
	var any := false
	for id: String in an.cfg["aquarium"]["yield"]:
		if cr.count(id) > 0:
			any = true
			var fid := id
			var b := Button.new()
			b.text = "%s ×%d" % [cr.item_name(id), cr.count(id)]
			b.focus_mode = Control.FOCUS_NONE
			b.disabled = an.tank.size() >= an.slots()
			b.pressed.connect(func() -> void:
				main.say(an.deposit(fid), 1.5)
				refresh())
			right.add_child(b)
	if not any:
		_label("No llevas peces. Pesca alguno.", right, 15, MUTED)

# --- crafteo a mano (estilo Terraria): recetas a la izquierda, tus materiales y consumibles a la derecha
func _book_text(text: String, r: Rect2, size: int, color: Color, center := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(l, r)
	return l

func _book_icon(id: String, r: Rect2, dim := false) -> TextureRect:
	var ic := TextureRect.new()
	ic.texture = load(main.icon_of(id))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		ic.modulate = Color(1, 1, 1, 0.45)
	_place(ic, r)
	return ic

func _build_craft_book() -> void:  # crafteo a mano sobre el libro: recetas a la izquierda, objeto, ingredientes y botón a la derecha
	var cr = main.crafting
	for t in [["inv", Rect2(30, 36, 52, 14)], ["craft", Rect2(175, 36, 52, 14)]]:
		var tb := Button.new()
		tb.flat = true
		tb.focus_mode = Control.FOCUS_NONE
		tb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tb.tooltip_text = "Inventario" if t[0] == "inv" else "Crafteo"
		tb.pressed.connect(_set_tab.bind(t[0]))
		_place(tb, t[1])
	var close := _label("[I] cerrar", book_items, 16, MUTED)
	close.position = book_pos + Vector2(222, 30) * BOOK_SCALE
	var ids: Array = cr.recipes_for("hand")
	if ids.is_empty():
		return
	if not ids.has(craft_sel):
		craft_sel = ids[0]
	var per := CRAFT_ROWS_Y.size()
	var pages := ceili(ids.size() / float(per))
	craft_page = clampi(craft_page, 0, pages - 1)
	# recetas: una por fila del dibujo; la elegida se marca con un velo dorado suave
	for k in per:
		var idx := craft_page * per + k
		if idx >= ids.size():
			break
		var rid: String = ids[idx]
		var out: String = cr.output_of(rid)
		var ok: bool = cr.why_not(rid) == ""
		var y: float = CRAFT_ROWS_Y[k]
		if rid == craft_sel:
			var mark := ColorRect.new()
			mark.color = Color(0.85, 0.6, 0.2, 0.22)
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_place(mark, Rect2(32, y, 81, 16))
		_book_icon(out, Rect2(34.5, y + 2, 13, 13), not ok)
		var nm: String = cr.item_name(out) + (" ×%d" % cr.qty_of(rid) if cr.qty_of(rid) > 1 and not main.prog.equipment.has(out) else "")
		for other: String in ids:  # dos recetas con el mismo resultado se distinguen por su ingrediente principal
			if other != rid and cr.output_of(other) == out:
				nm += " (%s)" % cr.item_name(cr.inputs_of(rid).keys()[0]).to_lower()
				break
		_book_text(nm, Rect2(51, y, 60, 17), 17, INK if ok else Color(0.45, 0.36, 0.27))
		var rb := Button.new()
		rb.flat = true
		rb.focus_mode = Control.FOCUS_NONE
		rb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		rb.tooltip_text = cr.item_desc(out) if ok else cr.why_not(rid)
		rb.pressed.connect(func() -> void:
			craft_sel = rid
			refresh())
		_place(rb, Rect2(31, y, 82, 17))
	if pages > 1:
		for dir in [-1, 1]:
			var ab := Button.new()
			ab.text = "◀" if dir < 0 else "▶"
			ab.focus_mode = Control.FOCUS_NONE
			ab.disabled = craft_page + dir < 0 or craft_page + dir >= pages
			ab.pressed.connect(func() -> void:
				craft_page += dir
				refresh())
			ab.tooltip_text = "Página %d / %d" % [craft_page + 1, pages]
			_place(ab, Rect2(103 + (dir + 1) * 5, 52, 8, 8))  # junto al título «Recetas»
	# objeto: icono grande, nombre y descripción (las estadísticas, al pasar el ratón)
	var out: String = cr.output_of(craft_sel)
	_book_icon(out, Rect2(170, 72, 26, 26))
	var hover := Control.new()
	hover.tooltip_text = cr.item_desc(out)
	if main.prog.equipment.has(out):
		var lines: Array[String] = [main.prog.equipment[out]["name"]]
		lines.append_array(_mods_lines(main.prog.equipment[out]["mods"]))
		hover.tooltip_text = "\n".join(lines)
	_place(hover, Rect2(166, 68, 34, 34))
	_book_text(cr.item_name(out), Rect2(146, 106, 78, 9), 19, INK, true)
	var d := _book_text(cr.item_desc(out), Rect2(146, 115, 78, 18), 13, Color(0.32, 0.24, 0.16), true)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.clip_text = false
	d.max_lines_visible = 2
	# ingredientes: icono en cada casilla y lo que tienes / lo que pide
	var ins: Dictionary = cr.inputs_of(craft_sel)
	var miss: Dictionary = cr.missing(ins)
	var k2 := 0
	for id: String in ins:
		if k2 >= CRAFT_INGR_X.size():
			break
		var x: float = CRAFT_INGR_X[k2]
		_book_icon(id, Rect2(x + 1, CRAFT_INGR_Y + 1, 14, 14))
		_book_text("%d/%d" % [cr.count(id), int(ins[id])], Rect2(x - 2, CRAFT_INGR_Y + 16, 20, 6), 13, Color(0.7, 0.15, 0.12) if miss.has(id) else Color(0.18, 0.4, 0.15), true)
		var tip := Control.new()
		tip.tooltip_text = "%s: tienes %d, necesitas %d" % [cr.item_name(id), cr.count(id), int(ins[id])]
		_place(tip, Rect2(x, CRAFT_INGR_Y, 16, 16))
		k2 += 1
	# botón dibujado «Craftear» (también con Intro)
	var reason: String = cr.why_not(craft_sel)
	var go := Button.new()
	go.flat = true
	go.focus_mode = Control.FOCUS_NONE
	go.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if reason == "" else Control.CURSOR_FORBIDDEN
	go.tooltip_text = "Craftear  [Intro]" if reason == "" else reason
	go.pressed.connect(_craft_now)
	_place(go, Rect2(144, 169, 79, 22))
	if reason != "":  # sin materiales: el botón se ve apagado
		var veil := ColorRect.new()
		veil.color = Color(0.85, 0.78, 0.62, 0.45)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(veil, Rect2(146, 172, 75, 16))

func _craft_now() -> void:
	if craft_sel == "" or main.crafting.why_not(craft_sel) != "":
		return
	var r: Dictionary = main.crafting.craft(craft_sel)
	if r["ok"]:
		main._apply_stats()
		main.save_game()
	main.say(("¡Obtuviste %s!" % r["msg"]) if r["ok"] else r["msg"], 2.0)
	refresh()

func _slider_row(grid: GridContainer, text: String, hint: String, value: float, on: Callable) -> void:  # etiqueta, control 0-100 % y pista
	_label(text, grid, 19)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(260, 28)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct := _label("%d %%" % roundi(value * 100.0), grid, 19, GOLD)
	s.value_changed.connect(func(v: float) -> void:
		on.call(v)
		pct.text = "%d %%" % roundi(v * 100.0)
		main.settings.save())
	grid.add_child(s)
	_label(hint, grid, 15, MUTED)

func _build_options() -> void:
	var st: RefCounted = main.settings
	var card := _card(body, Vector2(0, 0))
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label("Accesibilidad de efectos", card, 22, GOLD)
	var g1 := GridContainer.new()
	g1.columns = 4
	g1.add_theme_constant_override("h_separation", 28)
	g1.add_theme_constant_override("v_separation", 14)
	card.add_child(g1)
	_slider_row(g1, "Temblor de cámara", "Sacudidas e impulso al golpear (0 % = cámara quieta)", st.shake, func(v: float) -> void: st.shake = v)
	_slider_row(g1, "Destellos", "Flash blanco al golpear y luces de impacto (0 % = sin destellos)", st.flash, func(v: float) -> void: st.flash = v)
	var hs := CheckButton.new()
	hs.text = "Pausa de impacto en golpes pesados"
	hs.button_pressed = st.hitstop
	hs.focus_mode = Control.FOCUS_NONE
	hs.add_theme_font_size_override("font_size", 19)
	hs.toggled.connect(func(on: bool) -> void:
		st.hitstop = on
		st.save())
	card.add_child(hs)
	card.add_child(HSeparator.new())
	_label("Sonido", card, 22, GOLD)
	var g2 := GridContainer.new()
	g2.columns = 4
	g2.add_theme_constant_override("h_separation", 28)
	g2.add_theme_constant_override("v_separation", 14)
	card.add_child(g2)
	_slider_row(g2, "Volumen general", "", st.master, func(v: float) -> void:
		st.master = v
		st.apply_audio())
	_slider_row(g2, "Efectos", "Golpes, avisos y voces", st.sfx, func(v: float) -> void:
		st.sfx = v
		st.apply_audio())
	_slider_row(g2, "Música y ambiente", "Tema de cada zona y capa de combate", st.music, func(v: float) -> void:
		st.music = v
		st.apply_audio())
	_label("Los avisos de peligro (zonas rojas, línea de tiro) usan forma y color: no dependen de los destellos.", card, 15, MUTED)

func _build_stats() -> void:
	var p = main.prog
	var top := _card(body, Vector2(0, 0))
	_label("Nivel %d" % p.level, top, 26, GOLD)
	var bar := ProgressBar.new()
	bar.max_value = p.xp_needed()
	bar.value = p.xp
	bar.custom_minimum_size = Vector2(0, 22)
	bar.show_percentage = false
	var fill := _box(Color(0.6, 0.4, 0.9), Color(0.6, 0.4, 0.9), 0, 6, 0)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", _box(Color(0.1, 0.1, 0.16), Color(0.25, 0.28, 0.4), 1, 6, 0))
	top.add_child(bar)
	_label("XP %d / %d      Puntos disponibles: %d" % [p.xp, p.xp_needed(), p.points], top, 18, Color.WHITE if p.points == 0 else GOOD)
	var rows := _card(body, Vector2(0, 0))
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 10)
	rows.add_child(grid)
	for s: String in p.STATS:
		_label(p.STAT_NAMES[s], grid, 19)
		var bonus := int(p.bonus(s))
		_label("%d%s" % [p.spent[s], ("  (+%d equipo)" % bonus) if bonus != 0 else ""], grid, 19, GOLD)
		_label(p.STAT_INFO[s], grid, 15, MUTED)
		var b := Button.new()
		b.text = "+"
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(48, 34)
		b.disabled = p.points <= 0
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			var on: bool = st != "disabled"
			b.add_theme_stylebox_override(st, _box(Color(0.35, 0.27, 0.1) if on else Color(0.1, 0.12, 0.18), GOLD if on else Color(0.25, 0.28, 0.36), 2, 8, 4))
		b.pressed.connect(func() -> void:
			p.spend(s)
			main._apply_stats()
			refresh())
		grid.add_child(b)
	rows.add_child(HSeparator.new())
	_label("Vida máx. %d   ·   Maná máx. %d   ·   Estamina máx. %d" % [main.hero_max_hp, main.hero_data["mana"], main.hero_data["stamina"]], rows, 17)
	_label("Daño de espada ×%.2f   ·   Daño de magia ×%.2f   ·   Daño recibido ×%.2f" % [p.melee_mult(), p.magic_mult(), p.defense_mult()], rows, 17)
	_label("Velocidad de movimiento ×%.2f   ·   Velocidad de ataque ×%.2f" % [p.move_mult(), p.attack_speed()], rows, 17)

class _Slot extends Button:  # casilla de objeto: se puede arrastrar y, si es de la barra (index >= 0), recibe objetos
	var menu: Node
	var index := -1
	var id := ""

	func _get_drag_data(_at: Vector2) -> Variant:
		if id == "" or not menu.main.can_hotbar(id):
			return null
		var prev := TextureRect.new()
		prev.texture = load(menu.main.icon_of(id))
		prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		prev.size = Vector2(64, 64)
		prev.position = Vector2(-32, -32)
		var c := Control.new()
		c.add_child(prev)
		set_drag_preview(c)
		return {"id": id, "from": index}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("id") and (index >= 0 or int(data.get("from", -1)) >= 0)

	func _drop_data(_at: Vector2, data: Variant) -> void:
		if index >= 0:
			menu.main.hotbar_drop(str(data["id"]), index)
		else:
			menu.main.hotbar_clear(int(data["from"]))
		menu.refresh()

class _Zone extends Control:  # la mochila: soltar aquí un objeto de la barra lo quita de ella
	var menu: Node

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and int(data.get("from", -1)) >= 0

	func _drop_data(_at: Vector2, data: Variant) -> void:
		menu.main.hotbar_clear(int(data["from"]))
		menu.refresh()
