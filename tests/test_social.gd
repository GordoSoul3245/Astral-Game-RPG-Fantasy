extends SceneTree
# Relaciones con los habitantes: amistad en corazones, conversación diaria, regalos con gustos, eventos a 2 y 4 corazones,
# descuento de Tomás y bonus de Bram, el panel de regalos y el guardado.

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	main.save_path = "user://test_social_save.json"
	main.testing = true
	await process_frame
	var so: CanvasLayer = main.social
	var cr = main.crafting
	var clock = main.clock
	for id: String in so.cfg["npcs"]:
		var n: Dictionary = so.cfg["npcs"][id]
		assert(not n["loves"].is_empty() and not n["dislikes"].is_empty() and n["events"].size() == 2, "%s tiene gustos y dos eventos" % id)
		for e: Dictionary in n["events"]:
			for item: String in e["reward"].get("items", {}):
				assert(cr.cfg["materials"].has(item) or cr.cfg["consumables"].has(item), "%s: el premio %s existe" % [id, item])
			if e["reward"].has("blueprint"):
				assert(cr.cfg["blueprints"].has(e["reward"]["blueprint"]), "el plano del premio existe")

	# conversación diaria
	assert(so.hearts("mara") == 0 and so.hearts_text("mara") == "♡♡♡♡♡", "al principio no hay amistad")
	assert(so.on_talk("mara") and not so.on_talk("mara"), "hablar suma una vez al día")
	assert(int(so.friend["mara"]) == 20)
	clock.day += 1
	assert(so.on_talk("mara"), "al día siguiente suma otra vez")

	# regalos: gustos y límite diario
	cr.add("sopa_pescado", 3)
	cr.add("carbon", 2)
	cr.add("madera", 2)
	assert(so.liking("mara", "sopa_pescado") == "love" and so.liking("mara", "carbon") == "dislike" and so.liking("mara", "madera") == "neutral")
	var before: int = so.friend["mara"]
	var msg: String = so.give("mara", "sopa_pescado")
	assert(so.friend["mara"] == before + 80 and cr.count("sopa_pescado") == 2 and msg != "", "un regalo favorito da +80")
	assert(so.can_gift("mara") != "" and so.give("mara", "madera") == so.can_gift("mara") and cr.count("madera") == 2, "solo un regalo al día")
	clock.day += 1
	var b2: int = so.friend["mara"]
	so.give("mara", "carbon")
	assert(so.friend["mara"] == b2 - 25, "un regalo que no le gusta resta")
	clock.day += 1
	cr.add("sopa_pescado", 1, 2)
	cr.take("sopa_pescado", 2)  # quedan solo las de oro
	var b3: int = so.friend["mara"]
	so.give("mara", "sopa_pescado")
	assert(so.friend["mara"] - b3 == roundi(80.0 * 1.5), "un regalo de calidad vale más")

	# eventos a 2 y 4 corazones
	so.friend["mara"] = 200
	assert(so.hearts("mara") == 2 and not so.pending_event("mara").is_empty(), "a 2 corazones hay un evento")
	var coins0: int = main.prog.coins
	var lines: Array = so.take_event("mara")
	assert(lines.size() >= 2 and cr.count("estofado_zorro") >= 2 and so.pending_event("mara").is_empty(), "el evento da sus premios una sola vez")
	assert(so.take_event("mara").is_empty(), "no se repite")
	so.friend["teo"] = 400
	var sp0: int = main.prog.skill_points
	so.take_event("teo")
	so.take_event("teo")
	assert(main.prog.skill_points >= sp0 + 1 and cr.count("elixir_furia") >= 2, "Teo da un punto de habilidad a 4 corazones")
	so.friend["tomas"] = 400
	var bp0: bool = cr.knows("plano_elixir_vision")
	so.take_event("tomas")
	so.take_event("tomas")
	assert(cr.knows("plano_elixir_vision") or bp0, "Tomás da un plano")

	# ventajas de tienda
	so.friend["tomas"] = 0
	var base_price: int = main.shop.price_of("pocion_vida")
	so.friend["tomas"] = 500
	assert(main.shop.price_of("pocion_vida") < base_price and absf(float(main.shop.price_of("nasa")) - 35.0 * 0.8) <= 1.0, "5 corazones: 20 % de descuento en Tomás")
	cr.add("lingote_hierro", 2)
	so.friend["bram"] = 0
	var v0: int = main.shop.sell_value("lingote_hierro") if main.shop.cfg["smith"]["buys"].has("lingote_hierro") else 0
	so.friend["bram"] = 500
	if v0 > 0:
		assert(main.shop.sell_value("lingote_hierro") > v0, "Bram paga más a quien aprecia")

	# escena de evento: barras de cine, acercamiento de cámara y vuelta a la normalidad al cerrar
	var z0: Vector2 = main.cam.zoom
	so.play_scene("bram", ["Bram: Una escena de prueba.", "Bram: Hasta luego."])
	assert(so.in_scene and main.dialogue.visible, "la escena abre el diálogo")
	var waited := 0.0
	while (so.bar_top.offset_bottom < 90.0 or main.cam.zoom.x < z0.x * 1.25) and waited < 8.0:
		await create_timer(0.2, true, false, true).timeout
		waited += 0.2
	assert(main.cam.zoom.x > z0.x * 1.2 and so.bar_top.offset_bottom > 80.0, "la cámara se acerca y salen las barras (zoom %.2f contra %.2f, barra %.1f)" % [main.cam.zoom.x, z0.x, so.bar_top.offset_bottom])
	main.dialogue.close()
	waited = 0.0
	while (so.bar_top.offset_bottom > 1.0 or absf(main.cam.zoom.x - z0.x) > 0.01) and waited < 8.0:
		await create_timer(0.2, true, false, true).timeout
		waited += 0.2
	assert(not so.in_scene and absf(main.cam.zoom.x - z0.x) < 0.01 and so.bar_top.offset_bottom < 1.0, "al cerrar todo vuelve a su sitio")

	# panel de regalos
	so.open_for("mara")
	assert(so.visible and so.title.text.begins_with("Mara") and so.grid.get_child_count() > 0, "el panel se abre con los objetos del héroe")
	so.close()
	assert(not so.visible)

	# guardado
	so.friend["elda"] = 333
	main.save_game()
	so.friend.clear()
	so.done.clear()
	assert(main.load_game() and so.friend["elda"] == 333 and so.done.has("mara:2"), "amistad y eventos vistos se guardan")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.save_path))
	print("PASS social: amistad diaria, regalos con gustos, eventos, ventajas de tienda, panel y guardado")
	quit()
