extends SceneTree
# Creación en el juego real: estaciones del pueblo, recolección con herramientas, mina, paneles (forja, cocina, alquimia con planos),
# consumibles, botín de planos y guardado/carga. Complementa tests/test_crafting.gd (lógica pura).

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func _wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.dragon.set_physics_process(false)
	main.save_path = "user://test_craft_save.json"
	await process_frame
	var cr = main.crafting
	assert(cr.knows("plano_pocion_vida"), "el plano inicial ya se conoce")
	assert(main.stations.size() >= 3, "mesa, fogata y yunque registrados")

	# la mesa y la fogata están junto al mercader y se usan con E
	var table: Dictionary = {}
	for s: Dictionary in main.stations:
		if s["station"] == "alchemy":
			table = s
	assert(not table.is_empty() and table["tile"].distance_to(main.ground_to_tile(main.merchants.filter(func(m: Node2D) -> bool: return m.role == "merchant")[0].pos)) < 4.0, "la mesa está al lado del mercader")
	main.pos = main.tile_to_ground(table["tile"] + Vector2(0, 1.2))
	assert(main._near_station()["station"] == "alchemy", "cerca de la mesa se detecta la estación")
	assert(main.world.rects.size() > 5, "la mesa bloquea el paso")

	# recolección: sin hacha un árbol cuesta más golpes; con hacha de piedra, menos
	var tree: Dictionary = {}
	for n: Dictionary in main.world.res_nodes:
		if n["kind"] == "tree" and tree.is_empty():
			tree = n
	assert(not tree.is_empty(), "los árboles del mapa son recolectables")
	assert(main.world.res_nodes.any(func(n: Dictionary) -> bool: return n["kind"] == "herb") and main.world.res_nodes.any(func(n: Dictionary) -> bool: return n["kind"] == "berry"), "hay hierbas y bayas en el valle")
	main.pos = tree["g"] + Vector2(-26, 14)
	assert(main._near_node()["kind"] != "", "al lado del árbol se puede talar")
	var hits_bare := 0
	while not tree["depleted"] and hits_bare < 20:
		main.world.hit_node(tree, cr.swing_power("axe"))
		hits_bare += 1
	assert(hits_bare == 6 and tree["circle"][1] == 0.0, "a manos: 6 golpes y deja de bloquear (%d)" % hits_bare)
	for i in 40:  # la animación de caída dura 0,3 s; se espera a que termine
		if not tree["spr"].visible:
			break
		await _wait(0.1)
	assert(not tree["spr"].visible, "el árbol caído desaparece")
	tree["t"] = 0.01
	main.world._tick_respawns(0.1)
	assert(not tree["depleted"] and tree["circle"][1] > 0.0 and tree["hp"] == 6, "el árbol vuelve a crecer")
	cr.add("madera", 6)
	cr.add("piedra", 7)
	assert(cr.craft("hacha_piedra")["ok"] and cr.craft("pico_piedra")["ok"], "herramientas de piedra")
	assert(main.prog.equipped.has("axe") and main.prog.equipped.has("pickaxe"), "herramientas equipadas")
	var hits_axe := 0
	main.world._tick_respawns(1000.0)
	tree["hp"] = 6
	while not tree["depleted"] and hits_axe < 20:
		main.world.hit_node(tree, cr.swing_power("axe"))
		hits_axe += 1
	assert(hits_axe == 3, "con hacha de piedra: 3 golpes (%d)" % hits_axe)

	# gatillo real: balanceo, golpe en el fotograma y botín
	main.world._tick_respawns(1000.0)
	tree["hp"] = 2
	main.pos = tree["g"] + Vector2(-26, 14)
	var wood0: int = cr.count("madera")
	main._gather(tree)
	assert(main.gathering, "empieza la animación de recolectar")
	for i in 40:
		main._gather_tick(1.0 / 60.0)
	assert(not main.gathering and cr.count("madera") > wood0 and tree["depleted"], "el golpe a mitad de animación suelta madera")

	# mina: entrada con puerta, cueva con vetas y monstruos, y salida que restaura el pueblo
	assert(main.doors.any(func(d: Node2D) -> bool: return d.label == "Entrar a la mina"), "la entrada de la mina existe")
	var door_tiles: int = main.doors.size()
	main._enter_mine()
	await process_frame
	assert(main.in_mine and main.in_dungeon and main.world.has_method("free_tile"), "dentro de la mina")
	var kinds := {}
	for n: Dictionary in main.world.res_nodes:
		kinds[n["kind"]] = int(kinds.get(n["kind"], 0)) + 1
	assert(kinds.get("iron", 0) == 9 and kinds.get("coal", 0) == 7 and kinds.get("crystal", 0) == 3 and kinds.get("mushroom", 0) == 6, "vetas de la mina: %s" % kinds)
	assert(main.enemies.size() >= 5, "la mina tiene guardianes")
	for n: Dictionary in main.world.res_nodes:  # todo está en suelo conectado con la entrada
		assert(not main.world.rock.has(Vector2i(floori(n["tile"].x), floori(n["tile"].y))), "mena sobre suelo libre")
	main.pos = main.world.res_nodes[0]["g"] + Vector2(-26, 14)
	assert(main._scene_id() == "mine")
	# cristal solo con pico de hierro
	var crystal: Dictionary = main.world.res_nodes.filter(func(n: Dictionary) -> bool: return n["kind"] == "crystal")[0]
	assert(cr.can_gather("crystal") != "", "con pico de piedra no se parte el cristal")
	cr.add("lingote_hierro", 3)
	cr.add("madera", 2)
	assert(cr.craft("pico_hierro")["ok"] and cr.can_gather("crystal") == "")
	main._exit_mine()
	assert(not main.in_mine and not main.in_dungeon and main.world.visible and main.doors.size() == door_tiles, "vuelve al pueblo")
	assert(main.enemies.size() == 1, "los monstruos de la mina se van; queda el dragón (%d)" % main.enemies.size())

	# paneles: forja y cocina con recetas y animación; el resultado llega al inventario
	cr.add("cuero", 3)
	cr.add("carne_conejo", 2)
	main.station_ui.open("cook")
	await process_frame
	var cook: Node = main.station_ui.content
	assert(main.station_ui.visible and main.get_tree().paused and cook.selected == "carne_asada", "se abre la fogata y pausa el juego")
	cook.start_craft()
	assert(cook.busy)
	await _wait(1.7)
	assert(not cook.busy and cr.count("carne_asada") == 1, "tras la animación hay comida")
	main.station_ui.close()
	assert(not main.get_tree().paused)

	# alquimia: plano sobre la mesa, ingredientes uno a uno, preparar con animación; los planos no se gastan
	cr.add("frasco_vacio", 1)
	cr.add("hierba_vital", 2)
	cr.add("gel_slime", 1)
	main.station_ui.open("alchemy")
	await process_frame
	var al: Node = main.station_ui.content
	assert(al.brew_btn.disabled, "sin plano no se puede preparar")
	al.select_plano("plano_pocion_vida")
	assert(al.brew_btn.disabled, "con el plano pero sin ingredientes colocados tampoco")
	for id: String in cr.cfg["blueprints"]["plano_pocion_vida"]["inputs"]:
		al.placed[id] = true
	al.refresh()
	assert(not al.brew_btn.disabled, "con todo colocado se puede preparar")
	var potions0: int = main.prog.potions
	al.start_brew()
	assert(al.busy and al.stage.running)
	await _wait(3.5)
	assert(not al.busy and main.prog.potions == potions0 + 2, "la poción llega a la bolsa (%d -> %d)" % [potions0, main.prog.potions])
	assert(cr.knows("plano_pocion_vida"), "el plano sigue conocido")
	main.station_ui.close()

	# consumibles: la comida cura y da bonus; la tecla G usa la elegida
	main.hero_hp = 10
	cr.add("estofado_zorro", 1)
	main.prog.quick = "estofado_zorro"
	var str0: float = main.prog.stat("strength")
	main._use_quick()
	assert(main.hero_hp == 50 and main.prog.stat("strength") == str0 + 2.0, "el estofado cura 40 y da +2 Fuerza")
	assert(cr.count("estofado_zorro") == 0)
	cr.add("frasco_ignis", 1)
	var e: Node = main.spawn_enemy("slime", main.pos + Vector2(30, 0))
	e.set_physics_process(false)
	var hp0: int = e.hp
	cr.use(main, "frasco_ignis")
	assert(e.hp < hp0 or not e.alive, "el frasco de Ignis hiere a lo cercano")

	# botín: un plano que cae de un monstruo se aprende una sola vez
	assert(not cr.knows("plano_elixir_furia"))
	main.on_kill(_FakeEnemy.new(main.pos, {"drops": [{"item": "plano_elixir_furia", "chance": 1.0}]}))
	assert(cr.knows("plano_elixir_furia"), "el plano soltado se aprende")

	# guardado y carga conservan planos, herramientas y consumibles
	main.save_game()
	var blue_n: int = main.prog.blueprints.size()
	main.prog.blueprints.clear()
	main.prog.equipped.erase("axe")
	main.prog.materials.clear()
	assert(main.load_game())
	assert(main.prog.blueprints.size() == blue_n and cr.knows("plano_elixir_furia"), "los planos se guardan")
	assert(main.prog.equipped.get("axe") == "hacha_piedra" and main.prog.equipped.get("pickaxe") == "pico_hierro", "las herramientas se guardan")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.save_path))

	# la pestaña Crafteo del menú existe y se construye
	main.menu.tab = "craft"
	main.menu.visible = true
	main.menu.refresh()
	await process_frame
	assert(main.menu.tab_buttons.has("craft") and main.menu.side_card != null, "pestaña de crafteo")
	print("PASS crafting_world: mesa y fogata junto al mercader, recolección por herramienta, mina, forja, cocina, alquimia con planos y guardado")
	quit()

class _FakeEnemy extends Node2D:
	var data := {}
	var pos := Vector2.ZERO
	var id := ""
	func _init(p: Vector2, d: Dictionary) -> void:
		pos = p
		data = d
