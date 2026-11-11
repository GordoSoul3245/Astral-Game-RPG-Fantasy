extends SceneTree
# Pueblo: fauna golpeable, transparencia de estructuras, misiones, mercader, guardado/carga y reaparición.

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.dragon.set_physics_process(false)
	main.save_path = "user://test_save.json"
	await process_frame
	var spr: Dictionary = main._read_json("res://data/map.json")["sprites"]
	assert(spr.has("stall"), "el mapa incluye el puesto")

	# --- la fauna se puede golpear, da botín y reaparece
	var c: Node = main.fauna[0]
	for f in main.fauna + main.predators + main.villagers:
		f.set_physics_process(false)
	assert(main.targets().has(c), "el conejo es un blanco")
	var xp0: int = main.prog.xp
	main.combat.hit(c, 99, "light", c.pos + Vector2(-10, 0))
	assert(not c.alive and main.prog.xp == xp0 + roundi(3 * main.REWARD_XP), "el conejo muere y da XP")
	assert(not main.targets().has(c), "muerto: ya no es blanco")
	c._physics_process(c.dead_t + 0.1)
	assert(c.alive and c.hp == c.data["hp"] and c.state == "hidden", "reaparece escondido")
	var fox: Node = main.predators[0]
	fox.state = "rest"
	main.combat.hit(fox, 1, "light", fox.pos + Vector2(10, 0), false)
	assert(fox.alive and fox.state == "warn", "al golpear al zorro, se defiende")
	main.combat.hit(fox, 999, "heavy", fox.pos + Vector2(10, 0), false)
	assert(not fox.alive and not fox.dangerous())

	# --- estructuras translúcidas cuando tapan al héroe
	var w: Node = main.world
	assert(w.occluders.size() > 100, "árboles y edificios registrados")
	var tree: Sprite2D = null
	for s: Sprite2D in w.occluders:  # un sprite que tape: delante (z mayor) y con píxel opaco sobre el héroe
		main.pos = Vector2(s.position.x / main.SCALE + s.texture.get_width() * 0.5, s.z_index - 6.0)
		if w.covers_hero(s):
			tree = s
			break
	assert(tree != null, "hay una estructura que tapa al héroe")
	for i in 20:
		w._process(0.1)
	assert(tree.modulate.a < 0.4, "la estructura se vuelve translúcida")
	main.pos = main.start_pos + Vector2(900, 900)
	for i in 20:
		w._process(0.1)
	assert(tree.modulate.a > 0.95, "al apartarte vuelve a ser opaca")
	main.pos = main.start_pos

	# --- misiones: aceptar, avanzar, entregar, siguiente
	var q: RefCounted = main.quests
	assert(q.marker() == "!" and q.tracker() == "")
	var t: String = q.talk(main)
	assert(q.status == "active" and "dragon" == q.current()["id"] and t.find("Nueva misión") >= 0)
	assert(q.talk(main).find("(0/1)") >= 0, "recordatorio de progreso")
	main.quest_event("kill", "slime")  # otro objetivo: no cuenta
	assert(q.status == "active")
	main.quest_event("kill", "dragon")
	assert(q.status == "ready" and q.marker() == "?")
	var coins0: int = main.prog.coins
	q.talk(main)
	assert(main.prog.coins == coins0 + 40 and q.idx == 1 and q.status == "none", "recompensa y siguiente misión")
	q.talk(main)
	main.quest_event("kill", "fox")
	assert(q.status == "ready")

	# --- Tomás vende (pociones y equipo) y Bram compra materiales
	var roles: Array = main.merchants.map(func(x: Node) -> String: return x.role)
	assert(main.merchants.size() == 2 and roles.has("merchant") and roles.has("smith"), "dos comerciantes: %s" % [roles])
	var m: Node = main.merchants[roles.find("merchant")]
	main.pos = m.pos + Vector2(1400, 0)
	assert(main._near_merchant() == null, "lejos no vende")
	main.pos = m.pos + Vector2(60, 0)
	assert(main._near_merchant() == m, "cerca puede comprarle")
	var shop: CanvasLayer = main.shop
	main.prog.coins = 0
	var p0: int = main.prog.potions
	assert(shop.buy("pocion_vida").find("Te faltan") >= 0 and main.prog.potions == p0, "sin monedas no compra")
	main.prog.coins = 500
	shop.buy("pocion_vida")
	assert(main.prog.potions == p0 + 1 and main.prog.coins == 485)
	assert(shop.buy("armadura_cuero").find("Armadura de cuero") >= 0 and main.prog.owned.has("armadura_cuero") and main.prog.coins == 425, "compra equipo")
	assert(shop.buy("armadura_cuero").find("Ya tienes") >= 0 and main.prog.coins == 425, "no se repite")
	assert(shop.buy("katana_tormenta").find("no está en venta") >= 0, "lo que no vende, no se compra")
	assert(not shop.stock().any(func(s: Dictionary) -> bool: return s["id"] == "armadura_cuero"), "ya no aparece en el stock")
	main.prog.materials["gel_slime"] = 5
	var c0: int = main.prog.coins
	assert(shop.sell_value("gel_slime") == 20)
	shop.sell("gel_slime")
	assert(main.prog.coins == c0 + 20 and not main.prog.materials.has("gel_slime"), "Bram paga los materiales")
	assert(shop.sell("gel_slime").find("No tienes") >= 0, "sin materiales no vende")
	shop.open("merchant")  # la interfaz se construye y pausa el juego; Esc/cerrar lo reanuda
	assert(shop.is_open() and main.get_tree().paused and shop.list.get_child_count() > 0)
	shop.close()
	assert(not shop.is_open() and not main.get_tree().paused)

	# --- nuevos tipos de misión: recoger material y piso 4 opcional
	var qd: RefCounted = main.quests
	var qs: Dictionary = qd.to_dict()  # se restaura al final: el guardado de más abajo comprueba este estado
	qd.idx = qd.list.find_custom(func(q: Dictionary) -> bool: return q["id"] == "gel")
	qd.status = "active"
	qd.progress = 0
	main.quest_event("loot", "gel_slime")
	main.quest_event("loot", "gel_slime")
	assert(qd.status == "active")
	main.quest_event("loot", "gel_slime")
	assert(qd.status == "ready", "recoger tres geles cumple la misión")
	var dung: Dictionary = main._read_json("res://data/dungeon.json")
	assert(dung["floors"].size() == 4 and dung["floors"][3]["chest"].get("final", false) and not dung["floors"][2]["chest"].get("final", false), "el piso 4 es opcional y cierra la dungeon")
	qd.from_dict(qs)

	# --- guardado y carga (con validación)
	main.prog.level = 4
	main.prog.points = 3
	main.prog.spent["strength"] = 2
	main.dungeon_floor = 2
	main.prog.add_item(main.prog.equipment.keys()[0])
	main.save_game()
	main.prog.level = 1
	main.prog.spent["strength"] = 0
	main.dungeon_floor = 1
	main.quests.idx = 0
	assert(main.load_game())
	assert(main.prog.level == 4 and main.prog.points == 3 and main.prog.spent["strength"] == 2 and main.dungeon_floor == 2)
	assert(main.quests.idx == 1 and main.quests.status == "ready", "la misión se conserva")
	assert(not main.prog.owned.is_empty() and main.prog.equipped.size() >= 1, "el equipo se conserva")
	var f := FileAccess.open(main.save_path, FileAccess.WRITE)  # archivo corrupto: se ignora sin romper
	f.store_string("{no es json")
	f.close()
	var lvl: int = main.prog.level
	assert(not main.load_game() and main.prog.level == lvl)
	f = FileAccess.open(main.save_path, FileAccess.WRITE)  # valores absurdos: se sanean
	f.store_string('{"level": -5, "coins": -9, "spent": {"strength": -3}, "equipped": {"sword": "no_existe"}, "dungeon_floor": 99, "quests": {"idx": 99, "status": "raro"}}')
	f.close()
	assert(main.load_game())
	assert(main.prog.level == 1 and main.prog.coins == 0 and main.prog.spent["strength"] == 0 and main.prog.equipped.is_empty() and main.dungeon_floor == 4)
	assert(main.quests.idx == main.quests.list.size() and main.quests.status == "none")

	# --- al morir en la dungeon, despierta en el pueblo
	main._enter_dungeon()
	assert(main.in_dungeon)
	main.hero_hp = 0
	main.dying = true
	main._respawn()
	assert(not main.in_dungeon and main.pos == main.start_pos, "reaparece en el pueblo")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.save_path))
	print("PASS town: fauna golpeable, transparencia, misiones, mercader, guardado, reaparición en el pueblo")
	quit()
