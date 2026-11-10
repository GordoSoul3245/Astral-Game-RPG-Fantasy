extends Node2D
# Suelo (Blender, misma cámara/paleta cel que el hechicero) + hechicero con Walk / Sprint.
# Controles: WASD/flechas = caminar, Shift = sprint, clic izq = ataque ligero, clic der = ataque pesado
# del objeto equipado, 1/2 o Q = cambiar objeto de la barra, Espacio = dash, R = ultimate, rueda = zoom.

const SCALE := 3.0
const FEET := Vector2(68, 113.7)            # píxel de los pies dentro del sprite de 128x128
const WALK_SPEED := 90.0
const SPRINT_SPEED := 190.0
# Proyección del mapa (se carga de data/map.json): casilla (i,j) -> suelo = C1 + (i/TILES)*E1 + (j/TILES)*E2
var map_origin := Vector2.ZERO   # píxel de la imagen del suelo que es el (0,0) del suelo (centro del mapa)
var C1 := Vector2.ZERO
var E1 := Vector2.ZERO
var E2 := Vector2.ZERO
var TILES := 20.0
var world: Node2D                # world_map.gd: suelo, objetos y colisiones
var start_pos := Vector2.ZERO
var dragon_start := Vector2.ZERO

# orden por ángulo de pantalla (y hacia abajo), en pasos de 45° desde el este
const DIRS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
# animaciones del héroe sin bucle y su número de fotogramas
const ANIMS := {"slash_light": 6, "slash_heavy": 8, "cast": 8, "dash": 6, "fslash_light": 6, "fslash_heavy": 8, "megadash": 6}

# rueda del ratón: acercar / alejar la cámara
const ZOOM_DEFAULT := 0.7
const ZOOM_MIN := 0.3
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1

const HERO_RADIUS := 8.0      # contra entidades (px de suelo)
const DRAGON_RADIUS := 14.0
const HERO_R_T := 0.28        # contra el mapa (casillas = metros)
const DRAGON_R_T := 0.45

var dragon: AnimatedSprite2D
var creatures := {}
var hero_data := {}                 # entrada "hero" de data/creatures.json
var hero_hp := 100
var hero_max_hp := 100
var mana := 100.0
var stamina := 100.0
var stamina_idle := 0.0             # segundos desde el último gasto: la estamina/maná se regeneran tras una pausa
var mana_idle := 0.0
var exhausted := false              # sin estamina: no puede correr hasta recuperar un poco
var ult := 0.0                      # carga de la ultimate: se gana golpeando entidades
var burn_t := 0.0                   # segundos restantes de katana en llamas
var burn_mult := 1.0
var bars := {}                      # nombre -> ProgressBar
var burn_label: Label
var cam: Camera2D
var shake_amp := 0.0
var facing := "S"
var gait_phase := 0.0
var reaction_time := 0.0
var dying := false
var contact_shadow: Node2D
var spell_light: PointLight2D
var hero: AnimatedSprite2D
var pos := Vector2.ZERO  # pies del personaje, en píxeles del suelo original
var items := {}
var hotbar: Array = []           # ids de objeto en la barra; el seleccionado es el equipado
var selected := 0
var slots: Array[Panel] = []
var hint_label: Label
var cooldown := 0.0
var attacking := false           # animación de ataque en curso: el héroe no se mueve
var current := {}                # ataque en curso
var current_mode := "light"
var aim_dir := Vector2.DOWN      # dirección de apuntado del ataque, en px de suelo
var struck := false
var trailed := false
var trail_flip := 1.0
var dashing := false             # durante el dash: invulnerable y atraviesa entidades (no estructuras)
var dash_t := 0.0
const BUFFER_MS := 100          # punto de partida del estudio (probar 70/130)
var buf := ""                   # una sola acción anticipada: "light", "heavy" o "dash"
var buf_until := 0
var dash_dir := Vector2.ZERO
var dash_cd := 0.0
var dash_time_cur := 0.55
var dash_speed_cur := 220.0
var mega_active := false         # el dash en curso es la ultimate de la katana
var mega_spec := {}
var mega_hits: Array = []        # enemigos ya golpeados por el mega dash en curso
var ghost_t := 0.0
var aiming := false              # apuntando el meteoro: el clic confirma, clic derecho / Esc cancela
var aim_marker: Node2D
var aim_cell := Vector2.ZERO
var aim_valid := false
var burn_fx: CPUParticles2D
var fx_frames: SpriteFrames      # bola de fuego: "fly" e "impact"
var combat: Node2D               # combat.gd: feedback de golpes, marca de Ignis y luces

var touch_mode := false          # Android/iOS: controles táctiles en pantalla (scripts/touch_controls.gd)
var touch: Node = null

