extends SceneTree
# Presa: pasta, observa, huye a su madriguera, se esconde, vuelve; no oscila ni actúa en la dungeon.

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func _tick(c: Node, secs: float) -> void:
	var n := int(secs / 0.05)
	for i in n:
		c._physics_process(0.05)

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.dragon.set_physics_process(false)
	main.dragon.alive = false
	await process_frame

	assert(main.fauna.size() == 3, "conejos %d" % main.fauna.size())
	for f in main.fauna:
		assert(not main.world.blocked(main.ground_to_tile(f.home), 0.2), "madriguera en casilla libre")
		assert(not main.enemies.has(f), "la fauna no entra en combate")
	var c: Node = main.fauna[0]
	for f in main.fauna:
		f.set_physics_process(false)

	# lejos: pasta cerca de casa
	main.pos = c.home + Vector2(400, 0)
	_tick(c, 3.0)
	assert(c.state == "graze" and c.pos.distance_to(c.home) <= c.GRAZE_R + 2.0, "pasta junto a la madriguera")

	# se acerca: observa (tras el tiempo mínimo), no huye todavía
	main.pos = c.pos + Vector2(100, 0)
	_tick(c, 1.0)
	assert(c.state == "watch", "observa, estado %s" % c.state)
	# histéresis: entre NOTICE y CALM sigue observando
	main.pos = c.pos + Vector2(140, 0)
	_tick(c, 1.0)
	assert(c.state == "watch", "no oscila entre observar y pastar")

	# muy cerca: huye a la madriguera y se esconde
	c.pos = c.home + Vector2(20, 0)
	main.pos = c.pos + Vector2(40, 0)
	_tick(c, 0.1)
	assert(c.state == "flee")
	_tick(c, 2.0)
	assert(c.state == "hidden" and c.pos.distance_to(c.home) < 3.0, "escondido en casa, estado %s" % c.state)

	# no sale mientras el héroe sigue cerca; sale tras SAFE_TIME con el héroe lejos
	main.pos = c.home + Vector2(100, 0)
	_tick(c, c.SAFE_TIME + 1.0)
	assert(c.state == "hidden", "con peligro cerca sigue escondido")
	main.pos = c.home + Vector2(400, 0)
	_tick(c, c.SAFE_TIME + 0.2)
	assert(c.state == "graze", "vuelve a pastar")

	# en la dungeon se oculta y no actúa
	main._enter_dungeon()
	var p0: Vector2 = c.pos
	_tick(c, 1.0)
	assert(not c.visible and c.pos == p0)
	main._exit_dungeon()
	_tick(c, 0.1)
	assert(c.visible)
	print("PASS fauna: pasta, observa, histéresis, huye, se esconde, vuelve, pausa en dungeon")
	quit()
