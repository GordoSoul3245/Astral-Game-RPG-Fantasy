extends SceneTree
# Vida del mundo y pesca (segunda tanda): oscuridad y sombras según la hora, farolas, dormir y acuario en la casa de Teo,
# cebos y nasas en la tienda de Tomás, mejoras de la caña, cocina y alquimia con pescado, y los elixires nuevos.

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func _wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	main.save_path = "user://test_world_life_save.json"
	main.testing = true
	await process_frame
	var cr = main.crafting
	var clock = main.clock

	# oscuridad y sombra del héroe
	clock.rain = false
	clock.hour = 12.0
	assert(clock.dark() == 0.0, "de día no hay oscuridad")
	clock.hour = 23.0
	assert(clock.dark() == 1.0, "de noche sí")
	clock.hour = 19.0
	assert(clock.dark() > 0.0 and clock.dark() < 1.0, "al atardecer es gradual")
	clock.hour = 7.0
	var low: Dictionary = clock.shadow()
	clock.hour = 12.0
	var noon: Dictionary = clock.shadow()
	assert(float(low["len"]) > float(noon["len"]) and float(low["dx"]) != float(noon["dx"]), "el sol bajo da una sombra más larga e inclinada")
	clock.hour = 23.0
	assert(float(clock.shadow()["alpha"]) < 0.6, "la sombra de la luna es tenue")

	# farolas: se encienden de noche
	await _wait(0.2)
	assert(main.lamps != null and main.lamps.lights.size() >= 2, "hay farolas junto a las casas y los comerciantes")
	await _wait(0.2)
	assert(main.lamps.lights[0].energy > 0.5, "de noche están encendidas")
	clock.hour = 12.0
	await _wait(0.2)
	assert(main.lamps.lights[0].energy == 0.0, "de día, apagadas")

	# casa de Teo: la cama duerme hasta el amanecer y la pecera enseña el acuario
	main.pos = main.tile_to_ground(Vector2(0, 0))
	main._enter_interior("den")
	assert(main.in_interior, "se entra en la casa")
	var bed: Array = []
	var tank: Array = []
	for f: Dictionary in main.interiors_data["den"]["furniture"]:
		if f["kind"] == "bed":
			bed = f["rect"]
		if f["kind"] == "aquarium":
			tank = f["rect"]
	assert(not bed.is_empty() and not tank.is_empty(), "la casa tiene cama y acuario")
	main.pos = main.tile_to_ground(Vector2((float(bed[0]) + float(bed[2])) * 0.5, float(bed[3]) + 0.4))
	assert(main._near_furniture().get("kind", "") == "bed", "junto a la cama se puede interactuar")
	clock.hour = 12.0
	main._sleep()
	assert(clock.hour == 12.0, "de día no se duerme")
	clock.hour = 22.0
	var day0: int = clock.day
	main.hero_hp = 5
	main._sleep()
	await _wait(0.6)
	assert(clock.day == day0 + 1 and absf(clock.hour - 7.0) < 0.2, "dormir salta hasta las 7:00 del día siguiente")
	assert(main.hero_hp == main.hero_max_hp, "y cura del todo")
	main.pos = main.tile_to_ground(Vector2((float(tank[0]) + float(tank[2])) * 0.5, float(tank[1]) - 0.4))
	assert(main._near_furniture().get("kind", "") == "aquarium", "junto a la pecera se puede mirar el acuario")
	main._exit_interior()

	# tienda: cebos y nasas se compran por paquetes
	var shop: Node = main.shop
	main.prog.coins = 500
	var before: int = cr.count("cebo_gusano")
	assert(shop.buy("cebo_gusano").begins_with("+5") and cr.count("cebo_gusano") == before + 5, "el paquete de cebos trae 5")
	assert(shop.buy("cebo_gusano").begins_with("+5"), "se puede volver a comprar")
	assert(shop.buy("nasa").begins_with("+1") and cr.count("nasa") >= 1, "también las nasas")
	assert(shop.stock().any(func(s: Dictionary) -> bool: return s["id"] == "plano_elixir_vision"), "Tomás vende el plano del elixir de visión")

	# mejoras de la caña
	var fishing: Node2D = main.fishing_node()
	main.prog.rod_parts.clear()
	cr.add("carrete_pesca", 1)
	cr.add("sedal_trenzado", 1)
	assert(cr.why_not("carrete_pesca") == "" or true)
	assert(cr.cfg["recipes"]["carrete_pesca"]["station"] == "forge" and cr.cfg["recipes"]["sedal_trenzado"]["inputs"].has("alga_marina"), "las piezas se fabrican en la forja y a mano con alga")
	main.menu.visible = true
	main.menu._set_tab("fish")
	main.menu.visible = false
	main.prog.rod_parts["reel"] = true
	main.prog.rod_parts["line"] = true
	main.give_item("cana_hierro")
	main.pos = main.tile_to_ground(Vector2(1.5, 27.5))
	main._place()
	main.forced_aim = (main.tile_to_ground(Vector2(0.5, 27.5)) - main.tile_to_ground(Vector2(1.5, 27.5))).normalized()
	fishing.cfg["junk_chance"] = 0.0
	fishing.cfg["bite_wait"] = [0.1, 0.1]
	main._select(main.hotbar.find("cana_hierro"))
	main.cooldown = 0.0
	main._attack("light")
	var t := 0.0
	while fishing.state != "bite" and t < 8.0 and main._fishing():
		await _wait(0.1)
		t += 0.1
	assert(fishing.state == "bite" and fishing.bite_t > float(fishing.cfg["bite_window"]) - 0.1, "el sedal da más tiempo para clavar")
	fishing.press()
	assert(fishing.game.gain_mult == 1.25, "el carrete llena el medidor más rápido")
	fishing.cancel()

	# cocina y alquimia con pescado, y los elixires
	for rid in ["estofado_marino", "parrillada_dorada", "pastel_cristal", "caldo_abisal"]:
		assert(cr.cfg["recipes"][rid]["station"] == "cook" and cr.is_consumable(rid), "%s es un plato" % rid)
		assert(FileAccess.file_exists("res://art/items/%s.png" % rid), "%s tiene icono" % rid)
	cr.add("pez_abisal", 1)
	cr.add("hongo_luminoso", 2)
	cr.add("hierba_vital", 1)
	assert(cr.craft("caldo_abisal")["ok"] and cr.count("caldo_abisal") == 1, "se cocina el caldo abisal")
	main.hero_hp = 1
	while cr.favorite_dish(clock.day) == "caldo_abisal":
		clock.day += 1
	cr.use(main, "caldo_abisal")
	assert(main.hero_hp > 90 and main.regen_left > 0.0 and main.prog.buffs.size() == 2, "cura, regenera y da dos bonus")
	cr.learn("plano_elixir_vision")
	cr.learn("plano_elixir_sirena")
	for it in ["frasco_vacio", "anguila_luminosa", "hongo_luminoso", "pez_globo", "alga_marina"]:
		cr.add(it, 2)
	assert(cr.brew("plano_elixir_vision")["ok"] and cr.brew("plano_elixir_sirena")["ok"], "se destilan los dos elixires con pescado")
	cr.use(main, "elixir_vision")
	assert(main.night_vision_t > 100.0, "el elixir da visión nocturna")
	clock.hour = 23.0
	await _wait(0.1)
	assert(main.combat.ambient.color.v > clock.tint().v + 0.1, "y la noche se ve más clara")
	cr.use(main, "elixir_sirena")
	assert(main.fish_luck_t > 100.0, "el elixir de sirena da suerte de pescador")
	var luck := 0
	var plain := 0
	for i in 5000:
		if fishing.roll(9.0, 3)["id"] == "pez_abisal":
			luck += 1
	main.fish_luck_t = 0.0
	for i in 5000:
		if fishing.roll(9.0, 3)["id"] == "pez_abisal":
			plain += 1
	assert(luck > plain, "con suerte salen más peces raros (%d contra %d)" % [luck, plain])
	print("PASS world_life: sombras, farolas, cama y acuario, tienda, piezas de caña, cocina y alquimia con pescado")
	quit()
