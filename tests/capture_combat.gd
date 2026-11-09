extends SceneTree
# Capturas reales (ejecutar sin --headless): exterior, dungeon con marca de Ignis, telegráfico y detonación.

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
	main.set_physics_process(false)
	main.dragon.set_physics_process(false)
	await _shot("combat_exterior", 0.6)
	main._enter_dungeon()
	for e in main.enemies:
		e.set_physics_process(false)
	main._place()
	var mage: Node = main.spawn_enemy("storm_mage", main.pos + Vector2(40, 30))
	var archer: Node = main.spawn_enemy("skeleton_archer", main.pos + Vector2(-110, 40))
	for e in [mage, archer]:
		e.set_physics_process(false)
	archer.state = "windup"
	archer.t = 0.15
	archer.aim = (main.pos - archer.pos).normalized()
	main.combat.mark(mage)
	main.spawn_projectile("hero", main.pos + Vector2(0, 60), Vector2.RIGHT, main.items["grimorio_ignis"]["heavy"])
	await _shot("combat_dungeon_mark", 0.3)
	main.current = main.items["katana_ceniza"]["heavy"]
	main.current_mode = "heavy"
	main.aim_dir = (mage.pos - main.pos).normalized()
	main._strike()
	await _shot("combat_ignis_detonation", 0.08)
	print("PASS combat captures saved")
	quit()
