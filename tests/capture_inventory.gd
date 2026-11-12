extends SceneTree
# Captura de la mochila con nombres bajo cada objeto y paginación. Ejecutar sin --headless: guarda en production/qa/evidence/barra/.

const DIR := "res://production/qa/evidence/barra/"

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.save_path = "user://capture_inv_save.json"
	main.testing = true
	await create_timer(0.8, true, false, true).timeout
	for id: String in ["hacha_piedra", "pico_piedra", "armadura_cuero", "anillo_vigor", "collar_hueso", "katana_obsidiana"]:
		main.give_item(id)
	for id: String in main.crafting.cfg["materials"]:
		main.crafting.add(id, 3)
	main.crafting.add("carne_asada", 2)
	main.crafting.add("pocion_mana", 1)
	main.menu.visible = true
	main.menu.selected = "carne_asada"
	main.menu.refresh()
	await create_timer(0.3, true, false, true).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR + "5_mochila_pag1.png")
	main.menu.page = 1
	main.menu.refresh()
	await create_timer(0.3, true, false, true).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR + "6_mochila_pag2.png")
	quit()
