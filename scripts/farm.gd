extends Node2D
# Huerto del pueblo (data/farming.json): 12 parcelas de tierra cerca del inicio. Se plantan semillas desde la barra de objetos,
# se riegan con la regadera (la lluvia también riega) y crecen con las horas de juego (clock.total); el hongo luminoso solo de noche.
# Las cosechas son materiales normales (baya roja, hierba vital, hongo luminoso) para cocina y alquimia.

var main: Node
var cfg: Dictionary = {}
var plots: Array = []     # {tile: Vector2, seed: String, growth: float (horas), wet: float (horas de riego que quedan)}
var last_total := 0.0

func setup(m: Node) -> void:
	main = m
	cfg = main._read_json("res://data/farming.json")
	z_index = -3500  # a ras de suelo: nunca tapa al héroe ni a los vecinos
	last_total = main.clock.total
	_locate()

func _locate() -> void:  # busca cerca del inicio un hueco libre de tierra firme para la cuadrícula de parcelas
	var g: Dictionary = cfg["plots"]
	var sp: float = float(g["spacing"])
	var cols := int(g["cols"])
	var rows := int(g["rows"])
	var s: Vector2 = main.ground_to_tile(main.start_pos)
	var avoid: Array[Vector2] = []  # puestos, mesas, fogata y puertas: el huerto no debe estorbar el paso hacia ellos
	for st: Dictionary in main.stations:
		avoid.append(st["tile"])
	for m: Node2D in main.merchants:
		avoid.append(main.ground_to_tile(m.pos))
	for dr: Node2D in main.doors:
		avoid.append(dr.tile)
	var best := Vector2(-1, -1)
	var best_d := 1e9
	for dx in range(-24, 25):
		for dy in range(-24, 25):
			var o := Vector2(floorf(s.x) + dx, floorf(s.y) + dy)
			var d := o.distance_to(s)
			if d < float(g.get("min_dist", 9.0)) or d >= best_d:
				continue
			var ok := true
			var centre := o + Vector2(float(cols) * sp, float(rows) * sp) * 0.5
			for a: Vector2 in avoid:
				if a.distance_to(centre) < 9.0:
					ok = false
			if not ok:
				continue
			for c in cols:
				for r in rows:
					var t := o + Vector2(float(c) * sp, float(r) * sp) + Vector2(0.5, 0.5)
					if main.world.is_water(t) or main.world.blocked(t, 1.2):
						ok = false
			if ok:
				best = o
				best_d = d
	if best.x < 0:
		return
	for c in cols:
		for r in rows:
			plots.append({"tile": best + Vector2(float(c) * sp, float(r) * sp) + Vector2(0.5, 0.5), "seed": "", "growth": 0.0, "wet": 0.0})

func _outside() -> bool:
	return not (main.in_dungeon or main.in_interior)

# --- tiempo
func night_hours(dt: float) -> float:  # horas de noche dentro de las últimas dt horas
	var n := 0.0
	var step := 0.25
	var t := dt
	while t > 0.0:
		var h := fposmod(main.clock.hour - t + step * 0.5, 24.0)
		if h < 6.0 or h >= 20.0:
			n += minf(step, t)
		t -= step
	return n

func advance(dt: float) -> void:  # dt en horas de juego
	if dt <= 0.0:
		return
	for p: Dictionary in plots:
		if p["seed"] == "":
			continue
		var s: Dictionary = cfg["seeds"][p["seed"]]
		var wet: float = dt if main.clock.rain else minf(dt, float(p["wet"]))
		p["wet"] = float(cfg["water_hours"]) if main.clock.rain else maxf(0.0, float(p["wet"]) - dt)
		var grow := wet
		if s.get("night", false):
			grow = wet * night_hours(dt) / dt
		p["growth"] = minf(float(s["hours"]), float(p["growth"]) + grow)

func _process(_delta: float) -> void:
	var dt: float = main.clock.total - last_total
	last_total = main.clock.total
	advance(dt)
	visible = _outside()
	if visible:
		queue_redraw()

# --- acciones del jugador
func _nearest(reach: float, pred: Callable) -> int:
	var here: Vector2 = main.ground_to_tile(main.pos)
	var best := -1
	var best_d := reach
	for i in plots.size():
		var d := here.distance_to(plots[i]["tile"])
		if d < best_d and pred.call(plots[i]):
			best = i
			best_d = d
	return best

func plant(seed_id: String) -> String:
	if not _outside():
		return "El huerto está en el exterior."
	var i := _nearest(float(cfg["reach"]), func(p: Dictionary) -> bool: return p["seed"] == "")
	if i < 0:
		return "Acércate a una parcela vacía del huerto."
	main.crafting.take(seed_id, 1)
	plots[i]["seed"] = seed_id
	plots[i]["growth"] = 0.0
	plots[i]["wet"] = 0.0
	main.combat.play_at("hook", main.pos)
	return "Plantado: %s. Riégalo con la regadera." % main.crafting.item_name(cfg["seeds"][seed_id]["crop"])

func water() -> String:  # riega las parcelas plantadas a su alcance
	if not _outside():
		return "El huerto está en el exterior."
	var here: Vector2 = main.ground_to_tile(main.pos)
	var n := 0
	for p: Dictionary in plots:
		if p["seed"] != "" and here.distance_to(p["tile"]) <= float(cfg["reach"]):
			p["wet"] = float(cfg["water_hours"])
			n += 1
	if n == 0:
		return "No hay nada que regar aquí."
	main.combat.play_at("splash", main.pos)
	return "Riegas %d parcela%s." % [n, "s" if n > 1 else ""]

