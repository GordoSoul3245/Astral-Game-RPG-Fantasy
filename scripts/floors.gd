extends Node
# Dungeon infinita: cada piso se genera (dungeon_gen.gd), sube de nivel y de recompensa, y cada `boss_every` pisos hay un jefe.
# Los monstruos empiezan por debajo del nivel del héroe y se acercan a él piso a piso; el jefe va a su nivel (data/dungeon.json).
# La puerta de bajada se abre al matar a todos y aparece un cofre. El punto de reanudación es el piso siguiente a cada jefe.

const Gen := preload("res://scripts/dungeon_gen.gd")

var main: Node
var cfg := {}
var floor_no := 1
var cleared := false
var is_boss := false
var title := ""
var layout := {}
var next_door: Node2D
var chest: Node2D
var chest_door: Node2D
var label: Label
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	cfg = main._read_json("res://data/dungeon.json")
	rng.randomize()
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.offset_top = 12.0
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	layer.add_child(label)

func every() -> int:
	return int(cfg["boss_every"])

func is_boss_floor(n: int) -> bool:
	return n % every() == 0

func boss_def(n: int) -> Dictionary:
	var b: Array = cfg["bosses"]
	return b[(n / every() - 1) % b.size()]

# Nivel de los monstruos del piso n: por debajo del héroe al empezar cada tramo y casi igual en el jefe; cada tramo sube un poco.
func level_for(n: int, mini := false) -> int:
	var k := every()
	var lv: float = float(main.prog.level) + float((n - 1) % k - (k - 1)) * float(cfg["level"]["step"]) + float((n - 1) / k) * float(cfg["level"]["cycle_gain"])
	return maxi(1, roundi(lv) + (int(cfg["level"]["mini_bonus"]) if mini else 0))

# Qué monstruos hay en el piso n: lista de {id, level, extra}
func composition(n: int) -> Array:
	var out: Array = []
	var e: Dictionary = cfg["enemies"]
	var lv := level_for(n)
	if is_boss_floor(n):
		var def := boss_def(n)
		out.append({"id": def["id"], "level": lv, "extra": def})
		var tier := n / every() - 1
		for id: String in def["escort"]:
			var cnt: int = int(def["escort"][id]) + (tier / 2 if id != "cyclops" else tier / 3)
			for i in mini(cnt, 8):
				out.append({"id": id, "level": level_for(n, true) if id == "cyclops" else lv, "extra": {}})
		return out
	var budget := mini(int(e["base"]) + int(float(n - 1) * float(e["per_floor"])), int(e["max"]))
	var minis := 0
	if n >= int(e["mini_from"]):
		minis = mini(1 + (n - int(e["mini_from"])) / int(e["mini_every"]), int(e["mini_max"]))
	var rest := budget - minis
	var archers := 0
	if n >= int(e["archer_from"]):
		archers = int(float(rest) * minf(0.25 + 0.03 * float(n), 0.5))
	for i in minis:
		out.append({"id": "cyclops", "level": level_for(n, true), "extra": {}})
	for i in archers:
		out.append({"id": "skeleton_archer", "level": lv, "extra": {}})
	for i in rest - archers:
		out.append({"id": "slime", "level": lv, "extra": {}})
	return out

func reward_mult(n: int) -> float:  # lo que se multiplica la recompensa del cofre
	return 1.0 + float(cfg["per_floor"]["chest"]) * float(n - 1)

func start(n: int) -> void:
	floor_no = n
	if n % every() == 1:  # cada tramo acaba en un jefe: el piso siguiente es el nuevo punto de reanudación
		main.dungeon_floor = n
	cleared = false
	for e in main.enemies.duplicate():
		if e != main.dragon:
			main.enemies.erase(e)
			e.queue_free()
	for node in [next_door, chest_door]:
		if is_instance_valid(node):
			main.doors.erase(node)
			node.queue_free()
	if is_instance_valid(chest):
		chest.queue_free()
	next_door = null
	chest_door = null
	chest = null
	is_boss = is_boss_floor(n)
	layout = Gen.generate(n, rng, is_boss, str(cfg.get("layout", "open")) == "rooms")
	main.dungeon_node.setup({"tiles": Gen.N, "walk": layout["walk"]})
	title = "Piso %d" % n if not is_boss else "Piso %d · JEFE · %s" % [n, boss_def(n)["title"]]
	var spawn: Vector2 = main.ground_to_tile(main._dungeon_spawn())
	var placed: Array[Vector2] = []
	var comp := composition(n)
	for m: Dictionary in comp:
		var t: Vector2 = layout["boss_spot"] if (is_boss and m["extra"].has("id")) else _free_tile(placed, spawn)
		placed.append(t)
		main.set_enemy_level(int(m["level"]), m["extra"], floor_no)
		main.spawn_enemy(m["id"], main.tile_to_ground(t))
	main.set_enemy_level(0)
	next_door = main._add_door(Vector2(12.5, 24.75), "Bajar al piso %d" % (n + 1), next_floor)
	next_door.locked = true
	main.say(title, 2.5)

