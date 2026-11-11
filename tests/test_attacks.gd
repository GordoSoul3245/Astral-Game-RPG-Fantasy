extends SceneTree
# Variedad de ataques: abanico del arquero, corona del mago, embestida del cíclope y ritmo del dragón
# (ráfaga de 3 ataques con abanico, luego se queda sin aliento y recibe más daño).

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func _enemy(id: String, off: Vector2) -> Node2D:
	var e: Node2D = main.spawn_enemy(id, main.pos + off)
	e.set_physics_process(false)
	return e

func _balls() -> int:  # proyectiles vivos en la escena (projectile.gd tiene `source` y `dead`)
	return main.get_children().filter(func(n: Node) -> bool: return n.get_script() != null and n.get("source") != null and n.get("dead") == false).size()

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.dragon.set_physics_process(false)
	main.dragon.alive = false
	await process_frame
	main.hero_hp = main.hero_max_hp

	# --- arquero: dos flechas simples y un abanico de tres con más aviso y más recuperación
	var a := _enemy("skeleton_archer", Vector2(-120, 0))
	var windups: Array[float] = []
	var fired: Array[int] = []
	for shot in 3:
		a.cd = 0.0
		a.state = "chase"
		a._physics_process(0.016)
		assert(a.state == "windup")
		windups.append(a.t)
		var before := _balls()
		a._physics_process(a.t + 0.05)
		fired.append(_balls() - before)
		assert(a.state == "recover")
		if shot == 2:
			assert(a.t > a.data["recover"] * 1.4, "el abanico deja más recuperación")
	assert(fired == [1, 1, 3], "arquero: 1, 1 y abanico de 3 (%s)" % [fired])
	assert(windups[2] > windups[0] + 0.2, "el abanico avisa más tiempo")

	# --- mago: cada quinto hechizo es una corona de orbes; el sexto sigue siendo rayo
	var m := _enemy("storm_mage", Vector2(0, -150))
	m.casts = 4
	var b4 := _balls()
	m._cast(Vector2.DOWN)  # 5.º
	assert(_balls() - b4 == 6, "corona de 6 orbes (%d)" % (_balls() - b4))
	m.casts = 5
	var zones0: int = m.zones.size()
	m._cast(Vector2.DOWN)  # 6.º
	assert(m.zones.size() > zones0, "el sexto sigue siendo rayo")

	# --- cíclope: embiste desde lejos con aviso, recto, daña una vez y queda abierto (sala abierta de la dungeon: sin obstáculos)
	main._enter_dungeon()
	await create_timer(0.8).timeout
	for e in main.enemies:
		e.set_physics_process(false)
		e.alive = false
	main.pos = main.tile_to_ground(Vector2(12.5, 12.5))
	var c := _enemy("cyclops", Vector2(0, 0))
	c.pos = main.pos + Vector2(200, 0)
	c.state = "chase"
	c.charge_cd = 0.0
	c.cd = 0.0
	main.hero_hp = main.hero_max_hp
	c._physics_process(0.016)
	assert(c.state == "windup" and c.charging, "inicia la embestida desde lejos")
	var dir0: Vector2 = c.aim
	main.pos += Vector2(0, 40)  # el héroe se aparta: la dirección ya está fijada
	c._physics_process(c.CHARGE_WINDUP + 0.05)
	assert(c.state == "charge" and c.aim == dir0, "carga recta sin perseguir")
	var p0: Vector2 = c.pos
	c._physics_process(0.1)
	assert(c.pos.distance_to(p0) > 15.0, "corre rápido")
	main.pos = c.pos + Vector2(10, 0)  # el héroe queda en su camino
	main.dashing = false
	main.reaction_time = 0.0
	c._physics_process(0.05)
	assert(main.hero_hp < main.hero_max_hp and c.charge_hit, "la embestida daña")
	var hp1: int = main.hero_hp
	c._physics_process(0.05)
	assert(main.hero_hp == hp1, "y solo una vez")
	c._physics_process(1.0)
	assert(c.state == "recover" and c.t > c.data["recover"] * 1.4 and not c.charging and c.charge_cd > 0.0, "queda abierto mucho tiempo")

	# --- dragón: ráfaga de 3 (la 2.ª en abanico) y luego se queda sin aliento
	main.dragon.alive = true
	var d: Node = main.dragon
	d.attacks = 1
	d.state = d.State.ATTACK
	d.fired = false
	var dp0 := _balls()
	d.play("attack_S")
	d.frame = d.FIRE_FRAME  # la señal frame_changed dispara sola en este fotograma
	assert(d.fired and d.frame == d.FIRE_FRAME, "disparó (fired=%s frame=%d anim=%s)" % [d.fired, d.frame, d.animation])
	var srcs: Array = main.get_children().filter(func(n: Node) -> bool: return n.get_script() != null and n.get("source") != null).map(func(n: Node) -> String: return "%s:%s" % [n.get("source"), n.get("dead")])
	assert(_balls() - dp0 == 3, "el 2.º ataque es un abanico de 3 bolas (%d; antes %d; proyectiles %s)" % [_balls() - dp0, dp0, srcs])
	d.attacks = 2
	d.state = d.State.ATTACK
	d._on_animation_finished()
	assert(d.state == d.State.TIRED and d.tired_t == d.TIRED_TIME, "tras la ráfaga se queda sin aliento")
	d.hp = 60
	d.take_damage(10, false)
	assert(d.hp == 60 - 15, "cansado recibe x1.5")
	d.set_physics_process(false)
	for i in 40:
		d._physics_process(0.1)
	assert(d.state == d.State.CHASE and d.attacks == 0, "se recupera y reinicia la ráfaga")
	d.hp = 60
	d.take_damage(10, false)
	assert(d.hp == 50, "recuperado, daño normal")
	print("PASS attacks: abanico del arquero, corona del mago, embestida del cíclope y ráfaga del dragón")
	quit()
