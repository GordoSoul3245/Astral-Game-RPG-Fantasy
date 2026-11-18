extends SceneTree
# Captura del inventario-libro (diseño de PixelLab) con objetos, y de Estadísticas abierta desde el botón del HUD.
# Ejecutar sin --headless. Deja PNG en production/qa/evidence/inventario/.
const DIR := "res://production/qa/evidence/inventario/"
var main: Node

func _initialize() -> void:
	call_deferred("run")

func _shot(name: String) -> void:
	await create_timer(0.4, true, false, true).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR + name)

func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.save_path = "user://capture_inventario_save.json"
	main.testing = true
	await create_timer(1.5, true, false, true).timeout
	main.prog.coins = 125
	main.prog.potions = 3
	for id: String in main.prog.equipment.keys().slice(0, 6):
		main.prog.owned.append(id)
	main.prog.equip(main.prog.owned[0])
	main.prog.materials["madera"] = 12
	main.hero_hp = 70
	main.menu.selected = main.prog.owned[1]
	main.menu.open_tab("inv")
	await _shot("libro.png")
	main.menu.visible = false
	paused = false
	main.menu.open_tab("stats")
	await _shot("estadisticas_desde_hud.png")
	quit()
