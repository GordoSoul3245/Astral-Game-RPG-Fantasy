extends SceneTree
# Mecánicas de combate nuevas (investigación): esquiva perfecta, maná al golpear con espada, bonus de tajo tras dash
# y postura de los élites (se abren, reciben más daño y se recuperan).

var main: Node

func _initialize() -> void:
	call_deferred("run_checks")

func _enemy(id: String, off: Vector2) -> Node2D:
	var e: Node2D = main.spawn_enemy(id, main.pos + off)
	e.set_physics_process(false)
	return e

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	main.dragon.set_physics_process(false)
	main.dragon.alive = false
	await process_frame
	var c: Node = main.combat

	# --- esquiva perfecta: un golpe durante el dash da recursos y no hace daño; con cooldown no se repite
	main.hero_hp = main.hero_max_hp
	main.dashing = true
	main.ult = 0.0
	main.mana = 10.0
	main.stamina = 10.0
	main.damage_hero(30)
	assert(main.hero_hp == main.hero_max_hp, "el dash esquiva el daño")
	assert(main.ult == main.DODGE_ULT and main.mana == 25.0 and main.stamina == 35.0, "esquiva perfecta: carga ultimate, maná y estamina")
	var ult1: float = main.ult
	main.damage_hero(30)
	assert(main.ult == ult1, "no se acumula en el mismo instante (cooldown)")
	main.dodge_cd = 0.0
	main.mega_active = true
	main.damage_hero(30)
	assert(main.ult == ult1, "el mega dash no cuenta como esquiva perfecta")
	main.mega_active = false
	main.dashing = false
	main.dodge_cd = 0.0
	main.damage_hero(10)
	assert(main.hero_hp < main.hero_max_hp and main.ult == ult1, "sin dash, el golpe entra y no da recompensa")
	main.reaction_time = 0.0
	main.hero_hp = main.hero_max_hp

	# --- maná al golpear con espada, con tope por tajo
	var a := _enemy("slime", Vector2(30, 0))
	var b := _enemy("slime", Vector2(30, 10))
	var d := _enemy("slime", Vector2(30, 20))
	main.mana = 0.0
	main.swing_mana = 0.0
	c.hit(a, 1, "light", main.pos)
	assert(main.mana == 4.0, "el ligero da 4 de maná")
	c.hit(b, 1, "heavy", main.pos)
	assert(main.mana == 14.0 and main.swing_mana == 14.0, "el pesado da 10")
	c.hit(d, 1, "light", main.pos)
	assert(main.mana == 14.0, "tope por tajo: no regala más")
	main.swing_mana = 0.0
	c.hit(d, 1, "light", main.pos)
	assert(main.mana == 18.0, "un tajo nuevo vuelve a dar")
	main.mana = 0.0
	main.swing_mana = 0.0
	c.hit(a, 1, "magic", main.pos)
	c.hit(a, 1, "heavy", main.pos, false)
	assert(main.mana == 0.0, "la magia y el mega dash (sin carga) no dan maná")

	# --- bonus de tajo tras dash (se consume)
	var t := _enemy("cyclops", Vector2(40, 0))
	main.current = main.items["katana_ceniza"]["light"]
	main.current_mode = "light"
	var chest: Vector2 = main.pos - Vector2(0, 40)
	t.pos = chest + Vector2(30, 0) - preload("res://scripts/hitbox.gd").of(t)["c"]
	main.aim_dir = Vector2.RIGHT
	t.hp = 1000
	main.dash_bonus_t = 0.0
	main._strike()
	var normal: int = 1000 - t.hp
	t.hp = 1000
	t.poise = 0.0
	main.dash_bonus_t = main.DASH_BONUS_TIME
	main._strike()
	var boosted: int = 1000 - t.hp
	assert(normal > 0 and boosted > normal and main.dash_bonus_t == 0.0, "tras dash pega más (%d > %d) y se consume" % [boosted, normal])
	assert(absf(float(boosted) / normal - main.DASH_BONUS_MULT) < 0.1, "bonus x%.2f" % main.DASH_BONUS_MULT)

	# --- postura: el cíclope se abre con golpes pesados, recibe más daño, cancela su onda y se recupera
	t.hp = 1000
	t.poise = 0.0
	t.staggered = false
	t.state = "windup"
	t._spawn_zone(t.pos, 50.0, 0.8, 20, false, Color.RED)
	var pending: Node = t.zones[-1]
	var mx: float = t.data["poise"]
	var heavy: float = c.KINDS["heavy"]["poise"]
	var needed := ceili(mx / heavy)
	for i in needed - 1:
		c.hit(t, 1, "heavy", main.pos, false)
	assert(not t.staggered and t.poise > 0.0, "antes de llenar la barra sigue entero")
	c.hit(t, 1, "heavy", main.pos, false)
	assert(t.staggered and t.state == "recover" and t.poise == 0.0, "la barra llena lo abre")
	await process_frame
	assert(not is_instance_valid(pending), "su onda preparada se cancela")
	t.hp = 1000
	t.take_damage(10, false)
	assert(t.hp == 1000 - 15, "abierto recibe x1.5 (%d)" % (1000 - t.hp))
	for i in 30:
		t._physics_process(0.1)
	assert(not t.staggered and t.state == "chase", "tras STAGGER_TIME se recupera")
	t.hp = 1000
	t.take_damage(10, false)
	assert(t.hp == 990, "recuperado vuelve al daño normal")
	# la postura se regenera si dejas de golpear; los enemigos sin postura no la usan
	t.poise = 20.0
	t.poise_t = 2.5
	t._physics_process(1.0)
	assert(t.poise < 20.0, "regenera sin golpes")
	var s := _enemy("slime", Vector2(0, 60))
	s.add_poise(999.0)
	assert(not s.staggered and s.poise == 0.0, "el slime no tiene postura")
	print("PASS combat_ext: esquiva perfecta, maná al golpear, bonus tras dash y postura del élite")
	quit()
