extends SceneTree
# Presión de grupo: como máximo MAX_WINDUPS avisos simultáneos; el resto espera y ataca al liberarse un hueco.

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func _windups(list: Array) -> int:
	return list.filter(func(e: Node) -> bool: return e.alive and e.state == "windup").size()

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.dragon.set_physics_process(false)
	main.dragon.alive = false
	await process_frame

	var list: Array = []
	for i in 3:
		var e: Node2D = main.spawn_enemy("skeleton_archer", main.pos + Vector2(-120, -20.0 + 20.0 * i))
		e.set_physics_process(false)
		e.state = "chase"
		e.cd = 0.0
		list.append(e)
	for e in list:
		e._physics_process(0.016)
	assert(_windups(list) == main.MAX_WINDUPS, "avisos simultáneos %d" % _windups(list))

	# sin hueco no empieza, aunque pase el tiempo
	for k in 5:
		for e in list:
			if e.state != "windup":
				e._physics_process(0.016)
	assert(_windups(list) == main.MAX_WINDUPS)

	# al liberarse un hueco (uno muere) el que esperaba prepara su ataque
	var waiting: Node = list.filter(func(e: Node) -> bool: return e.state != "windup")[0]
	var busy: Node = list.filter(func(e: Node) -> bool: return e.state == "windup")[0]
	busy.take_damage(9999, false)
	waiting._physics_process(0.016)
	assert(waiting.state == "windup", "el que esperaba ocupa el hueco")
	print("PASS pressure: máximo %d avisos simultáneos, el resto espera y ocupa el hueco" % main.MAX_WINDUPS)
	quit()
