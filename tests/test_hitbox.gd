extends SceneTree
# Hitbox: la elipse corporal de cada entidad debe cubrir su silueta real (sprite) y no sobrar demasiado;
# los golpes en el aire se miden contra ella; las estructuras usan el tamaño real de su sprite.

var main: Node
const HB := preload("res://scripts/hitbox.gd")

func _initialize() -> void:
	call_deferred("run_checks")

func _silhouette(path: String, feet: Vector2, hit: Dictionary) -> Array:  # [cobertura, precisión] de la elipse sobre los píxeles opacos
	var img: Image = HB._image(path)
	var inside := 0
	var opaque := 0
	var ell := 0
	var c: Vector2 = feet + hit["c"]
	for y in img.get_height():
		for x in img.get_width():
			var o := img.get_pixel(x, y).a > 0.3
			var q := Vector2(x + 0.5 - c.x, y + 0.5 - c.y)
			var inn := Vector2(q.x / hit["rx"], q.y / hit["ry"]).length() <= 1.0
			if o:
				opaque += 1
				if inn:
					inside += 1
			if inn:
				ell += 1
	return [float(inside) / maxf(opaque, 1.0), float(inside) / maxf(ell, 1.0)]

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.dragon.set_physics_process(false)
	await process_frame
	var feet := Vector2(68.0, 113.7)
	var cases := {
		"héroe": [main, "res://art/hechicero/polished/idle_S_00.png", feet],
		"dragón": [main.dragon, "res://art/dragon/dragon_S_idle_00.png", feet],
		"conejo": [main.fauna[0], "res://art/fauna/rabbit_S_idle_00.png", feet],
		"zorro": [main.predators[0], "res://art/fauna/fox_S_idle_00.png", feet],
		"civil": [main.villagers[0], "res://art/fauna/villager_S_idle_00.png", feet],
		"mercader": [main.merchants[0], "res://art/fauna/villager_S_idle_00.png", feet],
	}
	for id: String in ["slime", "skeleton_archer", "cyclops", "storm_mage"]:
		var e: Node2D = main.spawn_enemy(id, main.pos + Vector2(0, 40))
		e.set_physics_process(false)
		var f: Array = e.data["sprites"]["feet"]
		cases[id] = [e, e.data["sprites"]["prefix"] + "S_idle_00.png", Vector2(f[0], f[1])]
	for id: String in cases:
		var c: Array = cases[id]
		var hit: Dictionary = HB.of(c[0])
		assert(not (c[0].get("hit") as Dictionary).is_empty(), "%s: hitbox medida del sprite" % id)
		var s := _silhouette(c[1], c[2], hit)
		print("%-16s rx=%5.1f ry=%5.1f  cobertura=%.2f precisión=%.2f" % [id, hit["rx"], hit["ry"], s[0], s[1]])
		assert(s[0] >= 0.8, "%s: la hitbox deja fuera parte del sprite (%.2f)" % [id, s[0]])
		assert(s[1] >= 0.3, "%s: la hitbox es mucho mayor que el sprite (%.2f)" % [id, s[1]])  # dragón y esqueleto son dispersos (alas, cola, huesos finos)

	# un golpe que toca el sprite toca la hitbox; uno por encima de la cabeza o muy a un lado no
	var a: Node2D = main.spawn_enemy("skeleton_archer", main.pos + Vector2(0, 40))
	a.set_physics_process(false)
	var b: Dictionary = HB.of(a)
	var mid: Vector2 = a.pos + b["c"]
	assert(HB.dist(a, mid) == 0.0, "el centro del cuerpo está dentro")
	assert(HB.dist(a, mid + Vector2(b["rx"] * 0.8, 0)) == 0.0, "el costado del sprite está dentro")
	assert(HB.dist(a, a.pos + Vector2(0, -b["ry"] * 2.0 - 20.0)) > 10.0, "por encima de la cabeza falla")
	assert(HB.dist(a, mid + Vector2(b["rx"] + 40.0, 0)) > 30.0, "lejos a un lado falla")
	assert(HB.foot_dist(a, a.pos) == 0.0 and HB.foot_dist(a, a.pos + Vector2(0, b["rx"])) > 0.0, "la huella está aplastada por la vista isométrica")

	# melee: un tajo hacia un enemigo cuyo cuerpo toca el alcance desde el pecho golpea; si está lejos no
	main.current = main.items["katana_ceniza"]["light"]
	main.current_mode = "light"
	var reach: float = main.current["reach"]
	var chest: Vector2 = main.pos - Vector2(0, 40)
	a.pos = chest + Vector2(reach + b["rx"] * 0.5, 0) - b["c"]  # el borde de su cuerpo queda dentro del alcance
	a.hp = 100
	main.aim_dir = Vector2.RIGHT
	main._strike()
	assert(a.hp < 100, "el tajo alcanza a un cuerpo que toca el alcance")
	a.hp = 100
	a.pos += Vector2(reach * 3.0, 0)
	main._strike()
	assert(a.hp == 100, "fuera de alcance no golpea")

	# estructuras: el castillo usa su zócalo real; el árbol bloquea proyectiles con el follaje y al caminar solo con el tronco
	var mp: Dictionary = main._read_json("res://data/map.json")
	var castle: Dictionary = mp["objects"].filter(func(o: Dictionary) -> bool: return o["sprite"] == "castle")[0]
	var cr: Array = castle["rect"]
	assert(cr[2] - cr[0] >= 4.4, "el rectángulo del castillo cubre las torres (%.2f m)" % (cr[2] - cr[0]))
	var tree: Dictionary = mp["objects"].filter(func(o: Dictionary) -> bool: return o["sprite"].begins_with("tree"))[0]
	assert(tree["pcircle"] > tree["circle"], "el follaje frena proyectiles")
	var tp := Vector2(tree["tile"][0], tree["tile"][1])
	assert(not main.world.hits_structure(tp + Vector2(0.45, 0), 0.0), "caminando, solo cuenta el tronco")
	assert(main.world.hits_structure(tp + Vector2(0.45, 0), 0.0, true), "un proyectil choca con el follaje")
	print("PASS hitbox: siluetas cubiertas, golpes y estructuras ajustados al sprite")
	quit()