func _free_tile(placed: Array[Vector2], spawn: Vector2) -> Vector2:  # casilla de sala lejos de la entrada y de otros monstruos
	var spots: Array = layout["spots"].duplicate()
	spots.shuffle()
	for gap in [3.0, 2.0, 1.2, 0.0]:
		for t: Vector2 in spots:
			if t.distance_to(spawn) < 6.0 and gap > 0.0:
				continue
			if placed.all(func(p: Vector2) -> bool: return t.distance_to(p) >= gap):
				return t
	return Vector2(12.5, 12.5)

func _process(_delta: float) -> void:
	if cleared:
		return
	var left := 0
	for e in main.enemies:
		if e != main.dragon and e.alive:
			left += 1
	label.text = "%s  ·  Enemigos: %d" % [title, left]
	if next_door:
		next_door.lock_text = "Derrota a todos los enemigos (%d)" % left
	if left == 0:
		_clear()

func _clear() -> void:
	cleared = true
	label.text = "%s  ·  ¡Completo!" % title
	if next_door:
		next_door.locked = false
	var spot: Vector2 = layout["chest_spot"]
	chest = Node2D.new()
	chest.set_script(load("res://scripts/chest.gd"))
	chest.main = main
	chest.tile = spot
	main.add_child(chest)
	chest_door = main._add_door(spot, "Abrir cofre", open_chest, false)
	chest_door.reach = 1.6
	main.say("¡Piso completo! Abre el cofre" + (" (el siguiente piso será tu punto de reanudación)" if is_boss else ""), 3.0)
	main.quest_event("floor", str(floor_no))

func next_floor() -> void:
	main._transition(func() -> void:
		start(floor_no + 1)
		main.pos = main._dungeon_spawn()
		main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE)

func open_chest() -> void:
	var c: Dictionary = cfg["chest"]
	var k := reward_mult(floor_no) * (float(c["boss_mult"]) if is_boss else 1.0)
	chest.open()
	main.doors.erase(chest_door)
	chest_door.queue_free()
	chest_door = null
	var coins := roundi(float(rng.randi_range(int(c["coins"][0]), int(c["coins"][1]))) * k * main.REWARD_COINS)
	var chest_xp := roundi(float(c["xp"]) * k * main.REWARD_XP)
	main.prog.coins += coins
	var lines: Array[String] = ["+%d monedas" % coins, "+%d XP" % chest_xp]
	var pool: Array = c["pools"][mini(c["pools"].size() - 1, (floor_no - 1) / 3 if not is_boss else floor_no / every())]
	var fresh: Array = pool.filter(func(i: String) -> bool: return not main.prog.owned.has(i))
	var owned: Array = pool.filter(func(i: String) -> bool: return main.prog.owned.has(i))
	fresh.shuffle()
	owned.shuffle()
	var n_items := 2 if is_boss else 1
	var got: Array = (fresh + owned).slice(0, n_items)
	for id: String in got:
		if main.prog.owned.has(id):  # ya lo tienes: se cambia por monedas
			var extra := roundi(40.0 * k)
			main.prog.coins += extra
			lines.append("%s (repetido): +%d monedas" % [main.crafting.item_name(id), extra])
		else:
			lines.append(main.give_item(id))
	main.show_loot(got)
	var mats: Array = c["materials"]  # materiales para crafteo: más cuanto más profundo
	var total := 0.0
	for m: Dictionary in mats:
		total += float(m["w"])
	for i in mini(1 + floor_no / 2 + (2 if is_boss else 0), 8):
		var pick := rng.randf() * total
		for m: Dictionary in mats:
			pick -= float(m["w"])
			if pick <= 0.0:
				main.crafting.add(str(m["id"]), 1)
				break
	lines.append("+ materiales de crafteo")
	main.gain_xp(chest_xp)
	if is_boss:  # reliquia del jefe: puntos de estadística
		main.prog.points += 2
		main.prog.skill_points += 1
		lines.append("+2 puntos de estadística y 1 de habilidad")
	main.say("\n".join(lines), 6.0)
	main.save_game()
