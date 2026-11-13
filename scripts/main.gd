extends Node2D
# Suelo (Blender, misma cámara/paleta cel que el hechicero) + hechicero con Walk / Sprint.
# Controles: WASD/flechas = caminar, Shift = sprint, clic izq = ataque ligero, clic der = ataque pesado
# del objeto equipado, 1/2 o Q = cambiar objeto de la barra, Espacio = dash, R = ultimate, rueda = zoom.

const SCALE := 3.0
const FEET := Vector2(68, 113.7)            # píxel de los pies dentro del sprite de 128x128
const WALK_SPEED := 100.0     # +11 %: el héroe se sentía lento junto al dash y al combate nuevo
const SPRINT_SPEED := 200.0
const ACCEL := 900.0          # px/s²: alcanza la velocidad de paso en ~0.11 s (inercia al arrancar)
const BRAKE := 1500.0         # frenado más seco que el arranque: se detiene en ~0.07 s
const ATTACK_MOVE := {"light": 0.5, "heavy": 0.2, "cast": 0.35}   # fracción de la velocidad al caminar mientras atacas
const LIGHT_CANCEL_T := 0.08  # s tras el impacto de un ligero a partir de los cuales caminar corta la recuperación
var move_vel := Vector2.ZERO  # velocidad actual del héroe (px/s sobre el plano de entrada); suaviza arranque y frenado
var recover_t := 0.0          # tiempo desde el impacto del ataque en curso
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
const ANIMS := {"slash_light": 6, "slash_heavy": 8, "cast": 8, "dash": 6, "chop_pick": 6, "chop_axe": 6, "pluck": 6, "drink": 6, "eat": 6, "fish_cast": 6, "fish_wait": 2, "fish_reel": 4, "fslash_light": 6, "fslash_heavy": 8, "megadash": 6}

# rueda del ratón: acercar / alejar la cámara
const ZOOM_DEFAULT := 0.7
const ZOOM_MIN := 0.3
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1

const HERO_RADIUS := 8.0      # contra entidades (px de suelo); el daño usa `hit` (cuerpo del sprite)
var hit := {}                 # hitbox corporal del héroe, medida de su sprite (hitbox.gd)
var debug_hitboxes := false   # F2
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
var buff_label: Label            # bonus temporales activos (comida y elixires)
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
const DASH_GHOST_EVERY := 0.05  # s entre siluetas residuales del dash
const DASH_GHOST_COL := Color(0.55, 0.8, 1.0)
var dash_cd := 0.0
var dash_time_cur := 0.4583
var dash_speed_cur := 303.6
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
	settings = load("res://scripts/settings.gd").new()
	if get_tree().get_script() == null:  # en los tests no se tocan las opciones del jugador
		settings.load_file()
	else:
		settings.path = "user://test_settings.json"
	settings.apply_audio()
	creatures = _read_json("res://data/creatures.json")
	interiors_data = _read_json("res://data/interiors.json")
	dialogue_data = _read_json("res://data/dialogue.json")
	hero_data = creatures["hero"]
	prog = load("res://scripts/progress.gd").new(_read_json("res://data/equipment.json"))
	crafting = load("res://scripts/crafting.gd").new(prog, _read_json("res://data/crafting.json"))
	prog.skill_data = _read_json("res://data/skills.json")
	for b: String in crafting.cfg["starting_blueprints"]:
		crafting.learn(b)
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
			frames.set_animation_loop(key, anim in ["fish_wait", "fish_reel"])
			if anim.begins_with("fish_"):
				frames.set_animation_speed(key, {"fish_cast": 10.0, "fish_wait": 3.0, "fish_reel": 10.0}[anim])
			for i in ANIMS[anim]:
				var folder := "polished/" if "slash" in anim else ""
				var timing: Array = [1.2, 1.35, 0.45, 0.55, 1.05, 1.4] if anim.ends_with("light") else ([1.0, 1.2, 1.25, 1.2, 0.35, 0.55, 1.0, 1.45] if anim.ends_with("heavy") else ([1.1, 1.2, 0.7, 1.0, 0.6, 0.9, 1.1, 1.4] if anim == "cast" else []))
				frames.add_frame(key, load("res://art/hechicero/%s%s_%s_%02d.png" % [folder, anim, d, i]), timing[i] if not timing.is_empty() else 1.0)
	hero = AnimatedSprite2D.new()
	hero.sprite_frames = frames
	hero.centered = false
	hero.scale = Vector2.ONE * SCALE
	hero.play("idle_S")
	var HB := preload("res://scripts/hitbox.gd")  # cuerpo del héroe medido de su sprite: lo usan los proyectiles enemigos
	hit = HB.measure(DIRS, "res://art/hechicero/polished/idle_%s_00.png", FEET)
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
	clock = load("res://scripts/clock.gd").new()
	add_child(clock)
	social = load("res://scripts/social.gd").new()
	social.main = self
	add_child(social)
	call_deferred("_build_lamps")
	call_deferred("_build_zone_doors")
	call_deferred("_build_farm")
	angler = load("res://scripts/angler.gd").new(self, _read_json("res://data/fishing.json"))
	traps = load("res://scripts/traps.gd").new()
	traps.main = self
	add_child(traps)
	combat = Node2D.new()
	combat.set_script(load("res://scripts/combat.gd"))
	combat.main = self
	add_child(combat)
	if get_tree().get_script() == null or force_music:  # la música se sintetiza en un hilo; los tests no la necesitan
		music = Node.new()
		music.set_script(load("res://scripts/music.gd"))
		music.main = self
		add_child(music)
	_spawn_dragon()
	_spawn_fauna()
	_load_inventory()
	combat.mark_spec = items["grimorio_ignis"].get("mark", combat.mark_spec)
	_build_prompt()
	_build_menu()
	quests = load("res://scripts/quests.gd").new(_read_json("res://data/quests.json"))
	testing = get_tree().get_script() != null  # los tests corren con un SceneTree propio: no tocan la partida guardada
	if not testing:
		if not get_tree().get_meta("new_game", false):
			load_game()
		if get_tree().has_meta("new_game"):
			get_tree().remove_meta("new_game")
	_apply_stats()
	var village_houses := 0
	for o: Dictionary in mp["objects"]:
		if o["sprite"] == "castle":  # la puerta de madera está en la cara frontal derecha del sprite del castillo
			var door_g := tile_to_ground(Vector2(o["tile"][0], o["tile"][1])) + Vector2(65, -8)
			_add_door(ground_to_tile(door_g), "Entrar a la dungeon", enter_dungeon, false)
		elif o["sprite"] == "stall":  # el mercader está de pie junto al puesto (tras el mostrador lo taparía el toldo)
			var m := Node2D.new()
			m.set_script(load("res://scripts/merchant.gd"))
			m.main = self
			m.pos = tile_to_ground(Vector2(o["tile"][0] - 1.75, o["tile"][1] + 0.3))  # del lado que mira al camino: delante del puesto en pantalla
			add_child(m)
			merchants.append(m)
		elif o["sprite"] == "house" and o["tile"][1] > 30.0 and not merchants.any(func(x: Node) -> bool: return x.role == "smith"):  # el herrero vive en la primera casa del pueblo; está frente a su puerta
			var s := Node2D.new()
			s.set_script(load("res://scripts/merchant.gd"))
			s.main = self
			s.role = "smith"
			s.pos = tile_to_ground(Vector2(o["tile"][0], o["tile"][1] - 2.2))
			add_child(s)
			merchants.append(s)
		if o["sprite"] == "house" and o["tile"][1] > 30.0 and village_houses < INTERIOR_IDS.size():  # las casas del pueblo se pueden visitar
			var iid: String = INTERIOR_IDS[village_houses]
			village_houses += 1
			var dd := _add_door(Vector2(o["tile"][0], o["rect"][3] + 0.6), "Entrar: " + interiors_data[iid]["title"], enter_interior.bind(iid), false)
			dd.reach = 1.8
	station_ui = CanvasLayer.new()
	station_ui.set_script(load("res://scripts/station_ui.gd"))
	station_ui.main = self
	add_child(station_ui)
	_build_world_props()
	shop = CanvasLayer.new()
	shop.set_script(load("res://scripts/shop.gd"))
	shop.main = self
	add_child(shop)
	dialogue = CanvasLayer.new()
	dialogue.set_script(load("res://scripts/dialogue.gd"))
	dialogue.main = self
	add_child(dialogue)
	_place()
	if not testing:
		var start_menu: CanvasLayer = load("res://scripts/start_menu.gd").new()
		start_menu.main = self
		add_child(start_menu)
		save_game()

# --- pueblo: misiones, mercader y guardado
var quests: RefCounted
var testing := false
var save_path := "user://save.json"
var autosave_t := 0.0
var quest_label: Label
var merchants: Array = []
var shop: CanvasLayer

func _in_combat() -> bool:  # hay un enemigo (o el zorro) cerca y activo: entra la capa de percusión
	for e in enemies + predators:
		if not e.alive or e.pos.distance_to(pos) > 320.0:
			continue
		var s: Variant = e.get("state")
		if (s is String and s != "idle" and s != "rest" and s != "home" and s != "eat" and s != "hunt") or (s is int and s != 0):
			return true
	return false

func _near_merchant() -> Node2D:
	for m: Node2D in merchants:
		if m.in_range():
			return m
	return null

func quest_event(event: String, target: String) -> void:  # muertes y pisos completados avanzan la misión activa
	if quests.notify(event, target):
		say("¡Misión cumplida! Vuelve con %s" % quests.giver, 3.0)
		save_game()

func save_game() -> void:
	if testing and save_path == "user://save.json":
		return
	var d := {"version": 1, "level": prog.level, "xp": prog.xp, "points": prog.points, "spent": prog.spent,
		"coins": prog.coins, "potions": prog.potions, "materials": prog.materials, "owned": prog.owned,
		"equipped": prog.equipped, "blueprints": prog.blueprints, "slots": prog.slots, "dungeon_floor": dungeon_floor, "quests": quests.to_dict(), "clock": clock.to_dict(), "stars": prog.stars, "angler": angler.to_dict(), "bait": bait, "rod_parts": prog.rod_parts, "farm": farm.to_dict() if farm else pending_farm, "skills": prog.skills, "skill_points": prog.skill_points, "social": social.to_dict(), "zones_done": zones_done}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))

