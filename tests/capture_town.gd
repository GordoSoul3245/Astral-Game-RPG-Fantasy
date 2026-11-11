extends SceneTree
# Capturas reales (sin --headless): pueblo, estructura translúcida tras el héroe y misión activa.

var main: Node

func _shot(name: String, wait: float) -> void:
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/%s.png" % name)

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.save_path = "user://capture_save.json"
	main.set_physics_process(false)
	main.dragon.set_physics_process(false)
	main.quests.talk(main)  # misión activa en la HUD
	main.pos = main.tile_to_ground(Vector2(12.0, 36.5))  # junto al puesto
	main._place()  # con la física apagada el sprite no sigue a pos: lo colocamos a mano
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	await _shot("town_village", 1.2)
	# héroe justo detrás de la casa (queda tapado): la casa se vuelve translúcida
	main.pos = main.tile_to_ground(Vector2(16.0, 38.6)) + Vector2(0, -22)
	main._place()
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	await _shot("town_occlusion", 1.5)
	main.prog.coins = 160
	main.prog.materials = {"gel_slime": 5, "ojo_ciclope": 2}
	main.shop.open("merchant")
	await _shot("town_shop", 0.5)
	main.shop.open("smith")
	await _shot("town_smith", 0.5)
	main.shop.close()
	main._enter_interior("forge")
	main.pos = main.tile_to_ground(Vector2(3.4, 3.0))
	main._place()
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	await _shot("interior_forge", 0.8)
	print("PASS town captures saved")
	quit()
