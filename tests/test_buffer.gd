extends SceneTree
# Buffer de entrada: una pulsación anticipada ejecuta una sola acción, caduca y se pierde al ser herido.

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.dragon.set_physics_process(false)
	main.dragon.alive = false
	await process_frame
	main.mana = main.hero_data["mana"]

	# libre: se ejecuta al instante y no se guarda nada
	main._press("light")
	assert(main.cooldown > 0.0 and main.buf == "", "ejecución inmediata")

	# en cooldown: se guarda y se ejecuta al terminar, una sola vez
	main.attacking = false
	main.cooldown = 0.05
	main._press("light")
	assert(main.buf == "light")
	main._physics_process(0.06)
	assert(main.buf == "" and main.cooldown > 0.0, "ejecuta al terminar el cooldown")

	# una segunda pulsación sustituye a la primera (un solo slot)
	main.attacking = false
	main.cooldown = 1.0
	main._press("light")
	main._press("heavy")
	assert(main.buf == "heavy")

	# caduca: tras BUFFER_MS no ejecuta aunque ya se pueda actuar
	main.buf_until = Time.get_ticks_msec() - 1
	main.cooldown = 0.0
	main._physics_process(0.016)
	assert(main.buf == "" and main.cooldown == 0.0 and not main.attacking, "caducada: no ataca")

	# herido/muerto: la acción guardada se descarta
	main.cooldown = 1.0
	main._press("light")
	main.reaction_time = 0.2
	main._physics_process(0.016)
	assert(main.buf == "")
	main.reaction_time = 0.0

	# cancelaciones: el dash no corta preparación/impacto; el ligero cede en recuperación; el pesado no cede
	main.stamina = main.hero_data["stamina"]
	main.dash_cd = 0.0
	main.buf = ""
	main.attacking = true
	main.struck = false
	main.current_mode = "light"
	main._press("dash")
	assert(not main.dashing and main.buf == "dash", "ligero antes del impacto no cancela")
	main.struck = true
	main._try_buffer()
	assert(main.dashing and not main.attacking and main.buf == "", "ligero en recuperación cancela al dash")
	main.dashing = false
	main.dash_cd = 0.0
	main.buf = ""
	main.attacking = true
	main.struck = true
	main.current_mode = "heavy"
	main._press("dash")
	assert(not main.dashing and main.attacking, "pesado no se cancela")
	main.buf = ""

	# dash anticipado: sale al acabar el dash en curso
	main.cooldown = 0.0
	main.attacking = false
	main.dashing = false
	main.dash_cd = 0.0
	main.stamina = main.hero_data["stamina"]
	main.dash_cd = 0.0
	main._press("dash")
	assert(main.dashing)
	main._press("dash")  # segundo dash mientras dura el primero
	assert(main.buf == "dash")
	print("PASS buffer: inmediato, un slot, caduca, herido lo descarta, dash anticipado")
	quit()
