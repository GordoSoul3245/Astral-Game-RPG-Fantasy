extends SceneTree
# Pesca: minijuego (lógica pura), tabla de peces por distancia y caña, y el ciclo completo en el juego real
# (lanzar, esperar el pique, clavar, minijuego, captura, cocina y venta).

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func _wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout

func run_checks() -> void:
	var FG := preload("res://scripts/fish_game.gd")
	# minijuego: seguir al pez gana, ignorarlo pierde, y "perfecto" exige no perderlo nunca
	for kind: String in ["mixed", "dart", "smooth", "sinker", "floater"]:
		var g = FG.new()
		g.setup(kind, 40.0, 0.35)
		for i in 3000:
			g.step(1.0 / 60.0, g.bar + g.size * 0.5 < g.fish)  # sube cuando el pez va por encima del centro de la barra
			if g.done:
				break
		assert(g.done, "%s: el minijuego termina" % kind)
	var easy = FG.new()
	easy.setup("smooth", 10.0, 0.6)
	for i in 3000:
		easy.fish = easy.bar + easy.size * 0.5  # el pez no se mueve de la barra
		easy.step(1.0 / 60.0, false)
		if easy.done:
			break
	assert(easy.won and easy.perfect, "con el pez siempre dentro se gana perfecto")
	var lost = FG.new()
	lost.setup("dart", 90.0, 0.2)
	lost.fish = 0.95
	lost.bar = 0.0
	lost.target = 0.95
	lost.retarget = 99.0
	for i in 3000:
		lost.step(1.0 / 60.0, false)
		if lost.done:
			break
	assert(lost.done and not lost.won and not lost.perfect, "sin tocar el clic el pez se escapa")

	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	main.save_path = "user://test_fishing_save.json"
	await process_frame
	var cr = main.crafting
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/fishing.json"))
	for id: String in cfg["fish"]:
		assert(cr.cfg["materials"].has(id) and FileAccess.file_exists("res://art/items/%s.png" % id), "%s es un material con icono" % id)
	assert(main.prog.equipment.has("cana_madera") and main.prog.equipment["cana_hierro"]["tool"]["kind"] == "rod", "las cañas existen como herramientas")
	for k in ["fish_cast", "fish_wait", "fish_reel"]:
		assert(main.hero.sprite_frames.has_animation("%s_S" % k) and main.hero.sprite_frames.has_animation("%s_NW" % k), "animación %s en todas las direcciones" % k)

	main.give_item("cana_madera")
	assert(main.hotbar.has("cana_madera"), "la caña equipada entra en la barra")
	var fishing: Node2D = preload("res://scripts/fishing.gd").new()
	main.add_child(fishing)
	fishing.setup(main)
	# tabla de peces: la distancia y la caña desbloquean los raros
	main.clock.hour = 23.0  # de noche y con lluvia salen los peces que solo pican entonces
	main.clock.rain = true
	var near := {}
	var deep := {}
	for i in 3000:
		near[fishing.roll(1.0, 1)["id"]] = true
		deep[fishing.roll(9.0, 3)["id"]] = true
	assert(not near.has("pez_abisal") and not near.has("pez_cristal") and not near.has("anguila_luminosa"), "cerca y con caña básica solo salen peces comunes")
	assert(near.has("sardina") and near.has("alga_marina"), "lo común y la basura salen")
	assert(deep.has("pez_cristal") and deep.has("pez_ceniza") and deep.has("anguila_luminosa"), "lejos y con buena caña salen los raros")
	main.clock.hour = 12.0
	main.clock.rain = false
	for i in 1500:
		var rid: String = fishing.roll(9.0, 3)["id"]
		assert(rid != "anguila_luminosa" and rid != "pez_cristal" and rid != "pez_lanza" and rid != "pez_abisal", "de día y sin lluvia no pican los peces nocturnos ni de lluvia")

	# ciclo completo en la orilla norte de la isla
	main.fishing = fishing
	cfg = fishing.cfg
	cfg["junk_chance"] = 0.0
	cfg["bite_wait"] = [0.1, 0.1]
	main.pos = main.tile_to_ground(Vector2(1.5, 27.5))
	main._place()
	main.forced_aim = (main.tile_to_ground(Vector2(0.5, 27.5)) - main.tile_to_ground(Vector2(1.5, 27.5))).normalized()
	main._select(main.hotbar.find("cana_madera"))
	main.cooldown = 0.0
	assert(main._attack("light") and main._fishing() and fishing.state == "charge", "el clic con la caña empieza a cargar el lanzamiento")
	var waited := 0.0
	while fishing.state != "bite" and waited < 8.0 and main._fishing():
		await _wait(0.1)
		waited += 0.1
	assert(fishing.state == "bite", "el flotador cae al agua y pica (estado: %s)" % fishing.state)
	assert(fishing.hooked["id"] != "" and not fishing.hooked["junk"], "pica un pez")
	var id: String = fishing.hooked["id"]
	var before: int = cr.count(id)
	fishing.press()
	assert(fishing.state == "fight" and fishing.game != null, "clavar el anzuelo abre el minijuego")
	var t := 0.0
	while fishing.state == "fight" and t < 20.0:
		fishing.game.fish = fishing.game.bar + fishing.game.size * 0.5
		fishing.game.target = fishing.game.fish
		fishing.game.retarget = 99.0
		await _wait(0.05)
		t += 0.05
	assert(cr.count(id) >= before + 1, "la captura llega a la bolsa (%s)" % id)
	await _wait(1.2)
	assert(not main._fishing(), "al terminar el héroe vuelve a estar libre")

	# lanzar a tierra no pesca nada
	main.pos = main.tile_to_ground(Vector2(20.5, 20.5))
	main._place()
	main.forced_aim = Vector2(1, 0.3).normalized()
	main.cooldown = 0.0
	main._attack("light")
	waited = 0.0
	while main._fishing() and waited < 4.0:
		await _wait(0.1)
		waited += 0.1
	assert(not main._fishing(), "lanzar a tierra cancela la pesca")

	# esquivar recoge el sedal
	main.pos = main.tile_to_ground(Vector2(1.5, 27.5))
	main._place()
	main.forced_aim = (main.tile_to_ground(Vector2(0.5, 27.5)) - main.tile_to_ground(Vector2(1.5, 27.5))).normalized()
	main.cooldown = 0.0
	main._attack("light")
	assert(main._fishing())
	main._dash()
	assert(not main._fishing(), "el dash cancela la pesca")

	# usos: cocina y alquimia con peces, venta
	while cr.favorite_dish(main.clock.day) == "pescado_asado":  # el plato favorito del día multiplica los efectos
		main.clock.day += 1
	cr.add("carpa_dorada", 1)
	assert(cr.why_not("pescado_asado") == "", "la carpa se cocina")
	cr.craft("pescado_asado")
	assert(cr.count("pescado_asado") == 1)
	main.hero_hp = 10
	cr.use(main, "pescado_asado")
	assert(main.hero_hp == 65, "el pescado asado cura 55")
	cr.learn("plano_elixir_marea")
	for item: String in ["frasco_vacio", "pez_cristal", "alga_marina"]:
		cr.add(item, 2)
	assert(cr.brew("plano_elixir_marea")["ok"] and cr.count("elixir_marea") == 1, "el pez cristal y las algas se destilan en un elixir")
	var shop_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop.json"))
	for id2: String in cfg["fish"]:
		assert(shop_cfg["smith"]["buys"].has(id2), "Bram compra %s" % id2)
	assert(cr.cfg["recipes"]["cana_cristal"]["inputs"].has("pez_cristal"), "la caña de cristal pide un pez cristal")
	print("PASS fishing: minijuego, tabla de peces, ciclo completo, cancelar, cocina, alquimia y venta")
	quit()
