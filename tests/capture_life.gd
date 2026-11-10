extends SceneTree
# Capturas reales (sin --headless) de la vida ambiental: civil, conejos y zorro en el exterior.

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
	main.set_physics_process(false)  # el héroe quieto; el mundo sigue vivo
	main.dragon.set_physics_process(false)
	var v: Node = main.villagers[0]
	main.pos = v.work + Vector2(40, 10)
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	await _shot("life_villager", 1.5)
	var fox: Node = main.predators[0]
	main.pos = (fox.den + main.fauna[0].home) / 2.0 + Vector2(0, 60)
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	await _shot("life_fox_rabbits", 3.0)
	main.pos = fox.den + Vector2(60, 20)
	main.cam.position = (main.pos - Vector2(0, 40)) * main.SCALE
	await _shot("life_fox_warn", 0.6)
	print("PASS life captures saved")
	quit()
