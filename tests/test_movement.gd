extends SceneTree
# Movimiento: inercia (arranque y frenado), caminar durante el ataque, cancelar la recuperación del ligero,
# dash con frenado que recorre la misma distancia, y velocidades base nuevas.

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func _hold(keys: Array) -> void:  # simula teclas pulsadas sustituyendo _input_dir
	main.forced_input = Vector2(float(keys.has("D")) - float(keys.has("A")), float(keys.has("S")) - float(keys.has("W")))

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.alive = false
	main.set_physics_process(false)
	await process_frame
	main._enter_dungeon()  # sala abierta: suelo libre en todas direcciones
	await create_timer(0.8).timeout
	main.pos = main.tile_to_ground(Vector2(12.5, 12.5))
	for e in main.enemies:
		e.set_physics_process(false)
		e.alive = false
	assert(main.WALK_SPEED == 100.0 and main.SPRINT_SPEED == 200.0, "velocidades base nuevas")

	# inercia: no alcanza la velocidad de golpe, la alcanza en ~0.11 s y frena en ~0.07 s
	_hold(["D"])
	main._physics_process(1.0 / 60.0)
	assert(main.move_vel.length() > 0.0 and main.move_vel.length() < main.WALK_SPEED, "arranca gradualmente (%.1f)" % main.move_vel.length())
	for i in 12:
		main._physics_process(1.0 / 60.0)
	assert(absf(main.move_vel.length() - main.WALK_SPEED * main.prog.move_mult()) < 1.0, "llega a la velocidad de paso (%.1f)" % main.move_vel.length())
	_hold([])
	main._physics_process(1.0 / 60.0)
	assert(main.move_vel.length() > 0.0, "no se detiene en seco")
	for i in 8:
		main._physics_process(1.0 / 60.0)
	assert(main.move_vel == Vector2.ZERO, "frena en menos de ~0.15 s")

	# caminar mientras atacas: avanza lento y no cambia de dirección ni corta el pesado
	_hold(["D"])
	main.facing = "S"
	main.current = main.items["katana_ceniza"]["heavy"]
	main.current_mode = "heavy"
	main.attacking = true
	main.struck = false
	var p0: Vector2 = main.pos
	for i in 30:
		main._physics_process(1.0 / 60.0)
	var moved: float = (main.pos - p0).length()
	assert(moved > 3.0, "el pesado permite avanzar un poco (%.1f)" % moved)
	assert(moved < main.WALK_SPEED * 0.5 and main.facing == "S", "pero muy lento y sin girar (%.1f)" % moved)
	assert(main.attacking, "caminar no corta el pesado")

	# el ligero conectado se corta caminando, tras un breve instante; antes del impacto no
	main.current = main.items["katana_ceniza"]["light"]
	main.current_mode = "light"
	main.attacking = true
	main.struck = false
	main._physics_process(1.0 / 60.0)
	assert(main.attacking, "antes del impacto no se corta")
	main.struck = true
	main.recover_t = 0.0
	main._physics_process(1.0 / 60.0)
	assert(main.attacking, "justo tras el impacto aún se ve el golpe")
	main.recover_t = main.LIGHT_CANCEL_T + 0.01
	main._physics_process(1.0 / 60.0)
	assert(not main.attacking, "caminar corta la recuperación del ligero")
	_hold([])
	main.move_vel = Vector2.ZERO
	for i in 10:
		main._physics_process(1.0 / 60.0)

	# dash con frenado: recorre la distancia prevista, rápido al principio y lento al final
	main.stamina = main.hero_data["stamina"]
	main.dash_cd = 0.0
	main.facing = "E"
	var start: Vector2 = main.pos
	main._dash()
	assert(main.dashing)
	var dt := 1.0 / 60.0
	var first := 0.0
	var last := 0.0
	var n := int(main.dash_time_cur / dt) + 2
	var prev: Vector2 = main.pos
	for i in n:
		main._physics_process(dt)
		var d: float = ((main.pos - prev) / Vector2(1, 0.6)).length()
		prev = main.pos
		if i == 3:
			first = d
		if main.dashing:
			last = d
	var total: float = ((main.pos - start) / Vector2(1, 0.6)).length()
	var expected: float = main.dash_speed_cur * main.dash_time_cur
	assert(not main.dashing and main.dash_bonus_t > 0.0, "el dash termina")
	assert(absf(total - expected) < expected * 0.08, "recorre la distancia prevista (%.1f vs %.1f)" % [total, expected])
	assert(first > last * 2.0, "frena al final (paso inicial %.2f, final %.2f)" % [first, last])
	print("PASS movement: inercia, caminar atacando, cancelar ligero, dash con frenado")
	quit()
