extends SceneTree
# Movimiento de entidades: rodean un muro (world.way), varias zonas del mismo instante pegan una vez,
# y embestir o saltar ocupa turno de ataque (can_prepare).

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.save_path = "user://pathing_save.json"
	await process_frame
	main._enter_dungeon()
	await create_timer(0.5).timeout
	var w: Node = main.world
	var n: int = main.DUNGEON_TILES
	var rows: Array = []
	for i in n:  # muro en la columna x = 10, con hueco abajo (y >= n - 3)
		var r := ""
		for j in n:
			r += "0" if i == 10 and j < n - 3 else "1"
		rows.append(r)
	w.setup({"tiles": n, "walk": rows})
	var from: Vector2 = main.tile_to_ground(Vector2(5.5, 5.5))
	var to: Vector2 = main.tile_to_ground(Vector2(15.5, 5.5))
	var probe := RefCounted.new()
	assert(w.way(from, to, 0.3, probe) != to, "con el muro en medio no va en línea recta")
	var p := from
	var steps := 0
	while p.distance_to(to) > 4.0 and steps < 4000:
		var d: Vector2 = w.way(p, to, 0.3, probe) - p
		p = w.move_collide(p, p + d.normalized() * minf(2.0, d.length()), 0.3)
		steps += 1
	assert(p.distance_to(to) <= 4.0, "rodea el muro por el hueco y llega (%d pasos)" % steps)
	var open_to: Vector2 = main.tile_to_ground(Vector2(5.5, 15.5))
	assert(w.way(from, open_to, 0.3, probe) == open_to, "sin obstáculo va directo")

	main.hurt_iframes = 0.0
	var hp0: int = main.hero_hp
	main.attacking = true  # atacando no hay animación de herida que proteja
	main.damage_hero(10)
	main.damage_hero(10)
	main.damage_hero(10)
	var hp1: int = main.hero_hp
	assert(hp0 - hp1 > 0 and hp0 - hp1 <= 10, "tres zonas en el mismo instante pegan una vez (%d)" % (hp0 - hp1))
	main.attacking = false
	await create_timer(0.4).timeout
	main.reaction_time = 0.0
	main.damage_hero(10)
	assert(main.hero_hp < hp1, "pasado el margen vuelve a recibir daño")

	var foes: Array = main.enemies.filter(func(e: Node) -> bool: return e != main.dragon and e.alive and e.get("state") is String)
	assert(foes.size() >= 3, "hay monstruos para probar el turno")
	for e in foes:
		e.set_physics_process(false)
		e.state = "idle"
	foes[0].state = "charge"
	foes[1].state = "air"
	foes[1].air_hit = true
	assert(not main.can_prepare(foes[2]), "una embestida y un salto de ataque ocupan los dos turnos")
	foes[1].air_hit = false
	assert(main.can_prepare(foes[2]), "un salto de reposición no ocupa turno")
	main.dashing = true
	main.dash_t = main.dash_time_cur * 0.2
	assert(main.dash_iframes(), "al empezar el dash es invulnerable")
	main.dash_t = main.dash_time_cur * 0.9
	assert(not main.dash_iframes(), "en el frenado final ya no")
	main.dashing = false
	foes[2].slow_t = 1.0
	foes[2].state = "recover"
	foes[2].t = 5.0
	foes[2].set_physics_process(true)
	await create_timer(0.5).timeout
	assert(foes[2].slow_t < 0.8, "el hielo se va gastando aunque no camine (%.2f)" % foes[2].slow_t)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.save_path))
	print("PASS pathing: rodean muros, golpes simultáneos cuentan una vez y embestir o saltar ocupa turno")
	quit()
