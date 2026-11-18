extends SceneTree
# Clip del Bosque del Fogón: el héroe sube por el camino hasta la fogata del viejo. Guarda 60 cuadros a 12 por segundo en
# production/qa/evidence/bosque/ (cuadro_000.png...) para montar un vídeo con ffmpeg. Ejecutar sin --headless.

const DIR := "res://production/qa/evidence/bosque/"

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	main.save_path = "user://capture_valley_clip_save.json"
	main.testing = true
	await create_timer(1.5, true, false, true).timeout
	main.clock.hour = 11.0
	main.clock.rain = false
	main._enter_zone("bosque")
	await create_timer(1.0, true, false, true).timeout
	var a: Vector2 = main.tile_to_ground(Vector2(18.5, 16.0))
	var b: Vector2 = main.tile_to_ground(Vector2(19.0, 6.5))
	for k in 60:
		main.pos = a.lerp(b, k / 59.0)
		main._place()
		main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
		await create_timer(1.0 / 12.0, true, false, true).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(DIR + "cuadro_%03d.png" % k)
	quit()