func _ready() -> void:
	touch_mode = OS.has_feature("android") or OS.has_feature("ios")
	if touch_mode:
		touch = load("res://scripts/touch_controls.gd").new()
		touch.main = self
		add_child(touch)
	RenderingServer.set_default_clear_color(Color("#0f1a2a"))  # mar alrededor de la isla
	creatures = _read_json("res://data/creatures.json")
	hero_data = creatures["hero"]
	prog = load("res://scripts/progress.gd").new(_read_json("res://data/equipment.json"))
	hero_base = {"hp": hero_data["hp"], "mana": hero_data["mana"], "stamina": hero_data["stamina"]}
	hero_max_hp = hero_data["hp"]
	hero_hp = hero_max_hp
	mana = hero_data["mana"]
	stamina = hero_data["stamina"]
	var mp := _read_json("res://data/map.json")
	TILES = float(mp["tiles"])
	var c1 := Vector2(mp["c1"][0], mp["c1"][1])
	E1 = Vector2(mp["e1"][0], mp["e1"][1])
	E2 = Vector2(mp["e2"][0], mp["e2"][1])
	map_origin = c1 + (E1 + E2) / 2.0   # el (0,0) del suelo es el centro del mapa
	C1 = c1 - map_origin
	start_pos = tile_to_ground(Vector2(mp["start"][0], mp["start"][1]))
	dragon_start = tile_to_ground(Vector2(mp["dragon"][0], mp["dragon"][1]))
	pos = start_pos
	world = Node2D.new()
	world.set_script(load("res://scripts/world_map.gd"))
	world.main = self
	add_child(world)
	world.setup(mp)

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for d in DIRS:
		for anim in ["idle", "walk", "run", "hurt", "death"]:
			var key := "%s_%s" % [anim, d]
			frames.add_animation(key)
			frames.set_animation_speed(key, 6.0 if anim == "idle" else (30.0 if anim == "hurt" else 12.0))
			frames.set_animation_loop(key, anim not in ["hurt", "death"])
			for i in (6 if anim == "hurt" else (12 if anim == "death" else 16)):
				frames.add_frame(key, load("res://art/hechicero/polished/%s_%s_%02d.png" % [anim, d, i]))
		for anim: String in ANIMS:
			var key := "%s_%s" % [anim, d]
			frames.add_animation(key)
			frames.set_animation_loop(key, false)
			for i in ANIMS[anim]:
				var folder := "polished/" if "slash" in anim else ""
				var timing: Array = [1.2, 1.35, 0.45, 0.55, 1.05, 1.4] if anim.ends_with("light") else ([1.0, 1.2, 1.25, 1.2, 0.35, 0.55, 1.0, 1.45] if anim.ends_with("heavy") else ([1.1, 1.2, 0.7, 1.0, 0.6, 0.9, 1.1, 1.4] if anim == "cast" else []))
				frames.add_frame(key, load("res://art/hechicero/%s%s_%s_%02d.png" % [folder, anim, d, i]), timing[i] if not timing.is_empty() else 1.0)
	hero = AnimatedSprite2D.new()
	hero.sprite_frames = frames
	hero.centered = false
	hero.scale = Vector2.ONE * SCALE
	hero.play("idle_S")
	hero.frame_changed.connect(_on_hero_frame)
	hero.animation_finished.connect(func() -> void: attacking = false)
	add_child(hero)
	contact_shadow = Node2D.new()
	for layer in 3:
		var shadow := Polygon2D.new()
		var outline := PackedVector2Array()
		for i in 32:
			var angle := TAU * i / 32.0
			outline.append(Vector2(cos(angle) * (12 - layer * 2), sin(angle) * (4.5 - layer * 0.7)) * SCALE)
		shadow.polygon = outline
		shadow.color = Color(0.04, 0.03, 0.08, 0.10)
		contact_shadow.add_child(shadow)
	add_child(contact_shadow)
	var glow_gradient := Gradient.new()
	glow_gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var glow_texture := GradientTexture2D.new()
	glow_texture.gradient = glow_gradient
	glow_texture.width = 128
	glow_texture.height = 128
	glow_texture.fill = GradientTexture2D.FILL_RADIAL
	glow_texture.fill_from = Vector2(0.5, 0.5)
	glow_texture.fill_to = Vector2(0.5, 1.0)
	spell_light = PointLight2D.new()
	spell_light.texture = glow_texture
	spell_light.texture_scale = 2.5
	spell_light.color = Color(1.0, 0.56, 0.23)
	spell_light.energy = 0.0
	add_child(spell_light)
	cam = Camera2D.new()
	cam.zoom = Vector2.ONE * ZOOM_DEFAULT
	cam.position = (pos - Vector2(0, 40)) * SCALE
	add_child(cam)
	_build_fx()
	_build_burn_fx()
	combat = Node2D.new()
	combat.set_script(load("res://scripts/combat.gd"))
	combat.main = self
	add_child(combat)
	_spawn_dragon()
	_spawn_fauna()
	_load_inventory()
	combat.mark_spec = items["grimorio_ignis"].get("mark", combat.mark_spec)
	_build_prompt()
	_build_menu()
	_apply_stats()
	for o: Dictionary in mp["objects"]:
		if o["sprite"] == "castle":  # la puerta de madera está en la cara frontal derecha del sprite del castillo
			var door_g := tile_to_ground(Vector2(o["tile"][0], o["tile"][1])) + Vector2(65, -8)
			_add_door(ground_to_tile(door_g), "Entrar a la dungeon", enter_dungeon, false)
	_place()

# --- puertas, avisos y dungeon
const DUNGEON_TILES := 25
var in_dungeon := false
var overworld := {}              # estado del mapa exterior mientras estás en la dungeon
var doors: Array = []            # puertas del mapa actual
var dungeon_node: Node2D
var prompt: Label
var fade: ColorRect
var transitioning := false
var say_t := 0.0
var say_text := ""

func _build_prompt() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	prompt = Label.new()
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.grow_vertical = Control.GROW_DIRECTION_BEGIN  # los avisos de varias líneas crecen hacia arriba
	loot_box = HBoxContainer.new()   # iconos de los objetos recién obtenidos
	loot_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	loot_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	loot_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	loot_box.offset_top = -340.0
	loot_box.add_theme_constant_override("separation", 14)
	layer.add_child(loot_box)
	prompt.offset_top = -190.0
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 26)
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 8)
	layer.add_child(prompt)
	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)

var loot_box: HBoxContainer
var loot_t := 0.0

func item_icon(id: String) -> String:
	return "res://art/items/%s.png" % id

func show_loot(ids: Array) -> void:  # muestra los iconos de los objetos obtenidos unos segundos
	for c in loot_box.get_children():
		c.queue_free()
	for id: String in ids:
		var t := TextureRect.new()
		t.texture = load(item_icon(id))
		t.custom_minimum_size = Vector2(110, 110)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		loot_box.add_child(t)
	loot_t = 6.0

func say(text: String, secs := 1.5) -> void:  # aviso temporal sobre la barra de objetos
	say_text = text
	say_t = secs

func _add_door(tile: Vector2, label: String, on_open: Callable, visible_door := true) -> Node2D:
	var d := Node2D.new()
	d.set_script(load("res://scripts/door.gd"))
	d.main = self
	d.tile = tile
	d.label = label
	d.on_open = on_open
	d.draw_door = visible_door
	add_child(d)
	doors.append(d)
	return d

