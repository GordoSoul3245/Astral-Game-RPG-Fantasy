extends SceneTree
# Capturas de la pesca: carga del lanzamiento, flotador en el agua, pique, minijuego y captura. Ejecutar sin --headless:
# guarda en production/qa/evidence/pesca/.

const DIR := "res://production/qa/evidence/pesca/"
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
	main.save_path = "user://capture_fishing_save.json"
	main.testing = true
	await _wait(0.8)
	main.give_item("cana_hierro")
	main.crafting.add("pez_cristal", 1)
	main.crafting.add("anguila_luminosa", 1)
	main.crafting.add("sardina", 3)
	main.pos = main.tile_to_ground(Vector2(1.5, 27.5))
	main._place()
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	main.forced_aim = (main.tile_to_ground(Vector2(0.5, 27.5)) - main.tile_to_ground(Vector2(1.5, 27.5))).normalized()
	main._select(main.hotbar.find("cana_hierro"))
	await _wait(0.5)
	main.cooldown = 0.0
	main._attack("light")
	await _wait(0.05)
	await _shot("1_cargar")
	var f: Node2D = main.fishing
	f.cfg["bite_wait"] = [1.0, 1.0]
	f.cfg["junk_chance"] = 0.0
	while f.state != "flight" and f.active:
		await _wait(0.05)
	await _wait(0.3)
	await _shot("2_lanzamiento")
	while f.state != "wait" and f.active:
		await _wait(0.05)
	await _wait(0.6)
	await _shot("3_esperando")
	while f.state != "bite" and f.active:
		await _wait(0.05)
	await _wait(0.15)
	await _shot("4_pique")
	f.press()
	f.game.setup("dart", 60.0, 0.3)
	await _wait(1.2)
	await _shot("5_minijuego")
	f.game.progress = 0.97
	f.game.fish = f.game.bar + f.game.size * 0.5
	f.game.target = f.game.fish
	f.game.retarget = 99.0
	while f.state == "fight":
		await _wait(0.05)
	await _wait(0.3)
	await _shot("6_captura")
	quit()
