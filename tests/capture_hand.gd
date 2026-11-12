extends SceneTree
# Capturas de la barra de objetos con herramientas y consumibles, y de las animaciones de hacha, pico y beber.
# Ejecutar sin --headless: guarda en production/qa/evidence/barra/.

const DIR := "res://production/qa/evidence/barra/"
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
	main.save_path = "user://capture_hand_save.json"
	main.testing = true
	await _wait(0.8)
	main.give_item("hacha_piedra")
	main.give_item("pico_piedra")
	main.crafting.add("carne_asada", 2)
	main.prog.hand.append("carne_asada")
	main.hero_hp = 40
	main._refresh_hotbar()
	var tree: Dictionary = main.world.res_nodes.filter(func(n: Dictionary) -> bool: return n["kind"] == "tree")[0]
	main.pos = tree["g"] + Vector2(-14, 10)
	main._place()
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	await _wait(0.5)
	main._select(main.hotbar.find("hacha_piedra"))
	await _shot("1_barra_hacha")
	main.cooldown = 0.0
	main._attack("light")
	await _wait(0.33)
	await _shot("2_hacha_golpe")
	await _wait(0.6)
	main._select(main.hotbar.find("pocion_vida"))
	main.cooldown = 0.0
	main._attack("light")
	await _wait(0.3)
	await _shot("3_beber")
	await _wait(0.8)
	main._select(main.hotbar.find("carne_asada"))
	main.hero_hp = 40
	main.cooldown = 0.0
	main._attack("light")
	await _wait(0.3)
	await _shot("4_comer")
	quit()
