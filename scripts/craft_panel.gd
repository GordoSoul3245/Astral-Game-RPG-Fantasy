extends HBoxContainer
# Panel de recetas (manos, forja y cocina): lista agrupada a la izquierda, detalle y animación del oficio a la derecha.
# Lo alojan el menú (pestaña Crafteo, estación "hand") y station_ui.gd (forja de Bram y fogata). La lógica vive en crafting.gd.

signal crafted(result: Dictionary)

const GOLD := Color("#d9a441")
const MUTED := Color(0.6, 0.65, 0.75)
const GOOD := Color(0.45, 0.9, 0.5)
const BAD := Color(0.95, 0.4, 0.4)
const TIER_COLORS := {1: Color("#8fa38f"), 2: Color("#4f8cff"), 3: Color("#e0a93a")}

var main: Node
var station := "hand"
var selected := ""
var busy := false
var list_box: VBoxContainer
var detail: VBoxContainer
var fx: Control
var msg: Label
var anim_t := 0.0
var anim_len := 1.0
var anim_recipe := ""

func setup(m: Node, st: String) -> void:
	main = m
	station = st
	add_theme_constant_override("separation", 16)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	left.add_theme_stylebox_override("panel", _box(Color(0.05, 0.06, 0.11), Color(0.25, 0.28, 0.4), 2, 8, 8))
	add_child(left)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 4)
	scroll.add_child(list_box)
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", _box(Color(0.05, 0.06, 0.11), Color(0.25, 0.28, 0.4), 2, 8, 12))
	add_child(right)
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 6)
	right.add_child(detail)
	var ids: Array = main.crafting.recipes_for(station)
	if selected == "" and not ids.is_empty():
		selected = ids[0]
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
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func refresh() -> void:
	var cr = main.crafting
	for c in list_box.get_children():
		c.queue_free()
	var last := ""
	for rid: String in cr.recipes_for(station):
		var g: String = cr.cfg["recipes"][rid]["group"]
		if g != last:
			last = g
			var h := _label(g, list_box, 15, GOLD)
			h.add_theme_constant_override("line_spacing", 6)
		list_box.add_child(_row(rid))
	_build_detail()

func _row(rid: String) -> Button:
	var cr = main.crafting
	var out: String = cr.output_of(rid)
	var ok: bool = cr.why_not(rid) == ""
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 48)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var chosen: bool = rid == selected
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := Color(0.09, 0.11, 0.18) if not chosen else Color(0.2, 0.17, 0.08)
		if st == "hover":
			bg = bg.lightened(0.08)
		b.add_theme_stylebox_override(st, _box(bg, GOLD if chosen else Color(0.2, 0.23, 0.33), 2 if chosen else 1, 6, 4))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	row.add_theme_constant_override("separation", 8)
	b.add_child(row)
	var ic := _icon(out, 38)
	ic.modulate = Color.WHITE if ok else Color(1, 1, 1, 0.45)
	row.add_child(ic)
	var label_text: String = cr.item_name(out) + (" ×%d" % cr.qty_of(rid) if cr.qty_of(rid) > 1 and not main.prog.equipment.has(out) else "")
	for other: String in cr.recipes_for(station):  # dos recetas con el mismo resultado se distinguen por su ingrediente principal
		if other != rid and cr.output_of(other) == out:
			label_text += "  (%s)" % cr.item_name(cr.inputs_of(rid).keys()[0]).to_lower()
			break
	var n := _label(label_text, row, 17, Color.WHITE if ok else MUTED)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		if busy:
			return
		selected = rid
		refresh())
	return b

func _build_detail() -> void:
	var cr = main.crafting
	for c in detail.get_children():
		c.queue_free()
	if selected == "":
		_label("No hay recetas aquí.", detail, 18, MUTED)
		return
	var out: String = cr.output_of(selected)
	var stn: Dictionary = cr.cfg["stations"][station]
	fx = preload("res://scripts/craft_fx.gd").new()
	fx.custom_minimum_size = Vector2(0, 190)
	fx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fx.main = main
	fx.station = station
	fx.icon_tex = load(cr.icon(out))
	detail.add_child(fx)
	var tier: int = int(main.prog.equipment[out]["tier"]) if main.prog.equipment.has(out) else 0
	var nm := _label(cr.item_name(out), detail, 24, TIER_COLORS.get(tier, Color.WHITE))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var d := _label(cr.item_desc(out), detail, 15, MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if main.prog.equipment.has(out):
		for line in _mods_lines(main.prog.equipment[out]["mods"]):
			var l := _label(line, detail, 16, GOOD)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.add_child(HSeparator.new())
	_label("Necesitas", detail, 16, GOLD)
	var miss: Dictionary = cr.missing(cr.inputs_of(selected))
	for id: String in cr.inputs_of(selected):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		detail.add_child(row)
		row.add_child(_icon(id, 32))
		var need: int = int(cr.inputs_of(selected)[id])
		var have: int = cr.count(id)
		var l := _label("%s" % cr.item_name(id), row, 17)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label("%d / %d" % [have, need], row, 17, BAD if miss.has(id) else GOOD)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(sp)
	msg = _label("", detail, 16, MUTED)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var reason: String = cr.why_not(selected)
	var act := Button.new()
	act.text = "%s  [Intro]" % stn["verb"] if reason == "" else reason
	act.disabled = reason != "" or busy
	act.focus_mode = Control.FOCUS_NONE
	act.custom_minimum_size = Vector2(0, 46)
	act.add_theme_font_size_override("font_size", 19)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := Color(0.35, 0.27, 0.1) if st != "hover" else Color(0.5, 0.38, 0.12)
		if st == "disabled":
			bg = Color(0.12, 0.13, 0.2)
		act.add_theme_stylebox_override(st, _box(bg, GOLD if st != "disabled" else Color(0.25, 0.28, 0.4), 2, 8, 6))
	act.pressed.connect(start_craft)
	detail.add_child(act)

func _mods_lines(mods: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k: String in mods:
		out.append("+%d %s" % [mods[k], main.prog.STAT_NAMES.get(k, "Vida máx.")])
	return out

func start_craft() -> void:
	if busy or selected == "" or main.crafting.why_not(selected) != "":
		return
	busy = true
	anim_recipe = selected
	anim_t = 0.0
	anim_len = float(main.crafting.cfg["stations"][station]["time"])
	if is_instance_valid(fx):
		fx.start(anim_len)
	_build_detail_busy()

func _build_detail_busy() -> void:  # congela el botón mientras dura la animación
	for c in detail.get_children():
		if c is Button:
			c.disabled = true
			c.text = "…"

func _process(delta: float) -> void:
	if not busy:
		return
	anim_t += delta
	if is_instance_valid(fx):
		fx.t = anim_t
	if anim_t >= anim_len:
		busy = false
		var r: Dictionary = main.crafting.craft(anim_recipe)
		if r["ok"]:
			main._apply_stats()
			main.save_game()
			crafted.emit(r)
		refresh()
		if is_instance_valid(fx) and r["ok"]:
			fx.finish(true)
		if is_instance_valid(msg):
			msg.text = ("¡Obtuviste %s!" % r["msg"]) if r["ok"] else r["msg"]
			msg.add_theme_color_override("font_color", GOOD if r["ok"] else BAD)

func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		start_craft()
		get_viewport().set_input_as_handled()