func load_game() -> bool:  # valida cada campo: el archivo puede estar editado o ser de otra versión
	if not FileAccess.file_exists(save_path):
		return false
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not d is Dictionary:
		push_warning("partida guardada ilegible: se ignora")
		return false
	prog.level = maxi(1, int(d.get("level", 1)))
	prog.xp = maxi(0, int(d.get("xp", 0)))
	prog.points = maxi(0, int(d.get("points", 0)))
	var spent: Variant = d.get("spent", {})
	for s: String in prog.STATS:
		prog.spent[s] = maxi(0, int(spent.get(s, 0))) if spent is Dictionary else 0
	prog.coins = maxi(0, int(d.get("coins", 0)))
	prog.potions = maxi(0, int(d.get("potions", 1)))
	prog.materials.clear()
	var mats: Variant = d.get("materials", {})
	if mats is Dictionary:
		for k: String in mats:
			if prog.material_names.has(k):
				prog.materials[k] = maxi(0, int(mats[k]))
	prog.owned = (d.get("owned", []) as Array).filter(func(i: Variant) -> bool: return prog.equipment.has(str(i))) if d.get("owned") is Array else []
	prog.equipped.clear()
	var eq: Variant = d.get("equipped", {})
	if eq is Dictionary:
		for slot: String in eq:
			var id := str(eq[slot])
			if prog.equipment.has(id) and prog.owned.has(id) and prog.equipment[id]["slot"] == slot:
				prog.equipped[slot] = id
	prog.blueprints.clear()
	var bps: Variant = d.get("blueprints", [])
	if bps is Array:
		for b: Variant in bps:
			if crafting.cfg["blueprints"].has(str(b)) and not prog.blueprints.has(str(b)):
				prog.blueprints.append(str(b))
	for b: String in crafting.cfg["starting_blueprints"]:
		crafting.learn(b)
	var layout: Array = []
	if d.get("slots") is Array:
		for i in HOTBAR_MAX:
			var sid := str(d["slots"][i]) if i < (d["slots"] as Array).size() else ""
			layout.append(sid if (sid == "" or (can_hotbar(sid) and not layout.has(sid))) else "")
	else:  # partida anterior a la barra editable: armas, herramientas equipadas y los consumibles elegidos
		layout = WEAPONS.duplicate()
		for kind: String in ["pickaxe", "axe", "rod"]:
			if prog.equipped.has(kind):
				layout.append(prog.equipped[kind])
		var old: Array = d["hand"] if d.get("hand") is Array else ["pocion_vida"]
		for h: Variant in old:
			if can_hotbar(str(h)) and not layout.has(str(h)):
				layout.append(str(h))
		layout = layout.slice(0, HOTBAR_MAX)
	while layout.size() < HOTBAR_MAX:
		layout.append("")
	prog.slots = layout
	tool_seen = prog.equipped.duplicate()
	_refresh_hotbar()
	dungeon_floor = (clampi(int(d.get("dungeon_floor", 1)), 1, 999) - 1) / 4 * 4 + 1  # siempre un punto de reanudación (piso 1, 5, 9...)
	if d.get("quests") is Dictionary:
		quests.from_dict(d["quests"])
	if d.get("clock") is Dictionary:
		clock.from_dict(d["clock"])
	prog.stars.clear()
	if d.get("stars") is Dictionary:
		for k: String in d["stars"]:
			if prog.materials.has(k) and d["stars"][k] is Array and (d["stars"][k] as Array).size() == 2:
				prog.stars[k] = [maxi(0, int(d["stars"][k][0])), maxi(0, int(d["stars"][k][1]))]
	if d.get("angler") is Dictionary:
		angler.from_dict(d["angler"])
		traps.rebuild()
	prog.rod_parts.clear()
	if d.get("rod_parts") is Dictionary:
		for k: String in ["reel", "line"]:
			if d["rod_parts"].get(k) == true:
				prog.rod_parts[k] = true
	zones_done.clear()
	if d.get("zones_done") is Array:
		for z: Variant in d["zones_done"]:
			if str(z) in ["pantano", "desierto"] and not zones_done.has(str(z)):
				zones_done.append(str(z))
	if d.get("social") is Dictionary:
		social.from_dict(d["social"])
	prog.skills.clear()
	if d.get("skills") is Dictionary:
		for sid: String in d["skills"]:
			if prog.skill_data["skills"].has(sid):
				prog.skills[sid] = clampi(int(d["skills"][sid]), 0, int(prog.skill_data["skills"][sid]["max"]))
	prog.skill_points = maxi(0, int(d.get("skill_points", 0)))
	if d.get("farm") is Dictionary:
		if farm:
			farm.from_dict(d["farm"])
		else:
			pending_farm = d["farm"]
	bait = str(d.get("bait", "")) if angler.cfg["baits"].has(str(d.get("bait", ""))) else ""
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

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
	quest_label = Label.new()  # misión activa, arriba a la derecha
	quest_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	quest_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	quest_label.offset_right = -18.0
	quest_label.offset_top = 14.0
	quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quest_label.add_theme_font_size_override("font_size", 20)
	quest_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	quest_label.add_theme_color_override("font_outline_color", Color.BLACK)
	quest_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(quest_label)
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

func social_target() -> String:  # con quién se puede hablar y a quién regalar: id de data/npcs.json
	if in_dungeon and not in_interior:
		return ""
	var n := _near_npc()
	if n != null and social.is_friend(n.id):
		return n.id
	var m := _near_merchant()
	if m != null:
		return "tomas" if m.role == "merchant" else "bram"
	var v := _near_villager()
	if v != null and v == villagers[0]:
		return "elda"
	return ""

func _interact() -> void:
	var d := _near_door()
	if d != null and not transitioning:
		d.use()
		return
	var sid := social_target()
	if sid != "":
		social.on_talk(sid)  # hablar suma amistad una vez al día
		var ev: Array = social.take_event(sid)
		if not ev.is_empty():
			dialogue.open(social.name_of(sid), ev)
			return
	var v := _near_villager()
	if v != null:
		var line: String = v.talk()
		if v == villagers[0]:  # Elda da las misiones
			line = quests.talk(self)
			save_game()
		var who: String = quests.giver if v == villagers[0] else "Aldeano"
		dialogue.open(who, line.replace(who + ": ", "").split("\n"))
		return
	var nd := _near_npc()
	if nd != null:
		dialogue.open(nd.display, npc_lines(nd))
		return
	var m := _near_merchant()
	if m != null:
		shop.open(m.role)
		return
	if farm and farm.try_harvest():
		return
	var fu := _near_furniture()
	if not fu.is_empty():
		if fu["kind"] == "bed":
			_sleep()
		else:
			menu.tab = "fish"
			menu.visible = true
			get_tree().paused = true
			menu.refresh()
		return
	var st := _near_station()
	if not st.is_empty():
		station_ui.open(st["station"])
		return
	var rn := _near_node()
	if not rn.is_empty():
		_gather(rn)

const FURNI_USE := {"bed": "Dormir hasta el amanecer", "aquarium": "Ver el acuario"}

func _near_furniture() -> Dictionary:  # mueble utilizable de la casa en la que estás
	if not in_interior:
		return {}
	var t := ground_to_tile(pos)
	for f: Dictionary in interiors_data[current_interior]["furniture"]:
		if FURNI_USE.has(f["kind"]):
			var r: Array = f["rect"]
			if Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]).grow(0.9).has_point(t):
				return {"kind": f["kind"], "label": FURNI_USE[f["kind"]]}
	return {}

func _sleep() -> void:  # cama: salta la noche hasta las 7:00, cura todo y guarda
	if clock.dark() <= 0.0:
		say("Aún no tienes sueño: es de día.", 2.0)
		return
	_transition(func() -> void:
		clock.sleep_until(7.0)
		hero_hp = hero_max_hp
		mana = hero_data["mana"]
		stamina = hero_data["stamina"]
		regen_left = 0.0
		combat.play_at("sleep", pos)
		save_game()
		say("Duermes hasta el amanecer. Día %d." % clock.day, 3.0))

func _near_villager() -> Node2D:
	if in_dungeon:
		return null
	for v: Node2D in villagers:
		if v.pos.distance_to(pos) < 35.0 and v.can_talk():
			return v
	return null

# ruido: golpes y explosiones dejan un evento breve que fauna y civiles perciben (no la posición del héroe)
var noises: Array = []  # [posición de suelo, radio, segundos restantes]

func noise(at: Vector2, radius: float) -> void:
	noises.append([at, radius, 1.0])

func noise_near(p: Vector2) -> bool:
	for n: Array in noises:
		if p.distance_to(n[0]) < n[1]:
			return true
	return false

func _update_prompt(delta: float) -> void:
	say_t = maxf(0.0, say_t - delta)
	if loot_t > 0.0:
		loot_t -= delta
		if loot_t <= 0.0:
			for c in loot_box.get_children():
				c.queue_free()
	if music:
		music.set_combat(_in_combat())
	if quests:
		quest_label.text = quests.tracker()
	autosave_t += delta
	if autosave_t > 20.0:  # guardado automático periódico
		autosave_t = 0.0
		save_game()
	for n: Array in noises:
		n[2] -= delta
	noises = noises.filter(func(n: Array) -> bool: return n[2] > 0.0)
	var d := _near_door()
	if say_t > 0.0:
		prompt.text = say_text
	elif _fishing():
		prompt.text = ""
	elif d != null and not transitioning:
		prompt.text = ("[E] " + d.label) if not d.locked else d.lock_text
	elif _near_villager() != null:
		prompt.text = "[E] Hablar con %s" % quests.giver if _near_villager() == villagers[0] else "[E] Hablar"
	elif _near_npc() != null:
		prompt.text = "[E] Hablar con %s" % _near_npc().display
	elif _near_merchant() != null:
		prompt.text = "[E] Comprar a Tomás  (tienes %d monedas)" % prog.coins if _near_merchant().role == "merchant" else "[E] Vender materiales a Bram"
	elif not _near_furniture().is_empty():
		prompt.text = "[E] " + _near_furniture()["label"]
	elif farm and farm.near_text() != "":
		prompt.text = farm.near_text()
	elif not _near_station().is_empty():
		prompt.text = "[E] " + _near_station()["label"]
	elif not _near_node().is_empty():
		var nn := _near_node()
		var why: String = crafting.can_gather(nn["kind"])
		prompt.text = "%s — %s" % [crafting.cfg["gather"][nn["kind"]]["name"], why] if why != "" else "[E] Recoger: %s" % crafting.cfg["gather"][nn["kind"]]["name"]
	else:
		prompt.text = ""
	if say_t <= 0.0 and prompt.text != "":  # con un vecino cerca: recordatorio de regalar y sus corazones
		var sid := social_target()
		if sid != "":
			prompt.text += "  ·  [G] Regalar  %s" % social.hearts_text(sid)

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
	refresh_world_levels()
	RenderingServer.set_default_clear_color(Color("#0f1a2a"))
	combat.set_zone(false)
	cam.position = (pos - Vector2(0, 40)) * SCALE