func _near_door() -> Node2D:
	var t := ground_to_tile(pos)
	for d: Node2D in doors:
		if t.distance_to(d.tile) <= d.reach:
			return d
	return null

func _interact() -> void:
	var d := _near_door()
	if d != null and not transitioning:
		d.use()

func _update_prompt(delta: float) -> void:
	say_t = maxf(0.0, say_t - delta)
	if loot_t > 0.0:
		loot_t -= delta
		if loot_t <= 0.0:
			for c in loot_box.get_children():
				c.queue_free()
	var d := _near_door()
	if say_t > 0.0:
		prompt.text = say_text
	elif d != null and not transitioning:
		prompt.text = ("[E] " + d.label) if not d.locked else d.lock_text
	else:
		prompt.text = ""

func _transition(change: Callable) -> void:  # fundido a negro, cambio de mapa y fundido de vuelta
	transitioning = true
	var t := create_tween()
	t.tween_property(fade, "color:a", 1.0, 0.25)
	t.tween_callback(change)
	t.tween_property(fade, "color:a", 0.0, 0.25)
	t.tween_callback(func() -> void: transitioning = false)

func _dungeon_spawn() -> Vector2:
	return tile_to_ground(Vector2(DUNGEON_TILES / 2.0, 2.4))

func enter_dungeon() -> void:
	_transition(_enter_dungeon)

func _enter_dungeon() -> void:
	in_dungeon = true
	overworld = {"pos": pos, "C1": C1, "E1": E1, "E2": E2, "tiles": TILES, "world": world, "doors": doors, "dragon_alive": dragon.alive}
	world.visible = false
	for d: Node2D in doors:
		d.visible = false
	doors = []
	dragon.visible = false
	dragon.alive = false  # fuera de juego mientras estás en la dungeon
	var s := DUNGEON_TILES / TILES  # misma casilla (1 m) que el exterior
	E1 *= s
	E2 *= s
	TILES = DUNGEON_TILES
	C1 = -(E1 + E2) / 2.0           # el piso queda centrado en el origen
	RenderingServer.set_default_clear_color(Color("#05060d"))
	combat.set_zone(true)
	dungeon_node = Node2D.new()
	dungeon_node.set_script(load("res://scripts/dungeon.gd"))
	dungeon_node.main = self
	add_child(dungeon_node)
	dungeon_node.setup({"tiles": DUNGEON_TILES})
	world = dungeon_node
	_add_door(Vector2(DUNGEON_TILES / 2.0, 0.25), "Salir de la dungeon", exit_dungeon)  # su cara trasera (0.25 m de fondo) toca el borde del suelo
	pos = _dungeon_spawn()
	cam.position = (pos - Vector2(0, 40)) * SCALE
	floors = Node.new()
	floors.set_script(load("res://scripts/floors.gd"))
	floors.main = self
	add_child(floors)
	floors.start(dungeon_floor)

func exit_dungeon() -> void:
	_transition(_exit_dungeon)

func _exit_dungeon() -> void:
	in_dungeon = false
	if is_instance_valid(floors.chest):
		floors.chest.queue_free()
	floors.queue_free()
	for e in enemies.duplicate():  # los monstruos de la dungeon se van; el dragón vuelve
		if e != dragon:
			enemies.erase(e)
			e.queue_free()
	for d: Node2D in doors:
		d.queue_free()
	dungeon_node.queue_free()
	world = overworld["world"]
	world.visible = true
	doors = overworld["doors"]
	for d: Node2D in doors:
		d.visible = true
	C1 = overworld["C1"]
	E1 = overworld["E1"]
	E2 = overworld["E2"]
	TILES = overworld["tiles"]
	pos = overworld["pos"]
	dragon.visible = true
	dragon.alive = overworld["dragon_alive"]
	RenderingServer.set_default_clear_color(Color("#0f1a2a"))
	combat.set_zone(false)
	cam.position = (pos - Vector2(0, 40)) * SCALE

# --- enemigos, botín y progresión (progress.gd)
var enemies: Array = []          # dragón y monstruos de la dungeon: alive, pos, radius, take_damage()
var prog: RefCounted
var hero_base := {}              # vida, maná y estamina base (sin nivel, puntos ni equipo)
var floors: Node
var dungeon_floor := 1
var info_label: Label

func _build_menu() -> void:
	var m := CanvasLayer.new()
	m.set_script(load("res://scripts/menu.gd"))
	m.main = self
	add_child(m)

func _apply_stats() -> void:  # recalcula máximos con nivel, puntos y equipo; si el máximo sube, sube también lo actual
	var old := hero_max_hp
	hero_max_hp = prog.max_hp(hero_base["hp"])
	hero_hp = clampi(hero_hp + hero_max_hp - old, 1, hero_max_hp)
	hero_data["mana"] = prog.max_mana(hero_base["mana"])
	hero_data["stamina"] = prog.max_stamina(hero_base["stamina"])
	mana = minf(mana, hero_data["mana"])
	stamina = minf(stamina, hero_data["stamina"])

func spawn_enemy(id: String, ground: Vector2) -> Node2D:
	var e := Node2D.new()
	e.set_script(load("res://scripts/enemy.gd"))
	e.main = self
	e.data = creatures[id]
	e.pos = ground
	add_child(e)
	enemies.append(e)
	return e

func popup(ground: Vector2, text: String, color := Color(1.0, 0.9, 0.5)) -> void:  # texto flotante sobre un punto del suelo
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.position = ground * SCALE + Vector2(-80, -170)
	l.z_index = 4000
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 60.0, 1.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.8)
	tw.tween_callback(l.queue_free)

func gain_xp(n: int) -> void:
	if prog.add_xp(n) > 0:
		_apply_stats()
		hero_hp = hero_max_hp
		say("¡Nivel %d!  +%d puntos de mejora: abre el menú [I]" % [prog.level, prog.POINTS_PER_LEVEL], 3.5)

