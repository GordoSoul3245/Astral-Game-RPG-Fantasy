extends SceneTree
# Capturas reales (sin --headless) de las pantallas de Magia (árbol de nodos), Pesca y Estadísticas en docs/previews/.

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
	await create_timer(1.0).timeout
	main.prog.skill_points = 3
	main.prog.learn("brasas_vivas")
	main.prog.learn("pozo_arcano")
	main.menu.open_tab("magic")
	await _shot("menu_magia", 0.5)
	main.menu.open_tab("fish")
	await _shot("menu_pesca", 0.5)
	main.menu.open_tab("stats")
	await _shot("menu_estadisticas", 0.5)
	print("PASS menu captures saved")
	quit()