# --- interiores de las casas del pueblo (data/interiors.json) y conversaciones (data/dialogue.json)
const INTERIOR_IDS := ["forge", "den"]   # primera y segunda casa del pueblo, por orden en map.json
var interiors_data := {}
var dialogue_data := {}
var dialogue: CanvasLayer
var in_interior := false
var current_interior := ""
var npcs: Array = []

func enter_interior(id: String) -> void:
	_transition(func() -> void: _enter_interior(id))

func _enter_interior(id: String) -> void:  # como la dungeon: oculta el exterior, cambia la cuadrícula y monta la sala
	var cfg: Dictionary = interiors_data[id]
	in_dungeon = true  # fauna, civiles y enemigos se pausan y ocultan igual que bajo tierra
	in_interior = true
	current_interior = id
	overworld = {"pos": pos, "C1": C1, "E1": E1, "E2": E2, "tiles": TILES, "world": world, "doors": doors, "dragon_alive": dragon.alive}
	world.visible = false
	for d: Node2D in doors:
		d.visible = false
	doors = []
	dragon.visible = false
	dragon.alive = false
	var n: int = cfg["tiles"]
	var s := n / TILES
	E1 *= s
	E2 *= s
	TILES = n
	C1 = -(E1 + E2) / 2.0
	RenderingServer.set_default_clear_color(Color("#1a120b"))
	combat.set_zone(false)
	combat.set_indoors()
	dungeon_node = Node2D.new()
	dungeon_node.set_script(load("res://scripts/interior.gd"))
	dungeon_node.main = self
	add_child(dungeon_node)
	dungeon_node.setup(cfg)
	world = dungeon_node
	_add_door(Vector2(n / 2.0, 0.25), "Salir de la casa", exit_interior)
	pos = tile_to_ground(Vector2(n / 2.0, 2.4))
	cam.position = (pos - Vector2(0, 40)) * SCALE
	for nd: Dictionary in cfg["npcs"]:
		var npc := Node2D.new()
		npc.set_script(load("res://scripts/npc.gd"))
		npc.main = self
		npc.id = nd["id"]
		npc.pos = tile_to_ground(Vector2(nd["tile"][0], nd["tile"][1]))
		add_child(npc)
		npcs.append(npc)

func exit_interior() -> void:
	_transition(_exit_interior)

func _exit_interior() -> void:
	in_dungeon = false
	in_interior = false
	current_interior = ""
	for nd in npcs:
		nd.queue_free()
	npcs.clear()
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

func _near_npc() -> Node2D:
	for nd: Node2D in npcs:
		if nd.in_range():
			return nd
	return null

func _dragon_alive() -> bool:  # dentro de una casa el dragón está desactivado: vale lo guardado
	return overworld.get("dragon_alive", dragon.alive) if in_dungeon else dragon.alive

func _talk_cond(c: String) -> bool:
	match c:
		"dragon_alive": return _dragon_alive()
		"dragon_dead": return not _dragon_alive()
		"fox_alive": return predators.any(func(p: Node) -> bool: return p.alive)
		"deep": return dungeon_floor >= 5
	return c == ""

func npc_lines(npc: Node2D) -> Array:  # conversaciones que se cumplen ahora; rota entre ellas
	var ok: Array = dialogue_data[npc.id]["talks"].filter(func(t: Dictionary) -> bool: return _talk_cond(t.get("if", "")))
	var pick: Dictionary = ok[npc.talks % ok.size()]
	npc.talks += 1
	return pick["lines"]

# --- enemigos, botín y progresión (progress.gd)
var enemies: Array = []          # dragón y monstruos de la dungeon: alive, pos, radius, take_damage()
var prog: RefCounted
var crafting: RefCounted      # recetas, alquimia, consumibles y recolección (scripts/crafting.gd)
var hero_base := {}              # vida, maná y estamina base (sin nivel, puntos ni equipo)
var floors: Node
var dungeon_floor := 1
var info_label: Label

func _build_menu() -> void:
	var m := CanvasLayer.new()
	m.set_script(load("res://scripts/menu.gd"))
	m.main = self
	add_child(m)
	menu = m

func _apply_stats() -> void:  # recalcula máximos con nivel, puntos y equipo; si el máximo sube, sube también lo actual
	var old := hero_max_hp
	hero_max_hp = prog.max_hp(hero_base["hp"])
	hero_hp = clampi(hero_hp + hero_max_hp - old, 1, hero_max_hp)
	hero_data["mana"] = prog.max_mana(hero_base["mana"])
	hero_data["stamina"] = prog.max_stamina(hero_base["stamina"])
	mana = minf(mana, hero_data["mana"])
	stamina = minf(stamina, hero_data["stamina"])
	_equip_look()
	_refresh_hotbar()

# --- el equipo se ve sobre el héroe (versión ligera: sin capas de sprite nuevas)
# armadura -> tono de la ropa (self_modulate, no choca con los destellos de daño en modulate);
# espada -> color del tajo; collar/anillo -> brillo tenue alrededor del héroe.
const ARMOR_TINT := {1: Color(1.0, 0.93, 0.82), 2: Color(0.88, 0.95, 1.08), 3: Color(1.12, 1.04, 0.78)}
const SWORD_TRAIL := {2: Color(0.62, 0.35, 0.95), 3: Color(0.65, 0.95, 1.0)}
const AURA := {1: Color(0.75, 0.75, 0.7), 2: Color(0.4, 0.65, 1.0), 3: Color(1.0, 0.8, 0.35)}
var equip_aura: PointLight2D

func _tier(slot: String) -> int:
	var id: String = prog.equipped.get(slot, "")
	return int(prog.equipment[id]["tier"]) if id != "" else 0

func _equip_look() -> void:
	if hero == null:
		return
	hero.self_modulate = ARMOR_TINT.get(_tier("armor"), Color.WHITE)
	var t := maxi(_tier("amulet"), _tier("ring"))
	if equip_aura == null and combat != null:
		equip_aura = combat.light(Color.WHITE, 0.0, 1.4)
		add_child(equip_aura)
	if equip_aura:
		equip_aura.color = AURA.get(t, Color.WHITE)
		equip_aura.energy = 0.0 if t == 0 else 0.12 + 0.06 * t

func sword_trail_color() -> Color:  # color del tajo según la espada equipada (la katana en llamas manda)
	var sid: String = prog.equipped.get("sword", "")
	if sid != "" and prog.equipment[sid].has("trail"):  # las espadas forjadas llevan su propio color
		return Color.html(prog.equipment[sid]["trail"])
	return SWORD_TRAIL.get(_tier("sword"), Color.html(current["trail_color"]))

func spawn_enemy(id: String, ground: Vector2) -> Node2D:
	var e := Node2D.new()
	e.set_script(load("res://scripts/enemy.gd"))
	e.main = self
	e.data = _scaled(creatures[id]) if in_dungeon else level_data(id, world_level(false))
	e.id = id
	e.pos = ground
	add_child(e)
	enemies.append(e)
	return e

# Dificultad por piso (data/dungeon.json "scale"): vida y daño de los monstruos crecen con la profundidad.
var floor_hp := 1.0
var floor_dmg := 1.0
var floor_reward := 1.0
var floor_extra := {}       # variante de jefe: hp_mult, dmg_mult, size_mult, xp_mult
const LEVEL_HP := 0.16      # vida de un monstruo por nivel sobre el 1
const LEVEL_DMG := 0.10     # daño por nivel
const LEVEL_REWARD := 0.12  # XP y monedas por nivel
const FLOOR_REWARD := 0.18  # XP y monedas por piso de dungeon

func set_enemy_level(level: int, extra := {}, floor_n := 1) -> void:  # los monstruos que se creen a continuación saldrán a ese nivel (0 = sin escalar)
	var l := float(maxi(level, 1) - 1)
	floor_hp = 1.0 + LEVEL_HP * l
	floor_dmg = 1.0 + LEVEL_DMG * l
	floor_reward = (1.0 + LEVEL_REWARD * l) * (1.0 + FLOOR_REWARD * float(floor_n - 1)) if level > 0 else 1.0
	floor_extra = extra if level > 0 else {}

func level_data(id: String, level: int, extra := {}) -> Dictionary:  # copia de creatures[id] a ese nivel
	var keep := [floor_hp, floor_dmg, floor_reward, floor_extra]
	set_enemy_level(level, extra)
	var d := _scaled(creatures[id])
	floor_hp = keep[0]
	floor_dmg = keep[1]
	floor_reward = keep[2]
	floor_extra = keep[3]
	return d

func world_level(boss: bool) -> int:  # en el exterior los monstruos van un par de niveles por debajo del héroe y los jefes, a su nivel
	return maxi(1, prog.level - (0 if boss else 2))

func refresh_world_levels() -> void:  # al subir de nivel o volver al exterior: el dragón y el zorro se reajustan (conservan su fracción de vida)
	if dragon != null:
		var d := level_data("dragon", world_level(true))
		var old: int = dragon.data["hp"]
		dragon.data = d
		dragon.hp = clampi(roundi(float(dragon.hp) * float(d["hp"]) / float(old)), 1, int(d["hp"])) if dragon.alive else dragon.hp
	for p: Node in predators:
		var d := level_data("fox", world_level(false))
		var old: int = p.data["hp"]
		p.data = d
		p.hp = clampi(roundi(float(p.hp) * float(d["hp"]) / float(old)), 1, int(d["hp"])) if p.alive else p.hp