func on_kill(e: Node) -> void:  # botín de un enemigo: XP, monedas y objetos (data/creatures.json)
	var d: Dictionary = e.data
	var xp := int(d.get("xp", 0))
	var lines: Array[String] = ["+%d XP" % xp]
	if d.has("coins"):
		var c := randi_range(int(d["coins"][0]), int(d["coins"][1]))
		prog.coins += c
		lines.append("+%d monedas" % c)
	for drop: Dictionary in d.get("drops", []):
		if randf() >= drop["chance"]:
			continue
		if drop["item"] == "pocion_vida":
			prog.potions += 1
			lines.append("Poción de vida")
		else:
			prog.materials[drop["item"]] = prog.materials.get(drop["item"], 0) + 1
			lines.append(prog.material_names[drop["item"]])
	popup(e.pos, "\n".join(lines))
	gain_xp(xp)

func give_item(id: String) -> String:  # entrega un objeto de equipo (se equipa solo si es mejor que lo actual)
	var equipped: bool = prog.add_item(id)
	_apply_stats()
	return "%s%s" % [prog.equipment[id]["name"], "  (equipado)" if equipped else "  (al inventario)"]

func _use_potion() -> void:
	if prog.potions <= 0 or hero_hp >= hero_max_hp:
		return
	prog.potions -= 1
	hero_hp = mini(hero_max_hp, hero_hp + 40)
	popup(pos, "+40 vida", Color(0.5, 1.0, 0.5))

func _read_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _make_bar(parent: Node, y: float, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = Vector2(16, y)
	b.custom_minimum_size = Vector2(260, 20)
	b.size = Vector2(260, 20)
	b.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.14, 0.8)
	bg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", bg)
	var l := Label.new()
	l.name = "Label"
	l.position = Vector2(8, -2)
	l.add_theme_font_size_override("font_size", 19)
	b.add_child(l)
	parent.add_child(b)
	return b

func _set_bar(key: String, value: float, max_value: float, text: String) -> void:
	var b: ProgressBar = bars[key]
	b.max_value = max_value
	b.value = value
	b.get_node("Label").text = text

func _update_bars() -> void:
	_set_bar("hp", hero_hp, hero_max_hp, "Vida %d / %d" % [hero_hp, hero_max_hp])
	_set_bar("mana", mana, hero_data["mana"], "Maná %d" % roundi(mana))
	_set_bar("stamina", stamina, hero_data["stamina"], "Estamina %d" % roundi(stamina) + ("  (agotada)" if exhausted else ""))
	var full: bool = ult >= hero_data["ult_max"]
	_set_bar("ult", ult, hero_data["ult_max"], "ULTIMATE LISTA  [R]" if full else "Ultimate %d%%" % roundi(ult))
	_set_bar("xp", prog.xp, prog.xp_needed(), "Nivel %d  ·  XP %d / %d" % [prog.level, prog.xp, prog.xp_needed()])
	info_label.text = "Monedas %d  ·  Pociones %d [H]  ·  Menú [I]%s" % [prog.coins, prog.potions, ("  ·  ¡%d puntos!" % prog.points) if prog.points > 0 else ""]
	burn_label.text = "Espada en llamas  %.1f s" % burn_t if burn_t > 0.0 else ""

func _load_inventory() -> void:
	items = _read_json("res://data/items.json")
	var inv := _read_json("res://data/inventory_test.json")
	hotbar = inv["hotbar"]
	selected = int(inv["selected"])
	var ui := CanvasLayer.new()
	add_child(ui)
	bars["hp"] = _make_bar(ui, 16, Color(0.8, 0.2, 0.2))
	bars["mana"] = _make_bar(ui, 40, Color(0.25, 0.5, 0.95))
	bars["stamina"] = _make_bar(ui, 64, Color(0.35, 0.8, 0.35))
	bars["ult"] = _make_bar(ui, 88, Color(1.0, 0.6, 0.15))
	bars["xp"] = _make_bar(ui, 112, Color(0.6, 0.4, 0.9))
	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 20)
	info_label.position = Vector2(16, 136)
	ui.add_child(info_label)
	burn_label = Label.new()
	burn_label.position = Vector2(16, 162)
	burn_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	ui.add_child(burn_label)
	_update_bars()
	# barra de objetos, abajo al centro: 1..n o Q para cambiar de objeto equipado
	# contenedores anclados al borde inferior: quedan abajo al centro con cualquier resolución o ventana
	var size := 72.0
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_END
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)
	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 20)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	for i in hotbar.size():
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(size, size)
		panel.clip_contents = true
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # que los clics sigan llegando al juego
		row.add_child(panel)
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # antes del tamaño: si no, el icono de 128 px desborda el cuadro
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(items[hotbar[i]]["icon"])
		icon.position = Vector2(4, 4)
		icon.size = Vector2(size - 8, size - 8)
		panel.add_child(icon)
		var num := Label.new()
		num.text = str(i + 1)
		num.position = Vector2(6, 2)
		panel.add_child(num)
		slots.append(panel)
	_select(selected)

func _select(i: int) -> void:
	_cancel_aim()
	selected = i
	for n in slots.size():
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.1, 0.16, 0.85)
		sb.set_border_width_all(3 if n == i else 1)
		sb.border_color = Color(0.95, 0.75, 0.3) if n == i else Color(0.4, 0.45, 0.55)
		sb.set_corner_radius_all(6)
		slots[n].add_theme_stylebox_override("panel", sb)
	var it: Dictionary = items[hotbar[i]]
	hint_label.text = "%s  ·  clic izq: %s  ·  clic der: %s  ·  R: %s" % [it["name"], it["light"]["name"], it["heavy"]["name"], it["ultimate"]["name"]]

func _build_fx() -> void:
	fx_frames = SpriteFrames.new()
	fx_frames.remove_animation("default")
	fx_frames.add_animation("fly")
	fx_frames.set_animation_speed("fly", 16.0)
	for i in 8:
		fx_frames.add_frame("fly", load("res://art/grimorio/fireball_%02d.png" % i))
	fx_frames.add_animation("impact")
	fx_frames.set_animation_speed("impact", 18.0)
	fx_frames.set_animation_loop("impact", false)
	for i in 6:
		fx_frames.add_frame("impact", load("res://art/grimorio/impact_%02d.png" % i))

