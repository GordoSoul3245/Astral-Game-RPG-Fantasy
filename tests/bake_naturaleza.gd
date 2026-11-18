extends SceneTree
# Hornea a PNG el aspecto actual (con shaders) del pasto, el agua y los árboles vivos, con fondo transparente:
# art/naturaleza/pasto_casilla.png, agua_orilla.png, agua_centro.png y arbol_1..4.png. Ejecutar sin --headless.
# Son fotos fijas para colocar o pintar a mano; en el juego siguen siendo los nodos animados (GrassTile, WaterPatch, LivingTree).

const DIR := "res://art/naturaleza/"
const CELL := Vector2(128, 64)

func _initialize() -> void:
	call_deferred("run")

func _corner(i: float, j: float) -> Vector2:
	return Vector2(i - j, i + j - 1.0) * CELL / 2.0

func _shot(node: Node2D, size: Vector2i, origin: Vector2, name: String) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	node.position = origin
	vp.add_child(node)
	await create_timer(0.6, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if name.begins_with("agua"):  # solo el rombo de la casilla
		for y in img.get_height():
			for x in img.get_width():
				if absf(x + 0.5 - 65.0) / 64.0 + absf(y + 0.5 - 33.0) / 32.0 > 1.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
	img.save_png(DIR + name + ".png")
	vp.queue_free()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	# una casilla de pasto
	var g := GrassTile.new()
	g.cell = CELL
	await _shot(g, Vector2i(140, 110), Vector2(70, 70), "pasto_casilla")
	# agua: una casilla de orilla (sola, rodeada de tierra) y una del centro (dentro de un lago grande)
	for v in [["agua_orilla", 0], ["agua_centro", 3]]:
		var water := {}
		for i in range(-v[1], v[1] + 1):
			for j in range(-v[1], v[1] + 1):
				water[Vector2i(i, j)] = true
		var w := WaterPatch.new()
		w.build(water, _corner)
		await _shot(w, Vector2i(130, 66), Vector2(65, 33) - _corner(0.5, 0.5), v[0])
	# árboles
	for k in 4:
		var t := LivingTree.new()
		t.seed_value = 3 + k * 7
		await _shot(t, Vector2i(260, 380), Vector2(130, 350), "arbol_%d" % (k + 1))
	print("BAKE_OK")
	quit()
