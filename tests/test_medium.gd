extends SceneTree
# Mecánicas medianas: mejora de herramientas en la forja, enemigos por horario y clima, y mascotas domadas.

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func _wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	main.save_path = "user://test_medium_save.json"
	main.testing = true
	await _wait(0.5)
	var cr = main.crafting
	var p = main.prog

	# --- mejora de herramientas
	main.give_item("pico_hierro")
	assert(cr.up_level("pico_hierro") == 0 and not cr.up_cost("pico_hierro").is_empty(), "una herramienta empieza en +0 con coste de mejora")
	assert(cr.up_cost("espada_hierro").is_empty(), "un arma no se mejora aquí")
	var base: int = cr.swing_power("pickaxe")
	assert(cr.upgrade("pico_hierro") == "Faltan materiales.", "sin materiales no mejora")
	for m: String in ["lingote_hierro", "lingote_acero", "carbon", "cristal_arcano"]:
		cr.add(m, 9)
	assert(cr.upgrade("pico_hierro").ends_with("+1.") and cr.up_level("pico_hierro") == 1, "mejora a +1")
	assert(cr.swing_power("pickaxe") == base + 1 and cr.item_name("pico_hierro").ends_with("+1"), "+1 de daño al recurso y el nombre lo muestra")
	cr.upgrade("pico_hierro")
	cr.upgrade("pico_hierro")
	assert(cr.up_level("pico_hierro") == 3 and cr.upgrade("pico_hierro") == "Ya está al máximo." and cr.swing_power("pickaxe") == base + 3, "máximo +3")
	main.give_item("cana_hierro")
	cr.upgrade("cana_hierro")
	main.save_game()
	p.tool_up.clear()
	assert(main.load_game() and cr.up_level("pico_hierro") == 3 and cr.up_level("cana_hierro") == 1, "las mejoras se guardan")
	var fishing: Node2D = main.fishing_node()
	main.pos = main.tile_to_ground(Vector2(1.5, 27.5))
	main._place()
	fishing.start("cana_hierro")
	assert(fishing.rod_up == 1, "la caña mejorada lo aplica al pescar")
	fishing.cancel()

	# --- horario y clima
	main.pos = main.tile_to_ground(Vector2(18.5, 30.5))
	main._place()
	main.clock.rain = false
	main.clock.hour = 12.0
	main._check_edges(0.1)
	assert(main.night_mobs.is_empty(), "de día sin lluvia no hay limos nocturnos")
	main.clock.hour = 23.0
	for i in 40:
		main.night_t = 0.0
		main._check_edges(0.1)
	assert(main.night_mobs.size() == 4 and main.night_mobs[0].id == "limo_nocturno" and main.night_mobs[0].data["hp"] > main.creatures["slime"]["hp"] - 1, "de noche salen 4 limos nocturnos")
	main.clock.hour = 12.0
	main._check_edges(0.1)
	assert(main.night_mobs.is_empty(), "al amanecer se disuelven")
	main.clock.rain = true
	main.clock.hour = 19.0
	for i in 20:
		main.night_t = 0.0
		main._check_edges(0.1)
	assert(main.night_mobs.size() == 2, "con lluvia al atardecer salen 2")
	await _wait(0.2)
	assert(main.fauna.all(func(f: Node) -> bool: return not f.visible) and not main.targets().any(func(t: Node) -> bool: return main.fauna.has(t)), "los conejos se esconden con la lluvia y no se pueden golpear")
	main.clock.rain = false
	await _wait(0.2)
	assert(main.fauna.all(func(f: Node) -> bool: return f.visible), "sin lluvia vuelven")

	# --- mascotas
	main.clock.rain = false
	main.clock.hour = 12.0
	await _wait(0.3)
	var bunny: Node2D = main.fauna[0]
	bunny.alive = true
	bunny.visible = true
	main.pos = bunny.pos + Vector2(20, 10)
	assert(not main.try_tame(), "sin comida no se doma")
	cr.add("hierba_vital", 3)
	assert(main.try_tame() and main.pets.is_empty() and cr.count("hierba_vital") == 2, "la primera comida acerca al conejo")
	assert(main.try_tame() and main.pets == ["rabbit"] and main.pet_nodes.size() == 1 and not bunny.alive, "la segunda lo doma")
	assert(main.pet_nodes[0].spr != null, "la mascota tiene su arte")
	main.pos = main.tile_to_ground(Vector2(30, 30))
	await _wait(0.5)
	assert(main.pet_nodes[0].pos.distance_to(main.pos) < 200.0, "la mascota sigue al héroe")
	main.save_game()
	main.pets.clear()
	for pn: Node in main.pet_nodes:
		pn.queue_free()
	main.pet_nodes.clear()
	assert(main.load_game() and main.pets == ["rabbit"] and main.pet_nodes.size() == 1, "las mascotas se guardan")
	main.pets.append("fox")
	main.pets.append("rabbit")
	var bunny2: Node2D = main.fauna[1]
	bunny2.alive = true
	bunny2.visible = true
	main.pos = bunny2.pos + Vector2(20, 10)
	assert(main.try_tame() and main.pets.size() == 3 and cr.count("hierba_vital") == 1, "con el límite lleno no gasta comida")
	main.pets.resize(2)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.save_path))
	print("PASS medium: mejora de herramientas, horario y clima, mascotas")
	quit()