# chispas y llamas alrededor del héroe mientras la katana arde o hace el mega dash
func _build_burn_fx() -> void:
	burn_fx = CPUParticles2D.new()
	burn_fx.emitting = false
	burn_fx.amount = 40
	burn_fx.lifetime = 0.5
	burn_fx.local_coords = false
	burn_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	burn_fx.emission_sphere_radius = 16.0
	burn_fx.direction = Vector2(0, -1)
	burn_fx.spread = 35.0
	burn_fx.gravity = Vector2(0, -60)
	burn_fx.initial_velocity_min = 25.0
	burn_fx.initial_velocity_max = 70.0
	burn_fx.scale_amount_min = 3.0
	burn_fx.scale_amount_max = 8.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.9, 0.4, 1), Color(1, 0.4, 0.05, 0.8), Color(0.6, 0.1, 0.0, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	burn_fx.color_ramp = g
	burn_fx.material = CanvasItemMaterial.new()
	burn_fx.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	burn_fx.z_index = 2000
	add_child(burn_fx)

func _spawn_dragon() -> void:
	dragon = AnimatedSprite2D.new()
	dragon.set_script(load("res://scripts/dragon.gd"))
	dragon.main = self
	dragon.data = creatures["dragon"]
	dragon.pos = dragon_start
	add_child(dragon)
	enemies.append(dragon)

var fauna: Array = []  # presas del exterior (critter.gd): no combaten ni bloquean

func _spawn_fauna() -> void:  # 3 conejos con madriguera en casillas libres a 4–9 m del inicio
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # mismas madrigueras en cada partida
	var tries := 0
	while fauna.size() < 3 and tries < 200:
		tries += 1
		var home: Vector2 = start_pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.0, 9.0) / _tiles_per_px(Vector2.RIGHT)
		if world.blocked(ground_to_tile(home), 0.6):
			continue
		var c := Node2D.new()
		c.set_script(load("res://scripts/critter.gd"))
		c.main = self
		c.world = world
		c.home = home
		add_child(c)
		fauna.append(c)

const MAX_WINDUPS := 2  # preparaciones peligrosas simultáneas (punto de partida del estudio, no una cifra aprobada)

func can_prepare(e: Node) -> bool:  # un enemigo solo empieza su aviso si hay hueco; los demás siguen posicionándose
	var n := 0
	for o in enemies:
		if o != e and o.alive and o.get("state") == "windup":
			n += 1
	return n < MAX_WINDUPS

func blockers() -> Array:  # enemigos vivos: bloquean al héroe; las estructuras las maneja world
	return enemies.filter(func(e: Node) -> bool: return e.alive)

func damage_hero(n: int) -> void:
	if dashing or dying or reaction_time > 0.0:
		return
	n = maxi(1, roundi(n * prog.defense_mult()))
	hero_hp = maxi(0, hero_hp - n)
	hero.modulate = Color(1.0, 0.4, 0.4)
	create_tween().tween_property(hero, "modulate", Color.WHITE, 0.25)
	if hero_hp == 0:
		_cancel_aim()
		dying = true
		attacking = false
		reaction_time = 1.0
		hero.offset = Vector2(-32, -32)
		hero.play("death_" + facing)
	elif not attacking:
		reaction_time = 0.2
		hero.play("hurt_" + facing)

func _respawn() -> void:
	dying = false
	hero.offset = Vector2.ZERO
	reaction_time = 0.0
	hero_hp = hero_max_hp
	mana = hero_data["mana"]
	stamina = hero_data["stamina"]
	burn_t = 0.0
	if in_dungeon:  # el pueblo aún no existe: reaparece en la entrada del piso
		pos = _dungeon_spawn()
	else:
		pos = start_pos
		dragon.reset(dragon_start)
	hero.play("idle_" + facing)

func gain_ultimate(damage: float) -> void:  # la ultimate se carga golpeando entidades
	ult = minf(hero_data["ult_max"], ult + damage * hero_data["ult_per_damage"])

func shake(amount: float) -> void:
	shake_amp = maxf(shake_amp, amount)

var kick_v := Vector2.ZERO  # empujón direccional de cámara (px de pantalla), vuelve solo al centro

func kick(v: Vector2) -> void:
	if v.length() > kick_v.length():
		kick_v = v

# --- casillas: el mapa es una cuadrícula de TILES x TILES (1 casilla = 1 m); coordenadas de casilla (0..TILES)
func ground_to_tile(p: Vector2) -> Vector2:
	var d := p - C1
	var det := E1.x * E2.y - E1.y * E2.x
	return TILES * Vector2((d.x * E2.y - d.y * E2.x) / det, (E1.x * d.y - E1.y * d.x) / det)

func tile_to_ground(t: Vector2) -> Vector2:
	return C1 + (t.x / TILES) * E1 + (t.y / TILES) * E2

func _tiles_per_px(dir: Vector2) -> float:  # casillas que se recorren por px de suelo en esa dirección
	var det := E1.x * E2.y - E1.y * E2.x
	return TILES * Vector2((dir.x * E2.y - dir.y * E2.x) / det, (E1.x * dir.y - E1.y * dir.x) / det).length()

func floor_contains(p: Vector2) -> bool:
	var t := ground_to_tile(p)
	return t.x >= 0.0 and t.x <= TILES and t.y >= 0.0 and t.y <= TILES

func hits_obstacle(p: Vector2) -> bool:  # estructuras del mapa (árboles, rocas, casa, castillo)
	return world.hits_obstacle(p)

func spawn_projectile(source: String, ground: Vector2, dir: Vector2, spec: Dictionary, tint := Color.WHITE) -> void:
	var p := Node2D.new()
	p.set_script(load("res://scripts/projectile.gd"))
	p.main = self
	p.source = source
	p.dir = dir
	p.speed = spec["speed"]
	p.radius = spec["radius"]
	p.damage = roundi(spec["damage"] * (prog.magic_mult() if source == "hero" else 1.0))
	p.height = spec["muzzle_height"]
	p.scale_mult = spec.get("scale", 1.0)
	p.aoe = spec.get("aoe", 0.0)
	p.ground = ground
	p.tint = Color.html(spec["tint"]) if spec.has("tint") else tint
	add_child(p)