const REWARD_XP := 0.8      # recompensas globales (ajustadas con tests/test_playthrough.gd)
const REWARD_COINS := 0.7

func _scaled(base: Dictionary) -> Dictionary:
	var d: Dictionary = base.duplicate(true)
	d["hp"] = roundi(d["hp"] * floor_hp * float(floor_extra.get("hp_mult", 1.0)))
	if d.has("xp"):
		d["xp"] = roundi(float(d["xp"]) * floor_reward * float(floor_extra.get("xp_mult", 1.0)))
	if d.has("coins"):
		d["coins"] = [roundi(float(d["coins"][0]) * floor_reward), roundi(float(d["coins"][1]) * floor_reward)]
	if floor_extra.has("size_mult"):
		d["size"] = float(d.get("size", 1.0)) * float(floor_extra["size_mult"])
		d["radius"] = float(d.get("radius", 10.0)) * float(floor_extra["size_mult"])
	for path: Array in [["contact_damage"], ["slam_damage"], ["projectile", "damage"], ["orb", "damage"], ["lightning", "damage"]]:
		var node: Dictionary = d
		for i in path.size() - 1:
			node = node.get(path[i], {})
		var key: String = path[-1]
		if node.has(key):
			node[key] = roundi(node[key] * floor_dmg * float(floor_extra.get("dmg_mult", 1.0)))
	return d

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
	var gained: int = prog.add_xp(n)
	if gained > 0:
		prog.skill_points += gained  # 1 punto de habilidad por nivel
		refresh_world_levels()
		_apply_stats()
		hero_hp = hero_max_hp
		say("¡Nivel %d!  +%d puntos de mejora: abre el menú [I]" % [prog.level, prog.POINTS_PER_LEVEL], 3.5)

func on_kill(e: Node) -> void:  # botín de un enemigo: XP, monedas y objetos (data/creatures.json)
	var d: Dictionary = e.data
	var xp := roundi(int(d.get("xp", 0)) * REWARD_XP)
	var lines: Array[String] = ["+%d XP" % xp]
	if d.has("coins"):
		var c := roundi(randi_range(int(d["coins"][0]), int(d["coins"][1])) * REWARD_COINS)
		prog.coins += c
		lines.append("+%d monedas" % c)
	for drop: Dictionary in d.get("drops", []):
		if randf() >= drop["chance"]:
			continue
		if drop["item"] == "pocion_vida":
			prog.potions += 1
			lines.append("Poción de vida")
		elif crafting.is_blueprint(drop["item"]):
			if crafting.learn(drop["item"]):
				lines.append("¡%s!" % crafting.item_name(drop["item"]).replace("Plano:", "Plano aprendido:"))
		else:
			prog.materials[drop["item"]] = prog.materials.get(drop["item"], 0) + 1
			lines.append(prog.material_names[drop["item"]])
			quest_event("loot", drop["item"])
	popup(e.pos, "\n".join(lines))
	gain_xp(xp)
	var eid: String = str(e.get("id")) if e.get("id") != null and str(e.get("id")) != "" else str(creatures.find_key(d))  # los monstruos de la dungeon llevan una copia escalada de sus datos
	if eid != "<null>" and eid != "":
		quest_event("kill", eid)

func give_item(id: String) -> String:  # entrega un objeto de equipo (se equipa solo si es mejor que lo actual)
	var equipped: bool = prog.add_item(id)
	_apply_stats()
	return "%s%s" % [prog.equipment[id]["name"], "  (equipado)" if equipped else "  (al inventario)"]

func _use_potion() -> void:  # atajo de pruebas y del botón táctil: bebe una poción de vida sin pasar por la barra
	var m: String = crafting.use(self, "pocion_vida")
	if m != "":
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
	_update_counts()
	_set_bar("hp", hero_hp, hero_max_hp, "Vida %d / %d" % [hero_hp, hero_max_hp])
	_set_bar("mana", mana, hero_data["mana"], "Maná %d" % roundi(mana))
	_set_bar("stamina", stamina, hero_data["stamina"], "Estamina %d" % roundi(stamina) + ("  (agotada)" if exhausted else ""))
	var full: bool = ult >= hero_data["ult_max"]
	_set_bar("ult", ult, hero_data["ult_max"], "ULTIMATE LISTA  [R]" if full else "Ultimate %d%%" % roundi(ult))
	_set_bar("xp", prog.xp, prog.xp_needed(), "Nivel %d  ·  XP %d / %d" % [prog.level, prog.xp, prog.xp_needed()])
	info_label.text = "Monedas %d  ·  Menú [I]%s  ·  %s" % [prog.coins, ("  ·  ¡%d puntos!" % prog.points) if prog.points > 0 else "", clock.text()]
	burn_label.text = "Espada en llamas  %.1f s" % burn_t if burn_t > 0.0 else ""

func _load_inventory() -> void:
	items = _read_json("res://data/items.json")
	items[""] = {"name": "Manos libres", "icon": "", "hand": "empty", "light": {"name": "casilla vacía: arrastra un objeto desde el inventario [I]"}}
	var inv := _read_json("res://data/inventory_test.json")
	hotbar = prog.slots
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
	buff_label = Label.new()
	buff_label.position = Vector2(16, 188)
	buff_label.add_theme_font_size_override("font_size", 18)
	buff_label.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
	buff_label.add_theme_color_override("font_outline_color", Color.BLACK)
	buff_label.add_theme_constant_override("outline_size", 5)
	ui.add_child(buff_label)
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
	hotbar_row = row
	hotbar_size = size
	_refresh_hotbar(true)

func _select(i: int) -> void:
	if _fishing():
		fishing.cancel()
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
	if it.has("hand"):
		hint_label.text = "%s%s  ·  clic izq: %s%s" % [it["name"], "  ×%d" % crafting.count(hotbar[i]) if it["hand"] == "consumable" else "", it["light"]["name"],
			"  ·  [B] cebo: %s" % (crafting.item_name(bait) if bait != "" else "ninguno") if it["hand"] == "rod" else ""]
		return
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
	dragon.data = level_data("dragon", world_level(true))
	dragon.pos = dragon_start
	add_child(dragon)
	enemies.append(dragon)

func targets() -> Array:  # todo lo que el héroe puede golpear: enemigos y, en el exterior, la fauna viva
	var t: Array = enemies.duplicate()
	if not in_dungeon:
		for f in fauna + predators:
			if f.alive:
				t.append(f)
	return t

var fauna: Array = []      # presas del exterior (critter.gd): se pueden cazar; no bloquean
var predators: Array = []  # zorro territorial (predator.gd)
var villagers: Array = []  # civiles (villager.gd)

func _free_spot(rng: RandomNumberGenerator, near: Vector2, min_m: float, max_m: float) -> Vector2:  # casilla libre a esa distancia (m)
	for i in 200:
		var p: Vector2 = near + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(min_m, max_m) / _tiles_per_px(Vector2.RIGHT)
		if not world.blocked(ground_to_tile(p), 0.6):
			return p
	return near

func _actor(script: String, props: Dictionary) -> Node2D:
	var a := Node2D.new()
	a.set_script(load(script))
	a.main = self
	a.world = world
	for k: String in props:
		a.set(k, props[k])
	add_child(a)
	return a

# vida ambiental del exterior en sitios fijos (semilla): 3 conejos, un zorro lejos del inicio y un civil cerca
func _spawn_fauna() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 3:
		fauna.append(_actor("res://scripts/critter.gd", {"home": _free_spot(rng, start_pos, 4.0, 9.0)}))
	var work := _free_spot(rng, start_pos, 3.0, 6.0)
	var rest := _free_spot(rng, work, 3.0, 5.0)
	villagers.append(_actor("res://scripts/villager.gd", {"work": work, "rest": rest, "stroll": _free_spot(rng, rest, 6.0, 9.0)}))
	# guarida cerca de algún conejo (caza a la vista) pero con el inicio y el refugio del civil fuera de su alcance
	var den := Vector2.ZERO
	for i in 60:
		den = _free_spot(rng, fauna[i % 3].home, 6.0, 11.0)
		if den.distance_to(start_pos) > 220.0 and den.distance_to(rest) > 220.0:
			break
	predators.append(_actor("res://scripts/predator.gd", {"den": den}))

const MAX_WINDUPS := 2  # preparaciones peligrosas simultáneas (punto de partida del estudio, no una cifra aprobada)

func can_prepare(e: Node) -> bool:  # un enemigo solo empieza su aviso si hay hueco; los demás siguen posicionándose
	var n := 0
	for o in enemies:
		if o != e and o.alive and o.get("state") is String and o.state == "windup":
			n += 1
	return n < MAX_WINDUPS

func blockers() -> Array:  # enemigos vivos: bloquean al héroe; las estructuras las maneja world
	return enemies.filter(func(e: Node) -> bool: return e.alive)

# --- recompensas de buen juego (investigación: Hades, Souls, DOOM)
var dodge_cd := 0.0
var dash_bonus_t := 0.0          # tras un dash, el siguiente tajo pega más
var swing_mana := 0.0            # maná ganado en el tajo en curso
const MANA_HIT := {"light": 4.0, "heavy": 10.0}   # maná por golpe de espada conectado
const SWING_MANA_CAP := 14.0     # tope por tajo: un golpe a varios enemigos no regala maná sin límite
const DASH_BONUS_TIME := 0.5
const DASH_BONUS_MULT := 1.3
const DODGE_ULT := 12.0

func mana_on_hit(kind: String) -> void:  # la espada alimenta la magia (no existe cura por pegar: no se premia recibir daño)
	var g := minf(MANA_HIT.get(kind, 0.0), SWING_MANA_CAP - swing_mana)
	if g > 0.0:
		swing_mana += g
		mana = minf(hero_data["mana"], mana + g)

func _perfect_dodge() -> void:  # un ataque habría golpeado durante el dash: esquiva perfecta
	dodge_cd = 0.6
	ult = minf(hero_data["ult_max"], ult + DODGE_ULT)
	mana = minf(hero_data["mana"], mana + 15.0)
	stamina = minf(hero_data["stamina"], stamina + 25.0)
	popup(pos, "¡Esquiva!", Color(0.5, 0.95, 1.0))
	combat.flash(pos, Color(0.5, 0.9, 1.0), 0.9, 2.0, 0.25)
	combat.play("light")

