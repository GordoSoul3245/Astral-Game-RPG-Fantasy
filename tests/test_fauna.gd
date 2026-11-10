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
	for f in main.fauna + main.predators + main.villagers:
		f.set_physics_process(false)
	assert(main.predators.size() == 1 and main.villagers.size() == 1)
	var den: Vector2 = main.predators[0].den
	assert(main.start_pos.distance_to(den) > main.predators[0].LEAVE, "el inicio queda fuera del territorio del zorro")
	assert(main.villagers[0].rest.distance_to(den) > main.villagers[0].DANGER, "el refugio del civil queda lejos del zorro")

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

	# --- zorro: caza un conejo visible, lo pierde en la madriguera, come y vuelve a descansar
	var fox: Node = main.predators[0]
	main.pos = fox.den + Vector2(600, 0)
	c.pos = fox.pos + Vector2(20, 0)
	c.state = "graze"
	fox._physics_process(0.05)
	assert(fox.state == "hunt" and fox.prey == c, "caza, estado %s" % fox.state)
	c._physics_process(0.05)
	assert(c.state == "flee", "el conejo huye del zorro")
	c.state = "graze"  # quieto para que lo alcance
	_tick(fox, 1.0)
	assert(fox.state == "eat" and c.state == "hidden" and c.pos == c.home, "lo alcanza: escapa a la madriguera, estado %s" % fox.state)
	_tick(fox, fox.EAT + 0.1)
	assert(fox.state in ["home", "rest"])
	fox.pos = fox.den
	fox.state = "rest"
	assert(fox._find_prey() == null or fox.cool > 0.0, "cansado: no vuelve a cazar enseguida")
	# se rinde al agotar la energía
	c.pos = fox.pos + Vector2(60, 0)
	c.state = "graze"
	fox.cool = 0.0
	fox._physics_process(0.05)
	fox.energy = 0.01
	fox._physics_process(0.05)
	assert(fox.state == "home" and fox.cool > 0.0, "se rinde y descansa")

	# territorio: advierte, embiste si insistes, y lo deja fuera del territorio
	fox.pos = fox.den
	fox.state = "rest"
	main.hero_hp = main.hero_max_hp
	main.reaction_time = 0.0
	main.pos = fox.den + Vector2(30, 0)
	fox._physics_process(0.05)
	assert(fox.state == "warn", "advierte primero")
	_tick(fox, 0.5)
	assert(fox.state == "warn" and main.hero_hp == main.hero_max_hp, "el aviso no daña")
	_tick(fox, 0.9)
	assert(fox.state in ["lunge", "recover"], "embiste si insistes, estado %s" % fox.state)
	_tick(fox, 0.4)
	assert(main.hero_hp < main.hero_max_hp, "la embestida muerde")
	main.reaction_time = 0.0
	main.pos = fox.den + Vector2(fox.LEAVE + 40.0, 0)
	_tick(fox, 1.2)
	assert(fox.state in ["home", "rest"], "fuera del territorio lo deja, estado %s" % fox.state)
	main.hero_hp = main.hero_max_hp

	# --- civil: va y viene, mira al héroe, retoma su destino, huye del peligro y vuelve
	var v: Node = main.villagers[0]
	main.pos = v.pos + Vector2(600, 0)
	v.pos = v.goal
	_tick(v, 0.1)
	assert(v.state == "pause")
	var g0: Vector2 = v.goal
	_tick(v, 4.2)
	assert(v.state == "walk" and v.goal != g0, "cambia de destino tras la pausa")
	var g1: Vector2 = v.goal
	main.pos = v.pos + Vector2(40, 0)
	_tick(v, 0.6)
	assert(v.state == "look", "mira al héroe, estado %s" % v.state)
	main.pos = v.pos + Vector2(75, 0)
	_tick(v, 0.6)
	assert(v.state == "look", "histéresis al mirar")
	main.pos = v.pos + Vector2(200, 0)
	_tick(v, 0.6)
	assert(v.state == "walk" and v.goal == g1, "retoma el destino pendiente")
	fox.pos = v.pos + Vector2(50, 0)
	fox.state = "warn"
	v._physics_process(0.05)
	assert(v.state == "flee", "huye del peligro")
	_tick(v, 4.0)
	assert(v.state == "hide" and v.pos.distance_to(v.rest) < 3.0, "se refugia, estado %s" % v.state)
	fox.state = "rest"
	fox.pos = fox.den
	_tick(v, v.SAFE_TIME + 0.2)
	assert(v.state in ["walk", "pause"] and v.goal == g1, "vuelve a su actividad, estado %s" % v.state)  # si su destino era el refugio, ya llegó

	# --- el mundo reacciona: ruido de combate asusta; huir alerta al grupo; hablar con el civil
	var c2: Node = main.fauna[1]
	for f in main.fauna:
		f.state = "graze"
		f.state_t = 1.0
	main.pos = c.pos + Vector2(600, 0)
	c2.pos = c.pos + Vector2(30, 0)
	main.noise(c.pos, 100.0)
	c._physics_process(0.05)
	assert(c.state == "flee", "el ruido de combate lo espanta")
	assert(c2.state == "watch", "el compañero cercano levanta las orejas")
	_tick(c, 1.2)  # el ruido caduca en main._process; aquí lo limpiamos a mano
	main.noises.clear()
	v.state = "walk"
	var g2: Vector2 = v.goal
	main.pos = v.pos + Vector2(20, 0)
	assert(main._near_villager() == v)
	var line: String = v.talk()
	assert(line != "" and v.state == "talk" and v.goal == g2, "habla sin perder su destino")
	main.dragon.alive = false
	v.goal = v.rest
	assert(v._next_goal() == v.stroll, "sin dragón, pasea más lejos")
	main.dragon.alive = true
	assert(v._next_goal() == v.work, "con dragón, no pasea")
	main.dragon.alive = false
	main.pos = v.pos + Vector2(600, 0)

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
