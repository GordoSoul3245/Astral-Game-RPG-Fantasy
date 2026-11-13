extends SceneTree
# Agricultura: huerto de 12 parcelas, plantar desde la barra, regar (regadera y lluvia), crecer con las horas de juego,
# el hongo solo de noche, cosechar con E, tienda y guardado.

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func _wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	main.save_path = "user://test_farm_save.json"
	main.testing = true
	await _wait(0.5)
	var farm: Node2D = main.farm
	var cr = main.crafting
	var clock = main.clock
	assert(farm != null and farm.plots.size() == 12, "el huerto tiene 12 parcelas")
	for p: Dictionary in farm.plots:
		assert(not main.world.is_water(p["tile"]) and not main.world.blocked(p["tile"], 0.4), "las parcelas están en suelo libre")
	for id: String in farm.cfg["seeds"]:
		assert(FileAccess.file_exists("res://art/items/%s.png" % id) and cr.cfg["materials"].has(farm.cfg["seeds"][id]["crop"]), "%s: icono y cultivo existen" % id)
	assert(FileAccess.file_exists("res://art/items/regadera.png"), "la regadera tiene icono")

	# plantar desde la barra con la semilla elegida
	clock.rain = false
	clock.hour = 12.0
	main.pos = main.tile_to_ground(farm.plots[0]["tile"])
	main._place()
	cr.add("semilla_baya", 2)
	cr.add("regadera", 1)
	assert(main.hotbar_add("semilla_baya") and main.hotbar_add("regadera"), "semillas y regadera caben en la barra")
	main._select(main.hotbar.find("semilla_baya"))
	main.cooldown = 0.0
	main._attack("light")
	assert(farm.plots[0]["seed"] == "semilla_baya" and cr.count("semilla_baya") == 1, "el clic con la semilla planta en la parcela cercana")
	assert(farm.near_text().contains("seca"), "avisa de que está seca (%s)" % farm.near_text())

	# sin riego no crece; regada, sí
	farm.advance(5.0)
	assert(float(farm.plots[0]["growth"]) == 0.0, "sin agua no crece")
	main._select(main.hotbar.find("regadera"))
	main.cooldown = 0.0
	main._attack("light")
	assert(float(farm.plots[0]["wet"]) > 0.0 and cr.count("regadera") == 1, "la regadera riega y no se gasta")
	farm.advance(4.0)
	assert(absf(float(farm.plots[0]["growth"]) - 4.0) < 0.01, "regada crece con las horas de juego")
	farm.advance(6.0)
	assert(float(farm.plots[0]["growth"]) < 8.1, "el riego se acaba: solo creció lo que duraba el agua (%.1f)" % farm.plots[0]["growth"])

	# la lluvia riega sola
	clock.rain = true
	farm.advance(10.0)
	assert(farm.ripe(farm.plots[0]), "con lluvia madura (10 h)")
	clock.rain = false

	# cosecha con E
	assert(farm.near_text().begins_with("[E] Cosechar"), "avisa de que se puede cosechar")
	var before: int = cr.count("baya_roja")
	main._interact()
	assert(cr.count("baya_roja") >= before + 2 and farm.plots[0]["seed"] == "", "E cosecha 2-4 bayas y deja la parcela libre")

	# el hongo solo crece de noche
	cr.add("semilla_hongo", 1)
	main.hotbar_add("semilla_hongo")
	main._select(main.hotbar.find("semilla_hongo"))
	main.cooldown = 0.0
	main._attack("light")
	var idx := -1
	for i in farm.plots.size():
		if farm.plots[i]["seed"] == "semilla_hongo":
			idx = i
	assert(idx >= 0, "se planta la espora")
	farm.plots[idx]["wet"] = 100.0
	clock.hour = 12.0
	farm.advance(3.0)
	assert(float(farm.plots[idx]["growth"]) == 0.0, "de día el hongo no crece")
	clock.hour = 3.0
	farm.advance(3.0)
	assert(float(farm.plots[idx]["growth"]) > 2.5, "de noche sí (%.1f)" % farm.plots[idx]["growth"])

	# tienda y guardado
	main.prog.coins = 200
	assert(main.shop.buy("semilla_hierba").begins_with("+3") and main.shop.buy("regadera").begins_with("+1"), "Tomás vende semillas y regadera")
	main.save_game()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main.save_path))
	assert(saved["farm"]["plots"].size() == 12, "el guardado incluye el huerto")
	var grown: float = farm.plots[idx]["growth"]
	farm.plots[idx]["seed"] = ""
	farm.plots[idx]["growth"] = 0.0
	assert(main.load_game() and farm.plots[idx]["seed"] == "semilla_hongo" and absf(float(farm.plots[idx]["growth"]) - grown) < 0.01, "se restaura lo plantado")
	assert(cr.use(main, "semilla_hierba").begins_with("Se usa desde la barra"), "desde el menú no se gastan las semillas")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.save_path))
	print("PASS farm: huerto, plantar, regar, lluvia, crecimiento, hongo nocturno, cosecha, tienda y guardado")
	quit()
