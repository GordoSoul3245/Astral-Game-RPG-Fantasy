extends SceneTree
# Reacción al golpe pesado: el enemigo se aplasta y rebota, y el suelo marca onda y grietas.
# Comprueba la lógica y guarda una captura (ejecutar sin --headless para la imagen).

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.alive = false
	main._enter_dungeon()
	await create_timer(0.8).timeout
	var e = null
	for x in main.enemies:
		x.set_physics_process(false)
		if e == null and x.get("spr"):
			e = x
	assert(e != null, "hay un enemigo con sprite")
	main.pos = e.pos + Vector2(-40, 10)
	main._place()
	var before: int = main.get_child_count()
	main.combat.hit(e, 1, "heavy", main.pos)
	assert(e.scale.x > 1.1 and e.scale.y < 0.9, "el pesado aplasta al enemigo (%s)" % e.scale)
	assert(main.get_child_count() > before, "deja huella en el suelo")
	var drops: Array = main.get_children().filter(func(c): return c.get_script() == preload("res://scripts/splatter.gd"))
	assert(drops.size() == 1 and drops[0].tint == Color(e.data["blood"]), "salpica con el color de la criatura")
	assert(e.spr.animation.begins_with("hurt"), "reproduce el golpe recibido de Blender (%s)" % e.spr.animation)
	await create_timer(0.08).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/previews/heavy_impact.png")
	await create_timer(0.4).timeout
	assert(e.scale.is_equal_approx(Vector2.ONE), "vuelve a su forma (%s)" % e.scale)
	print("PASS impact: aplastamiento con rebote, golpe recibido y huella en el suelo")
	quit()