func ripe(p: Dictionary) -> bool:
	return p["seed"] != "" and float(p["growth"]) >= float(cfg["seeds"][p["seed"]]["hours"])

func try_harvest() -> bool:  # E junto a una parcela madura
	if not _outside():
		return false
	var i := _nearest(float(cfg["reach"]), func(p: Dictionary) -> bool: return ripe(p))
	if i < 0:
		return false
	var s: Dictionary = cfg["seeds"][plots[i]["seed"]]
	var n: int = main.crafting.rng.randi_range(int(s["yield"][0]), int(s["yield"][1]))
	var crop: String = s["crop"]
	main.crafting.add(crop, n)
	var msg := "%s ×%d" % [main.crafting.item_name(crop), n]
	if main.crafting.rng.randf() < float(cfg["seed_back"]):  # a veces queda una semilla para volver a plantar
		main.crafting.add(plots[i]["seed"], 1)
		msg += "  +1 semilla"
	plots[i]["seed"] = ""
	plots[i]["growth"] = 0.0
	main.quest_event("loot", crop)
	main.show_loot([crop])
	main.popup(main.pos, msg, Color(0.7, 1.0, 0.6))
	main.combat.play_at("catch", main.pos)
	return true

func near_text() -> String:  # aviso al acercarte a una parcela
	if not _outside():
		return ""
	var i := _nearest(float(cfg["reach"]), func(p: Dictionary) -> bool: return true)
	if i < 0:
		return ""
	var p: Dictionary = plots[i]
	if p["seed"] == "":
		return "Parcela libre: elige una semilla en la barra y haz clic"
	var s: Dictionary = cfg["seeds"][p["seed"]]
	var name: String = main.crafting.item_name(s["crop"])
	if ripe(p):
		return "[E] Cosechar: %s" % name
	var pct := int(float(p["growth"]) / float(s["hours"]) * 100.0)
	var state := "regada" if (float(p["wet"]) > 0.0 or main.clock.rain) else "seca: usa la regadera"
	if s.get("night", false) and not main.clock.is_night():
		state += "; solo crece de noche"
	return "%s %d %%  ·  %s" % [name, pct, state]

# --- guardado
func to_dict() -> Dictionary:
	var out: Array = []
	for p: Dictionary in plots:
		out.append({"seed": p["seed"], "growth": p["growth"], "wet": p["wet"]})
	return {"plots": out}

func from_dict(d: Dictionary) -> void:  # validado: datos de disco
	last_total = main.clock.total
	if not d.get("plots") is Array:
		return
	var src: Array = d["plots"]
	for i in mini(src.size(), plots.size()):
		var e: Variant = src[i]
		if e is Dictionary and cfg["seeds"].has(str(e.get("seed", ""))):
			plots[i]["seed"] = str(e["seed"])
			plots[i]["growth"] = clampf(float(e.get("growth", 0.0)), 0.0, float(cfg["seeds"][str(e["seed"])]["hours"]))
			plots[i]["wet"] = clampf(float(e.get("wet", 0.0)), 0.0, float(cfg["water_hours"]))
		else:
			plots[i]["seed"] = ""
			plots[i]["growth"] = 0.0
			plots[i]["wet"] = 0.0

# --- dibujo: tierra labrada y la planta según su fase
func _quad(c: Vector2, half: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k: Vector2 in [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]:
		pts.append(main.tile_to_ground(c + k) * main.SCALE)
	return pts

func _draw() -> void:
	if main == null or not _outside():
		return
	var sc: float = main.SCALE
	for p: Dictionary in plots:
		var wet: bool = float(p["wet"]) > 0.0 or main.clock.rain
		draw_colored_polygon(_quad(p["tile"], 0.46), Color(0.24, 0.15, 0.09) if wet else Color(0.42, 0.29, 0.17))
		var q := _quad(p["tile"], 0.46)
		q.append(q[0])
		draw_polyline(q, Color(0.16, 0.1, 0.06), 2.0)
		if p["seed"] == "":
			continue
		var s: Dictionary = cfg["seeds"][p["seed"]]
		var g: Vector2 = main.tile_to_ground(p["tile"]) * sc
		var stage := 3 if ripe(p) else mini(2, int(float(p["growth"]) / float(s["hours"]) * 3.0))
		var tex: Texture2D = _tex(str(s["sprite"]), stage)
		var size := Vector2(44, 44) * sc
		draw_texture_rect(tex, Rect2(g - Vector2(size.x * 0.5, size.y * 0.78), size), false)
		if stage == 3:  # madura: destello que sube y baja
			draw_circle(g + Vector2(0, -40 + sin(Time.get_ticks_msec() * 0.006) * 2.0) * sc, 2.5 * sc, Color(1.0, 0.9, 0.3))

var tex_cache := {}

func _tex(crop: String, stage: int) -> Texture2D:
	var key := "%s_%d" % [crop, stage]
	if not tex_cache.has(key):
		tex_cache[key] = load("res://art/items/cultivo_%s.png" % key)
	return tex_cache[key]
