extends SceneTree
# Combate: marca de Ignis, detonación con el pesado, recuperación/telegráfico enemigo y limpieza de luces.

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func _enemy(id: String, off: Vector2) -> Node2D:
	var e: Node2D = main.spawn_enemy(id, main.pos + off)
	e.set_physics_process(false)
	return e

func _heavy_at(e: Node) -> void:  # tajo pesado de la katana apuntado al enemigo
	main.current = main.items["katana_ceniza"]["heavy"]
	main.current_mode = "heavy"
	main.burn_t = 0.0
	main.aim_dir = (e.pos - main.pos).normalized()
	main._strike()

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.dragon.set_physics_process(false)
	main.dragon.alive = false
	await process_frame
	var c: Node = main.combat
	var dur: float = c.mark_spec["duration"]

	# marca: aplica, refresca, caduca
	var a := _enemy("storm_mage", Vector2(30, 0))
	c.mark(a)
	assert(c.marks.has(a))
	c.marks[a] = 0.5
	c.mark(a)
	assert(is_equal_approx(c.marks[a], dur))
	c._process(dur + 0.1)
	assert(not c.marks.has(a))

	# el pesado consume la marca una sola vez y la explosión añade daño
	var heavy := roundi(40 * main.prog.melee_mult())
	var blast := roundi(c.mark_spec["damage"] * main.prog.magic_mult())
	c.mark(a)
	var hp0: int = a.hp
	_heavy_at(a)
	assert(not c.marks.has(a))
	assert(a.hp == hp0 - heavy - blast, "hp %d esperado %d" % [a.hp, hp0 - heavy - blast])
	hp0 = a.hp
	_heavy_at(a)
	assert(a.hp == hp0 - heavy)
	# el ligero no consume
	c.mark(a)
	main.current = main.items["katana_ceniza"]["light"]
	main.current_mode = "light"
	main._strike()
	assert(c.marks.has(a))

	# la explosión no consume otras marcas (no hay cadena) y no duplica botín
	var b := _enemy("slime", Vector2(30, 14))
	c.mark(b)
	var xp0: int = main.prog.xp
	c.detonate(a.pos)
	assert(c.marks.has(b) and c.marks.has(a))
	b.take_damage(999)
	b.take_damage(999)
	c.detonate(b.pos)
	assert(main.prog.xp == xp0 + 10, "xp %d" % (main.prog.xp - xp0))
	assert(not b.alive)

	# enemigos muertos no actúan
	b.state = "windup"
	b._physics_process(0.5)
	assert(b.state == "windup")

	# arquero: dirección fijada al avisar y recuperación castigable
	var r := _enemy("skeleton_archer", Vector2(-120, 0))
	r.state = "chase"
	r.cd = 0.0
	r._physics_process(0.016)
	assert(r.state == "windup")
	var locked: Vector2 = r.aim
	main.pos += Vector2(0, 60)  # el héroe se aparta: la flecha sigue la línea avisada
	r._physics_process(0.6)
	assert(r.state == "recover" and r.aim == locked)
	var p0: Vector2 = r.pos
	r._physics_process(0.3)
	assert(r.state == "recover" and r.pos == p0)
	r._physics_process(0.2)
	assert(r.state == "chase")
	# el pesado interrumpe el aviso de un ligero, no el del cíclope
	r.state = "windup"
	r.knock(Vector2(100, 0), true)
	assert(r.state == "recover")
	a.state = "windup"
	a.knock(Vector2(100, 0), true)
	assert(a.state == "windup" and a.kb.length() < 30.0)
	main.pos -= Vector2(0, 60)

	# el aviso del suelo coincide con la colisión (elipse 0.6 en Y)
	var zr := 40.0
	for case in [[Vector2(zr + 8.0 - 1.0, 0), true], [Vector2(zr + 9.0, 0), false], [Vector2(0, (zr + 8.0) * 0.6 - 1.0), true], [Vector2(0, (zr + 8.0) * 0.6 + 1.0), false]]:
		main.hero_hp = main.hero_max_hp
		main.reaction_time = 0.0
		var z := Node2D.new()
		z.set_script(load("res://scripts/zone.gd"))
		z.main = main
		z.center = main.pos - case[0]
		z.radius = zr
		z.delay = 0.1
		main.add_child(z)
		z._process(0.2)
		assert((main.hero_hp < main.hero_max_hp) == case[1], "zona %s" % case[0])
		z.queue_free()

	# un enemigo muerto cancela su onda pendiente
	main.hero_hp = main.hero_max_hp
	main.reaction_time = 0.0
	a._spawn_zone(main.pos, 50.0, 0.5, 20, false, Color.RED)
	var pending: Node = a.zones[-1]
	a.take_damage(9999)
	await process_frame
	assert(not is_instance_valid(pending))

	# pausa de impacto: el pesado congela solo animaciones, poco tiempo, y no se acumula por objetivo
	var hs := _enemy("skeleton_archer", Vector2(40, 0))
	await create_timer(0.2).timeout
	c.hit(hs, 1, "heavy", main.pos)
	assert(main.hero.speed_scale == 0.0 and hs.spr.speed_scale == 0.0, "pausa de impacto activa")
	var until: int = c.stop_until
	c.hit(hs, 1, "heavy", main.pos)
	assert(c.stop_until == until, "un segundo objetivo no acumula pausa")
	await create_timer(0.1).timeout
	assert(main.hero.speed_scale == 1.0 and hs.spr.speed_scale == 1.0, "la pausa termina")
	c.hit(hs, 1, "light", main.pos)
	assert(main.hero.speed_scale == 1.0, "el ligero no pausa")

	# luces: los destellos se borran solos y el ambiente cambia con el mapa
	await create_timer(1.2).timeout
	var lights := main.find_children("*", "PointLight2D", true, false).size()
	c.flash(main.pos, Color.ORANGE, 1.0, 2.0, 0.2)
	assert(main.find_children("*", "PointLight2D", true, false).size() == lights + 1)
	await create_timer(0.4).timeout
	var after := main.find_children("*", "PointLight2D", true, false).size()
	assert(after == lights, "luces %d -> %d" % [lights, after])
	main._enter_dungeon()
	assert(c.ambient.color == c.AMBIENT_DUNGEON and c.lantern.energy > 0.0)
	c.mark(main.enemies[-1])
	main._exit_dungeon()
	assert(c.ambient.color == c.AMBIENT_OUT and c.lantern.energy == 0.0 and c.marks.is_empty())
	print("PASS combat: marca Ignis, detonación única, recover, telegráfico=daño, luces")
	quit()