func _input_dir() -> Vector2:
	if touch_mode:
		return Vector2.ZERO if aiming else touch.stick
	return Vector2(
		float(_held([KEY_D, KEY_RIGHT])) - float(_held([KEY_A, KEY_LEFT])),
		float(_held([KEY_S, KEY_DOWN])) - float(_held([KEY_W, KEY_UP])))

func touch_default_aim() -> Vector2:  # táctil: apunta al enemigo más cercano; si no hay, hacia donde mira el héroe
	var chest := pos - Vector2(0, 40)
	var best: Node = null
	var best_d := 220.0
	for e in enemies:
		if e.alive and e.pos.distance_to(pos) < best_d:
			best = e
			best_d = e.pos.distance_to(pos)
	if best != null:
		return best.pos - chest
	return Vector2.from_angle(DIRS.find(facing) * PI / 4.0) * 60.0

func _mouse() -> Vector2:
	if touch_mode:
		var aim: Vector2 = touch.aim_point if aiming else touch_default_aim()
		return (pos - Vector2(0, 40) + aim) * SCALE
	return get_global_mouse_position()

func _mb(button: int) -> bool:  # clic mantenido (en táctil lo simulan los botones en pantalla)
	if touch_mode:
		return touch.held[button]
	return Input.is_mouse_button_pressed(button)

func _chest_aim() -> Vector2:  # dirección del pecho del héroe al cursor, en px de suelo
	var aim := _mouse() / SCALE - (pos - Vector2(0, 40))
	return aim.normalized() if aim.length() >= 1.0 else Vector2.from_angle(DIRS.find(facing) * PI / 4.0)

# Espacio: dash hacia donde se mueve (o hacia donde mira si está quieto); cancela un ataque en curso
func _dash() -> bool:  # true si el dash empezó
	if dashing or dash_cd > 0.0 or aiming or stamina < hero_data["dash_stamina"]:
		return false
	if attacking and (not struck or current_mode == "heavy"):  # cancelar: el ligero solo en su recuperación; el pesado, nunca (compromiso)
		return false
	stamina -= hero_data["dash_stamina"]
	stamina_idle = 0.0
	var d := _input_dir()
	dash_dir = d.normalized() if d != Vector2.ZERO else Vector2.from_angle(DIRS.find(facing) * PI / 4.0)
	facing = DIRS[posmod(roundi(dash_dir.angle() / (PI / 4.0)), 8)]
	dashing = true
	mega_active = false
	attacking = false
	dash_t = 0.0
	dash_time_cur = hero_data["dash_time"]
	dash_speed_cur = hero_data["dash_speed"]
	dash_cd = hero_data["dash_cooldown"]
	var key := "dash_" + facing
	hero.sprite_frames.set_animation_speed(key, 6.0 / dash_time_cur)
	hero.play(key)
	return true

func _push_out(list: Array) -> void:  # saca al héroe de los enemigos
	for e in list:
		var off: Vector2 = pos - e.pos
		if off.length() < e.radius + HERO_RADIUS:
			pos = e.pos + off.normalized() * (e.radius + HERO_RADIUS)

# ¿alcanza el recurso para este ataque? (maná para magia, estamina para espada)
func _afford(spec: Dictionary) -> bool:
	return mana >= spec.get("mana", 0.0) and stamina >= spec.get("stamina", 0.0)

func _pay(spec: Dictionary) -> void:
	if spec.has("mana"):
		mana -= spec["mana"]
		mana_idle = 0.0
	if spec.has("stamina"):
		stamina -= spec["stamina"]
		stamina_idle = 0.0

# clic izquierdo = "light", clic derecho = "heavy" del objeto equipado (data/items.json)
func _attack(mode: String) -> bool:  # true si el ataque empezó (y se cobró)
	if attacking or dashing or aiming or cooldown > 0.0:
		return false
	var spec: Dictionary = items[hotbar[selected]][mode]
	if not _afford(spec):
		return false
	_pay(spec)
	_begin(spec, mode)
	return true

# pulsación anticipada: si no se puede actuar ahora, se guarda una sola acción durante BUFFER_MS
func _press(action: String) -> void:
	var started: bool = _dash() if action == "dash" else _attack(action)
	if not started:
		buf = action
		buf_until = Time.get_ticks_msec() + BUFFER_MS

func _try_buffer() -> void:
	if buf == "":
		return
	if Time.get_ticks_msec() > buf_until:
		buf = ""
		return
	var started: bool = _dash() if buf == "dash" else _attack(buf)
	if started:
		buf = ""

# arranca un ataque o ultimate: orienta al héroe y reproduce su animación (o dispara al instante si no tiene)
func _begin(spec: Dictionary, mode: String) -> void:
	current = spec
	current_mode = mode
	cooldown = current["cooldown"] / prog.attack_speed()
	aim_dir = _chest_aim()
	facing = DIRS[posmod(roundi(aim_dir.angle() / (PI / 4.0)), 8)]  # el héroe mira hacia donde ataca
	if current.has("anim"):
		attacking = true
		struck = false
		trailed = false
		var anim: String = current["anim"]
		if burn_t > 0.0 and anim.begins_with("slash"):
			anim = "f" + anim  # con la espada en llamas: tajos con fuego
		var key := "%s_%s" % [anim, facing]
		hero.sprite_frames.set_animation_speed(key, current["fps"] * prog.attack_speed())
		hero.play(key)
	else:
		_strike()  # sin animación (bola de fuego básica): sale al instante

func _on_hero_frame() -> void:
	if not attacking:
		return
	if not trailed and current.has("trail_frame") and hero.frame == current["trail_frame"]:
		trailed = true
		_spawn_trail()
	if not struck and hero.frame == current["strike_frame"]:
		struck = true
		_strike()

