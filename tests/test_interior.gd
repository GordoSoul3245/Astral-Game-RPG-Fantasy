extends SceneTree
# Interiores de las casas del pueblo y diálogos: puertas, entrada/salida que restauran el exterior, muebles con
# colisión, conversaciones que dependen del estado del mundo y cuadro de diálogo (pausa, avance y cierre).

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.save_path = "user://test_save.json"
	main.set_physics_process(false)
	main.dragon.set_physics_process(false)
	await process_frame

	# puertas a las dos casas del pueblo
	var enter_doors: Array = main.doors.filter(func(d: Node2D) -> bool: return d.label.begins_with("Entrar: "))
	assert(enter_doors.size() == 2, "dos casas visitables (%d)" % enter_doors.size())
	var outside_pos: Vector2 = main.pos
	var tiles0: float = main.TILES
	var world0: Node = main.world
	var dragon_alive0: bool = main.dragon.alive

	# entrar: otra cuadrícula, NPC dentro, exterior oculto y desactivado
	main._enter_interior("forge")
	assert(main.in_interior and main.in_dungeon and main.current_interior == "forge")
	assert(main.TILES == 8.0 and main.world != world0 and not world0.visible, "cuadrícula y mapa del interior")
	assert(main.npcs.size() == 1 and main.npcs[0].display == "Mara", "Mara está dentro")
	assert(main.doors.size() == 1 and main.doors[0].label == "Salir de la casa", "solo la puerta de salida")
	assert(not main.dragon.alive and not main.dragon.visible, "el dragón no actúa dentro de una casa")

	# los muebles bloquean; el suelo libre no
	var table_center := Vector2(5.9, 5.9)  # centro de la mesa de la fragua
	assert(main.world.blocked(table_center, 0.28), "la mesa bloquea")
	assert(not main.world.blocked(Vector2(4.0, 1.5), 0.28), "el suelo libre no bloquea")
	var from_g: Vector2 = main.tile_to_ground(Vector2(4.0, 5.9))
	var to_g: Vector2 = main.tile_to_ground(table_center)
	var got: Vector2 = main.world.move_collide(from_g, to_g, 0.28)
	assert(main.ground_to_tile(got).x < 5.0 + 0.05 or got != to_g, "no atraviesa la mesa")

	# conversaciones: dependen del estado del mundo y rotan
	var mara: Node2D = main.npcs[0]
	mara.talks = 0
	var l0: Array = main.npc_lines(mara)
	assert(l0[0].find("dragón") >= 0 and l0[0].find("Mataste") < 0, "con el dragón vivo habla de él")
	main.dragon.alive = false
	main.overworld["dragon_alive"] = false
	mara.talks = 0
	var l1: Array = main.npc_lines(mara)
	assert(l1[0].find("Mataste") >= 0, "con el dragón muerto lo celebra")
	assert(mara.talks == 1, "cuenta las conversaciones")
	main.overworld["dragon_alive"] = true

	# cuadro de diálogo: pausa, completa la línea al primer toque, avanza y cierra
	var dlg: CanvasLayer = main.dialogue
	dlg.open("Mara", ["Primera línea.", "Segunda línea."])
	assert(dlg.is_open() and main.get_tree().paused and dlg.name_label.text == "Mara")
	dlg.advance()  # completa el texto que se estaba escribiendo
	assert(dlg.idx == 0 and dlg.text_label.visible_characters == -1, "el primer toque completa la línea")
	dlg.advance()
	assert(dlg.idx == 1 and dlg.text_label.text == "Segunda línea.", "avanza a la siguiente")
	dlg.advance()
	dlg.advance()
	assert(not dlg.is_open() and not main.get_tree().paused, "al terminar, cierra y reanuda")

	# salir: todo se restaura
	main._exit_interior()
	assert(not main.in_interior and not main.in_dungeon and main.npcs.is_empty())
	assert(main.TILES == tiles0 and main.world == world0 and world0.visible and main.pos == outside_pos, "vuelve al exterior donde estaba")
	assert(main.dragon.alive == dragon_alive0 and main.dragon.visible, "el dragón vuelve a su estado")

	# la segunda casa y morir dentro: despierta fuera
	main._enter_interior("den")
	assert(main.npcs[0].display == "Teo")
	main.hero_hp = 0
	main.dying = true
	main._respawn()
	assert(not main.in_interior and not main.in_dungeon and main.pos == main.start_pos, "morir dentro despierta en el pueblo")
	# el equipo se nota sobre el héroe: tono de armadura, color del tajo y brillo de collar/anillo
	assert(main.hero.self_modulate == Color.WHITE and (main.equip_aura == null or main.equip_aura.energy == 0.0), "sin equipo, aspecto base")
	main.prog.add_item("armadura_dorada")
	main.prog.add_item("katana_tormenta")
	main.prog.add_item("amuleto_tormenta")
	main._apply_stats()
	assert(main.hero.self_modulate == main.ARMOR_TINT[3], "la armadura dorada tiñe la ropa")
	main.current = main.items["katana_ceniza"]["light"]
	assert(main.sword_trail_color() == main.SWORD_TRAIL[3], "la katana de la tormenta cambia el tajo")
	assert(main.equip_aura.energy > 0.0 and main.equip_aura.color == main.AURA[3], "el amuleto brilla")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.save_path))
	print("PASS interior: casas visitables con muebles, NPC y diálogos que reaccionan al mundo")
	quit()
