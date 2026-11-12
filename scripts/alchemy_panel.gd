extends HBoxContainer
# Mesa de alquimia: eliges un plano de tu colección (se coloca sobre la mesa), colocas uno a uno los ingredientes que pide y,
# con todo en su sitio, preparas la poción con una animación. Los planos se aprenden y no se gastan; el catalizador (opcional) duplica.

signal brewed(result: Dictionary)

const GOLD := Color("#d9a441")
const MUTED := Color(0.6, 0.65, 0.75)
const GOOD := Color(0.45, 0.9, 0.5)
const BAD := Color(0.95, 0.4, 0.4)

var main: Node
var plano := ""
var placed: Dictionary = {}
var catalyst_on := false
var busy := false
var list_grid: GridContainer
var table_view: Control   # PlanoView grande
var stage: Control        # AlchemyFX
var req_box: VBoxContainer
var msg: Label
var brew_btn: Button
var anim_t := 0.0

func setup(m: Node) -> void:
	main = m
	add_theme_constant_override("separation", 14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	# izquierda: colección de planos
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(360, 0)
	left.add_theme_stylebox_override("panel", _box(Color(0.05, 0.06, 0.11), Color(0.25, 0.28, 0.4), 2, 8, 8))
	add_child(left)
	var lv := VBoxContainer.new()
	left.add_child(lv)
	_label("Tus planos", lv, 18, GOLD)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(scroll)
	list_grid = GridContainer.new()
	list_grid.columns = 2
	list_grid.add_theme_constant_override("h_separation", 8)
	list_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(list_grid)
	# centro: el plano sobre la mesa y el frasco
	var mid := PanelContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_stylebox_override("panel", _box(Color(0.05, 0.06, 0.11), Color(0.25, 0.28, 0.4), 2, 8, 10))
	add_child(mid)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 8)
	mid.add_child(mv)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mv.add_child(row)
	table_view = preload("res://scripts/plano_view.gd").new()
	table_view.main = main
	table_view.custom_minimum_size = Vector2(250, 330)
	row.add_child(table_view)
	stage = preload("res://scripts/alchemy_fx.gd").new()
	stage.main = main
	stage.custom_minimum_size = Vector2(300, 330)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stage)
	msg = _label("Elige un plano de tu colección.", mv, 16, MUTED)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brew_btn = Button.new()
	brew_btn.focus_mode = Control.FOCUS_NONE
	brew_btn.custom_minimum_size = Vector2(0, 48)
	brew_btn.add_theme_font_size_override("font_size", 20)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := Color(0.35, 0.27, 0.1) if st != "hover" else Color(0.5, 0.38, 0.12)
		if st == "disabled":
			bg = Color(0.12, 0.13, 0.2)
		brew_btn.add_theme_stylebox_override(st, _box(bg, GOLD if st != "disabled" else Color(0.25, 0.28, 0.4), 2, 8, 6))
	brew_btn.pressed.connect(start_brew)
	mv.add_child(brew_btn)
	# derecha: ingredientes
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(330, 0)
	right.add_theme_stylebox_override("panel", _box(Color(0.05, 0.06, 0.11), Color(0.25, 0.28, 0.4), 2, 8, 10))
	add_child(right)
	req_box = VBoxContainer.new()
	req_box.add_theme_constant_override("separation", 6)
	right.add_child(req_box)
	refresh()

