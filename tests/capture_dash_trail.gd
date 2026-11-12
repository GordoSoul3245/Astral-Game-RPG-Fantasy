extends SceneTree
# Captura la estela del dash a mitad y al final del recorrido (ejecutar sin --headless).

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	await create_timer(0.6).timeout
	main.forced_input = Vector2(1, -1)
	main.stamina = main.hero_data["stamina"]
	main.dash_cd = 0.0
	main._dash()
	await create_timer(main.dash_time_cur * 0.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/dash_trail_mid.png")
	await create_timer(main.dash_time_cur * 0.4 + 0.05).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/dash_trail_end.png")
	print("PASS dash trail captures saved")
	quit()
