extends SceneTree
# Secuencia de la demo del pasto: 8 cuadros cada 0,25 s mientras el personaje de prueba cruza la rejilla, en una hoja de contacto.
# Ejecutar sin --headless: guarda production/qa/evidence/pasto/secuencia.png y un cuadro grande.

const DIR := "res://production/qa/evidence/pasto/"

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var demo: Node = load("res://scenes/grass_demo.tscn").instantiate()
	root.add_child(demo)
	await create_timer(1.0, true, false, true).timeout
	var shots: Array[Image] = []
	var crops := Image.create(4 * 480, 2 * 320, false, Image.FORMAT_RGBA8)
	for k in 8:
		await RenderingServer.frame_post_draw
		shots.append(root.get_texture().get_image())
		var c: Vector2 = demo.hero.get_global_transform_with_canvas().origin
		var cr := Image.create(240, 160, false, Image.FORMAT_RGBA8)
		cr.blit_rect(shots[k], Rect2i(Vector2i(c) - Vector2i(120, 110), Vector2i(240, 160)), Vector2i.ZERO)
		cr.resize(480, 320, Image.INTERPOLATE_NEAREST)
		crops.blit_rect(cr, Rect2i(0, 0, 480, 320), Vector2i((k % 4) * 480, (k / 4) * 320))
		await create_timer(0.25, true, false, true).timeout
	crops.save_png(DIR + "cerca_del_personaje.png")
	shots[0].save_png(DIR + "cuadro_grande.png")
	var w := shots[0].get_width() / 2
	var h := shots[0].get_height() / 2
	var sheet := Image.create(w * 4, h * 2, false, Image.FORMAT_RGBA8)
	for k in 8:
		var s := shots[k].duplicate() as Image
		s.resize(w, h, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(s, Rect2i(0, 0, w, h), Vector2i((k % 4) * w, (k / 4) * h))
	sheet.save_png(DIR + "secuencia.png")
	quit()