func _box(bg: Color, border: Color, width := 2, radius := 8, margin := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s

func _label(text: String, parent: Node, size := 16, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l

func _icon(id: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(main.crafting.icon(id))
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t

func select_plano(id: String) -> void:  # coloca un plano sobre la mesa (devuelve los ingredientes colocados)
	if busy:
		return
	plano = id
	placed.clear()
	catalyst_on = false
	refresh()

func refresh() -> void:
	var cr = main.crafting
	for c in list_grid.get_children():
		c.queue_free()
	for pid: String in cr.cfg["blueprints"]:
		if not cr.knows(pid):
			continue
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(160, 150)
		var chosen: bool = pid == plano
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, _box(Color(0.09, 0.11, 0.18), GOLD if chosen else Color(0.2, 0.23, 0.33), 3 if chosen else 1, 6, 3))
		var pv: Control = preload("res://scripts/plano_view.gd").new()
		pv.main = main
		pv.plano_id = pid
		pv.compact = true
		pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
		b.add_child(pv)
		b.pressed.connect(select_plano.bind(pid))
		list_grid.add_child(b)
	var unknown := 0
	for pid: String in cr.cfg["blueprints"]:
		if not cr.knows(pid):
			unknown += 1
	if unknown > 0:
		var hint := _label("Planos por descubrir: %d\n(los venden, caen de monstruos y jefes)" % unknown, list_grid, 13, MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD
		hint.custom_minimum_size = Vector2(160, 0)
	table_view.plano_id = plano
	table_view.placed = placed
	_refresh_stage()
	_build_reqs()

func _refresh_stage() -> void:
	var cr = main.crafting
	stage.placed_tex.clear()
	if plano != "":
		var bp: Dictionary = cr.cfg["blueprints"][plano]
		stage.color = Color(bp["color"])
		stage.result_tex = load(cr.icon(bp["output"]))
		for id: String in bp["inputs"]:
			if placed.get(id, false):
				stage.placed_tex.append(load(cr.icon(id)))
	var cat: String = cr.cfg["alchemy_catalyst"]["id"]
	stage.catalyst_tex = load(cr.icon(cat))
	stage.catalyst_on = catalyst_on

func _build_reqs() -> void:
	var cr = main.crafting
	for c in req_box.get_children():
		c.queue_free()
	if plano == "":
		var t := _label("Sobre la mesa", req_box, 20, GOLD)
		var d := _label("Coloca un plano y pon encima los ingredientes que pide su dibujo. El plano no se gasta: es conocimiento.", req_box, 15, MUTED)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD
		brew_btn.text = "Elige un plano"
		brew_btn.disabled = true
		return
	var bp: Dictionary = cr.cfg["blueprints"][plano]
	_label("Ingredientes", req_box, 20, GOLD)
	var hint := _label(bp["hint"], req_box, 14, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	var all_ok := true
	for id: String in bp["inputs"]:
		var need: int = int(bp["inputs"][id])
		var have: int = cr.count(id)
		var on: bool = placed.get(id, false)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		req_box.add_child(row)
		row.add_child(_icon(id, 36))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		_label(cr.item_name(id), info, 16)
		_label("tienes %d · pide %d" % [have, need], info, 13, GOOD if have >= need else BAD)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(96, 36)
		b.text = "✔ Quitar" if on else "Colocar"
		b.disabled = busy or (not on and have < need)
		b.pressed.connect(func() -> void:
			placed[id] = not placed.get(id, false)
			refresh())
		row.add_child(b)
		all_ok = all_ok and on and have >= need
	req_box.add_child(HSeparator.new())
	var cat: String = cr.cfg["alchemy_catalyst"]["id"]
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 8)
	req_box.add_child(crow)
	crow.add_child(_icon(cat, 36))
	var ci := VBoxContainer.new()
	ci.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crow.add_child(ci)
	_label("Catalizador (opcional)", ci, 15, GOLD)
	_label("%s · tienes %d" % [cr.item_name(cat), cr.count(cat)], ci, 13, MUTED)
	var cb := Button.new()
	cb.focus_mode = Control.FOCUS_NONE
	cb.custom_minimum_size = Vector2(96, 36)
	cb.text = "✔ Quitar" if catalyst_on else "Añadir"
	cb.disabled = busy or (not catalyst_on and cr.count(cat) < 1)
	cb.pressed.connect(func() -> void:
		catalyst_on = not catalyst_on
		refresh())
	crow.add_child(cb)
	var cd := _label(cr.cfg["alchemy_catalyst"]["bonus"], req_box, 13, MUTED)
	cd.autowrap_mode = TextServer.AUTOWRAP_WORD
	var n: int = int(bp["qty"]) * (2 if catalyst_on else 1)
	brew_btn.text = "Preparar  → %s ×%d" % [cr.item_name(bp["output"]), n] if all_ok else "Coloca todos los ingredientes"
	brew_btn.disabled = busy or not all_ok

func start_brew() -> void:
	if busy or plano == "" or brew_btn.disabled:
		return
	busy = true
	anim_t = 0.0
	stage.start(float(main.crafting.cfg["stations"]["alchemy"]["time"]))
	table_view.glow = 1.0
	brew_btn.disabled = true
	brew_btn.text = "Preparando…"
	msg.text = ""
	main.combat.play("magic")

func _process(delta: float) -> void:
	if table_view:
		table_view.queue_redraw()
	if not busy:
		return
	anim_t += delta
	if anim_t >= stage.length:
		busy = false
		var r: Dictionary = main.crafting.brew(plano, catalyst_on)
		table_view.glow = 0.0
		if r["ok"]:
			stage.finish()
			main.combat.play("heavy")
			msg.text = "¡Obtuviste %s!" % r["msg"]
			msg.add_theme_color_override("font_color", GOOD)
			placed.clear()
			catalyst_on = false
			main.save_game()
			brewed.emit(r)
		else:
			msg.text = r["msg"]
			msg.add_theme_color_override("font_color", BAD)
			stage.running = false
		var keep := msg.text
		refresh()
		msg.text = keep
