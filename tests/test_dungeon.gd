extends SceneTree
# Dungeon procedural: pisos conexos con la entrada, la salida y todos los puestos de monstruos alcanzables; jefe cada 4 pisos;
# niveles de los monstruos (por debajo del héroe al principio, el jefe a su nivel, y subiendo piso a piso); recompensas crecientes;
# punto de reanudación tras cada jefe; y monstruos del exterior ajustados al nivel del héroe.

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var Gen := preload("res://scripts/dungeon_gen.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	# generador: conexo en todos los pisos y semillas
	for n in range(1, 26):
		for k in 6:
			var boss: bool = n % 4 == 0
			var lay: Dictionary = Gen.generate(n, rng, boss)
			var seen: Dictionary = Gen.reachable(lay["walk"], Vector2i(12, 2))
			assert(seen.has(Vector2i(12, 24)), "piso %d: de la entrada se llega a la salida" % n)
			assert(seen.has(Vector2i(12, 0)), "la puerta de salida está en suelo")
			assert(lay["spots"].size() >= 12, "piso %d: hay sitio para los monstruos" % n)
			for t: Vector2 in lay["spots"]:
				assert(seen.has(Vector2i(int(t.x), int(t.y))), "todo puesto de monstruo es alcanzable")
			var c: Vector2 = lay["chest_spot"]
			assert(seen.has(Vector2i(int(c.x), int(c.y))), "el cofre es alcanzable")
			if boss:
				var b: Vector2 = lay["boss_spot"]
				assert(seen.has(Vector2i(int(b.x), int(b.y))), "el jefe aparece en la arena")
	var a: Dictionary = Gen.generate(2, rng, false)
	var b2: Dictionary = Gen.generate(2, rng, false)
	assert(a["walk"] != b2["walk"], "dos pisos seguidos no son iguales")

	var open_lay: Dictionary = Gen.generate(3, rng, false, false)
	assert(open_lay["walk"].all(func(r: String) -> bool: return not r.contains("0")), "el modo abierto es un salón sin muros")
	assert(Gen.reachable(open_lay["walk"], Vector2i(12, 2)).size() == 625 and open_lay["spots"].size() >= 12, "y todo es alcanzable")

	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	main.save_path = "user://test_dungeon_save.json"
	main.testing = true
	await process_frame
	main._enter_dungeon()
	await create_timer(0.8, true, false, true).timeout
	var fl: Node = main.floors
	assert(main.in_dungeon and fl.floor_no == 1 and not fl.is_boss, "se entra al piso 1")

	# jefe cada 4 pisos, con jefes que rotan
	for n in range(1, 13):
		assert(fl.is_boss_floor(n) == (n % 4 == 0), "el piso %d %s jefe" % [n, "es" if n % 4 == 0 else "no es"])
	assert(fl.boss_def(4)["id"] == "storm_mage" and fl.boss_def(8)["id"] == "cyclops" and fl.boss_def(12)["id"] == "storm_mage", "los jefes rotan")

	# niveles: empiezan por debajo del héroe, el jefe va a su nivel y cada tramo sube
	main.prog.level = 10
	assert(fl.level_for(1) == 8 and fl.level_for(2) == 9 and fl.level_for(3) == 9 and fl.level_for(4) == 10, "tramo 1: P-2, P-1, P-1 y jefe P")
	assert(fl.level_for(1) < fl.level_for(4) and fl.level_for(5) <= fl.level_for(8) and fl.level_for(5) > fl.level_for(1), "sube dentro del tramo y entre tramos")
	assert(fl.level_for(3, true) == fl.level_for(3) + 1, "los minijefes llevan un nivel más")
	main.prog.level = 1
	assert(fl.level_for(1) == 1, "nunca baja del nivel 1")

	# composición: más monstruos cada piso, minijefes desde el 3, jefe con escolta
	var counts: Array = []
	for n in range(1, 8):
		if n % 4 != 0:
			counts.append(fl.composition(n).size())
	assert(counts[0] < counts[-1] and counts.max() <= 14, "más monstruos con la profundidad, con tope")
	assert(fl.composition(1).all(func(m: Dictionary) -> bool: return m["id"] == "slime"), "el piso 1 solo tiene slimes")
	assert(fl.composition(2).any(func(m: Dictionary) -> bool: return m["id"] == "skeleton_archer"), "arqueros desde el piso 2")
	assert(fl.composition(3).any(func(m: Dictionary) -> bool: return m["id"] == "cyclops"), "minijefe desde el piso 3")
	var boss_comp: Array = fl.composition(4)
	assert(boss_comp[0]["id"] == "storm_mage" and boss_comp.size() > 3, "el jefe viene con escolta")

	# el piso real: monstruos a su nivel y jefe con más vida
	main.prog.level = 8
	fl.start(4)
	await process_frame
	var mage: Node = null
	for e in main.enemies:
		if e != main.dragon and e.id == "storm_mage":
			mage = e
	assert(mage != null and fl.is_boss, "el piso 4 trae al mago de la tormenta")
	var base_hp: int = int(main.creatures["storm_mage"]["hp"])
	var mage_hp: int = mage.data["hp"]
	assert(mage_hp > base_hp * 2, "el jefe está escalado a su nivel (%d contra %d)" % [mage_hp, base_hp])
	fl.start(5)
	await process_frame
	var slimes: Array = main.enemies.filter(func(e: Node) -> bool: return e != main.dragon and e.id == "slime")
	assert(not slimes.is_empty() and slimes[0].data["hp"] < mage_hp, "los slimes del piso 5 son más flojos que el jefe")
	assert(main.dungeon_floor == 5, "tras el jefe el piso 5 es el punto de reanudación")
	fl.start(7)
	assert(main.dungeon_floor == 5, "mitad de tramo: el punto no cambia")

	# recompensas crecientes
	assert(fl.reward_mult(1) == 1.0 and fl.reward_mult(5) > fl.reward_mult(2), "el cofre rinde más cuanto más hondo")
	main.set_enemy_level(5, {}, 1)
	var shallow: Dictionary = main._scaled(main.creatures["slime"])
	main.set_enemy_level(5, {}, 9)
	var deep: Dictionary = main._scaled(main.creatures["slime"])
	main.set_enemy_level(0)
	assert(deep["xp"] > shallow["xp"] and deep["coins"][1] > shallow["coins"][1], "los monstruos de un piso hondo pagan más XP y monedas")
	assert(shallow["hp"] > main.creatures["slime"]["hp"], "un monstruo de nivel 5 tiene más vida que el base")

	# el exterior: un par de niveles por debajo del héroe, jefes a su nivel
	main.prog.level = 12
	var fox: Node = main.predators[0]
	main._exit_dungeon()
	main.refresh_world_levels()
	assert(main.world_level(false) == 10 and main.world_level(true) == 12, "monstruos P-2, jefes P")
	assert(fox.data["hp"] > main.creatures["fox"]["hp"] and main.dragon.data["hp"] > main.creatures["dragon"]["hp"], "el zorro y el dragón se adaptan al nivel")
	assert(float(main.dragon.data["hp"]) / float(main.creatures["dragon"]["hp"]) > float(fox.data["hp"]) / float(main.creatures["fox"]["hp"]), "el jefe se escala más que el monstruo normal")
	main.prog.level = 1
	main.refresh_world_levels()
	assert(main.dragon.data["hp"] == main.creatures["dragon"]["hp"], "a nivel 1 todo está como en los datos")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.save_path))
	print("PASS dungeon: pisos conexos, jefe cada 4, niveles y recompensas por piso, reanudación y exterior adaptado")
	quit()
