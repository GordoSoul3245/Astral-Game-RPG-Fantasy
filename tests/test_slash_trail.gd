extends SceneTree
# Estela del tajo: cada ataque con animación tiene puntos de filo calibrados en las 8 direcciones; la cinta nace en trail_frame,
# deja de emitir en trail_end, queda en el mundo aunque el héroe se mueva, se corta si el ataque se interrumpe y se libera sola.
# La katana en llamas sigue exactamente la misma trayectoria.

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func _wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout

func _trail() -> Node:
	for c in main.get_children():
		if c.get_script() != null and c.get_script().resource_path.ends_with("slash_trail.gd"):
			return c
	return null

func _attack(mode: String, dir_i: int) -> Node:  # empieza un ataque y devuelve la cinta que nace
	main.forced_aim = Vector2.from_angle(dir_i * PI / 4.0)
	main.cooldown = 0.0
	main.attacking = false
	assert(main._attack(mode), "el ataque %s empieza" % mode)
	for k in 300:
		await _wait(0.01)
		if _trail() != null:
			return _trail()
	return null

func _head(t: Node, i: int) -> Vector2:  # dónde debe estar la punta de la muestra i, con el héroe donde está ahora
	var p: Array = t.pts[i]
	return main.hero.position + (Vector2(p[2], p[3]) + main.hero.offset) * main.SCALE

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	main.save_path = "user://test_slash_trail_save.json"
	main.testing = true
	await _wait(0.5)
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/blade_points.json"))
	var sub := int(table["_sub"])
	var dirs := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

	# datos: todo ataque cuerpo a cuerpo con animación tiene trayectoria calibrada y su ventana de emisión
	var melee := 0
	for id: String in main.items:
		for mode in ["light", "heavy"]:
			var spec: Dictionary = main.items[id].get(mode, {})
			if spec.get("type", "") != "melee":
				continue
			melee += 1
			var frames: int = main.ANIMS[spec["anim"]]
			assert(spec["trail_frame"] >= 1 and spec["trail_frame"] < spec["trail_end"] and spec["trail_end"] < frames, "%s/%s: la ventana de la cinta cabe en la animación" % [id, mode])
			assert(spec["trail_frame"] <= spec["strike_frame"] and spec["trail_end"] >= spec["strike_frame"], "%s/%s: la cinta cubre el momento del impacto" % [id, mode])
			assert(spec["trail_width"] > 0.0 and spec["trail_time"] > 0.0 and spec["trail_shards"] >= 0, "%s/%s: ancho, persistencia y fragmentos" % [id, mode])
			for d in dirs:
				assert(table[spec["anim"]][d].size() == (frames - 1) * sub + 1, "%s/%s/%s: una muestra por tramo de fotograma" % [id, mode, d])
	assert(melee >= 2, "hay ataques cuerpo a cuerpo que comprobar")
	var light: Dictionary = main.items["katana_ceniza"]["light"]
	var heavy: Dictionary = main.items["katana_ceniza"]["heavy"]
	assert(heavy["trail_width"] > light["trail_width"] and heavy["trail_time"] > light["trail_time"] and heavy["trail_shards"] > light["trail_shards"], "el tajo pesado se distingue del ligero en ancho, persistencia y fragmentos")
	assert(table["slash_light"]["E"] != table["slash_heavy"]["E"] and table["slash_light"]["SE"] != table["slash_light"]["E"], "cada animación y dirección tiene su propio recorrido")

	main.pos = main.tile_to_ground(Vector2(10, 30))
	main._place()
	main._select(main.hotbar.find("katana_ceniza"))
	await _wait(0.3)

	# tajo pesado hacia el sureste: nace en trail_frame, crece, termina en trail_end y se libera
	var t := await _attack("heavy", 1)
	assert(t != null, "al llegar a trail_frame nace la cinta")
	assert(t.first == heavy["trail_frame"] and t.last == heavy["trail_end"], "la cinta empieza donde dice el ataque, no en la anticipación")
	var first_tip: Vector2 = t.tips[0]
	for k in 400:
		await _wait(0.01)
		if not t.emitting:
			break
	assert(not t.emitting and t.fr == heavy["trail_end"], "al terminar el recorrido deja de emitir")
	assert(t.tips.size() == (t.last - t.first) * sub + 1, "emitió todos los tramos del barrido")
	assert(t.tips[t.tips.size() - 1].is_equal_approx(_head(t, t.last * sub)), "la cabeza de la cinta es la punta del filo en el último fotograma")
	assert(t.tips[0] == first_tip and t.bits.size() == heavy["trail_shards"], "los tramos no se mueven y quedan fragmentos")
	await _wait(1.2)
	assert(not is_instance_valid(t), "la cinta se libera sola cuando se apaga")

	# el héroe se mueve mientras ataca: lo ya emitido se queda donde estaba
	await _wait(0.6)
	t = await _attack("heavy", 0)
	var anchored: Vector2 = t.tips[0]
	main.hero.position += Vector2(150, 0)
	for k in 400:
		await _wait(0.01)
		if not t.emitting:
			break
	assert(t.tips[0] == anchored, "el primer tramo sigue en su sitio del mundo")
	assert(t.tips[t.tips.size() - 1].is_equal_approx(_head(t, t.last * sub)), "los tramos nuevos salen del héroe donde está ahora")
	main.hero.position -= Vector2(150, 0)
	await _wait(1.2)

	# interrumpido a medias: deja de emitir y se apaga
	await _wait(0.6)
	t = await _attack("heavy", 2)
	main.attacking = false
	await _wait(0.1)
	assert(not t.emitting and t.fr < t.last, "un ataque cancelado corta la emisión")
	await _wait(1.2)
	assert(not is_instance_valid(t), "y la cinta cortada también se libera")

	# otra espada: mismo recorrido, su color y su acabado (trail_fx)
	await _wait(0.6)
	main.prog.equipped["sword"] = "espada_cristal"
	var crystal: Node = await _attack("light", 3)
	var fx: Dictionary = main.prog.equipment["espada_cristal"]["trail_fx"]
	assert(crystal.pts == table["slash_light"]["SW"] and crystal.color == Color.html(main.prog.equipment["espada_cristal"]["trail"]), "la hoja de cristal usa la misma trayectoria y su color")
	assert(is_equal_approx(crystal.life, light["trail_time"] * float(fx["time"])) and crystal.shards == light["trail_shards"] + int(fx["shards"]), "y su persistencia y fragmentos")
	main.prog.equipped.erase("sword")
	await _wait(1.2)

	# katana en llamas: mismo recorrido, otro acabado
	await _wait(0.6)
	var plain: Node = await _attack("light", 3)
	var plain_pts: Array = plain.pts
	var plain_shards: int = plain.shards
	await _wait(1.2)
	main.burn_t = 30.0
	await _wait(0.6)
	var fire: Node = await _attack("light", 3)
	assert(fire.pts == plain_pts, "la espada en llamas sigue la misma trayectoria")
	assert(fire.color == Color(1.0, 0.45, 0.1) and fire.shards > plain_shards and fire.anim_key.begins_with("fslash"), "y conserva su aspecto de fuego")
	main.burn_t = 0.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.save_path))
	print("PASS slash_trail: puntos calibrados en 8 direcciones, cinta que nace, crece, se ancla al mundo y se apaga")
	quit()
