extends SceneTree
# Capturas de las extensiones de pesca: noche con lluvia y una nasa lista, el minijuego con cofre y la pestaña Pesca del menú.
# Ejecutar sin --headless: guarda en production/qa/evidence/pesca_plus/.

const DIR := "res://production/qa/evidence/pesca_plus/"
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
	main.save_path = "user://capture_angling_save.json"
	main.testing = true
	await _wait(0.8)
	main.give_item("cana_hierro")
	for id in ["cebo_gusano", "cebo_carne"]:
		main.crafting.add(id, 5)
	main.crafting.add("nasa", 2)
	main.crafting.add("pez_cristal", 1)
	main.crafting.add("sardina", 2, 1)
	main.crafting.add("carpa_dorada", 1, 2)
	main.pos = main.tile_to_ground(Vector2(1.5, 27.5))
	main._place()
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	main.forced_aim = (main.tile_to_ground(Vector2(0.5, 27.5)) - main.tile_to_ground(Vector2(1.5, 27.5))).normalized()
	main.clock.hour = 22.0
	main.clock.rain = true
	main.traps.place("nasa", "water")
	main.angler.traps[0]["ready"] = 0.0
	main.bait = "cebo_carne"
	main._select(main.hotbar.find("cana_hierro"))
	await _wait(1.0)
	await _shot("1_noche_lluvia_nasa")
	# minijuego con cofre
	main.pos = main.tile_to_ground(Vector2(1.5, 27.5))
	main.cooldown = 0.0
	main._attack("light")
	var f: Node2D = main.fishing
	f.cfg["bite_wait"] = [1.0, 1.0]
	f.cfg["junk_chance"] = 0.0
	f.cfg["treasure"]["chance"] = 1.0
	f.cfg["treasure"]["delay"] = 0.1
	while f.state != "bite" and f.active:
		await _wait(0.05)
	f.press()
	f.game.setup("smooth", 40.0, 0.3)
	f.game.with_chest(0.1, 0.45, 0.25)
	await _wait(1.0)
	await _shot("2_minijuego_cofre")
	f.cancel()
	# pestaña de pesca
	main.angler.record("sardina", 30, 1)
	main.angler.record("carpa_dorada", 41, 2)
	main.angler.tank.append("pez_cristal")
	main.menu.visible = true
	main.menu._set_tab("fish")
	await _wait(0.3)
	await _shot("3_pestana_pesca")
	quit()
