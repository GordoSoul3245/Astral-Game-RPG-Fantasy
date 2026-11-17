extends SceneTree
# Clip del valle en movimiento: el héroe camina entre pasto, árboles y el lago. Guarda 60 cuadros a 12 por segundo en
# production/qa/evidence/valle_vivo/ (cuadro_000.png...) para montar un vídeo con ffmpeg. Ejecutar sin --headless.

const DIR := "res://production/qa/evidence/valle_vivo/"

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
	var a: Vector2 = main.tile_to_ground(Vector2(22.0, 17.0))
	var b: Vector2 = main.tile_to_ground(Vector2(27.0, 21.0))
	for k in 60:
		main.pos = a.lerp(b, k / 59.0)
		main._place()
		main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
		await create_timer(1.0 / 12.0, true, false, true).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(DIR + "cuadro_%03d.png" % k)
	quit()