func _strike() -> void:
	match current["type"]:
		"projectile":
			spawn_projectile("hero", pos, aim_dir, current)
		"meteor":
			var m := Node2D.new()
			m.set_script(load("res://scripts/meteor.gd"))
			m.main = self
			m.cell = aim_cell
			m.spec = current
			add_child(m)
		"melee":
			var dmg: float = current["damage"] * (burn_mult if burn_t > 0.0 else 1.0) * prog.melee_mult()
			var blasts: Array[Vector2] = []
			for e in enemies.duplicate():
				if not e.alive:
					continue
				var to: Vector2 = e.pos - pos
				if to.length() > current["reach"] + e.radius:
					continue
				if absf(angle_difference(aim_dir.angle(), to.angle())) > deg_to_rad(current["arc"]) / 2.0:
					continue
				if current_mode == "heavy" and combat.consume(e):  # el pesado detona la marca de Ignis
					blasts.append(e.pos)
				combat.hit(e, roundi(dmg), current_mode, pos)
			for b in blasts:
				combat.detonate(b)

func _spawn_trail() -> void:
	var t := Node2D.new()
	t.set_script(load("res://scripts/slash_trail.gd"))
	t.center = (pos - Vector2(0, 40)) * SCALE
	t.aim = aim_dir.angle()
	t.arc = deg_to_rad(current["arc"])
	t.radius = current["trail_radius"] * SCALE
	t.color = Color(1.0, 0.45, 0.1) if burn_t > 0.0 else Color.html(current["trail_color"])
	t.duration = current["trail_time"]
	t.flip = trail_flip
	if current_mode == "light":
		trail_flip = -trail_flip  # los tajos ligeros alternan de lado
	t.z_index = int(pos.y) + 6
	add_child(t)

# --- ultimates (R): requieren la carga llena, que se gana golpeando entidades
func _ultimate() -> void:
	if aiming:
		_cancel_aim()
		return
	if ult < hero_data["ult_max"] or attacking or dashing:
		return
	var u: Dictionary = items[hotbar[selected]]["ultimate"]
	if u["type"] == "meteor":
		aiming = true  # el clic izquierdo elige dónde cae
		aim_marker = Node2D.new()
		aim_marker.set_script(load("res://scripts/tile_marker.gd"))
		aim_marker.main = self
		aim_marker.z_index = -3000
		add_child(aim_marker)
	elif u["type"] == "flame_dash":
		_mega_dash(u)

func _cancel_aim() -> void:
	aiming = false
	if aim_marker:
		aim_marker.queue_free()
		aim_marker = null

func _update_aim() -> void:  # el marcador sigue al cursor y solo es válido dentro del rango de casillas
	var u: Dictionary = items[hotbar[selected]]["ultimate"]
	var t := ground_to_tile(_mouse() / SCALE)
	aim_cell = Vector2(floorf(t.x), floorf(t.y))
	var h := ground_to_tile(pos)
	var r: float = u["range_tiles"]
	aim_valid = aim_cell.x >= 0 and aim_cell.x < TILES and aim_cell.y >= 0 and aim_cell.y < TILES \
		and absf(aim_cell.x - floorf(h.x)) <= r and absf(aim_cell.y - floorf(h.y)) <= r
	var n: float = u["aoe_tiles"]
	var half := floorf(n / 2.0)
	aim_marker.rect = Rect2(aim_cell - Vector2(half, half), Vector2(n, n))
	aim_marker.color = Color(1.0, 0.4, 0.1) if aim_valid else Color(0.6, 0.6, 0.6)

func _confirm_meteor() -> void:
	var u: Dictionary = items[hotbar[selected]]["ultimate"]
	ult = 0.0
	var cell := aim_cell
	_cancel_aim()
	aim_cell = cell
	_begin(u, "ultimate")  # animación de lanzamiento; el meteoro cae en el fotograma de disparo

func _mega_dash(u: Dictionary) -> void:
	ult = 0.0
	var to_cursor := _mouse() / SCALE - pos  # se mueve por el suelo: rumbo de los pies al cursor
	dash_dir = to_cursor.normalized() if to_cursor.length() >= 1.0 else Vector2.from_angle(DIRS.find(facing) * PI / 4.0)
	facing = DIRS[posmod(roundi(dash_dir.angle() / (PI / 4.0)), 8)]
	mega_spec = u
	mega_active = true
	mega_hits.clear()
	dashing = true
	attacking = false
	dash_t = 0.0
	ghost_t = 0.0
	dash_time_cur = u["duration"]
	dash_speed_cur = u["distance_tiles"] / _tiles_per_px(dash_dir) / dash_time_cur  # recorre exactamente N casillas
	var key := "megadash_" + facing
	hero.sprite_frames.set_animation_speed(key, 6.0 / dash_time_cur)
	hero.play(key)

func _spawn_ghost() -> void:  # imagen residual de fuego: la estela del mega dash
	var g := Sprite2D.new()
	g.texture = hero.sprite_frames.get_frame_texture(hero.animation, hero.frame)
	g.centered = false
	g.scale = hero.scale
	g.position = hero.position
	g.z_index = hero.z_index - 1
	g.modulate = Color(1.0, 0.5, 0.15, 0.8)
	g.material = CanvasItemMaterial.new()
	g.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_child(g)
	var tw := create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.35)
	tw.tween_callback(g.queue_free)

func _unhandled_input(event: InputEvent) -> void:
	if dying or reaction_time > 0.0:
		return
	if touch_mode and event is InputEventMouseButton:
		return  # los toques emulan clics del ratón; aquí mandan los botones en pantalla
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE:
			_press("dash")
		elif event.physical_keycode == KEY_R:
			_ultimate()
		elif event.physical_keycode == KEY_E:
			_interact()
		elif event.physical_keycode == KEY_H:
			_use_potion()
		elif event.physical_keycode == KEY_ESCAPE:
			_cancel_aim()
		elif not attacking:
			var i: int = event.physical_keycode - KEY_1
			if event.physical_keycode == KEY_Q:
				_select((selected + 1) % hotbar.size())
			elif i >= 0 and i < hotbar.size():
				_select(i)
	if event is InputEventMouseButton and event.pressed:
		if aiming:
			if event.button_index == MOUSE_BUTTON_LEFT and aim_valid:
				_confirm_meteor()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_aim()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_press("light")
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_press("heavy")
		var step := 0.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			step = ZOOM_STEP
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			step = -ZOOM_STEP
		if step != 0.0:
			cam.zoom = Vector2.ONE * clampf(cam.zoom.x + step, ZOOM_MIN, ZOOM_MAX)

