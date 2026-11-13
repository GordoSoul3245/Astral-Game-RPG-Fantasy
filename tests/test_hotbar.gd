extends SceneTree
# Barra de objetos editable: 6 casillas, colocar/intercambiar/quitar objetos (lo que hace el arrastre del menú), herramientas
# nuevas que entran solas, casilla vacía, y guardado con migración de partidas antiguas.

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	main.save_path = "user://test_hotbar_save.json"
	main.testing = true
	await process_frame
	var cr = main.crafting
	assert(main.hotbar.size() == 6 and main.hotbar.slice(0, 3) == ["katana_ceniza", "grimorio_ignis", "pocion_vida"] and main.hotbar[3] == "", "al empezar: katana, grimorio, poción y tres casillas libres")

	# colocar en una casilla concreta e intercambiar
	cr.add("carne_asada", 2)
	assert(main.hotbar_drop("carne_asada", 5) and main.hotbar[5] == "carne_asada", "se coloca donde se suelta")
	assert(main.hotbar_drop("carne_asada", 0) and main.hotbar[0] == "carne_asada" and main.hotbar[5] == "katana_ceniza", "si había otro objeto se intercambian")
	assert(main.hotbar_drop("pocion_vida", 4) and main.hotbar[2] == "" and main.hotbar[4] == "pocion_vida", "mover a una casilla libre deja libre la de origen")
	main.hotbar_drop("katana_ceniza", 0)
	assert(main.hotbar[0] == "katana_ceniza" and main.hotbar[5] == "carne_asada", "deshacer el intercambio")

	# soltar sobre un objeto desde la mochila: el desplazado vuelve a la mochila
	cr.add("pocion_mana", 1)
	main.hotbar_drop("pocion_mana", 1)
	assert(main.hotbar[1] == "pocion_mana" and not main.hotbar.has("grimorio_ignis"), "el grimorio sale de la barra")
	var menu: CanvasLayer = main.menu
	assert(menu._backpack().has("grimorio_ignis"), "y aparece en la mochila para volver a ponerlo")

	# quitar de la barra
	main.hotbar_clear(1)
	assert(main.hotbar[1] == "", "se vacía la casilla")
	assert(not main.hotbar_drop("armadura_cuero", 1) and main.hotbar[1] == "", "no todo cabe en la barra: la armadura no")

	# llena: hotbar_add falla, soltar sobre una casilla sigue funcionando
	for id in ["carne_asada", "pocion_vida", "pocion_mana"]:
		main.hotbar_remove(id)
	for id in ["pocion_vida", "pocion_mana", "carne_asada", "asado_zorro", "pastel_baya"]:
		cr.add(id, 1)
		main.hotbar_add(id)
	assert(not main.hotbar.has(""), "la barra se llena")
	cr.add("tostada_hongo", 1)
	assert(not main.hotbar_add("tostada_hongo"), "llena: no se añade solo")
	assert(main.hotbar_drop("tostada_hongo", 3) and main.hotbar[3] == "tostada_hongo", "pero se puede soltar sobre una casilla")

	# herramientas: las nuevas entran solas en la casilla de la anterior; soltarlas en la barra las equipa
	main.hotbar_clear(2)
	main.give_item("hacha_piedra")
	assert(main.hotbar.has("hacha_piedra"), "una herramienta nueva ocupa un sitio sola")
	var slot_axe: int = main.hotbar.find("hacha_piedra")
	main.give_item("hacha_hierro")
	assert(main.hotbar[slot_axe] == "hacha_hierro", "la herramienta mejor ocupa el sitio de la anterior")
	main.hotbar_drop("hacha_piedra", 0)
	assert(main.prog.equipped["axe"] == "hacha_piedra", "soltar una herramienta en la barra la equipa")

	# casilla vacía
	main.hotbar_clear(1)
	main._select(1)
	main.cooldown = 0.0
	assert(not main._attack("light"), "con la casilla vacía no se hace nada")

	# arrastre real de la interfaz: casilla de la mochila -> casilla de la barra, y barra -> mochila
	menu.visible = true
	menu._set_tab("inv")
	var Slot = menu.get_script().get_script_constant_map()["_Slot"]
	var from_bag = Slot.new()
	from_bag.menu = menu
	from_bag.id = "carne_asada"
	menu.add_child(from_bag)
	var target = Slot.new()
	target.menu = menu
	target.index = 1
	assert(from_bag._get_drag_data(Vector2.ZERO) is Dictionary and target._can_drop_data(Vector2.ZERO, {"id": "carne_asada", "from": -1}), "se puede arrastrar y soltar")
	target._drop_data(Vector2.ZERO, {"id": "carne_asada", "from": -1})
	assert(main.hotbar[1] == "carne_asada", "soltar en la casilla la rellena")
	var bag_slot = Slot.new()
	bag_slot.menu = menu
	assert(bag_slot._can_drop_data(Vector2.ZERO, {"id": "carne_asada", "from": 1}) and not bag_slot._can_drop_data(Vector2.ZERO, {"id": "carne_asada", "from": -1}), "la mochila solo acepta lo que viene de la barra")
	bag_slot._drop_data(Vector2.ZERO, {"id": "carne_asada", "from": 1})
	assert(main.hotbar[1] == "", "soltar sobre la mochila lo quita de la barra")
	assert(menu.bar_row.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion()).size() == 6, "el menú muestra las 6 casillas de la barra")
	menu.visible = false

	# guardado
	main.hotbar_drop("pocion_mana", 2)
	var layout: Array = main.hotbar.duplicate()
	main.save_game()
	main.prog.slots = ["", "", "", "", "", ""]
	main.hotbar = main.prog.slots
	assert(main.load_game() and main.hotbar == layout, "la disposición se guarda y se carga")
	# partida antigua: sin "slots", con "hand"
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main.save_path))
	d.erase("slots")
	d["hand"] = ["pocion_vida", "carne_asada"]
	var f := FileAccess.open(main.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	assert(main.load_game(), "se carga una partida antigua")
	assert(main.hotbar.slice(0, 2) == ["katana_ceniza", "grimorio_ignis"] and main.hotbar.has("pocion_vida") and main.hotbar.has("carne_asada") and main.hotbar.size() == 6, "y se migra a la barra nueva")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.save_path))
	print("PASS hotbar: colocar, intercambiar, quitar, herramientas, casilla vacía, arrastre del menú y guardado")
	quit()
