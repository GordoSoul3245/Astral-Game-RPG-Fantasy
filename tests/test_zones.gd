extends SceneTree
# Zonas escritas a mano (Marisma Sombría y Desierto de Ceniza): todo lo colocado está sobre suelo alcanzable desde la entrada,
# entrar y salir por las puertas del valle, monstruos fijos a nivel del héroe, recursos, cofre de una sola vez y guardado.

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func _wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout

func _reachable(walk: Array, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := c + d
			if q.x >= 0 and q.y >= 0 and q.x < walk.size() and q.y < str(walk[0]).length() and not seen.has(q) and str(walk[q.x])[q.y] == "1":
				seen[q] = true
				queue.append(q)
	return seen

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	main.save_path = "user://test_zones_save.json"
	main.testing = true
	await _wait(0.5)
	assert(main.frames.size() == 2 and main.links.size() == 1)
	var pueblo: Dictionary = main._read_json("res://data/map.json")
	assert(pueblo.objects.filter(func(o): return o.sprite == "house").size() == 5)
	for y in range(38, 50):
		assert(pueblo.layout[y].count("=") >= 4)
		for x in range(50):
			if pueblo.layout[y][x] != "=":
				continue
			assert(not main.world.blocked(Vector2(x + 0.5, y + 0.5), 0.25))
	# Bosque del Fogón: se llega a la fogata y al lago desde el inicio, el viejo está y se le puede hablar
	main._enter_zone("bosque")
	await _wait(0.4)
	var b: Node2D = main.dungeon_node
	var bs: Vector2 = b.spawn_tile()
	var bseen := _reachable(b.walk, Vector2i(int(bs.x), int(bs.y)))
	var camp: Dictionary = main.zones_cfg["bosque"]["camp"]
	assert(bseen.has(Vector2i(int(camp["fire"][0]) + 1, int(camp["fire"][1]) + 1)), "bosque: la fogata se alcanza desde el inicio")
	assert(bseen.has(Vector2i(19, 9)), "bosque: se llega a la orilla del lago")
	assert(b.water.size() > 30 and b.paths.size() > 100, "bosque: hay lago y camino")
	assert(main.doors.any(func(d: Node) -> bool: return d.label == "Hablar con el viejo"), "bosque: el viejo de la fogata se puede hablar")
	main.pos = main.tile_to_ground(Vector2(28.5, -0.3))
	main.travel_cd = 0.0
	main._check_edges(0.0)
	await _wait(1.0)
	assert(main.region() == "valle", "bosque: el camino del norte lleva al valle (el pueblo)")

	assert(main.quests.status == "none", "llegar al pueblo no completa el encargo de la mazmorra")
	main.pos = main.tile_to_ground(Vector2(23.5, 50.2))
	main._check_edges(0.0)
	assert(main.region() == "bosque")
	# Cruce a pie por el pasto a ambos lados del camino, con el radio real del héroe.
	for band: Vector2i in [Vector2i(8, 24), Vector2i(33, 41)]:
		var crossed := false
		for x in range(band.x, band.y):
			var inside: Vector2 = main.tile_to_ground(Vector2(x + 0.5, 0.65))
			var across: Vector2 = main.tile_to_ground(Vector2(x + 0.5, -0.65))
			var valley_tile: Vector2 = main._tile_in(main.frames[main.valley_world], across)
			if b.blocked(main.ground_to_tile(inside), main.HERO_R_T) or main.valley_world.blocked(valley_tile, main.HERO_R_T):
				continue
			main.pos = b.move_collide(inside, across, main.HERO_R_T)
			main._check_edges(0.0)
			assert(main.region() == "valle")
			main.pos = main.world.move_collide(main.pos, inside, main.HERO_R_T)
			main._check_edges(0.0)
			assert(main.region() == "bosque")
			crossed = true
			break
		assert(crossed, "Debe haber paso fuera del camino en cada lado")
	print("PASS: bosque, pueblo de cinco casas, camino libre de ida y vuelta y primera misión")
	quit()
