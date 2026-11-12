extends SceneTree
# Extensiones de la pesca: reloj y clima, cebos, calidad por estrellas, cofre del fondo, libro de capturas, acuario,
# encargos de Bram y Tomás, nasas y trampas, comida duradera y plato favorito, y el guardado de todo ello.

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func _wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	main.save_path = "user://test_angling_save.json"
	main.testing = true
	await process_frame
	var cr = main.crafting
	var an = main.angler
	var clock = main.clock

	# reloj: avanza, cambia de día y oscurece de noche
	clock.hour = 23.5
	var d0: int = clock.day
	clock.advance(clock.DAY_SECONDS * 0.05)
	assert(clock.day == d0 + 1 and clock.hour < 2.0, "pasada la medianoche empieza otro día")
	clock.hour = 12.0
	clock.rain = false
	var noon: Color = clock.tint()
	clock.hour = 1.0
	assert(clock.tint().v < noon.v - 0.2, "de noche el ambiente es más oscuro que a mediodía")
	clock.hour = 12.0

	# cebos: los raros salen más con cebo de carne
	var fishing: Node2D = main.fishing_node()
	clock.hour = 23.0
	clock.rain = true
	var plain := 0
	var baited := 0
	for i in 6000:
		if fishing.roll(9.0, 3)["id"] == "pez_abisal":
			plain += 1
		if fishing.roll(9.0, 3, "cebo_carne")["id"] == "pez_abisal":
			baited += 1
	assert(baited > plain, "el cebo de carne atrae más peces raros (%d contra %d)" % [baited, plain])
	clock.hour = 12.0
	clock.rain = false

	# estrellas: se gastan en orden, se venden más caras y mejoran la comida
	cr.add("carpa_dorada", 3)
	cr.add("carpa_dorada", 1, 2)
	assert(cr.stars_of("carpa_dorada") == [0, 1], "una carpa de oro entre cuatro")
	assert(cr.take("carpa_dorada", 1) == 0 and cr.stars_of("carpa_dorada") == [0, 1], "al gastar sin más se usan primero las normales")
	var q: int = cr.take("carpa_dorada", 1, true)
	assert(q == 2 and cr.stars_of("carpa_dorada") == [0, 0], "cocinando se usa primero la mejor")
	cr.take("carpa_dorada", 5)
	cr.add("carpa_dorada", 1, 2)
	while cr.favorite_dish(clock.day) == "pescado_asado":
		clock.day += 1
	cr.craft("pescado_asado")
	assert(cr.stars_of("pescado_asado") == [0, 1], "un pescado de oro da un plato de oro")
	main.hero_hp = 1
	var msg: String = cr.use(main, "pescado_asado")
	assert(main.hero_hp == 1 + roundi(55.0 * 1.5) and "★★" in msg, "el plato de oro cura un 50 % más")
	assert(main.regen_left > 0.0, "la comida regenera vida con el tiempo")
	var hp0: int = main.hero_hp
	main._physics_process(1.0)
	assert(main.hero_hp > hp0, "la regeneración sube la vida")
	var shop: Node = main.shop
	cr.add("sardina", 2)
	cr.add("sardina", 1, 1)
	var base: int = int(shop.cfg["smith"]["buys"]["sardina"])
	assert(shop.sell_value("sardina") == roundi(base * 3.25), "la calidad paga más al vender")
	shop.sell("sardina")
	assert(cr.count("sardina") == 0 and cr.stars_of("sardina") == [0, 0], "vender limpia también las estrellas")

	# cofre del fondo: seguirlo con la barra lo llena
	var FG := preload("res://scripts/fish_game.gd")
	var g = FG.new()
	g.setup("smooth", 10.0, 0.5)
	g.with_chest(0.1, 0.45, 0.25)
	for i in 600:
		if g.chest >= 0.0:
			g.bar = clampf(g.chest - g.size * 0.5, 0.0, 1.0 - g.size)
			g.bar_v = 0.0
		g.fish = clampf(g.bar + g.size * 0.5, 0.0, 1.0)
		g.target = g.fish
		g.retarget = 99.0
		g.progress = 0.5
		g.step(1.0 / 60.0, false)
		if g.chest_got:
			break
	assert(g.chest_got, "con la barra sobre el cofre se recoge")
	assert(fishing._open_chest() != "", "el cofre da algo")

	# libro de capturas: especie nueva, récord e hitos
	var coins0: int = main.prog.coins
	for id in ["sardina", "carpa_dorada", "trucha_plateada"]:
		an.record(id, 20, 0)
	assert(an.book.size() == 3 and main.prog.coins >= coins0 + 60, "tres especies dan el primer hito")
	assert("Récord" in an.record("sardina", 99, 1), "un tamaño mayor es récord")
	assert(not ("Libro" in an.record("sardina", 5, 0)), "los hitos se cobran una sola vez")

	# acuario: los peces producen con los días
	cr.add("pez_cristal", 1)
	assert(an.deposit("pez_cristal") != "" and an.tank == ["pez_cristal"] and cr.count("pez_cristal") == 0, "el pez pasa al acuario")
	clock.advance(clock.DAY_SECONDS)
	assert(an.bin.get("cristal_arcano", 0) >= 1, "al día siguiente produce un cristal")
	var cry0: int = cr.count("cristal_arcano")
	an.collect()
	assert(cr.count("cristal_arcano") > cry0 and an.bin.is_empty(), "se recoge la producción")
	an.release(0)
	assert(an.tank.is_empty() and cr.count("pez_cristal") == 1, "se saca el pez del acuario")

	# encargos del día
	var o: Dictionary = an.order("smith")
	assert(not o.is_empty() and not an.order_done("smith"))
	cr.add(str(o["item"]), int(o["qty"]))
	var c1: int = main.prog.coins
	an.deliver("smith")
	assert(main.prog.coins == c1 + int(o["coins"]) and an.order_done("smith"), "entregar el encargo paga")
	assert("Hoy" in an.deliver("smith"), "solo uno por día")
	clock.advance(clock.DAY_SECONDS)
	assert(not an.order_done("smith"), "al día siguiente hay otro encargo")

	# nasas y trampas
	cr.add("nasa", 1)
	cr.add("trampa", 1)
	main.pos = main.tile_to_ground(Vector2(1.5, 27.5))
	main._place()
	main.forced_aim = (main.tile_to_ground(Vector2(0.5, 27.5)) - main.tile_to_ground(Vector2(1.5, 27.5))).normalized()
	assert(main.traps.place("nasa", "water").begins_with("Colocada") and an.traps.size() == 1, "la nasa se coloca en el agua")
	main.pos = main.tile_to_ground(Vector2(20.5, 20.5))
	main._place()
	main.forced_aim = Vector2(1, 0.3).normalized()
	assert(main.traps.place("trampa", "land").begins_with("Colocada") and an.traps.size() == 2, "la trampa se coloca en tierra")

	# guardado y carga conservan todo
	main.bait = "cebo_gusano"
	cr.add("sardina", 2, 1)
	main.save_game()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main.save_path))
	assert(saved.has("clock") and saved.has("angler") and saved["stars"].has("sardina"), "el guardado incluye reloj, pescador y estrellas")
	an.traps.clear()
	an.book.clear()
	cr.take("sardina", 2)
	main.bait = ""
	assert(main.load_game(), "se carga")
	assert(an.traps.size() == 2 and an.book.size() == 3 and cr.stars_of("sardina") == [2, 0] and main.bait == "cebo_gusano", "se restauran nasas, libro, estrellas y cebo")

	# las nasas se recogen solas al pasar cerca cuando están listas
	var n0: int = an.traps.size()
	clock.total += 10.0
	main.pos = Vector2(an.traps[0]["pos"][0], an.traps[0]["pos"][1])
	await _wait(0.2)
	assert(an.traps.size() < n0, "una trampa lista se recoge al acercarse")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.save_path))
	print("PASS angling: reloj, cebos, estrellas, cofre, libro, acuario, encargos, nasas, comida duradera y guardado")
	quit()
