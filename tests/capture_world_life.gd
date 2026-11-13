extends SceneTree
# Capturas de la segunda tanda: pueblo de noche con farolas, la casa de Teo con la pecera, y el inventario con la barra abierta.
# Ejecutar sin --headless: guarda en production/qa/evidence/mundo_vivo/.

const DIR := "res://production/qa/evidence/mundo_vivo/"
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
	main.save_path = "user://capture_world_life_save.json"
	main.testing = true
	await _wait(0.8)
	main.crafting.add("carne_asada", 2)
	main.crafting.add("pocion_mana", 1)
	main.give_item("pico_piedra")
	main.give_item("cana_madera")
	main.angler.tank = ["pez_cristal", "sardina", "carpa_dorada"]
	# pueblo de noche, junto al mercader
	main.clock.hour = 21.5
	main.clock.rain = false
	var m: Node2D = main.merchants[0]
	main.pos = m.pos + Vector2(-60, 40)
	main._place()
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	await _wait(1.0)
	await _shot("1_pueblo_noche_farolas")
	# casa de Teo con la pecera
	main.clock.hour = 20.0
	main.pos = main.tile_to_ground(Vector2(0, 0))
	main._enter_interior("den")
	main.pos = main.tile_to_ground(Vector2(5.2, 4.6))
	main._place()
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	await _wait(1.0)
	await _shot("2_casa_pecera")
	main._exit_interior()
	# nasa y trampa colocadas en el mundo
	main.clock.hour = 12.0
	main.crafting.add("nasa", 1)
	main.crafting.add("trampa", 1)
	main.pos = main.tile_to_ground(Vector2(1.5, 27.5))
	main._place()
	main.forced_aim = (main.tile_to_ground(Vector2(0.5, 27.5)) - main.tile_to_ground(Vector2(1.5, 27.5))).normalized()
	main.traps.place("nasa", "water")
	main.pos = main.tile_to_ground(Vector2(3.5, 27.5))
	main._place()
	main.forced_aim = Vector2(0, 1).normalized()
	main.traps.place("trampa", "land")
	for t: Dictionary in main.angler.traps:
		t["ready"] = main.clock.total + 100.0
	main.angler.traps[0]["ready"] = 0.0
	main.pos = main.tile_to_ground(Vector2(8.5, 27.5))
	main._place()
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	main.forced_aim = Vector2(1, 0)
	await _wait(0.8)
	await _shot("4_nasa_y_trampa")
	# huerto con cultivos en distintas fases
	var farm: Node2D = main.farm
	var seeds := ["semilla_baya", "semilla_hierba", "semilla_hongo"]
	for i in farm.plots.size():
		farm.plots[i]["seed"] = seeds[i % 3]
		farm.plots[i]["growth"] = float(farm.cfg["seeds"][seeds[i % 3]]["hours"]) * [0.05, 0.4, 0.7, 1.0][i % 4]
		farm.plots[i]["wet"] = 4.0 if i % 2 == 0 else 0.0
	main.pos = main.tile_to_ground(farm.plots[5]["tile"] + Vector2(1.5, 1.5))
	main._place()
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	main.clock.hour = 12.0
	await _wait(0.8)
	await _shot("5_huerto")
	# inventario con la barra abierta
	main.menu.visible = true
	main.menu._set_tab("inv")
	main.menu.refresh()
	await _wait(0.5)
	await _shot("3_inventario_barra")
	
	# árbol de habilidades del grimorio
	main.prog.skill_points = 5
	main.prog.learn("brasas_vivas")
	main.prog.learn("pozo_arcano")
	main.prog.learn("marca_duradera")
	main.menu.visible = true
	main.menu._set_tab("magic")
	await _wait(0.4)
	await _shot("6_arbol_magia")
	
	# panel de amistad y regalos
	main.menu.visible = false
	main.crafting.add("sopa_pescado", 2)
	main.crafting.add("carbon", 3)
	main.crafting.add("hongo_luminoso", 2)
	main.social.friend["mara"] = 240
	main.social.open_for("mara")
	main.social.reply.text = "¡Justo lo que quería! Gracias de corazón."
	await _wait(0.4)
	await _shot("7_amistad_regalos")
	
	# zonas escritas a mano
	main.social.close()
	main.prog.level = 5
	main.pos = main.tile_to_ground(Vector2(10, 30))
	for id in ["pantano", "desierto"]:
		main._enter_zone(id)
		await _wait(1.2)
		main.pos = main.tile_to_ground(Vector2(14.5, 18.0))
		main._place()
		main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
		await _wait(0.6)
		await _shot("8_zona_" + id)
		main._exit_mine()
		await _wait(0.6)
	# puerta de entrada en el valle
	var door: Node2D = main.doors.filter(func(d: Node2D) -> bool: return d.label.begins_with("Camino"))[0]
	main.pos = main.tile_to_ground(door.tile) + Vector2(0, 50)
	main._place()
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	main.clock.hour = 12.0
	await _wait(0.8)
	await _shot("9_puerta_zona")
	quit()
