extends SceneTree
# Test de humo con un bot: recorre la dungeon (pisos 1-4: pelea, abre el cofre y baja) con el motor real
# (física, IA, hitbox, botín). Ejecutar con --fixed-fps 60 (pasos exactos de 1/60 s lo más rápido posible;
# Engine.time_scale agranda el paso y rompe la simulación). Mide por piso tiempo, daño recibido y muertes.
# No sustituye a jugar: el bot apunta perfecto y no esquiva, así que sirve para detectar atascos y desbalances gruesos.

var main: Node
var elapsed := 0.0
var damage_taken := 0
var deaths := 0
var last_hp := 0
var swings := 0
var done := false
var floor_t0 := 0.0
var floor_dmg0 := 0
var floor_deaths0 := 0
var report: Array[String] = []
const LIMIT := 1500.0    # s de juego simulado
const DT := 1.0 / 60.0

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.save_path = "user://playthrough_save.json"
	main.dragon.alive = false
	await process_frame
	main._enter_dungeon()
	await create_timer(0.8).timeout  # fundido de entrada
	last_hp = main.hero_hp
	physics_frame.connect(_tick)

func _target() -> Node:
	var best: Node = null
	var bd := 1e9
	for e in main.enemies:
		if e != main.dragon and e.alive:
			var d: float = main.pos.distance_to(e.pos)
			if d < bd:
				bd = d
				best = e
	return best

func _floor_done() -> void:
	var f: int = main.floors.floor_no
	report.append("piso %d: %.0f s, daño %d, muertes %d, nivel %d" % [f, elapsed - floor_t0, damage_taken - floor_dmg0, deaths - floor_deaths0, main.prog.level])
	floor_t0 = elapsed
	floor_dmg0 = damage_taken
	floor_deaths0 = deaths

func _tick() -> void:
	if done:
		return
	elapsed += DT  # un tick de física = 1/60 s de juego
	if main.hero_hp < last_hp:
		damage_taken += last_hp - main.hero_hp
	last_hp = main.hero_hp
	if main.dying:
		if main.reaction_time <= DT * 1.5:
			deaths += 1
		return
	if main.transitioning or main.reaction_time > 0.0:
		return
	if not main.in_dungeon:  # murió: despertó en el pueblo; vuelve a bajar al piso alcanzado
		main._enter_dungeon()
		return
	if elapsed > LIMIT:
		_finish()
		return
	if main.hero_hp < 35 and main.prog.potions > 0:
		main._use_potion()
	if main.floors.cleared:
		_floor_done()
		if is_instance_valid(main.floors.chest_door):
			main.floors.open_chest()
		if main.floors.floor_no >= 4:
			_finish()
		else:
			main.floors.next_floor()
		return
	var t := _target()
	if t == null:
		return
	var HB := preload("res://scripts/hitbox.gd")
	var chest: Vector2 = main.pos - Vector2(0, 40)
	var reach: float = main.items[main.hotbar[main.selected]]["light"]["reach"]
	if HB.dist(t, chest) > reach - 8.0 and not main.attacking and not main.dashing:  # acércate hasta tener su cuerpo al alcance
		var dir: Vector2 = (HB.center(t) - chest).normalized()
		main.pos = main.world.move_collide(main.pos, main.pos + dir * 95.0 * DT * Vector2(1, 0.6), main.HERO_R_T)
		main._place()
	elif not main.attacking:
		main.forced_aim = (HB.center(t) - chest).normalized()
		main._press("heavy" if swings % 4 == 3 else "light")
		if main.attacking:
			swings += 1

func _finish() -> void:
	done = true
	for line in report:
		print("PLAYTHROUGH ", line)
	print("PLAYTHROUGH total: %.0f s de juego, daño %d, muertes %d, golpes %d, nivel %d, monedas %d, puntos sin gastar %d" % [elapsed, damage_taken, deaths, swings, main.prog.level, main.prog.coins, main.prog.points])
	assert(swings >= 20, "el bot llegó a pelear")
	assert(report.size() == 4, "se completaron los 4 pisos (%d) dentro del límite de %.0f s" % [report.size(), LIMIT])
	assert(main.prog.points >= 3, "el cofre final da los 3 puntos de estadística")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(main.save_path))
	print("PASS playthrough: los 4 pisos se completan con el motor real")
	quit()
