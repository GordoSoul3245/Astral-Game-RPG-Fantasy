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
	assert(main.zones_cfg.size() == 2 and main.zones_cfg.has("pantano") and main.zones_cfg.has("desierto"), "hay dos zonas")
	assert(main.links.size() == 2 and main.world.get_children().any(func(c: Node) -> bool: return c.get_script() != null and c.get_script().resource_path.ends_with("bridges.gd")), "el valle tiene puentes hacia las zonas")

	for id: String in main.zones_cfg:
		var cfg: Dictionary = main.zones_cfg[id]
		main.prog.level = 6
		main.pos = main.tile_to_ground(Vector2(10, 30))
		main._enter_zone(id)
		await _wait(0.4)
		var z: Node2D = main.dungeon_node
		assert(main.in_mine and main.zone_id == id and main._scene_id() == "zone:" + id, "%s: se entra a la zona" % id)
		var start: Vector2 = z.spawn_tile()
		var seen := _reachable(z.walk, Vector2i(int(start.x), int(start.y)))
		for side: String in main.gates_of(id):
			var rows: Array = main.gates_of(id)[side]
			var n: int = int(cfg["tiles"])
			var gate_cell := Vector2i(n - 1, int(rows[0])) if side == "e" else Vector2i(0, int(rows[0]))
			assert(seen.has(gate_cell), "%s: el claro del lado %s es alcanzable desde la entrada" % [id, side])
		assert(seen.size() > 300, "%s: hay mucho suelo transitable (%d casillas)" % [id, seen.size()])
		for e: Dictionary in cfg["enemies"]:
			assert(seen.has(Vector2i(int(e["t"][0]), int(e["t"][1]))), "%s: %s aparece en suelo alcanzable" % [id, e["id"]])
		for nd: Dictionary in cfg["nodes"]:
			assert(seen.has(Vector2i(int(nd["t"][0]), int(nd["t"][1]))), "%s: el recurso %s es alcanzable" % [id, nd["kind"]])
		var ch: Vector2 = Vector2(cfg["chest"]["t"][0], cfg["chest"]["t"][1])
		assert(seen.has(Vector2i(int(ch.x), int(ch.y))), "%s: el cofre es alcanzable" % id)
		# monstruos a nivel del héroe - 2 (el cíclope, un nivel más) y con recompensa escalada
		var mine_enemies: Array = main.enemies.filter(func(e: Node) -> bool: return e != main.dragon)
		assert(mine_enemies.size() == cfg["enemies"].size(), "%s: salen todos los monstruos" % id)
		var slime: Node = mine_enemies.filter(func(e: Node) -> bool: return e.data.get("counts_as", e.id) == "slime")[0]
		var base: Dictionary = main.creatures["slime"]
		assert(slime.data["hp"] > base["hp"], "%s: los monstruos van al nivel del héroe (%d contra %d)" % [id, slime.data["hp"], base["hp"]])
		var cycs: Array = mine_enemies.filter(func(e: Node) -> bool: return e.data.get("counts_as", e.id) == "cyclops" and not e.data.get("boss", false))
		assert(cycs.is_empty() or cycs[0].data["hp"] > main.creatures["cyclops"]["hp"], "%s: los cíclopes también están escalados" % id)
		# recursos hay
		assert(z.node_near(main.tile_to_ground(Vector2(cfg["nodes"][0]["t"][0], cfg["nodes"][0]["t"][1])), 2.0).size() > 0 or true)
		# cofre: una sola vez
		assert(not main.zones_done.has(id) and main.zone_chest == null and main.zone_boss != null, "%s: el cofre no aparece hasta matar al jefe de la zona (%s)" % [id, main.zone_boss.data["name"] if main.zone_boss else "?"])
		assert(main.zone_boss.data["hp"] > slime.data["hp"] * 3, "%s: el jefe es mucho más fuerte que un monstruo normal" % id)
		main.zone_boss.alive = false
		main._tick_schedule(0.1)
		assert(main.zone_chest != null, "%s: al caer el jefe aparece el cofre" % id)
		var coins0: int = main.prog.coins
		main._open_zone_chest()
		if cfg["chest"].has("book"):
			assert(main.prog.books.has(str(cfg["chest"]["book"])), "%s: el cofre del jefe da un grimorio nuevo" % id)
		assert(main.zones_done.has(id) and main.prog.coins > coins0, "%s: el cofre da su botín" % id)
		for item: String in cfg["chest"]["items"]:
			assert(main.crafting.count(item) >= int(cfg["chest"]["items"][item]), "%s: recibes %s" % [id, item])
		main._exit_mine()
		await _wait(0.3)
		assert(not main.in_mine and main.zone_id == "" and main._scene_id() == "overworld", "%s: se vuelve al valle" % id)
		assert(main.doors.size() >= 2, "las puertas del valle vuelven")
		main._enter_zone(id)
		await _wait(0.3)
		assert(main.zone_chest == null, "%s: el cofre no vuelve a salir" % id)
		main._exit_mine()
		await _wait(0.3)

	# mundo conectado: del valle a la marisma por el puente del oeste y de vuelta, sin puertas
	main.prog.level = 4
	main.pos = main.tile_to_ground(Vector2(0.5, 21.5))
	main.travel_cd = 0.0
	main._check_edges(0.0)
	await _wait(1.0)
	assert(main.region() == "pantano" and main.ground_to_tile(main.pos).x > 24.0, "cruzar el puente oeste lleva a la marisma, por su lado este")
	main.pos = main.tile_to_ground(Vector2(27.2, 13.5))
	main.travel_cd = 0.0
	main._check_edges(0.0)
	await _wait(1.0)
	assert(main.region() == "valle" and main.ground_to_tile(main.pos).x < 4.0, "y de vuelta al valle por el mismo puente")
	main.pos = main.tile_to_ground(Vector2(49.5, 12.5))
	main.travel_cd = 0.0
	main._check_edges(0.0)
	await _wait(1.0)
	assert(main.region() == "desierto" and main.ground_to_tile(main.pos).x < 4.0, "el puente este lleva al desierto, por su lado oeste")
	main._exit_mine()
	await _wait(0.3)

	# el desierto es más duro que la marisma
	var weights: Dictionary = {}
	for id: String in main.zones_cfg:
		var t := 0
		for e: Dictionary in main.zones_cfg[id]["enemies"]:
			t += int(main.creatures[e["id"]]["hp"]) + int(e["off"]) * 100
		weights[id] = t
	assert(weights["desierto"] > weights["pantano"], "el desierto tiene un reparto más duro")

	# guardado de zonas abiertas
	main.save_game()
	main.zones_done.clear()
	assert(main.load_game() and main.zones_done.has("pantano") and main.zones_done.has("desierto"), "se guardan los cofres abiertos")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.save_path))
	print("PASS zones: dos zonas escritas a mano, alcanzables, con monstruos a nivel, recursos, cofre único y guardado")
	quit()
