extends CanvasLayer
# Relaciones con los habitantes (data/npcs.json): amistad en corazones (0-5), conversación diaria, regalos con gustos propios
# y eventos al llegar a 2 y 4 corazones. Los comerciantes dan descuento (Tomás) o pagan mejor (Bram) según el cariño.
# E habla (suma una vez al día); G abre el panel de regalos del vecino más cercano.

const MAX_HEARTS := 5

var main: Node
var cfg: Dictionary = {}
var friend := {}      # id -> puntos de amistad
var talked := {}      # id -> último día en que se habló
var gifted := {}      # id -> último día en que se le regaló algo
var done: Array = []  # eventos ya vistos: "id:corazones"
var panel: PanelContainer
var title: Label
var info: Label
var reply: Label
var grid: GridContainer
var current := ""

func _ready() -> void:
	cfg = main._read_json("res://data/npcs.json")
	layer = 58
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(760, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.12, 0.96)
	style.border_color = Color(0.85, 0.65, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	v.add_child(title)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 17)
	info.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(info)
	reply = Label.new()
	reply.add_theme_font_size_override("font_size", 20)
	reply.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	reply.autowrap_mode = TextServer.AUTOWRAP_WORD
	reply.custom_minimum_size = Vector2(720, 52)
	v.add_child(reply)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(720, 260)
	v.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var close_btn := Button.new()
	close_btn.text = "Cerrar  [Esc]"
	close_btn.pressed.connect(close)
	v.add_child(close_btn)

# --- amistad
func is_friend(id: String) -> bool:
	return cfg["npcs"].has(id)

func name_of(id: String) -> String:
	return str(cfg["npcs"][id]["name"])

func hearts(id: String) -> int:
	return mini(MAX_HEARTS, int(friend.get(id, 0)) / int(cfg["per_heart"]))

func hearts_text(id: String) -> String:
	return "♥".repeat(hearts(id)) + "♡".repeat(MAX_HEARTS - hearts(id))

func add(id: String, n: int) -> void:
	friend[id] = clampi(int(friend.get(id, 0)) + n, 0, MAX_HEARTS * int(cfg["per_heart"]))

func on_talk(id: String) -> bool:  # hablar suma una vez al día; true si sumó
	if int(talked.get(id, 0)) == int(main.clock.day):
		return false
	talked[id] = int(main.clock.day)
	add(id, int(cfg["talk_points"]))
	return true

func liking(id: String, item: String) -> String:  # love, like, dislike o neutral
	var n: Dictionary = cfg["npcs"][id]
	for k: String in ["loves", "likes", "dislikes"]:
		if (n[k] as Array).has(item):
			return {"loves": "love", "likes": "like", "dislikes": "dislike"}[k]
	return "neutral"

func can_gift(id: String) -> String:  # "" = se puede
	if int(gifted.get(id, 0)) == int(main.clock.day):
		return "Ya le has dado algo hoy."
	return ""

func give(id: String, item: String) -> String:  # devuelve lo que responde
	if can_gift(id) != "" or main.crafting.count(item) <= 0:
		return can_gift(id)
	var q: int = main.crafting.take(item, 1, true)
	var kind := liking(id, item)
	var pts := int(cfg["gift_points"][kind])
	if pts > 0 and q > 0:
		pts = roundi(float(pts) * (1.0 + 0.25 * float(q)))  # un regalo de calidad vale más
	var before := hearts(id)
	add(id, pts)
	gifted[id] = int(main.clock.day)
	var lines: Array = cfg["reactions"][kind]
	var msg: String = lines[main.crafting.rng.randi_range(0, lines.size() - 1)]
	if hearts(id) > before:
		msg += "   ♥ ¡Tu amistad con %s sube!" % name_of(id)
	return msg

# --- eventos al llegar a ciertos corazones
func pending_event(id: String) -> Dictionary:
	for e: Dictionary in cfg["npcs"][id]["events"]:
		if hearts(id) >= int(e["hearts"]) and not done.has("%s:%d" % [id, int(e["hearts"])]):
			return e
	return {}

# --- escena de evento: barras de cine, la cámara se acerca, el héroe mira al vecino y salen corazones
var bars: CanvasLayer
var bar_top: ColorRect
var bar_bottom: ColorRect
var zoom_before := Vector2.ONE
var in_scene := false

