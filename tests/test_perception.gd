extends SceneTree
# Percepción: ver al héroe, perderlo, buscar en la última posición vista y volver a idle.

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

	var e: Node2D = main.spawn_enemy("skeleton_archer", main.pos + Vector2(-120, 0))  # como test_combat: ese punto es transitable
	e.set_physics_process(false)
	var rng: float = e.data["detect_range"]
	var dir := Vector2.LEFT  # dirección libre de colisión desde el punto de aparición
	for c: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		if main.world.move_collide(e.pos, e.pos + c * 5.0, e.data["r_t"]).distance_to(e.pos) > 1.0:
			dir = c
			break

	# fuera de alcance: sigue en idle
	main.pos = e.pos - dir * rng * 2.0
	e._physics_process(0.016)
	assert(e.state == "idle", "lejos: idle")

	# a la vista: persigue y recuerda dónde está el héroe
	main.pos = e.pos + dir * 60.0
	var seen: Vector2 = main.pos
	e._physics_process(0.016)
	assert(e.state in ["chase", "windup"], "a la vista: persigue, estado %s" % e.state)
	assert(e.last_seen == seen)

	# lo pierde (más allá del umbral de pérdida): va a la última posición vista, no a la real
	e.state = "chase"
	e.cd = 99.0
	main.pos = e.pos - dir * (rng * e.LOSE_MULT + 50.0)
	var d0: float = e.pos.distance_to(seen)
	e._physics_process(0.1)
	assert(e.state == "chase" and e.last_seen == seen, "sigue buscando, no se rinde al instante")
	assert(e.pos.distance_to(seen) < d0, "se acerca a la última posición vista (d0 %.1f, ahora %.1f, pos %s, seen %s, estado %s)" % [d0, e.pos.distance_to(seen), e.pos, seen, e.state])

	# histéresis: entre detección y pérdida sigue viéndolo
	var held := false  # alguna dirección con línea libre: persiguiendo sí lo ve, en idle no
	for c: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		main.pos = e.pos + c * (rng * 1.2)
		e.state = "chase"
		if e._sees(rng * 1.2):
			e.state = "idle"
			assert(not e._sees(rng * 1.2), "en idle no lo ve más allá de detect_range")
			held = true
			break
	assert(held, "lo sigue viendo entre detect y lose")
	e.state = "chase"

	# búsqueda agotada: vuelve a idle
	main.pos = e.pos - dir * (rng * e.LOSE_MULT + 50.0)
	for i in 10:
		e._physics_process(0.5)
	assert(e.state == "idle", "tras SEARCH_TIME vuelve a idle, estado %s" % e.state)

	# un golpe recibido lo alerta con la posición del golpeador
	e.take_damage(1, false)
	assert(e.state == "chase" and e.last_seen == main.pos and e.lost_t == 0.0)
	print("PASS perception: ve, pierde, busca en la última posición, vuelve a idle, histéresis")
	quit()