func damage_hero(n: int) -> void:
	if _fishing() and not dashing:
		fishing.cancel("¡Te hieren!")
	if dashing and not mega_active and dodge_cd <= 0.0 and not dying:
		_perfect_dodge()
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
	if in_interior:
		_exit_interior()
	elif in_mine:
		_exit_mine()
		say("Despiertas en el pueblo", 2.5)
	elif in_dungeon:  # despierta en el pueblo; el piso alcanzado y la misión se conservan
		_exit_dungeon()
		say("Despiertas en el pueblo", 2.5)
	else:
		dragon.reset(dragon_start)
	pos = start_pos
	cam.position = (pos - Vector2(0, 40)) * SCALE
	save_game()
	hero.play("idle_" + facing)

func gain_ultimate(damage: float) -> void:  # la ultimate se carga golpeando entidades
	ult = minf(hero_data["ult_max"], ult + damage * hero_data["ult_per_damage"] * (1.0 + prog.skill_sum("ult_gain_pct")))

var settings: RefCounted   # opciones del jugador (settings.gd): accesibilidad de efectos y volúmenes
var music: Node
var menu: CanvasLayer
var force_music := false   # capturas y pruebas de audio: activa la música aunque corra un script de test

func shake(amount: float) -> void:
	shake_amp = maxf(shake_amp, amount * settings.shake)

var kick_v := Vector2.ZERO  # empujón direccional de cámara (px de pantalla), vuelve solo al centro

func kick(v: Vector2) -> void:
	v *= settings.shake
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
	p.aoe = float(spec.get("aoe", 0.0)) * (1.0 + (prog.skill_sum("aoe_pct") if source == "hero" else 0.0))
	p.ground = ground
	p.tint = Color.html(spec["tint"]) if spec.has("tint") else tint
	add_child(p)

var forced_input := Vector2.ZERO   # pruebas: sustituye al teclado cuando no es cero

func _input_dir() -> Vector2:
	if forced_input != Vector2.ZERO:
		return forced_input
	if touch_mode:
		return Vector2.ZERO if aiming else touch.stick
	return Vector2(
		float(_held([KEY_D, KEY_RIGHT])) - float(_held([KEY_A, KEY_LEFT])),
		float(_held([KEY_S, KEY_DOWN])) - float(_held([KEY_W, KEY_UP])))

func _targets() -> Array:
	return enemies + predators

func touch_target() -> Node:  # táctil: el enemigo fijado con un toque; si no, el que más conviene (cerca y poca vida)
	if is_instance_valid(touch.locked) and touch.locked.alive and touch.locked.pos.distance_to(pos) < 600.0:
		return touch.locked
	var best: Node = null
	var best_score := INF
	for e in _targets():
		if not is_instance_valid(e) or not e.alive:
			continue
		var d: float = e.pos.distance_to(pos)
		if d > 320.0:
			continue
		var max_hp := maxf(1.0, float(e.data.get("hp", maxi(e.hp, 1))))
		var frac := clampf(float(e.hp) / max_hp, 0.0, 1.0)
		var score := d / 320.0 * 0.6 + frac * 0.4
		if score < best_score:
			best_score = score
			best = e
	return best

func touch_default_aim() -> Vector2:  # apunta al objetivo; sin enemigos cerca, hacia donde mira el héroe
	var t := touch_target()
	if t != null:
		return t.pos - (pos - Vector2(0, 40))
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

var forced_aim := Vector2.ZERO  # pruebas con bot (test_playthrough.gd): dirección de mira fija en vez del cursor

func _chest_aim() -> Vector2:  # dirección del pecho del héroe al cursor, en px de suelo
	if forced_aim != Vector2.ZERO:
		return forced_aim
	var aim := _mouse() / SCALE - (pos - Vector2(0, 40))
	return aim.normalized() if aim.length() >= 1.0 else Vector2.from_angle(DIRS.find(facing) * PI / 4.0)

# Espacio: dash hacia donde se mueve (o hacia donde mira si está quieto); cancela un ataque en curso
func _dash() -> bool:  # true si el dash empezó
	if _fishing():
		fishing.cancel()  # esquivar recoge el sedal; el dash sale en cuanto se pueda
		return false
	if dashing or dash_cd > 0.0 or aiming or stamina < hero_data["dash_stamina"]:
		return false
	gathering = false  # esquivar corta la recolección
	if attacking and (not struck or current_mode == "heavy"):  # cancelar: el ligero solo en su recuperación; el pesado, nunca (compromiso)
		return false
	stamina -= hero_data["dash_stamina"]
	stamina_idle = 0.0
	var d := _input_dir()
	dash_dir = d.normalized() if d != Vector2.ZERO else Vector2.from_angle(DIRS.find(facing) * PI / 4.0)
	facing = DIRS[posmod(roundi(dash_dir.angle() / (PI / 4.0)), 8)]
	dashing = true
	move_vel = Vector2.ZERO
	_spawn_dash_dust(-dash_dir)
	ghost_t = DASH_GHOST_EVERY  # la primera silueta sale en el primer paso
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
func mana_cost(spec: Dictionary) -> float:  # la eficiencia del grimorio abarata los hechizos
	return float(spec.get("mana", 0.0)) * (1.0 - minf(0.6, prog.skill_sum("cost_pct")))

func _afford(spec: Dictionary) -> bool:
	return mana >= mana_cost(spec) and stamina >= spec.get("stamina", 0.0)

func _pay(spec: Dictionary) -> void:
	if spec.has("mana"):
		mana -= mana_cost(spec)
		mana_idle = 0.0
	if spec.has("stamina"):
		stamina -= spec["stamina"]
		stamina_idle = 0.0

# clic izquierdo = "light", clic derecho = "heavy" del objeto equipado (data/items.json)
func _attack(mode: String) -> bool:  # true si el ataque empezó (y se cobró)
	if _fishing():
		return false
	if attacking or dashing or aiming or gathering or cooldown > 0.0:
		return false
	if items[hotbar[selected]].has("hand"):
		return _use_hand(hotbar[selected], items[hotbar[selected]])
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
	var cd_skill: float = minf(0.5, prog.skill_sum("cd_pct")) if current.get("type", "") == "projectile" else 0.0  # chispa veloz
	cooldown = current["cooldown"] / prog.attack_speed() * (1.0 - cd_skill)
	swing_mana = 0.0
	recover_t = 0.0
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
		recover_t = 0.0
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
		"consume":
			var m: String = crafting.use(self, current["id"])
			if m != "":
				say(m, 2.0)
			_refresh_hotbar()
		"melee":
			var dmg: float = current["damage"] * (burn_mult if burn_t > 0.0 else 1.0) * prog.melee_mult()
			if dash_bonus_t > 0.0:  # tajo tras dash: más daño, se consume
				dmg *= DASH_BONUS_MULT
				dash_bonus_t = 0.0
				popup(pos, "¡Embestida!", Color(1.0, 0.8, 0.4))
			var blasts: Array[Vector2] = []
			if current_mode == "heavy":  # el pesado muerde el suelo delante aunque falle: el peso se ve
				combat.ground_impact(pos + aim_dir * current["reach"] * 0.5 * Vector2(1, 0.6), 0.6)
			var HB := preload("res://scripts/hitbox.gd")
			var chest := pos - Vector2(0, 40)  # el tajo sale del pecho (como su estela) y se mide contra el cuerpo del sprite
			for e in targets():
				if not e.alive:
					continue
				if HB.dist(e, chest) > current["reach"]:
					continue
				var to: Vector2 = HB.center(e) - chest
				var hb: Dictionary = HB.of(e)
				var tol := asin(clampf(sqrt(hb["rx"] * hb["ry"]) / maxf(to.length(), 1.0), 0.0, 1.0))  # cuerpo ancho: el borde también cuenta
				if absf(angle_difference(aim_dir.angle(), to.angle())) > deg_to_rad(current["arc"]) / 2.0 + tol:
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
	t.color = Color(1.0, 0.45, 0.1) if burn_t > 0.0 else sword_trail_color()
	t.duration = current["trail_time"]
	t.anchor = hero
	t.heavy = current_mode == "heavy"
	t.flip = trail_flip
	if current_mode == "light":
		trail_flip = -trail_flip  # los tajos ligeros alternan de lado
	t.z_index = int(pos.y) + 6
	add_child(t)

func _spawn_dash_dust(direction: Vector2) -> void:
	var dust := preload("res://scripts/dash_dust.gd").new()
	dust.position = pos * SCALE
	dust.direction = direction
	dust.tint = Color("#8e8da1") if in_dungeon else Color("#b7a38a")
	dust.z_index = int(pos.y) + 1
	add_child(dust)

# --- ultimates (R): requieren la carga llena, que se gana golpeando entidades
func _ultimate() -> void:
	if aiming:
		_cancel_aim()
		return
	if ult < hero_data["ult_max"] or attacking or dashing or items[hotbar[selected]].has("hand"):
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
	_spawn_dash_dust(-aim_dir)
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