func npc_pos(id: String) -> Vector2:  # dónde está ese vecino (px de suelo); el héroe si no se encuentra
	if id == "elda" and not main.villagers.is_empty():
		return main.villagers[0].pos
	for m: Node2D in main.merchants:
		if (id == "tomas" and m.role == "merchant") or (id == "bram" and m.role == "smith"):
			return m.pos
	for n: Node2D in main.npcs:
		if n.id == id:
			return n.pos
	return main.pos

func _bars_setup() -> void:
	if bars != null:
		return
	bars = CanvasLayer.new()
	bars.layer = 54
	bars.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(bars)
	for k in 2:
		var r := ColorRect.new()
		r.color = Color.BLACK
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_anchors_preset(Control.PRESET_TOP_WIDE if k == 0 else Control.PRESET_BOTTOM_WIDE)
		r.custom_minimum_size = Vector2(0, 0)
		bars.add_child(r)
		if k == 0:
			bar_top = r
		else:
			bar_bottom = r

func _tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)

func play_scene(id: String, lines: Array) -> void:
	_bars_setup()
	in_scene = true
	var h := 96.0
	bar_top.offset_top = -h
	bar_top.offset_bottom = 0.0
	bar_bottom.offset_top = 0.0
	bar_bottom.offset_bottom = h
	var tw := _tween()
	tw.tween_property(bar_top, "offset_top", 0.0, 0.5)
	tw.tween_property(bar_top, "offset_bottom", h, 0.5)
	tw.tween_property(bar_bottom, "offset_top", -h, 0.5)
	tw.tween_property(bar_bottom, "offset_bottom", 0.0, 0.5)
	zoom_before = main.cam.zoom
	tw.tween_property(main.cam, "zoom", zoom_before * 1.3, 0.6)
	var to: Vector2 = npc_pos(id) - main.pos  # el héroe se vuelve hacia el vecino
	if to.length() > 1.0:
		main.facing = main.DIRS[posmod(roundi(to.angle() / (PI / 4.0)), 8)]
		main.hero.play("idle_" + main.facing)
	main.combat.play_at("chest", main.pos)
	_hearts(npc_pos(id), 8)
	main.dialogue.on_close = _end_scene.bind(id)
	main.dialogue.open(name_of(id), lines)

func _hearts(ground: Vector2, n: int) -> void:  # corazones que suben sobre el vecino
	for k in n:
		var l := Label.new()
		l.text = "♥"
		l.add_theme_font_size_override("font_size", 30)
		l.add_theme_color_override("font_color", Color(1.0, 0.4, 0.55))
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 6)
		l.process_mode = Node.PROCESS_MODE_ALWAYS
		var p: Vector2 = (ground + Vector2(main.rng_hearts.randf_range(-26.0, 26.0), -50.0)) * main.SCALE
		l.position = p
		l.z_index = 4000
		main.add_child(l)
		var tw := _tween()
		tw.tween_property(l, "position:y", p.y - 150.0, 1.6).set_delay(float(k) * 0.12)
		tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.9 + float(k) * 0.12)
		tw.chain().tween_callback(l.queue_free)

func _end_scene(id: String) -> void:
	in_scene = false
	var tw := _tween()
	tw.tween_property(bar_top, "offset_top", -96.0, 0.4)
	tw.tween_property(bar_top, "offset_bottom", 0.0, 0.4)
	tw.tween_property(bar_bottom, "offset_top", 0.0, 0.4)
	tw.tween_property(bar_bottom, "offset_bottom", 96.0, 0.4)
	tw.tween_property(main.cam, "zoom", zoom_before, 0.5)
	main.combat.play_at("catch", main.pos)
	_hearts(npc_pos(id), 5)

