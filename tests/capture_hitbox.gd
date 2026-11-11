extends SceneTree
# Capturas reales (sin --headless) con las hitbox dibujadas (verde = cuerpo, azul = huella): héroe, fauna, civil y enemigos.

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
	main.debug_hitboxes = true
	main.pos = main.tile_to_ground(Vector2(12.0, 36.5))
	main._place()
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	await _shot("hitbox_village", 1.2)
	main._enter_dungeon()
	for e in main.enemies:
		e.set_physics_process(false)
	main._place()
	var list: Array = []
	for pair: Array in [["slime", Vector2(-120, 20)], ["skeleton_archer", Vector2(0, -90)], ["cyclops", Vector2(150, 40)]]:
		var e: Node2D = main.spawn_enemy(pair[0], main.pos + pair[1])
		e.set_physics_process(false)
		list.append(e)
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	list[2].poise = 45.0  # barra de postura del cíclope a medias
	await _shot("hitbox_enemies", 1.0)
	list[2].add_poise(100.0)  # se abre: barra llena y parpadeante, aviso "¡Abierto!"
	await _shot("combat_stagger", 0.3)
	print("PASS hitbox captures saved")
	quit()
