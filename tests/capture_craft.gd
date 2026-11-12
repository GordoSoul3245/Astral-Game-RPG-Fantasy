extends SceneTree
# Capturas de la creación: pueblo con mesa, fogata y mina; mesa de alquimia a mitad de preparación; forja; cocina; pestaña Crafteo;
# recolección y la mina por dentro. Ejecutar sin --headless: guarda en production/qa/evidence/creacion/.

const DIR := "res://production/qa/evidence/creacion/"
var main: Node

func _initialize() -> void:
	call_deferred("capture")

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR + name + ".png")

func _wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	main.save_path = "user://capture_craft_save.json"
	main.testing = true
	await _wait(0.8)
	var cr = main.crafting
	# pertrechos para que los paneles se vean completos
	for id: String in ["madera", "piedra", "mena_hierro", "carbon", "lingote_hierro", "cuero", "carne_conejo", "carne_zorro", "hierba_vital", "baya_roja", "frasco_vacio", "gel_slime", "hongo_luminoso", "cristal_arcano", "nucleo_tormenta", "ojo_ciclope", "hueso_antiguo"]:
		cr.add(id, 5)
	cr.add("pocion_mana", 2)
	cr.add("carne_asada", 3)
	cr.add("estofado_zorro", 1)
	for b in ["plano_pocion_mana", "plano_pocion_vigor", "plano_elixir_furia", "plano_elixir_celeridad", "plano_frasco_ignis", "plano_pocion_vida_mayor"]:
		cr.learn(b)
	# 1) el pueblo: mesa de alquimia y fogata junto al mercader
	var table: Dictionary = main.stations.filter(func(s: Dictionary) -> bool: return s["station"] == "alchemy")[0]
	main.pos = main.tile_to_ground(table["tile"] + Vector2(3.0, 2.2))
	main._place()
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	await _wait(0.6)
	await _shot("01-pueblo-mesa-fogata")
	# 2) la entrada de la mina
	main.pos = main.tile_to_ground(Vector2(15.5, 24.4))
	main._place()
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	await _wait(0.6)
	await _shot("02-entrada-mina")
	# 3) recolectar con la mano levantada sobre un árbol
	var tree: Dictionary = main.world.node_near(main.pos, 6.0)
	if not tree.is_empty():
		main.pos = tree["g"] + Vector2(-26, 14)
		main._place()
		main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
		main._gather(tree)
		await _wait(0.28)
		await _shot("03-recolectando")
		await _wait(0.5)
	# 4) mesa de alquimia a mitad de la preparación, con su plano
	main.station_ui.open("alchemy")
	await _wait(0.3)
	var al: Node = main.station_ui.content
	al.select_plano("plano_elixir_furia")
	for id: String in cr.cfg["blueprints"]["plano_elixir_furia"]["inputs"]:
		al.placed[id] = true
	al.catalyst_on = true
	al.refresh()
	await _wait(0.3)
	await _shot("04-alquimia-listo")
	al.start_brew()
	await _wait(1.9)
	await _shot("05-alquimia-preparando")
	await _wait(2.0)
	await _shot("06-alquimia-resultado")
	main.station_ui.close()
	# 5) forja con una espada seleccionada y el martillo en acción
	main.station_ui.open("forge")
	await _wait(0.3)
	var fg: Node = main.station_ui.content
	fg.selected = "espada_hierro"
	fg.refresh()
	await _wait(0.2)
	await _shot("07-forja-lista")
	fg.start_craft()
	await _wait(0.55)
	await _shot("08-forja-golpe")
	await _wait(1.4)
	await _shot("09-forja-resultado")
	main.station_ui.close()
	# 6) cocina
	main.station_ui.open("cook")
	await _wait(0.3)
	var ck: Node = main.station_ui.content
	ck.selected = "estofado_zorro"
	ck.refresh()
	ck.start_craft()
	await _wait(0.8)
	await _shot("10-cocina")
	await _wait(1.0)
	main.station_ui.close()
	# 7) pestaña Crafteo del menú
	main.menu.tab = "craft"
	main.menu.visible = true
	main.menu.refresh()
	main.get_tree().paused = true
	await _wait(0.3)
	await _shot("11-menu-crafteo")
	main.menu.visible = false
	main.get_tree().paused = false
	# 8) la mina por dentro
	main._enter_mine()
	await _wait(0.9)
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	await _shot("12-mina-entrada")
	var ore: Dictionary = main.world.node_near(main.pos, 30.0)
	if not ore.is_empty():
		main.pos = ore["g"] + Vector2(-30, 20)
		main._place()
		main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
		await _wait(0.8)
		await _shot("13-mina-veta")
	# 9) el yunque de Bram dentro de su casa
	main._exit_mine()
	main._enter_interior("forge")
	await _wait(0.9)
	main.pos = main.tile_to_ground(Vector2(3.1, 5.4))
	main._place()
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	await _wait(0.6)
	await _shot("14-yunque-bram")
	print("PASS craft captures saved")
	quit()