func take_event(id: String) -> Array:  # lo que dice el evento y entrega su recompensa; [] si no hay
	var e := pending_event(id)
	if e.is_empty():
		return []
	done.append("%s:%d" % [id, int(e["hearts"])])
	var r: Dictionary = e["reward"]
	var parts: Array[String] = []
	if r.has("coins"):
		main.prog.coins += int(r["coins"])
		parts.append("%d monedas" % int(r["coins"]))
	for item: String in r.get("items", {}):
		main.crafting.add(item, int(r["items"][item]))
		parts.append("%s ×%d" % [main.crafting.item_name(item), int(r["items"][item])])
	if r.has("blueprint"):
		if main.crafting.learn(str(r["blueprint"])):
			parts.append("plano: %s" % main.crafting.item_name(str(r["blueprint"])))
		else:
			main.prog.coins += 80
			parts.append("80 monedas")
	if r.has("skill_points"):
		main.prog.skill_points += int(r["skill_points"])
		parts.append("%d punto de habilidad" % int(r["skill_points"]))
	var lines: Array = (e["lines"] as Array).duplicate()
	lines.append("(%s te da: %s)" % [name_of(id), ", ".join(parts)])
	if r.has("xp"):
		main.gain_xp(int(r["xp"]))
	main.save_game()
	return lines

# --- ventajas
func discount(id: String) -> float:  # Tomás: 4 % menos por corazón
	return 0.04 * float(hearts(id)) if cfg["npcs"][id].get("perk", "") == "discount" else 0.0

func sell_bonus(id: String) -> float:  # Bram: 4 % más por corazón al venderle
	return 0.04 * float(hearts(id)) if cfg["npcs"][id].get("perk", "") == "sell_bonus" else 0.0

# --- panel de regalos
func open_near() -> void:
	var id: String = main.social_target()
	if id == "":
		main.say("No hay nadie cerca a quien regalar.", 1.5)
		return
	open_for(id)

func open_for(id: String) -> void:
	current = id
	title.text = "%s   %s" % [name_of(id), hearts_text(id)]
	var perk := ""
	if cfg["npcs"][id].get("perk", "") == "discount":
		perk = "  Descuento en su puesto: %d %%." % roundi(discount(id) * 100.0)
	elif cfg["npcs"][id].get("perk", "") == "sell_bonus":
		perk = "  Te paga un %d %% más por los materiales." % roundi(sell_bonus(id) * 100.0)
	var ev := pending_event(id)
	info.text = ("Algo quiere contarte: habla con %s [E]." % name_of(id) if not ev.is_empty() else "Habla con cada uno una vez al día y hazles regalos (uno al día) para ganar su amistad.") + perk
	reply.text = can_gift(id)
	_fill_items()
	visible = true
	main.get_tree().paused = true

func _fill_items() -> void:
	for c in grid.get_children():
		c.queue_free()
	var ids: Array = []
	if main.prog.potions > 0:
		ids.append("pocion_vida")
	for k: String in main.prog.materials:
		if int(main.prog.materials[k]) > 0 and not main.crafting.is_blueprint(k):
			ids.append(k)
	var blocked: bool = can_gift(current) != ""
	for k: String in ids:
		var b := Button.new()
		b.text = "%s ×%d" % [main.crafting.item_name(k), main.crafting.count(k)]
		b.icon = load(main.crafting.icon(k))
		b.expand_icon = true
		b.custom_minimum_size = Vector2(228, 52)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = blocked
		var item := k
		b.pressed.connect(func() -> void:
			reply.text = give(current, item)
			title.text = "%s   %s" % [name_of(current), hearts_text(current)]
			_fill_items())
		grid.add_child(b)
	if ids.is_empty():
		var l := Label.new()
		l.text = "No llevas nada que regalar."
		grid.add_child(l)

func close() -> void:
	visible = false
	main.get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode in [KEY_ESCAPE, KEY_G]:
		close()
		get_viewport().set_input_as_handled()

# --- guardado
func to_dict() -> Dictionary:
	return {"friend": friend, "talked": talked, "gifted": gifted, "done": done}

func from_dict(d: Dictionary) -> void:  # validado: datos de disco
	friend.clear()
	talked.clear()
	gifted.clear()
	done.clear()
	for src: String in ["friend", "talked", "gifted"]:
		if d.get(src) is Dictionary:
			for id: String in d[src]:
				if cfg["npcs"].has(id):
					var dst: Dictionary = {"friend": friend, "talked": talked, "gifted": gifted}[src]
					dst[id] = maxi(0, int(d[src][id]))
	if d.get("done") is Array:
		for e: Variant in d["done"]:
			if str(e).split(":").size() == 2 and cfg["npcs"].has(str(e).split(":")[0]):
				done.append(str(e))
