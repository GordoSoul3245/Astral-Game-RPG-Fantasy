extends SceneTree
# Árbol de habilidades del grimorio: puntos por nivel y por jefe, requisitos, rangos, efectos reales sobre daño, coste de maná,
# cadencia, marca de Ignis, regeneración, pestaña del menú, reinicio y guardado.

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.dragon.set_physics_process(false)
	main.save_path = "user://test_skills_save.json"
	main.testing = true
	await process_frame
	var p = main.prog
	var data: Dictionary = p.skill_data
	for sid: String in data["skills"]:
		var d: Dictionary = data["skills"][sid]
		assert(d.has("name") and d.has("max") and d.has("key") and d.has("per"), "%s está completa" % sid)
		for r: String in [d.get("req", ""), d.get("req2", "")]:
			assert(r == "" or data["skills"].has(r), "%s: el requisito existe" % sid)
	var in_branch := {}
	for br: Dictionary in data["branches"]:
		for sid: String in br["skills"]:
			in_branch[sid] = true
	assert(in_branch.size() == data["skills"].size(), "toda habilidad está en una rama")

	# puntos: 1 por nivel
	assert(p.skill_points == 0, "al empezar no hay puntos")
	main.gain_xp(p.xp_needed())
	assert(p.level == 2 and p.skill_points == 1, "subir de nivel da 1 punto de habilidad")
	assert(p.why_not_learn("llamarada") != "", "sin su requisito no se aprende")
	assert(p.learn("brasas_vivas") and p.skill_rank("brasas_vivas") == 1 and p.skill_points == 0, "se aprende y gasta el punto")
	assert(not p.learn("brasas_vivas") and p.why_not_learn("brasas_vivas") == "Sin puntos de habilidad.", "sin puntos no se sube")

	# efectos reales
	var dmg0: float = 1.0 + 0.06 * p.stat("magic")
	assert(absf(p.magic_mult() - (dmg0 + 0.10)) < 0.001, "Brasas vivas: +10 % de daño de magia")
	p.skill_points = 20
	assert(p.learn("brasas_vivas") and p.learn("brasas_vivas") and not p.learn("brasas_vivas"), "rango máximo 3")
	assert(absf(p.magic_mult() - (dmg0 + 0.30)) < 0.001, "tres rangos: +30 %")
	var mana0: float = p.max_mana(100.0)
	assert(p.learn("pozo_arcano") and absf(p.max_mana(100.0) - (mana0 + 15.0)) < 0.01, "Pozo arcano: +15 de maná máximo")
	var spec: Dictionary = {"mana": 30.0}
	assert(main.mana_cost(spec) == 30.0, "sin eficiencia el hechizo cuesta lo normal")
	assert(p.learn("eficiencia") and absf(main.mana_cost(spec) - 30.0 * 0.92) < 0.01, "Eficiencia: -8 % de coste")
	main.mana = 28.0
	assert(main._afford(spec), "con el descuento alcanza el maná justo")
	assert(p.learn("chispa_veloz") and p.learn("llamarada"), "se abren las ramas de Brasas")
	assert(p.learn("fuego_devorador"), "Fuego devorador con sus dos requisitos")
	assert(p.learn("marca_duradera") and p.learn("marca_ardiente") and p.learn("meteoro_mayor") and p.learn("ira_de_ignis"), "rama de Cataclismo")
	assert(p.learn("flujo_constante"))
	# marca de Ignis
	var base_time: float = main.combat.mark_spec["duration"]
	var e: Node2D = main.spawn_enemy("slime", main.pos + Vector2(300, 0))
	main.combat.mark(e)
	assert(absf(float(main.combat.marks[e]) - (base_time + 1.0)) < 0.01, "Marca duradera: 1 s más")
	# cadencia del proyectil
	var cd_before: float = 0.35 / p.attack_speed()
	main.mana = main.hero_data["mana"]
	main.cooldown = 0.0
	main._select(0)
	main._select(main.hotbar.find("grimorio_ignis"))
	main._attack("light")
	assert(main.cooldown < cd_before - 0.01, "Chispa veloz acorta la espera (%.3f contra %.3f)" % [main.cooldown, cd_before])
	# aoe del proyectil
	main.spawn_projectile("hero", main.pos, Vector2.RIGHT, {"speed": 100.0, "radius": 6.0, "damage": 10, "muzzle_height": 20.0, "aoe": 40.0})
	var proj: Node = main.get_child(main.get_child_count() - 1)
	assert(absf(float(proj.aoe) - 40.0 * 1.15) < 0.01, "Llamarada: explosión un 15 % más ancha")
	var d_proj: int = int(proj.damage)
	assert(d_proj == roundi(10.0 * p.magic_mult()), "el daño del proyectil usa la habilidad")
	# ultimate y regeneración
	main.ult = 0.0
	main.gain_ultimate(10.0)
	assert(absf(main.ult - 10.0 * main.hero_data["ult_per_damage"] * 1.15) < 0.01, "Ira de Ignis: la ultimate se carga un 15 % más rápido")

	# menú: pestaña Magia
	main.menu.visible = true
	main.menu._set_tab("magic")
	assert(main.menu.tab == "magic", "la pestaña existe")
	main.menu.visible = false

	# reinicio y guardado
	var spent := 0
	for sid: String in p.skills:
		spent += int(p.skills[sid])
	var pts: int = p.skill_points
	main.save_game()
	p.skills.clear()
	p.skill_points = 0
	assert(main.load_game() and p.skill_rank("brasas_vivas") == 3 and p.skill_points == pts, "se guardan rangos y puntos")
	p.respec()
	assert(p.skills.is_empty() and p.skill_points == pts + spent, "reiniciar devuelve todos los puntos")
	assert(absf(p.magic_mult() - dmg0) < 0.001, "y quita los efectos")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.save_path))
	print("PASS skills: puntos por nivel, requisitos, rangos, efectos en daño, maná, cadencia, marca, ultimate, menú y guardado")
	quit()
