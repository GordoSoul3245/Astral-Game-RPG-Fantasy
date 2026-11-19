extends SceneTree
# Mapa único: cruza caminando del Bosque del Fogón al valle (sin fundido) y saca una vista alejada de todas las regiones juntas.
# Ejecutar sin --headless. Deja PNG en production/qa/evidence/mapa_unico/.
const DIR := "res://production/qa/evidence/mapa_unico/"
var main: Node

func _initialize() -> void:
	call_deferred("run")

func _shot(name: String) -> void:
	await create_timer(0.15, true, false, true).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR + name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.save_path = "user://capture_mapa_unico_save.json"
	main.testing = true
	await create_timer(1.5, true, false, true).timeout
	main.clock.hour = 12.0
	main._enter_zone("bosque")
	await create_timer(0.5, true, false, true).timeout
	var regions: Array[String] = []
	var walk: Array[Vector2] = []  # el recorrido se calcula en casillas del bosque antes de cruzar
	for k in 6:
		walk.append(main.tile_to_ground(Vector2(28.5, 4.0 - k * 1.6)))
	for k in 6:  # por el camino del norte del bosque hasta el valle, paso a paso
		main.pos = walk[k]
		main._check_edges(0.0)
		main._place()
		main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
		regions.append(main.region())
		await _shot("cruce_%d.png" % k)
	print("CRUCE regiones: ", regions)
	assert(regions[0] == "bosque" and regions[-1] == "valle", "se cruza caminando del bosque al valle")
	main.cam.zoom = Vector2.ONE * 0.12  # vista alejada: el valle y las cuatro zonas juntas
	main.cam.position = main.valley_world.position + main.tile_to_ground(Vector2(25, 25)) * main.SCALE
	await _shot("vista_general.png")
	quit()
