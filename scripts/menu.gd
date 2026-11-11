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
	var panel := PanelContainer.new()
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
	for pair in [["inv", "Inventario"], ["stats", "Estadísticas"], ["opt", "Opciones"]]:
		var b := Button.new()
		b.text = pair[1]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 40)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_set_tab.bind(pair[0]))
		head.add_child(b)
		tab_buttons[pair[0]] = b
	_label("[I] cerrar", head, 16, MUTED)
	v.add_child(HSeparator.new())
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)

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

func refresh() -> void:
	var p = main.prog
	if selected != "" and not p.owned.has(selected):
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
	if tab == "inv":
		_build_inv()
	elif tab == "opt":
		_build_options()
	else:
		_build_stats()

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
func _slot_button(id: String, size: float, equipped := false) -> Button:
	var p = main.prog
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	var tier := 0 if id == "" else int(p.equipment[id]["tier"])
	var col: Color = TIER_COLORS.get(tier, Color(0.2, 0.23, 0.32))
	var chosen := id != "" and id == selected
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := Color(0.07, 0.09, 0.15) if id == "" else col.darkened(0.82)
		if st == "hover" and id != "":
			bg = col.darkened(0.7)
		b.add_theme_stylebox_override(st, _box(bg, Color.WHITE if chosen else col, 3 if chosen else 2, 8, 4))
	if id != "":
		var icon := TextureRect.new()
		icon.texture = load(main.item_icon(id))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
		b.add_child(icon)
		b.tooltip_text = "%s\n%s" % [p.equipment[id]["name"], "\n".join(_mods_lines(p.equipment[id]["mods"]))]
		b.pressed.connect(func() -> void:
			selected = id
			refresh())
		b.gui_input.connect(func(ev: InputEvent) -> void:  # doble clic: equipar
			if ev is InputEventMouseButton and ev.pressed and ev.double_click and not equipped:
				p.equip(id)
				main._apply_stats()
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

func _build_inv() -> void:
	var p = main.prog
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	body.add_child(cols)
	# --- equipo: muñeco de ranuras (collar arriba; espada, armadura y grimorio en medio; anillo abajo)
	var left := _card(cols, Vector2(340, 0))
	_label("Equipo", left, 22, GOLD)
	var doll := GridContainer.new()
	doll.columns = 3
	doll.add_theme_constant_override("h_separation", 10)
	doll.add_theme_constant_override("v_separation", 8)
	doll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(doll)
	for slot in ["", "amulet", "", "sword", "armor", "grimoire", "", "ring", ""]:
		if slot == "":
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(92, 92)
			doll.add_child(sp)
			continue
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		doll.add_child(cell)
		cell.add_child(_slot_button(p.equipped.get(slot, ""), 92, true))
		var nm := _label(p.SLOT_NAMES[slot], cell, 14, MUTED)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(HSeparator.new())
	_label("Monedas: %d" % p.coins, left, 18, GOLD)
	_label("Pociones de vida: %d   [H]" % p.potions, left, 18, Color(0.95, 0.5, 0.5))
	_label("Materiales", left, 18, GOLD)
	if p.materials.is_empty():
		_label("(ninguno)", left, 15, MUTED)
	for id: String in p.materials:
		_label("%s  ×%d" % [p.material_names[id], p.materials[id]], left, 15)
	# --- mochila: cuadrícula de objetos (clic = ver, doble clic = equipar)
	var mid := _card(cols, Vector2(430, 0))
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label("Mochila  (%d)" % p.owned.size(), mid, 22, GOLD)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	var equipped_ids: Array = p.equipped.values()
	for id: String in p.owned:
		grid.add_child(_slot_button(id, 84, equipped_ids.has(id)))
	for i in maxi(0, BACKPACK_SLOTS - p.owned.size()):
		grid.add_child(_slot_button("", 84))
	if p.owned.is_empty():
		_label("Abre los cofres de la dungeon para conseguir equipo.", mid, 15, MUTED)
	# --- detalle del objeto elegido, con comparación contra lo que llevas puesto
	var right := _card(cols, Vector2(330, 0))
	_label("Detalle", right, 22, GOLD)
	if selected == "":
		_label("Elige un objeto para ver sus estadísticas.", right, 16, MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD
		return
	var it: Dictionary = p.equipment[selected]
	var tier := int(it["tier"])
	var tcol: Color = TIER_COLORS[tier]
	var big := _slot_button(selected, 128, p.equipped.get(it["slot"], "") == selected)
	big.disabled = false
	big.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(big)
	var nm := _label(it["name"], right, 22, tcol)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label("%s  ·  %s" % [TIER_NAMES[tier], p.SLOT_NAMES[it["slot"]]], right, 15, MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(HSeparator.new())
	var cur_id: String = p.equipped.get(it["slot"], "")
	var is_eq := cur_id == selected
	var vs: Dictionary = {} if (cur_id == "" or is_eq) else p.equipment[cur_id]["mods"]
	for line in _mods_lines(it["mods"], vs, not is_eq and cur_id != ""):
		var good := not line.contains("▼")
		_label(line, right, 17, GOOD if good else BAD)
	var d := _label(it["desc"], right, 15, MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD
	if cur_id != "" and not is_eq:
		_label("Reemplaza: %s" % p.equipment[cur_id]["name"], right, 14, MUTED)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(sp)
	var act := Button.new()
	act.text = "Quitar" if is_eq else "Equipar"
	act.focus_mode = Control.FOCUS_NONE
	act.custom_minimum_size = Vector2(0, 44)
	act.add_theme_font_size_override("font_size", 18)
	for st in ["normal", "hover", "pressed", "focus"]:
		act.add_theme_stylebox_override(st, _box(Color(0.35, 0.27, 0.1) if st != "hover" else Color(0.5, 0.38, 0.12), GOLD, 2, 8, 6))
	act.pressed.connect(func() -> void:
		if is_eq:
			p.unequip(it["slot"])
		else:
			p.equip(selected)
		main._apply_stats()
		refresh())
	right.add_child(act)

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