# imagen residual: silueta plana del fotograma actual (cuerpo, capa y arma), color sólido con borde más brillante.
# Sirve al dash (azul acero, corta) y al mega dash (fuego, más larga).
var ghost_shader: Shader
func _spawn_ghost(col := Color(1.0, 0.5, 0.15), life := 0.35, alpha := 0.8) -> void:
	if ghost_shader == null:
		ghost_shader = Shader.new()
		ghost_shader.code = """shader_type canvas_item;
render_mode blend_mix;
uniform vec4 tint : source_color;
void fragment() {
	float a = texture(TEXTURE, UV).a;
	float n = texture(TEXTURE, UV + vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a * texture(TEXTURE, UV - vec2(TEXTURE_PIXEL_SIZE.x, 0.0)).a
		* texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a * texture(TEXTURE, UV - vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a;
	float rim = step(0.5, a) * (1.0 - step(0.5, n));  // contorno de 1 px del sprite
	COLOR = vec4(mix(tint.rgb, vec3(1.0), rim * 0.5), step(0.5, a) * tint.a * mix(0.35, 0.9, rim) * COLOR.a);
}"""
	var g := Sprite2D.new()
	g.texture = hero.sprite_frames.get_frame_texture(hero.animation, hero.frame)
	g.centered = false
	g.scale = hero.scale
	g.offset = hero.offset
	g.position = hero.position
	g.z_index = hero.z_index - 1
	var m := ShaderMaterial.new()
	m.shader = ghost_shader
	m.set_shader_parameter("tint", col)
	g.material = m
	g.modulate.a = alpha
	add_child(g)
	var tw := create_tween()
	tw.tween_property(g, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	tw.tween_callback(g.queue_free)

func _unhandled_input(event: InputEvent) -> void:
	if dying or reaction_time > 0.0:
		return
	if touch_mode and event is InputEventMouseButton:
		return  # los toques emulan clics del ratón; aquí mandan los botones en pantalla
	if _fishing():  # mientras pescas el clic es del sedal; Esc lo recoge
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			fishing.press()
			return
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
			fishing.cancel()
			return
		if event is InputEventKey and event.physical_keycode in [KEY_E, KEY_R]:
			return  # ni recolectar ni la ultimate mientras pescas
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE:
			_press("dash")
		elif event.physical_keycode == KEY_R:
			_ultimate()
		elif event.physical_keycode == KEY_E:
			_interact()
		elif event.physical_keycode == KEY_F2:
			debug_hitboxes = not debug_hitboxes  # dibuja las hitbox sobre los sprites
		elif event.physical_keycode == KEY_ESCAPE:
			_cancel_aim()
		elif event.physical_keycode == KEY_B:
			cycle_bait()
		elif event.physical_keycode == KEY_G:
			social.open_near()
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
	night_vision_t = maxf(0.0, night_vision_t - delta)
	fish_luck_t = maxf(0.0, fish_luck_t - delta)
	if regen_left > 0.0:  # comida duradera: la vida llega poco a poco
		var h := minf(regen_left, regen_rate * delta)
		regen_left -= h
		regen_acc += h
		if regen_acc >= 1.0:
			hero_hp = mini(hero_max_hp, hero_hp + int(regen_acc))
			regen_acc -= int(regen_acc)
	cooldown = maxf(0.0, cooldown - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	dash_bonus_t = maxf(0.0, dash_bonus_t - delta)
	if not prog.buffs.is_empty():
		if prog.tick_buffs(delta):
			_apply_stats()
		var parts: Array[String] = []
		for f: Dictionary in prog.buffs:
			parts.append("+%d %s  %ds" % [int(f["amount"]), prog.STAT_NAMES[f["stat"]], ceili(f["t"])])
		buff_label.text = "
".join(parts)
	elif buff_label.text != "":
		buff_label.text = ""
	_try_buffer()
	if _fishing():
		fishing.tick(delta)
		_place()
		return
	if gathering:
		_gather_tick(delta)
		_place()
		return
	burn_t = maxf(0.0, burn_t - delta)
	# regeneración tras una pausa sin gastar
	stamina_idle += delta
	mana_idle += delta
	if stamina_idle >= hero_data["stamina_regen_delay"]:
		stamina = minf(hero_data["stamina"], stamina + hero_data["stamina_regen"] * delta)
	if mana_idle >= hero_data["mana_regen_delay"]:
		mana = minf(hero_data["mana"], mana + hero_data["mana_regen"] * (1.0 + prog.skill_sum("regen_pct")) * delta)
	if exhausted and stamina >= 20.0:
		exhausted = false
	if dashing:
		var step_dt := minf(delta, dash_time_cur - dash_t)  # el último paso no se pasa de la distancia
		dash_t += delta
		# el dash frena al final (curva 1.75→0.25 con media 1): recorre lo mismo pero termina en un punto legible; el mega dash va a velocidad constante
		var ease_k := 1.0 if mega_active else 1.5 * (1.0 - clampf(dash_t / dash_time_cur, 0.0, 1.0)) + 0.25
		var step := dash_dir * dash_speed_cur * ease_k * step_dt * (Vector2.ONE if mega_active else Vector2(1, 0.6))
		pos = world.move_collide(pos, pos + step, HERO_R_T)  # atraviesa al dragón pero no estructuras ni agua
		ghost_t += delta
		if not mega_active and ghost_t >= DASH_GHOST_EVERY and dash_t < dash_time_cur * 0.8:
			ghost_t = 0.0  # siluetas de acero: más densas y opacas al arrancar, se apagan cuando el dash frena
			_spawn_ghost(DASH_GHOST_COL, 0.25, lerpf(0.8, 0.3, dash_t / dash_time_cur))
		if mega_active:
			if ghost_t >= 0.035:
				ghost_t = 0.0
				_spawn_ghost()
			for e in targets():  # el mega dash daña (una vez) a todo lo que atraviesa
				if e.alive and not mega_hits.has(e) and preload("res://scripts/hitbox.gd").dist(e, pos - Vector2(0, 40)) < 10.0:
					mega_hits.append(e)
					combat.hit(e, roundi(mega_spec["damage"] * prog.melee_mult()), "heavy", pos, false)
					shake(8.0)
		if dash_t >= dash_time_cur:
			dashing = false
			_spawn_dash_dust(dash_dir)
			if not mega_active:
				dash_bonus_t = DASH_BONUS_TIME  # el siguiente tajo pega más
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
	if attacking:
		recover_t += delta
		var dir_a := _input_dir()
		# un ligero ya conectado se corta caminando (ritmo de combate); el pesado y los hechizos se cumplen enteros
		if dir_a != Vector2.ZERO and struck and current_mode == "light" and current.get("type", "") == "melee" and recover_t > LIGHT_CANCEL_T:
			attacking = false
			recover_t = 0.0
		else:
			_move_while_attacking(dir_a, delta)  # avance lento: no te clava en el sitio, pero conserva el compromiso
			_place()
			return
	var dir := _input_dir()
	var sprint := dir != Vector2.ZERO and (_held([KEY_SHIFT]) or (touch_mode and bool(touch.sprint))) and not exhausted
	if sprint:  # correr gasta estamina; sin ella se camina
		stamina = maxf(0.0, stamina - hero_data["sprint_drain"] * delta)
		stamina_idle = 0.0
		if stamina == 0.0:
			exhausted = true
	if dir != Vector2.ZERO:
		facing = DIRS[posmod(roundi(dir.angle() / (PI / 4.0)), 8)]
	# inercia: acelera hacia la velocidad pedida y frena más seco; el eje Y se acorta por la vista isométrica
	var target: Vector2 = dir.normalized() * (SPRINT_SPEED if sprint else WALK_SPEED) * prog.move_mult()
	move_vel = move_vel.move_toward(target, (ACCEL if dir != Vector2.ZERO else BRAKE) * delta)
	if move_vel.length() < 1.0:
		move_vel = Vector2.ZERO
		hero.play("idle_" + facing)
		_place()
		return
	var step: Vector2 = move_vel * delta * Vector2(1, 0.6)
	var previous_pos := pos
	pos = world.move_collide(pos, pos + step, HERO_R_T)  # el mapa (agua, árboles, rocas, edificios) bloquea
	var traveled := ((pos - previous_pos) / Vector2(1, 0.6)).length()
	if traveled < 0.001:
		move_vel = Vector2.ZERO  # contra una pared no se acumula velocidad
	_push_out(blockers())  # el dragón también bloquea al héroe
	_update_gait(traveled, sprint)
	_place()

func _move_while_attacking(dir: Vector2, delta: float) -> void:  # caminar lento durante un ataque; no cambia hacia dónde mira ni su animación
	var kind := "cast" if current.get("type", "") in ["projectile", "meteor"] else current_mode
	var mult: float = ATTACK_MOVE.get(kind, 0.3)
	var target: Vector2 = dir.normalized() * WALK_SPEED * prog.move_mult() * mult
	move_vel = move_vel.move_toward(target, (ACCEL if dir != Vector2.ZERO else BRAKE) * delta)
	if move_vel.length() >= 1.0:
		pos = world.move_collide(pos, pos + move_vel * delta * Vector2(1, 0.6), HERO_R_T)
		_push_out(blockers())

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
		var sh: Dictionary = clock.shadow() if clock.outdoors else {"dx": 0.0, "len": 1.0, "alpha": 1.0}
		contact_shadow.position = pos * SCALE + Vector2(float(sh["dx"]) * 10.0 * SCALE, 0.0)
		contact_shadow.scale = Vector2(float(sh["len"]), 1.0)
		contact_shadow.modulate.a = float(sh["alpha"])
	if equip_aura:
		equip_aura.position = (pos - Vector2(0, 34)) * SCALE
		contact_shadow.z_index = hero.z_index - 1

# --- creación: estaciones del mundo, recolección y mina (data/crafting.json)
var stations: Array = []     # {station, scene, tile, reach, label}: dónde se usa cada oficio
var station_ui: CanvasLayer
var in_mine := false
var zone_id := ""                # zona escrita a mano en la que estás ("" = ninguna); comparte el mecanismo de la mina
var zones_cfg := {}
var zones_done: Array = []       # zonas cuyo cofre ya abriste
var zone_chest: Node2D
var zone_chest_door: Node2D
var gathering := false       # balanceando el pico, el hacha o las manos sobre un recurso
var gather_t := 0.0
var gather_node: Dictionary = {}
var gather_hit_done := false
const GATHER_TIME := 0.5

func _scene_id() -> String:
	if in_interior:
		return "interior:" + current_interior
	if in_mine:
		return "zone:" + zone_id if zone_id != "" else "mine"
	return "dungeon" if in_dungeon else "overworld"

func _build_world_props() -> void:  # mesa de alquimia y fogata junto al mercader, plantas del valle, entrada de la mina y yunque de Bram
	for pr: Dictionary in crafting.cfg["world_props"]:
		var node := Node2D.new()
		node.set_script(load("res://scripts/station_prop.gd"))
		node.main = self
		node.sprite_key = pr["sprite"]
		node.tile = Vector2(pr["tile"][0], pr["tile"][1])
		if pr.has("light"):
			node.light_col = Color(pr["light"][0], pr["light"][1], pr["light"][2])
		add_child(node)
		var half := Vector2(pr["footprint"][0], pr["footprint"][1])
		world.rects.append(Rect2(node.tile - half, half * 2.0))  # no se atraviesa
		stations.append({"station": pr["station"], "scene": "overworld", "tile": node.tile, "reach": float(pr["reach"]), "label": pr["label"]})
	stations.append({"station": "forge", "scene": "interior:forge", "tile": Vector2(3.1, 4.0), "reach": 2.3, "label": "Forjar en el yunque de Bram"})
	for nd: Dictionary in crafting.cfg["overworld_nodes"]:
		var spec: Dictionary = crafting.cfg["world_sprites"]["herb_bush" if nd["kind"] == "herb" else "berry_bush"]
		world.add_resource(nd["kind"], Vector2(nd["tile"][0], nd["tile"][1]), spec["paths"][0], spec["feet"], 0.0)
	var mine: Dictionary = crafting.cfg["mine"]
	var ent := Node2D.new()
	ent.set_script(load("res://scripts/station_prop.gd"))
	ent.main = self
	ent.sprite_key = "mine_entrance"
	ent.tile = Vector2(mine["entrance_tile"][0], mine["entrance_tile"][1])
	add_child(ent)
	var r: Array = mine["entrance_rect"]
	world.rects.append(Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1]))
	var door := _add_door(Vector2(mine["door_tile"][0], mine["door_tile"][1]), "Entrar a la mina", enter_mine, false)
	door.reach = 1.9

