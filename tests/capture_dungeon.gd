extends SceneTree
# Capturas de la dungeon procedural: un piso normal y la arena del jefe. Ejecutar sin --headless:
# guarda en production/qa/evidence/dungeon_proc/.

const DIR := "res://production/qa/evidence/dungeon_proc/"
var main: Node

func _initialize() -> void:
	call_deferred("capture")

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR + name + ".png")

func _wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	main.save_path = "user://capture_dungeon_save.json"
	main.testing = true
	await _wait(0.8)
	main.prog.level = 6
	main._enter_dungeon()
	await _wait(1.0)
	main.floors.start(3)
	main.pos = main._dungeon_spawn()
	main.cam.zoom = Vector2.ONE * 0.45
	await _wait(1.0)
	await _shot("1_piso_3_generado")
	main.floors.start(4)
	main.pos = main._dungeon_spawn()
	await _wait(1.0)
	await _shot("2_piso_4_jefe")
	quit()
