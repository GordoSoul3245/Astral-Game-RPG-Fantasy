extends SceneTree
# Captura la bola de fuego del grimorio en vuelo (ejecutar sin --headless).

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	await create_timer(0.6).timeout
	main.aim_dir = Vector2(1, -0.4).normalized()
	main.spawn_projectile("hero", main.pos, main.aim_dir, main.items["grimorio_ignis"]["light"])
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/magic_orb.png")
	print("PASS magic orb capture saved")
	quit()