func _near_station() -> Dictionary:
	var here := _scene_id()
	var t := ground_to_tile(pos)
	for s: Dictionary in stations:
		if s["scene"] == here and t.distance_to(s["tile"]) < s["reach"]:
			return s
	return {}

func _near_node() -> Dictionary:  # árbol, roca, veta o planta al alcance del héroe
	if gathering or dying or not world.has_method("node_near"):
		return {}
	return world.node_near(pos)

func _gather(n: Dictionary) -> void:
	if gathering or attacking or dashing or aiming:
		return
	var why: String = crafting.can_gather(n["kind"])
	if why != "":
		say(why, 1.6)
		return
	var dir: Vector2 = n["g"] - pos
	facing = DIRS[posmod(roundi(dir.angle() / (PI / 4.0)), 8)]
	gathering = true
	gather_t = 0.0
	gather_node = n
	gather_hit_done = false
	move_vel = Vector2.ZERO
	var tool: String = crafting.cfg["gather"][n["kind"]]["tool"]
	var key := "%s_%s" % [{"pickaxe": "chop_pick", "axe": "chop_axe"}.get(tool, "pluck"), facing]
	hero.sprite_frames.set_animation_speed(key, 6.0 / GATHER_TIME)
	hero.play(key)

func _gather_tick(delta: float) -> void:
	gather_t += delta
	if not gather_hit_done and gather_t >= GATHER_TIME * 0.62:  # el golpe cae en el fotograma de impacto
		gather_hit_done = true
		_gather_hit()
	if gather_t >= GATHER_TIME:
		gathering = false
		var n := gather_node
		if not n.is_empty() and not n["depleted"] and (Input.is_physical_key_pressed(KEY_E) or (touch_mode and bool(touch.interact_held))) and crafting.can_gather(n["kind"]) == "":
			_gather(n)  # mantener E sigue golpeando

func _gather_hit() -> void:
	var n := gather_node
	var g: Dictionary = crafting.cfg["gather"][n["kind"]]
	var broken: bool = world.hit_node(n, crafting.swing_power(g["tool"]))
	var chips := preload("res://scripts/splatter.gd").new()  # astillas, esquirlas u hojas del color del recurso
	chips.tint = Color(g["chips"])
	chips.dir = (n["g"] - pos).normalized()
	chips.count = 10 if broken else 5
	chips.origin_h = 40.0
	chips.position = n["g"] * SCALE
	chips.z_index = int(n["g"].y) + 2
	add_child(chips)
	combat.play("light")
	shake(2.5 if broken else 1.2)
	if not broken:
		return
	var lines: Array[String] = []
	var drops: Dictionary = crafting.roll_drops(n["kind"])
	for id: String in drops:
		crafting.add(id, int(drops[id]))
		lines.append("+%d %s" % [int(drops[id]), crafting.item_name(id)])
		quest_event("loot", id)
	popup(n["g"], "\n".join(lines))
	quest_event("gather", n["kind"])

# --- barra de objetos: 6 casillas (prog.slots) que se colocan arrastrando desde el inventario; las herramientas nuevas entran solas
const HOTBAR_MAX := 6
const WEAPONS := ["katana_ceniza", "grimorio_ignis"]
var hotbar_row: HBoxContainer
var clock: Node        # clock.gd: hora, día y lluvia
var angler: RefCounted # angler.gd: libro de capturas, acuario, encargos y nasas
var social: CanvasLayer    # social.gd: amistad, regalos y eventos
var farm: Node2D       # farm.gd: huerto
var pending_farm := {}
var lamps: Node2D      # lamps.gd: farolas del pueblo
var traps: Node2D      # traps.gd: nasas y trampas colocadas en el mundo
var bait := ""         # cebo elegido para la caña (tecla B)
var regen_left := 0.0  # vida que aún regenera la comida; regen_rate por segundo
var regen_rate := 0.0
var regen_acc := 0.0
var night_vision_t := 0.0   # segundos de visión nocturna (elixir)
var fish_luck_t := 0.0      # segundos de suerte de pescador (elixir de sirena)
var fishing: Node2D   # fishing.gd: se crea al lanzar la caña por primera vez
var hotbar_size := 72.0
var count_labels := {}   # id -> etiqueta de cantidad

func _hand_item(id: String) -> Dictionary:  # entrada tipo items.json para una herramienta o un consumible
	var kind := "consumable"
	var act := "Usar"
	if prog.equipment.has(id):
		kind = prog.equipment[id]["tool"]["kind"]
		act = "Lanzar la caña (mantén el clic)" if kind == "rod" else "Golpear recurso cercano"
	return {"name": crafting.item_name(id), "icon": crafting.icon(id), "hand": kind, "light": {"name": act}}

var tool_seen := {}    # ranura de herramienta -> última equipada que ya se colocó en la barra
var hotbar_sig := ""

func can_hotbar(id: String) -> bool:  # qué puede ir en la barra: armas base, consumibles y herramientas que tengas
	return WEAPONS.has(id) or crafting.is_consumable(id) or (prog.equipment.has(id) and prog.equipment[id].has("tool") and prog.owned.has(id))

func icon_of(id: String) -> String:
	return items[id]["icon"] if WEAPONS.has(id) else crafting.icon(id)

func name_of(id: String) -> String:
	return items[id]["name"] if WEAPONS.has(id) else crafting.item_name(id)

func hotbar_drop(id: String, to: int) -> bool:  # suelta un objeto en una casilla: si había otro, se intercambian (o vuelve a la mochila)
	if not can_hotbar(id) or to < 0 or to >= HOTBAR_MAX:
		return false
	var from: int = hotbar.find(id)
	var displaced: String = hotbar[to]
	hotbar[to] = id
	if from >= 0 and from != to:
		hotbar[from] = displaced
	if prog.equipment.has(id):  # una herramienta en la barra pasa a ser la equipada
		var kind: String = prog.equipment[id]["slot"]
		prog.equipped[kind] = id
		tool_seen[kind] = id
		_apply_stats()
	_refresh_hotbar(true)
	save_game()
	return true

func hotbar_clear(slot: int) -> void:  # devuelve lo de la casilla a la mochila
	if slot >= 0 and slot < HOTBAR_MAX and hotbar[slot] != "":
		hotbar[slot] = ""
		_refresh_hotbar(true)
		save_game()

func hotbar_add(id: String) -> bool:  # a la primera casilla libre
	var free: int = hotbar.find("")
	return free >= 0 and hotbar_drop(id, free)

func hotbar_remove(id: String) -> void:
	hotbar_clear(hotbar.find(id))

func _sync_tools() -> void:  # una herramienta recién equipada ocupa el sitio de la anterior de su tipo o la primera casilla libre
	for kind: String in ["pickaxe", "axe", "rod"]:
		var e: String = prog.equipped.get(kind, "")
		if e == "" or tool_seen.get(kind, "") == e:
			continue
		tool_seen[kind] = e
		if prog.slots.has(e):
			continue
		var put := -1
		for i in prog.slots.size():
			var o: String = prog.slots[i]
			if o != "" and prog.equipment.has(o) and prog.equipment[o]["slot"] == kind:
				put = i
				break
		if put < 0:
			put = prog.slots.find("")
		if put >= 0:
			prog.slots[put] = e
		else:
			say("La barra está llena: arrastra %s desde el inventario." % crafting.item_name(e), 3.0)

func _refresh_hotbar(force := false) -> void:
	if hotbar_row == null:
		return
	_sync_tools()
	hotbar = prog.slots
	for id: String in hotbar:
		if id != "" and not WEAPONS.has(id):
			items[id] = _hand_item(id)
	var sig := ",".join(hotbar)
	if not force and sig == hotbar_sig:
		return
	hotbar_sig = sig
	for c in hotbar_row.get_children():
		c.queue_free()
	slots.clear()
	count_labels.clear()
	for i in hotbar.size():
		var panel := Panel.new()
		panel.custom_minimum_size = Vector2(hotbar_size, hotbar_size)
		panel.clip_contents = true
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # que los clics sigan llegando al juego
		hotbar_row.add_child(panel)
		if hotbar[i] != "":
			var icon := TextureRect.new()
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # antes del tamaño: si no, el icono de 128 px desborda el cuadro
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture = load(items[hotbar[i]]["icon"])
			icon.position = Vector2(4, 4)
			icon.size = Vector2(hotbar_size - 8, hotbar_size - 8)
			panel.add_child(icon)
		var num := Label.new()
		num.text = str(i + 1)
		num.position = Vector2(6, 2)
		panel.add_child(num)
		if items[hotbar[i]].get("hand", "") == "consumable":
			var cnt := Label.new()
			cnt.position = Vector2(hotbar_size - 30, hotbar_size - 26)
			cnt.add_theme_color_override("font_outline_color", Color.BLACK)
			cnt.add_theme_constant_override("outline_size", 5)
			panel.add_child(cnt)
			count_labels[hotbar[i]] = cnt
		slots.append(panel)
	_update_counts()
	_select(clampi(selected, 0, HOTBAR_MAX - 1))

