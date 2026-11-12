extends SceneTree
# Creación: recetas de manos, forja y cocina, alquimia con planos (no se gastan, catalizador duplica), consumibles y buffs,
# herramientas por nivel y recolección. Lógica pura: no necesita la escena de juego.

const Progress := preload("res://scripts/progress.gd")
const Crafting := preload("res://scripts/crafting.gd")

func _initialize() -> void:
	call_deferred("run_checks")

func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func run_checks() -> void:
	var prog = Progress.new(_read("res://data/equipment.json"))
	var cr = Crafting.new(prog, _read("res://data/crafting.json"))
	cr.rng.seed = 7

	# todo lo que usan las recetas, planos y consumibles existe y tiene icono
	for rid: String in cr.cfg["recipes"]:
		for id: String in cr.inputs_of(rid):
			assert(prog.material_names.has(id), "material conocido: %s" % id)
			assert(ResourceLoader.exists(cr.icon(id)), "icono de %s" % id)
		var out: String = cr.output_of(rid)
		assert(prog.material_names.has(out) or prog.equipment.has(out), "salida conocida: %s" % rid)
		assert(ResourceLoader.exists(cr.icon(out)), "icono de %s" % out)
	for pid: String in cr.cfg["blueprints"]:
		var bp: Dictionary = cr.cfg["blueprints"][pid]
		assert(cr.cfg["consumables"].has(bp["output"]), "el plano %s produce un consumible" % pid)
		for id: String in bp["inputs"]:
			assert(prog.material_names.has(id), "ingrediente conocido: %s" % id)
	for id: String in cr.cfg["consumables"]:
		assert(ResourceLoader.exists(cr.icon(id)), "icono de %s" % id)

	# manos: herramientas de piedra a partir de madera y piedra
	assert(cr.why_not("pico_piedra") == "Faltan materiales.", "sin materiales no se fabrica")
	assert(not cr.craft("pico_piedra")["ok"])
	cr.add("madera", 6)
	cr.add("piedra", 9)
	assert(cr.tool_tier("pickaxe") == 0 and cr.swing_power("pickaxe") == 1, "con las manos el golpe vale 1")
	var r: Dictionary = cr.craft("pico_piedra")
	assert(r["ok"] and cr.count("madera") == 3 and cr.count("piedra") == 5, "gasta lo justo (%s)" % r)
	assert(prog.equipped.get("pickaxe") == "pico_piedra", "la herramienta se equipa sola")
	assert(cr.swing_power("pickaxe") == 2 and cr.why_not("pico_piedra") == "Ya la tienes.", "no se repite el mismo equipo")
	assert(cr.craft("hacha_piedra")["ok"] and prog.equipped.get("axe") == "hacha_piedra")

	# recolección: el hierro y el carbón exigen pico de piedra; el cristal, de hierro
	assert(cr.can_gather("iron") == "", "el pico de piedra rompe hierro")
	assert(cr.can_gather("crystal") != "", "el cristal arcano exige pico de hierro")
	prog.equipped.erase("pickaxe")
	assert(cr.can_gather("iron") != "" and cr.can_gather("tree") == "", "con las manos no hay mineral, pero sí ramas y rocas")
	prog.equipped["pickaxe"] = "pico_piedra"
	var drops: Dictionary = cr.roll_drops("iron")
	assert(drops.has("mena_hierro") and drops["mena_hierro"] >= 1 and drops["mena_hierro"] <= 3, "tirada de hierro")

	# forja: mena + carbón -> lingote -> pico de hierro; sin cuero no hay espada
	cr.add("mena_hierro", 12)
	cr.add("carbon", 10)
	cr.add("madera", 2)
	for i in 6:
		assert(cr.craft("lingote_hierro")["ok"], "funde lingote %d" % i)
	assert(cr.count("lingote_hierro") == 6 and cr.count("mena_hierro") == 0 and cr.count("carbon") == 4)
	assert(cr.craft("pico_hierro")["ok"] and prog.equipped["pickaxe"] == "pico_hierro", "el pico mejor sustituye al peor")
	assert(cr.can_gather("crystal") == "" and cr.tool_tier("pickaxe") == 2)
	assert(cr.roll_drops("iron")["mena_hierro"] >= 2, "herramienta de nivel 2: un recurso extra")
	assert(cr.why_not("espada_hierro") == "Faltan materiales.")
	cr.add("cuero", 3)
	cr.add("lingote_hierro", 2)
	cr.add("madera", 5)
	assert(cr.craft("espada_hierro")["ok"] and prog.owned.has("espada_hierro"))
	assert(prog.equipped["sword"] == "espada_hierro", "la espada nueva se equipa")

	# cocina
	cr.add("carne_conejo", 2)
	assert(cr.craft("carne_asada")["ok"] and cr.count("carne_asada") == 1 and cr.count("carne_conejo") == 1)

	# alquimia: plano inicial, ingredientes, catalizador y planos que no se gastan
	assert(not cr.knows("plano_pocion_vida") and not cr.brew("plano_pocion_vida")["ok"], "sin plano no se prepara")
	assert(cr.learn("plano_pocion_vida") and not cr.learn("plano_pocion_vida"), "aprender una sola vez")
	assert(not cr.brew("plano_pocion_vida")["ok"], "faltan ingredientes")
	cr.add("frasco_vacio", 3)
	cr.add("hierba_vital", 4)
	cr.add("gel_slime", 2)
	var potions0: int = prog.potions
	var b: Dictionary = cr.brew("plano_pocion_vida")
	assert(b["ok"] and b["qty"] == 2 and prog.potions == potions0 + 2, "la poción de vida va a prog.potions (%s)" % b)
	assert(cr.knows("plano_pocion_vida"), "el plano no se gasta")
	assert(cr.count("frasco_vacio") == 2 and cr.count("hierba_vital") == 2 and cr.count("gel_slime") == 1)
	cr.add("nucleo_tormenta", 1)
	b = cr.brew("plano_pocion_vida", true)
	assert(b["ok"] and b["qty"] == 4 and cr.count("nucleo_tormenta") == 0, "el catalizador duplica el resultado (%s)" % b)
	assert(not cr.brew("plano_pocion_vida", true)["ok"], "sin ingredientes ni catalizador no se prepara")

	# buffs de comida y elixires: duran, se renuevan sin sumarse y terminan
	var base: float = prog.stat("strength")
	prog.add_buff("strength", 4.0, 10.0)
	assert(prog.stat("strength") == base + 4.0)
	prog.add_buff("strength", 2.0, 20.0)
	assert(prog.stat("strength") == base + 4.0 and prog.buffs[0]["t"] == 20.0, "renueva sin acumular")
	assert(not prog.tick_buffs(19.0) and prog.tick_buffs(2.0) and prog.stat("strength") == base, "el bonus termina")

	# cada consumible hace algo
	for id: String in cr.cfg["consumables"]:
		var c: Dictionary = cr.cfg["consumables"][id]
		assert(c.has("heal") or c.has("mana") or c.has("stamina") or c.has("buff") or c.has("bomb"), "%s hace algo" % id)
	print("PASS crafting: manos, forja, cocina, alquimia con planos, buffs y recolección por nivel de herramienta")
	quit()