func _held(keys: Array) -> bool:
	for k in keys:
		if Input.is_physical_key_pressed(k):
			return true
	return false

func _process(delta: float) -> void:
	var casting: bool = attacking and current.get("type", "") in ["projectile", "meteor"]
	var light_target := 0.45 if (casting or burn_t > 0.0 or mega_active) and not dying else 0.0
	spell_light.energy = lerpf(spell_light.energy, light_target, 1.0 - exp(-12.0 * delta))
	spell_light.position = (pos - Vector2(0, 24)) * SCALE
	if aiming:
		_update_aim()
	_update_bars()
	_update_prompt(delta)
	# llamas alrededor del héroe mientras la katana arde o hace el mega dash
	burn_fx.emitting = burn_t > 0.0 or mega_active
	burn_fx.position = (pos - Vector2(0, 40)) * SCALE
	# la cámara sigue al héroe (suavizada) y tiembla al impactar
	cam.position = cam.position.lerp((pos - Vector2(0, 40)) * SCALE, 1.0 - exp(-8.0 * delta))
	shake_amp = maxf(0.0, shake_amp - delta * 40.0)
	kick_v = kick_v.move_toward(Vector2.ZERO, delta * 90.0)
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amp + kick_v

func _physics_process(delta: float) -> void:
	if reaction_time > 0.0:
		buf = ""  # herido o muerto: la acción anticipada se pierde
		reaction_time = maxf(0.0, reaction_time - delta)
		if reaction_time == 0.0 and dying:
			_respawn()
		_place()
		return
	cooldown = maxf(0.0, cooldown - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	_try_buffer()
	burn_t = maxf(0.0, burn_t - delta)
	# regeneración tras una pausa sin gastar
	stamina_idle += delta
	mana_idle += delta
	if stamina_idle >= hero_data["stamina_regen_delay"]:
		stamina = minf(hero_data["stamina"], stamina + hero_data["stamina_regen"] * delta)
	if mana_idle >= hero_data["mana_regen_delay"]:
		mana = minf(hero_data["mana"], mana + hero_data["mana_regen"] * delta)
	if exhausted and stamina >= 20.0:
		exhausted = false
	if dashing:
		var step_dt := minf(delta, dash_time_cur - dash_t)  # el último paso no se pasa de la distancia
		dash_t += delta
		var step := dash_dir * dash_speed_cur * step_dt * (Vector2.ONE if mega_active else Vector2(1, 0.6))
		pos = world.move_collide(pos, pos + step, HERO_R_T)  # atraviesa al dragón pero no estructuras ni agua
		if mega_active:
			ghost_t += delta
			if ghost_t >= 0.035:
				ghost_t = 0.0
				_spawn_ghost()
			for e in enemies:  # el mega dash daña (una vez) a todo lo que atraviesa
				if e.alive and not mega_hits.has(e) and pos.distance_to(e.pos) < 12.0 + e.radius:
					mega_hits.append(e)
					combat.hit(e, roundi(mega_spec["damage"] * prog.melee_mult()), "heavy", pos, false)
					shake(8.0)
		if dash_t >= dash_time_cur:
			dashing = false
			if mega_active:
				mega_active = false
				burn_t = mega_spec["burn_time"]  # la katana queda en llamas
				burn_mult = mega_spec["burn_mult"]
			_push_out(blockers())  # si termina dentro del dragón, sale de él
		_place()
		return
	if _mb(MOUSE_BUTTON_LEFT):
		_attack("light")  # mantener pulsado repite respetando el cooldown
	elif _mb(MOUSE_BUTTON_RIGHT):
		_attack("heavy")
	if attacking:  # durante la animación de ataque el héroe no se mueve
		_place()
		return
	var dir := _input_dir()
	if dir == Vector2.ZERO:
		hero.play("idle_" + facing)
		_place()
		return
	var sprint := (_held([KEY_SHIFT]) or (touch_mode and bool(touch.sprint))) and not exhausted
	if sprint:  # correr gasta estamina; sin ella se camina
		stamina = maxf(0.0, stamina - hero_data["sprint_drain"] * delta)
		stamina_idle = 0.0
		if stamina == 0.0:
			exhausted = true
	facing = DIRS[posmod(roundi(dir.angle() / (PI / 4.0)), 8)]
	# el eje Y se acorta por la vista isométrica
	var step: Vector2 = dir.normalized() * (SPRINT_SPEED if sprint else WALK_SPEED) * prog.move_mult() * delta * Vector2(1, 0.6)
	var previous_pos := pos
	pos = world.move_collide(pos, pos + step, HERO_R_T)  # el mapa (agua, árboles, rocas, edificios) bloquea
	var traveled := ((pos - previous_pos) / Vector2(1, 0.6)).length()
	_push_out(blockers())  # el dragón también bloquea al héroe
	_update_gait(traveled, sprint)
	_place()

func _update_gait(traveled: float, sprint: bool) -> void:
	if traveled < 0.001:
		hero.play("idle_" + facing)
		return
	# La distancia manda la zancada; girar conserva la fase y una pared la detiene.
	# Longitud de paso / fracción de apoyo, proyectada con SpriteCam (128 px / 2.75 m).
	var cycle_distance := (1.12 / 0.52 if sprint else 0.96 / 0.62) * 128.0 / 2.75
	gait_phase = fposmod(gait_phase + traveled / cycle_distance, 1.0)
	var key := ("run_" if sprint else "walk_") + facing
	hero.animation = key
	hero.pause()
	var sample := gait_phase * hero.sprite_frames.get_frame_count(key)
	hero.set_frame_and_progress(int(sample), sample - floorf(sample))

func _place() -> void:
	hero.position = (pos - FEET) * SCALE
	hero.z_index = int(pos.y)
	if is_instance_valid(contact_shadow):
		contact_shadow.position = pos * SCALE
		contact_shadow.z_index = hero.z_index - 1