func _update_counts() -> void:
	for id: String in count_labels:
		var n: int = crafting.count(id)
		count_labels[id].text = "×%d" % n
		slots[hotbar.find(id)].modulate = Color.WHITE if n > 0 else Color(1, 1, 1, 0.45)

func cycle_bait() -> void:  # B: sin cebo -> cada cebo con existencias -> sin cebo
	if _fishing():
		return
	var opts: Array = [""]
	for b: String in angler.cfg["baits"]:
		if crafting.count(b) > 0 or b == bait:
			opts.append(b)
	bait = opts[(opts.find(bait) + 1) % opts.size()]
	say("Cebo: %s" % (crafting.item_name(bait) + " ×%d" % crafting.count(bait) if bait != "" else "ninguno"), 1.5)
	_select(selected)

func _build_farm() -> void:  # el huerto, junto al inicio
	farm = Node2D.new()
	farm.set_script(load("res://scripts/farm.gd"))
	add_child(farm)
	farm.setup(self)
	if not pending_farm.is_empty():
		farm.from_dict(pending_farm)

func _build_lamps() -> void:  # farolas en las puertas de las casas y junto a los comerciantes; solo se encienden de noche
	var pts: Array = []
	for d: Node2D in doors:
		if d.label.begins_with("Entrar:"):
			pts.append(tile_to_ground(d.tile) + Vector2(26, 6))
	for m: Node2D in merchants:
		pts.append(m.pos + Vector2(30, 8))
	lamps = Node2D.new()
	lamps.set_script(load("res://scripts/lamps.gd"))
	lamps.main = self
	lamps.points = pts
	add_child(lamps)

func fishing_node() -> Node2D:  # se crea al usarlo por primera vez
	if fishing == null:
		fishing = preload("res://scripts/fishing.gd").new()
		add_child(fishing)
		fishing.setup(self)
	return fishing

func _fishing() -> bool:
	return fishing != null and fishing.active

func _use_hand(id: String, it: Dictionary) -> bool:  # clic izquierdo con una herramienta o un consumible seleccionado
	if it["hand"] == "empty":
		say("Casilla vacía: arrastra un objeto desde el inventario [I].", 2.0)
		cooldown = 0.4
		return false
	if prog.equipment.has(id):  # la herramienta de la casilla es la que cuenta para recolectar y pescar
		prog.equipped[prog.equipment[id]["slot"]] = id
	if it["hand"] == "rod":
		if not world.has_method("is_water"):
			say("Aquí no hay dónde pescar.", 1.5)
			cooldown = 0.5
			return false
		fishing_node().start(id)
		return true
	if it["hand"] == "consumable":
		var c: Dictionary = crafting.cfg["consumables"][id]
		if crafting.count(id) <= 0:
			say("Se acabó: %s." % it["name"], 1.5)
		elif c.has("place"):
			say(traps.place(id, str(c["place"])), 2.0)
		elif c.has("plant"):
			say(farm.plant(id) if farm else "Aquí no hay huerto.", 2.0)
		elif c.has("water"):
			say(farm.water() if farm else "Aquí no hay huerto.", 1.5)
		elif c.has("heal") and not c.has("buff") and hero_hp >= hero_max_hp:
			say("Ya tienes la vida completa.", 1.5)
		else:
			var drink: bool = id.begins_with("pocion") or id.begins_with("elixir") or id.begins_with("frasco")
			current = {"type": "consume", "id": id, "anim": "drink" if drink else "eat", "fps": 9.0, "strike_frame": 3, "cooldown": 0.5}
			_begin(current, "light")
			return true
		cooldown = 0.5
		return false
	var n := _near_node()
	if n.is_empty():
		say("No hay nada que golpear aquí.", 1.2)
	elif crafting.cfg["gather"][n["kind"]]["tool"] != it["hand"]:
		say("Eso no se golpea con %s." % it["name"], 1.5)
	else:
		_gather(n)
		return gathering
	cooldown = 0.5
	return false

# --- la mina: cueva de minerales fuera del pueblo (mine.gd)
func enter_mine() -> void:
	_transition(_enter_mine)

func _enter_mine() -> void:
	var cfg: Dictionary = crafting.cfg["mine"]
	in_dungeon = true  # fauna, civiles y el dragón se pausan igual que bajo tierra
	in_mine = true
	overworld = {"pos": pos, "C1": C1, "E1": E1, "E2": E2, "tiles": TILES, "world": world, "doors": doors, "dragon_alive": dragon.alive}
	world.visible = false
	for d: Node2D in doors:
		d.visible = false
	doors = []
	dragon.visible = false
	dragon.alive = false
	var n: int = cfg["tiles"]
	var s := n / TILES
	E1 *= s
	E2 *= s
	TILES = n
	C1 = -(E1 + E2) / 2.0
	RenderingServer.set_default_clear_color(Color("#07060a"))
	combat.set_zone(true)
	dungeon_node = Node2D.new()
	dungeon_node.set_script(load("res://scripts/mine.gd"))
	dungeon_node.main = self
	add_child(dungeon_node)
	dungeon_node.setup(cfg)
	world = dungeon_node
	var exit_door := _add_door(Vector2(n / 2.0 + 0.5, 0.9), "Salir de la mina", exit_mine)
	exit_door.reach = 2.0
	pos = tile_to_ground(dungeon_node.spawn_tile())
	cam.position = (pos - Vector2(0, 40)) * SCALE
	floor_hp = 1.0
	floor_dmg = 1.0
	var taken: Array = []
	for id: String in cfg["enemies"]:
		for i in int(cfg["enemies"][id]):
			var t: Vector2 = dungeon_node.free_tile(taken, 8.0)
			taken.append(t)
			spawn_enemy(id, tile_to_ground(t))
	say("La mina: vetas de hierro, carbón y cristal. Cuidado con lo que vive aquí.", 3.0)

func enter_zone(id: String) -> void:
	_transition(func() -> void: _enter_zone(id))

func _build_zone_doors() -> void:  # entradas a las zonas: arcos en el campo, cerca del sitio indicado en data/zones.json
	zones_cfg = _read_json("res://data/zones.json")
	for id: String in zones_cfg:
		var cfg: Dictionary = zones_cfg[id]
		var hint := Vector2(cfg["hint"][0], cfg["hint"][1])
		var spot := hint
		var found := false
		for r in range(0, 16):
			for dx in range(-r, r + 1):
				for dy in range(-r, r + 1):
					if found or maxi(absi(dx), absi(dy)) != r:
						continue
					var t := hint + Vector2(dx, dy)
					if not world.is_water(t) and not world.blocked(t, 1.4):
						spot = t
						found = true
		var d := _add_door(spot, str(cfg["door_label"]), enter_zone.bind(id))
		d.reach = 2.0

func _enter_zone(id: String) -> void:
	var cfg: Dictionary = zones_cfg[id]
	in_dungeon = true  # fauna, civiles y el dragón se pausan; es exterior, así que sigue el reloj y la luz del día
	in_mine = true
	zone_id = id
	overworld = {"pos": pos, "C1": C1, "E1": E1, "E2": E2, "tiles": TILES, "world": world, "doors": doors, "dragon_alive": dragon.alive}
	world.visible = false
	for d: Node2D in doors:
		d.visible = false
	doors = []
	dragon.visible = false
	dragon.alive = false
	var n: int = cfg["tiles"]
	var s := n / TILES
	E1 *= s
	E2 *= s
	TILES = n
	C1 = -(E1 + E2) / 2.0
	RenderingServer.set_default_clear_color(Color(cfg["clear"]))
	combat.set_zone(false)
	dungeon_node = Node2D.new()
	dungeon_node.set_script(load("res://scripts/zone.gd"))
	dungeon_node.main = self
	add_child(dungeon_node)
	dungeon_node.setup(cfg)
	world = dungeon_node
	var exit_door := _add_door(Vector2(cfg["exit"][0], cfg["exit"][1]), "Volver al valle", exit_mine)
	exit_door.reach = 2.2
	pos = tile_to_ground(dungeon_node.spawn_tile())
	cam.position = (pos - Vector2(0, 40)) * SCALE
	for e: Dictionary in cfg["enemies"]:  # monstruos fijos al nivel del héroe -2 (+ el desvío de la zona)
		set_enemy_level(world_level(false) + int(e["off"]))
		spawn_enemy(str(e["id"]), tile_to_ground(Vector2(e["t"][0], e["t"][1])))
	set_enemy_level(0)
	if not zones_done.has(id):
		var ch: Dictionary = cfg["chest"]
		var spot := Vector2(ch["t"][0], ch["t"][1])
		zone_chest = Node2D.new()
		zone_chest.set_script(load("res://scripts/chest.gd"))
		zone_chest.main = self
		zone_chest.tile = spot
		add_child(zone_chest)
		zone_chest_door = _add_door(spot, "Abrir el cofre de la zona", _open_zone_chest, false)
		zone_chest_door.reach = 1.6
	say("%s: %s" % [cfg["name"], cfg["level_note"]], 3.5)

func _open_zone_chest() -> void:
	var ch: Dictionary = zones_cfg[zone_id]["chest"]
	zone_chest.open()
	doors.erase(zone_chest_door)
	zone_chest_door.queue_free()
	zone_chest_door = null
	var coins := randi_range(int(ch["coins"][0]), int(ch["coins"][1]))
	prog.coins += coins
	var lines: Array[String] = ["+%d monedas" % coins]
	for item: String in ch["items"]:
		crafting.add(item, int(ch["items"][item]))
		lines.append("%s ×%d" % [crafting.item_name(item), int(ch["items"][item])])
	zones_done.append(zone_id)
	show_loot(ch["items"].keys())
	say("\n".join(lines), 5.0)
	gain_xp(int(ch["xp"]))
	save_game()

func exit_mine() -> void:
	_transition(_exit_mine)

func _exit_mine() -> void:
	in_dungeon = false
	in_mine = false
	zone_id = ""
	for c: Node in [zone_chest, zone_chest_door]:
		if is_instance_valid(c):
			doors.erase(c)
			c.queue_free()
	zone_chest = null
	zone_chest_door = null
	for e in enemies.duplicate():
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
