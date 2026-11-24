extends Node2D
# Enemigo genérico de la dungeon (data/creatures.json). El comportamiento depende de data["kind"]:
# slime (salta y daña al contacto), archer (mantiene distancia y dispara), brute (cíclope: onda de choque),
# mage (jefe: rayos y bolas eléctricas). Dibujado por código (arte provisional con la silueta de las referencias).

const HERO_H := 78.0   # altura aproximada del héroe en px de suelo

var main: Node
var data := {}
var pos := Vector2.ZERO      # pies, px de suelo
var hp := 0
var alive := true
var radius := 10.0
var face := 1.0              # 1 derecha, -1 izquierda
var state := "idle"          # idle, chase, windup, recover
var t := 0.0
var cd := 1.0
var contact_cd := 0.0
var anim_t := 0.0
var hopping := false
var casts := 0
var flash_tw: Tween
var spr: AnimatedSprite2D    # sprites de Blender (si data["sprites"]); si no, se dibuja por código
var spr_base := Vector2.ZERO
var look := Vector2.DOWN
var adir := "S"              # dirección fija durante el ataque
var aim := Vector2.DOWN      # dirección del disparo, fijada al empezar el aviso (no persigue al héroe)
var slow_t := 0.0           # ralentizado por hielo: se mueve a la mitad
var kb := Vector2.ZERO       # empuje recibido, px de suelo/s
var zones: Array = []        # avisos pendientes: se cancelan si muere antes del golpe
var id := ""                 # clave en data/creatures.json (data puede ser una copia escalada por piso)
var hit := {}                # hitbox corporal medida del sprite (hitbox.gd); {} = círculo por `radius`
var last_seen := Vector2.ZERO  # última posición vista del héroe (px de suelo)
var lost_t := 0.0            # segundos sin ver al héroe
const SEARCH_TIME := 4.0     # busca en la última posición este tiempo y vuelve a idle
const LOSE_MULT := 1.5       # umbral de pérdida = detect_range * esto (histéresis: no oscila en el borde)

func _sees(dist: float) -> bool:  # alcance (más holgado si ya lo persigue) y línea libre de estructuras
	if dist >= data["detect_range"] * (1.0 if state == "idle" else LOSE_MULT):
		return false
	var n := ceili(dist / 8.0)
	for i in range(1, n):
		if main.hits_obstacle(pos.lerp(main.pos, float(i) / n)):
			return false
	return true

const ALERT_RANGE := 170.0  # px de suelo: avisa solo a los compañeros cercanos
const ALERT_MAX := 3         # como mucho avisa a los 3 más cercanos
const ALERT_SHOW := 0.9      # s que se ve el "!" sobre quien se alerta
var alert_t := 0.0

# alerta compartida: pasa la posición aproximada del evento a los compañeros en reposo cercanos.
# No encadena (los avisados no avisan) y no da acceso continuo al héroe: luego cada uno usa su propia vista.
func _alert() -> void:
	alert_t = ALERT_SHOW
	main.combat.play_at("alert", pos)
	var near: Array = main.enemies.filter(func(o: Node) -> bool:
		return o != self and o.alive and o.get("state") is String and o.state == "idle" and pos.distance_to(o.pos) < ALERT_RANGE)
	near.sort_custom(func(a: Node, b: Node) -> bool: return pos.distance_to(a.pos) < pos.distance_to(b.pos))
	for o in near.slice(0, ALERT_MAX):
		o.state = "chase"
		o.last_seen = last_seen
		o.lost_t = 0.0
		o.alert_t = ALERT_SHOW

func _search(delta: float) -> void:  # sin ver al héroe: va a donde lo vio por última vez y, si no aparece, se rinde
	lost_t += delta
	var d := last_seen - pos
	if data["kind"] == "slime":
		_slime(d, d.length(), delta)
	elif d.length() > 6.0:
		look = d
		_move(_toward(last_seen), 1.0, delta)
		_anim("walk")
	else:
		_anim("idle")
	if lost_t >= SEARCH_TIME:
		state = "idle"
		_anim("idle")

# --- postura (Sekiro, versión suave): los golpes llenan la barra de los élites; al llenarse quedan abiertos
# unos segundos (no actúan y reciben más daño). Los tajos pesados la llenan 4 veces más rápido que los ligeros.
const POISE_REGEN := 12.0     # por segundo, tras 2 s sin recibir golpes
const STAGGER_TIME := 2.2
const STAGGER_BONUS := 1.5
var poise := 0.0
var poise_t := 0.0
var staggered := false

func add_poise(v: float) -> void:
	var mx: float = data.get("poise", 0.0)
	if mx <= 0.0 or not alive or staggered:
		return
	poise = minf(mx, poise + v)
	poise_t = 0.0
	if poise >= mx:
		_stagger()

func _stagger() -> void:
	staggered = true
	poise = 0.0
	state = "recover"
	combo_left = 0
	if spr:  # si lo abren en pleno salto, cae al suelo
		spr.position = spr_base
	t = STAGGER_TIME
	kb = Vector2.ZERO
	for z in zones:  # un golpe de zona preparado se cancela
		if is_instance_valid(z) and not z.fired:
			z.queue_free()
	if spr:
		spr.stop()
		_anim("idle")
	main.popup(pos, "¡Abierto!", Color(1.0, 0.85, 0.3))
	main.combat.play("blast")
	main.combat.flash(pos, Color(1.0, 0.85, 0.3), 1.0, 2.5, 0.35)

func knock(v: Vector2, heavy: bool) -> void:  # empuje; los pesados interrumpen el aviso de los que se pueden aturdir
	kb = v * (1.0 - data.get("knock_resist", 0.0))
	if heavy and data.get("staggerable", false) and state == "windup":
		state = "recover"
		t = data.get("recover", 0.4)
		if spr:
			spr.stop()
			_anim("idle")

func _ready() -> void:
	hp = data["hp"]
	radius = data["radius"]
	if data.has("sprites"):
		_build_sprite()
		var HB := preload("res://scripts/hitbox.gd")
		var f: Array = data["sprites"]["feet"]
		hit = HB.measure(main.DIRS, data["sprites"]["prefix"] + "%s_idle_00.png", Vector2(f[0], f[1]))
	_place()

func _dir_name(v: Vector2) -> String:
	return main.DIRS[posmod(roundi(v.angle() / (PI / 4.0)), 8)]

func _build_sprite() -> void:  # <prefijo><DIR>_<idle|walk|attack>_<NN>.png, 8 direcciones
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for dir: String in main.DIRS:
		for kind: String in data["sprites"].get("kinds", ["idle", "walk", "attack"]):
			var key := "%s_%s" % [kind, dir]
			frames.add_animation(key)
			frames.set_animation_speed(key, 8.0)
			frames.set_animation_loop(key, kind == "idle" or (kind == "walk" and data["kind"] != "slime"))  # el salto del slime y los ataques no se repiten
			for i in (1 if kind == "idle" else 8):
				frames.add_frame(key, load("%s%s_%s_%02d.png" % [data["sprites"]["prefix"], dir, kind, i]))
		var hurt0 := "%s%s_hurt_00.png" % [data["sprites"]["prefix"], dir]
		if ResourceLoader.exists(hurt0):  # golpe recibido (4 fotogramas renderizados en Blender), si la criatura lo tiene
			var hk := "hurt_" + dir
			frames.add_animation(hk)
			frames.set_animation_speed(hk, 16.0)  # 0,25 s: pico en el primer fotograma, recupera rápido
			frames.set_animation_loop(hk, false)
			for i in 4:
				frames.add_frame(hk, load("%s%s_hurt_%02d.png" % [data["sprites"]["prefix"], dir, i]))
	spr = AnimatedSprite2D.new()
	spr.sprite_frames = frames
	spr.centered = false
	spr.scale = Vector2.ONE * main.SCALE
	var f: Array = data["sprites"]["feet"]
	spr.position = -Vector2(f[0], f[1]) * main.SCALE
	spr_base = spr.position
	if data.has("tint"):  # variantes de zona: mismo cuerpo con otro color
		spr.self_modulate = Color(str(data["tint"]))
	add_child(spr)
	spr.play("idle_S")

func _anim(kind: String) -> void:  # animación en bucle hacia donde mira (sin cortar un ataque en curso)
	if spr:
		if (spr.animation.begins_with("attack") or spr.animation.begins_with("hurt")) and spr.is_playing():
			return
		var key := "%s_%s" % [kind, _dir_name(look)]
		if spr.animation != key:
			spr.play(key)

# ataque: el fotograma `strike_frame` cae justo al terminar el aviso (`delay` s); el resto es la recuperación
func _play_attack(to: Vector2, strike_frame: int, delay: float) -> void:
	if spr:
		adir = _dir_name(to)
		spr.sprite_frames.set_animation_speed("attack_" + adir, float(strike_frame) / delay)
		spr.play("attack_" + adir)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	anim_t += delta
	alert_t = maxf(0.0, alert_t - delta)
	cd = maxf(0.0, cd - delta)
	contact_cd = maxf(0.0, contact_cd - delta)
	slow_t = maxf(0.0, slow_t - delta)
	var to: Vector2 = main.pos - pos
	var dist := to.length()
	var sees := _sees(dist)
	if sees:
		last_seen = main.pos
		lost_t = 0.0
		if state == "idle":
			state = "chase"
			_alert()
	if kb.length() > 5.0:
		pos = main.world.move_collide(pos, pos + kb * delta * Vector2(1, 0.6), data["r_t"])
		kb = kb.move_toward(Vector2.ZERO, 900.0 * delta)
	poise_t += delta
	if poise > 0.0 and poise_t > 2.0 and not staggered:
		poise = maxf(0.0, poise - POISE_REGEN * delta)
	if state == "air":  # en el aire (salto de ataque o de reposición): arco hasta el destino
		_air_step(delta)
		_separate()
		_place()
		queue_redraw()
		return
	if _elite():
		hop_cd -= delta
		strafe_t -= delta
		if strafe_t <= 0.0:
			strafe_t = randf_range(1.6, 3.4)
			strafe_side = -strafe_side
		if state == "chase" and sees and hop_cd <= 0.0 and dist < 260.0 and not staggered:  # salto lateral para no quedarse quieto
			hop_cd = randf_range(3.0, 5.5)
			var side := Vector2(to.y, -to.x).normalized() * strafe_side
			_jump(main.world.move_collide(pos, pos + (side * randf_range(55.0, 90.0) - to.normalized() * 20.0) * Vector2(1, 0.6), data["r_t"]), 0.42, 28.0, false)
	if state == "recover":  # recuperación castigable: no se mueve ni ataca
		t -= delta
		if t <= 0.0:
			state = "chase"
			staggered = false
			charging = false
	elif state == "chase" and not sees:
		_search(delta)
	elif state != "idle":
		if absf(to.x) > 2.0 and state != "windup":
			face = signf(to.x)
		if state != "windup" and state != "recover":
			look = to
		match data["kind"]:
			"slime": _slime(to, dist, delta)
			"archer": _archer(to, dist, delta)
			"brute": _brute(to, dist, delta)
			"mage": _mage(to, dist, delta)
			"pattern": _pattern(to, dist, delta)
	_separate()
	_place()
	queue_redraw()

func _move(dir: Vector2, mult: float, delta: float) -> void:
	if slow_t > 0.0:
		mult *= 0.5
	var p: Vector2 = main.world.move_collide(pos, pos + dir * data["speed"] * mult * delta * Vector2(1, 0.6), data["r_t"])
	var off: Vector2 = p - main.pos
	var min_d: float = radius + main.HERO_RADIUS
	if not main.dashing and off.length() < min_d:  # el héroe en dash los atraviesa
		p = main.world.move_collide(pos, main.pos + (off.normalized() if off.length() > 0.01 else Vector2.RIGHT) * min_d, data["r_t"])
	pos = p

func _slot(dist: float) -> Vector2:  # hueco propio alrededor del héroe (8 puestos): de cerca va directo
	if dist < 70.0:
		return main.pos
	return main.pos + Vector2.from_angle((get_instance_id() % 8) * TAU / 8.0) * 45.0 * Vector2(1, 0.6)

func _away(to: Vector2) -> Vector2:  # se aleja en diagonal; si detrás hay pared, cambia de lado
	var side := Vector2(to.y, -to.x).normalized() * strafe_side
	var d := (-to.normalized() + side * 0.6).normalized()
	var probe: Vector2 = pos + d * 14.0 * Vector2(1, 0.6)
	if main.world.move_collide(pos, probe, data["r_t"]).distance_to(probe) > 1.0:
		strafe_side = -strafe_side
		d = (-to.normalized() - side * 0.6).normalized()
	return d

func _toward(target: Vector2) -> Vector2:  # dirección para llegar rodeando muros y estructuras
	var d: Vector2 = main.world.way(pos, target, data["r_t"], self) - pos
	return d.normalized() if d.length() > 0.5 else (target - pos).normalized()

func _separate() -> void:  # los enemigos no se montan unos sobre otros
	for o in main.enemies:
		if o == self or not o.alive:
			continue
		var d: Vector2 = pos - o.pos
		var min_d: float = radius + o.radius
		if d.length() < min_d:
			pos = main.world.move_collide(pos, pos + (d.normalized() if d.length() > 0.01 else Vector2.RIGHT) * (min_d - d.length()) * 0.5, data["r_t"])

func _spawn_zone(center: Vector2, r: float, delay: float, dmg: int, bolt: bool, col: Color) -> void:
	var z := Node2D.new()
	z.set_script(load("res://scripts/zone.gd"))
	z.main = main
	z.center = center
	z.radius = r
	z.delay = delay
	z.damage = dmg
	z.bolt = bolt
	z.color = col
	main.add_child(z)
	zones.append(z)

func _slime(to: Vector2, dist: float, delta: float) -> void:
	t -= delta
	if t <= 0.0:
		hopping = not hopping
		t = data["hop_time"] if hopping else data["hop_rest"]
		if spr:
			if hopping:  # un salto completo de la animación por salto
				var key := "walk_" + _dir_name(look)
				spr.sprite_frames.set_animation_speed(key, 8.0 / data["hop_time"])
				spr.animation = key
				spr.frame = 0
				spr.play()
			else:
				_anim("idle")
	if hopping:
		_move(_toward(_slot(dist)), 2.0, delta)
	if dist < radius + main.HERO_RADIUS + 4.0 and contact_cd == 0.0:
		main.damage_hero(data["contact_damage"])
		contact_cd = data["contact_cooldown"]

const FAN_ANGLES := [-0.26, 0.0, 0.26]   # abanico del arquero: tres flechas separadas ~15°
var shots := 0               # el 3.er disparo del arquero es un abanico (más aviso, hay que moverse en vez de ladearse)
var fan_shot := false
var slams := 0
var charging := false        # el cíclope embiste desde lejos: línea de aviso, carrera recta y recuperación larga
var charge_cd := 3.0
var charge_hit := false
const CHARGE_WINDUP := 0.9
const CHARGE_TIME := 0.7
const CHARGE_SPEED := 6.0

func _archer(to: Vector2, dist: float, delta: float) -> void:
	if state == "windup":
		t -= delta
		if t <= 0.0:
			for a: float in (FAN_ANGLES if fan_shot else [0.0]):
				var d := aim.rotated(a)
				main.spawn_projectile("enemy", pos + d * 10.0, d, data["projectile"])
			shots += 1
			cd = data["attack_cooldown"]
			state = "recover"
			t = data.get("recover", 0.4) * (1.5 if fan_shot else 1.0)  # el abanico deja más tiempo para castigarlo
		return
	if dist < data["flee_distance"]:
		_move(_away(to), 1.1, delta)
		_anim("walk")
	elif dist > data["keep_distance"] + 15.0:
		_move(_toward(main.pos), 1.0, delta)
		_anim("walk")
	else:
		_anim("idle")
	if cd == 0.0 and main.can_prepare(self):
		state = "windup"
		fan_shot = shots % 3 == 2
		t = data["windup"] + (0.25 if fan_shot else 0.0)
		aim = to.normalized()
		_play_attack(to, 4, t)  # la flecha sale en el fotograma 4

func _charge_step(delta: float, dmg: int) -> void:  # carrera recta en la dirección avisada: no persigue
	t -= delta
	_move(aim, CHARGE_SPEED, delta)
	if not charge_hit and pos.distance_to(main.pos) < radius + main.HERO_RADIUS + 8.0:
		charge_hit = true
		main.damage_hero(dmg)
		main.shake(8.0)
	if t <= 0.0:
		state = "recover"
		t = data.get("recover", 0.7) * 1.6  # embestir deja abierto mucho tiempo
		charging = false
		charge_cd = 7.0
		_anim("idle")

func _brute(to: Vector2, dist: float, delta: float) -> void:
	if state == "charge":
		_charge_step(delta, roundi(data["slam_damage"] * 0.8))
		return
	if state == "windup":
		t -= delta
		if t <= 0.0:
			if charging:
				state = "charge"
				t = CHARGE_TIME
				charge_hit = false
			else:
				state = "recover"
				t = data.get("recover", 0.7)
		return
	charge_cd = maxf(0.0, charge_cd - delta)
	if dist > data["attack_range"]:
		if charge_cd == 0.0 and dist > data["attack_range"] * 1.6 and dist < 260.0 and main.can_prepare(self):  # cierra distancia embistiendo
			state = "windup"
			charging = true
			t = CHARGE_WINDUP
			aim = Vector2(to.x, to.y / 0.6).normalized()  # dirección en el espacio de movimiento (el suelo se acorta ×0.6 en Y): así el desplazamiento apunta al héroe
			cd = data["attack_cooldown"]
			_play_attack(to, 5, t)
			return
		_move(_toward(_slot(dist)), 1.0, delta)
		_anim("walk")
	elif cd == 0.0 and main.can_prepare(self):
		state = "windup"
		slams += 1
		t = data["windup"]
		cd = data["attack_cooldown"]
		_play_attack(to, 5, data["windup"])
		_spawn_zone(pos + Vector2(to.x, to.y / 0.6).normalized() * 32.0 * Vector2(1, 0.6), data["slam_radius"], data["windup"], data["slam_damage"], false, Color(1.0, 0.35, 0.2))
	else:
		_anim("idle")

# --- monstruos con repertorio propio (data["attacks"]): usa sus ataques en orden y se acerca hasta el alcance del siguiente.
# Tipos: charge (embestida en línea), leap (salta a donde estaba el héroe), zone_hero (golpes sobre el héroe),
# zone_line (fila de golpes hacia el héroe), zone_ring (golpes alrededor de sí), shot (abanico de proyectiles), ring (corona de proyectiles).
# Más: multi_leap (saltos seguidos), dash_combo (ráfaga de embestidas), meteor_rain (lluvia escalonada sobre el héroe),
# cross (cruz de golpes; "diag" añade diagonales), shockwave (anillos que se expanden), spiral (oleadas de proyectiles en espiral).
var atk_i := 0
var cur := {}                # ataque en curso
var leap_to := Vector2.ZERO
var combo_left := 0          # saltos o embestidas que quedan del combo
var hop_cd := 2.5            # salto de reposición de jefes y semijefes
var strafe_t := 0.0
var strafe_side := 1.0
var air_from := Vector2.ZERO
var air_to := Vector2.ZERO
var air_dur := 0.4
var air_h := 40.0
var air_hit := false         # el aterrizaje es un ataque o solo una reposición
const AIR := 0.4             # lo que dura el salto de ataque

func _elite() -> bool:
	return data.get("boss", false) or data.get("mini", false)

func _jump(to_pos: Vector2, dur: float, h: float, hit_: bool) -> void:
	air_from = pos
	air_to = to_pos
	air_dur = dur
	air_h = h
	air_hit = hit_
	t = 0.0
	state = "air"
	_anim("walk")

func _air_step(delta: float) -> void:
	t += delta
	var k := clampf(t / air_dur, 0.0, 1.0)
	pos = main.world.move_collide(pos, air_from.lerp(air_to, k), data["r_t"])
	if spr:
		spr.position = spr_base - Vector2(0, sin(k * PI) * air_h * main.SCALE)
	if k < 1.0:
		return
	if spr:
		spr.position = spr_base
	if not air_hit:
		state = "chase"
		return
	main.shake(6.0)
	if combo_left > 0:  # combo de saltos: apunta de nuevo y vuelve a saltar enseguida
		combo_left -= 1
		leap_to = main.pos
		state = "windup"
		t = 0.3
		_spawn_zone(leap_to, float(cur.get("radius", 30.0)), t + AIR, int(cur.get("damage", 0)), false, Color(str(cur.get("color", "#ff5a33"))))
		_play_attack(main.pos - pos, 5, t)
	else:
		state = "recover"
		t = data.get("recover", 0.5)

func _pattern(to: Vector2, dist: float, delta: float) -> void:
	if state == "charge":
		_charge_step(delta, int(cur["damage"]))
		if state == "recover" and combo_left > 0:  # ráfaga de embestidas: vuelve a apuntar y arremete otra vez
			combo_left -= 1
			state = "windup"
			charging = true
			t = 0.35
			aim = Vector2(to.x, to.y / 0.6).normalized()
			_play_attack(to, 5, t)
		return
	if state == "windup":
		t -= delta
		if t <= 0.0:
			_strike_pattern()
		return
	var atks: Array = data["attacks"]
	var a: Dictionary = atks[atk_i % atks.size()]
	var reach: float = a.get("range", 40.0)
	var keep: float = data.get("keep_distance", 0.0)
	var side := Vector2(to.y, -to.x).normalized() * strafe_side
	var lat := 0.45 if _elite() else 0.0  # los jefes rodean al héroe en curva, no van en línea recta
	if keep > 0.0 and dist < keep - 30.0:
		_move(_away(to), 1.0, delta)
		_anim("walk")
	elif dist > (keep + 20.0 if keep > 0.0 else reach * 0.8):
		_move((_toward(_slot(dist) if keep == 0.0 else main.pos) + side * lat).normalized(), 1.0, delta)
		_anim("walk")
	elif _elite():
		_move(side, 0.7, delta)  # a su distancia: lo rodea mientras espera el siguiente golpe
		_anim("walk")
	else:
		_anim("idle")
	if cd == 0.0 and main.can_prepare(self):
		var ready_: Array = atks.filter(func(x: Dictionary) -> bool: return dist <= float(x.get("range", 40.0)))
		if ready_.size() > 1:
			ready_ = ready_.filter(func(x: Dictionary) -> bool: return x != cur)
		if not ready_.is_empty():
			_begin_pattern(ready_[randi() % ready_.size()], to)

func _begin_pattern(a: Dictionary, to: Vector2) -> void:
	cur = a
	atk_i += 1
	state = "windup"
	t = a.get("windup", data.get("windup", 0.7))
	aim = to.normalized()
	var enraged: bool = data.get("boss", false) and hp < data["hp"] * 0.5
	cd = data["attack_cooldown"] * (0.7 if enraged else 1.0)
	var r: float = a.get("radius", 24.0)
	var dmg: int = a.get("damage", 0)
	var col := Color(str(a.get("color", "#ff5a33")))
	match str(a["type"]):
		"charge":
			charging = true
			t = CHARGE_WINDUP
			aim = Vector2(to.x, to.y / 0.6).normalized()  # en el espacio de movimiento, como el cíclope
		"leap", "multi_leap":
			leap_to = main.pos
			combo_left = int(a.get("count", 3)) - 1 if str(a["type"]) == "multi_leap" else 0
			_spawn_zone(leap_to, r, t + AIR, dmg, false, col)
		"dash_combo":
			charging = true
			t = CHARGE_WINDUP * 0.8
			combo_left = int(a.get("count", 3)) - 1
			aim = Vector2(to.x, to.y / 0.6).normalized()
		"meteor_rain":
			for i in int(a.get("count", 6)):
				var off := Vector2.from_angle(randf() * TAU) * randf_range(0.0, float(a.get("spread", 80.0)))
				_spawn_zone(main.pos + off * Vector2(1, 0.6), r, t + 0.18 * i, dmg, bool(a.get("bolt", false)), col)
		"cross":
			var dirs := 8 if a.get("diag", false) else 4
			for d in dirs:
				var v := Vector2.from_angle(d * TAU / dirs + (aim.angle() if a.get("aimed", false) else 0.0)) * Vector2(1, 0.6)
				for i in int(a.get("count", 4)):
					_spawn_zone(pos + v * float(a.get("step", 26.0)) * (i + 1), r, t + 0.08 * i, dmg, false, col)
		"shockwave":
			for w in int(a.get("waves", 3)):
				var n := 8 + 4 * w
				for i in n:
					_spawn_zone(pos + Vector2.from_angle(i * TAU / n + w * 0.3) * float(a.get("step", 34.0)) * (w + 1) * Vector2(1, 0.6), r, t + 0.25 * w, dmg, false, col)
		"zone_hero":
			for i in int(a.get("count", 1)):
				var off := Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * float(a.get("spread", 50.0)) * Vector2(1, 0.6)
				_spawn_zone(main.pos + off, r, t + 0.15 * i, dmg, bool(a.get("bolt", false)), col)
		"zone_line":
			for i in int(a.get("count", 5)):
				_spawn_zone(pos + Vector2(aim.x, aim.y / 0.6).normalized() * float(a.get("step", 26.0)) * (i + 1) * Vector2(1, 0.6), r, t + 0.1 * i, dmg, false, col)
		"zone_ring":
			var n := int(a.get("count", 1))
			for i in n:
				_spawn_zone(pos + Vector2.from_angle(i * TAU / n) * float(a.get("dist", 0.0)) * Vector2(1, 0.6), r, t, dmg, false, col)
	_play_attack(to, 5, t)

func _strike_pattern() -> void:
	match str(cur["type"]):
		"charge":
			state = "charge"
			t = CHARGE_TIME
			charge_hit = false
			return
		"leap", "multi_leap":  # salta en arco hasta donde se avisó (las paredes lo frenan); el golpe cae al aterrizar
			_jump(leap_to, AIR, 48.0, true)
			return
		"dash_combo":
			state = "charge"
			t = CHARGE_TIME * 0.7
			charge_hit = false
			return
		"spiral":  # oleadas giratorias: hay que moverse con el giro
			var n := int(cur.get("n", 6))
			var ph := randf() * TAU
			var spec: Dictionary = cur["projectile"]
			for w in int(cur.get("waves", 5)):
				var wave := w
				get_tree().create_timer(0.14 * w, false).timeout.connect(func() -> void:
					if not alive:
						return
					for i in n:
						var d := Vector2.from_angle(ph + i * TAU / n + wave * 0.32)
						main.spawn_projectile("enemy", pos + d * 12.0, d, spec))
		"shot":
			var n := int(cur.get("n", 1))
			for i in n:
				var d := aim.rotated((i - (n - 1) / 2.0) * float(cur.get("spread", 0.25)))
				main.spawn_projectile("enemy", pos + d * 12.0, d, cur["projectile"])
		"ring":
			var n := int(cur.get("n", 8))
			var ph := randf() * TAU
			for i in n:
				var d := Vector2.from_angle(ph + i * TAU / n)
				main.spawn_projectile("enemy", pos + d * 12.0, d, cur["projectile"])
	state = "recover"
	t = data.get("recover", 0.5)

func _mage(to: Vector2, dist: float, delta: float) -> void:
	if state == "windup":
		t -= delta
		if t <= 0.0:
			_cast(aim)
			state = "recover"
			t = data.get("recover", 0.5)
		return
	var keep: float = data["keep_distance"]
	if dist < keep - 30.0:
		_move(_away(to), 1.0, delta)
		_anim("walk")
	elif dist > keep + 20.0:
		_move(_toward(main.pos), 1.0, delta)
		_anim("walk")
	else:
		_anim("idle")
	if cd == 0.0 and main.can_prepare(self):
		state = "windup"
		t = data.get("windup", 0.7)
		aim = to.normalized()
		_play_attack(to, 5, t)  # el hechizo sale en el fotograma 5

func _cast(to: Vector2) -> void:  # cada tercer hechizo es un rayo; el resto, bolas eléctricas; con poca vida lanza más
	casts += 1
	var enraged: bool = hp < data["hp"] * 0.5
	cd = data["attack_cooldown"] * (0.7 if enraged else 1.0)
	if casts % 3 == 0:
		var l: Dictionary = data["lightning"]
		_spawn_zone(main.pos, l["radius"], l["delay"], l["damage"], true, Color(0.5, 0.9, 1.0))
		if enraged:
			_spawn_zone(main.pos + Vector2.from_angle(randf() * TAU) * 60.0, l["radius"], l["delay"], l["damage"], true, Color(0.5, 0.9, 1.0))
	elif casts % 5 == 0:  # corona de orbes en todas direcciones: hay que buscar el hueco entre ellas
		var ring := 8 if enraged else 6
		var phase := randf() * TAU
		for i in ring:
			var a := Vector2.from_angle(phase + i * TAU / ring)
			main.spawn_projectile("enemy", pos + a * 12.0, a, data["orb"])
	else:
		var n := 3 if enraged else 1
		for i in n:
			var a := to.normalized().rotated((i - (n - 1) / 2.0) * 0.3)
			main.spawn_projectile("enemy", pos + a * 12.0, a, data["orb"])

func take_damage(n: int, charge := true) -> void:
	if not alive:
		return
	if staggered:
		n = roundi(n * STAGGER_BONUS)  # abierto: recibe más daño
	if charge:  # golpear entidades carga la ultimate
		main.gain_ultimate(minf(n, hp))
	hp -= n
	if state == "idle":
		state = "chase"  # un golpe lo alerta
		last_seen = main.pos
		lost_t = 0.0
		_alert()
	if flash_tw:
		flash_tw.kill()
	modulate = Color.WHITE.lerp(Color(3.0, 3.0, 3.0), main.settings.flash)  # destello blanco claro (opción de accesibilidad), se sostiene un instante y se apaga
	flash_tw = create_tween()
	flash_tw.tween_interval(0.05)
	flash_tw.tween_property(self, "modulate", Color.WHITE, 0.15)
	if spr and hp > 0 and not (spr.animation.begins_with("attack") and spr.is_playing()):  # no corta un ataque: el aviso sigue siendo fiable
		var hk := "hurt_" + _dir_name(look)
		if spr.sprite_frames.has_animation(hk):
			spr.play(hk)
	if hp <= 0:
		alive = false
		for z in zones:
			if is_instance_valid(z) and not z.fired:
				z.queue_free()
		main.on_kill(self)
		flash_tw.kill()
		modulate = Color.WHITE
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 1.0)
		tw.tween_callback(func() -> void:
			main.enemies.erase(self)
			queue_free())

func _place() -> void:
	position = pos * main.SCALE
	z_index = int(pos.y)

# --- dibujo (unidades: px de suelo, pies en el origen, arriba = y negativa)
func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		pts.append(c + Vector2(cos(i * TAU / 24.0) * rx, sin(i * TAU / 24.0) * ry))
	draw_colored_polygon(pts, col)

func _draw() -> void:
	var S: float = main.SCALE
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * S)
	_ell(Vector2.ZERO, radius * 1.15, radius * 0.55, Color(0, 0, 0, 0.35))  # sombra
	var body_h := 34.0
	match data["kind"]:
		"slime":
			if spr == null:
				_draw_slime(S)
		"archer":
			body_h = 84.0
			if spr == null:
				_draw_archer(S)
		"brute":
			body_h = HERO_H * data["size"]
			if spr == null:
				_draw_cyclops(S)
		"mage":
			body_h = HERO_H * data["size"]
			if spr == null:
				_draw_mage(S)
		"pattern":
			body_h = HERO_H * data.get("size", 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * S)
	if state == "windup" and (data["kind"] in ["archer", "mage"] or str(cur.get("type", "")) == "shot"):  # línea de tiro fijada: el héroe puede salirse
		var k := 1.0 - clampf(t / data.get("windup", 0.7), 0.0, 1.0)
		for a: float in (FAN_ANGLES if fan_shot and data["kind"] == "archer" else [0.0]):  # el abanico avisa sus tres líneas
			var d := aim.rotated(a)
			draw_line(d * radius, d * (radius + 40.0 + 120.0 * k), Color(1.0, 0.3, 0.2, 0.35 + 0.5 * k), 1.5)
	if state == "windup" and charging:  # embestida del cíclope: pasillo rojo en la dirección fijada
		var kc := 1.0 - clampf(t / CHARGE_WINDUP, 0.0, 1.0)
		var screen_dir := Vector2(aim.x, aim.y * 0.6)  # lo que realmente se desplaza por segundo, por unidad de velocidad
		var perp: Vector2 = screen_dir.normalized().orthogonal() * (radius + 6.0)
		var far: Vector2 = screen_dir * (CHARGE_SPEED * float(data["speed"]) * CHARGE_TIME)
		draw_colored_polygon(PackedVector2Array([perp, far + perp, far - perp, -perp]), Color(1.0, 0.25, 0.2, 0.12 + 0.2 * kc))
		draw_line(perp, far + perp, Color(1.0, 0.3, 0.2, 0.7), 1.5)
		draw_line(-perp, far - perp, Color(1.0, 0.3, 0.2, 0.7), 1.5)
	if alert_t > 0.0:  # aviso de alerta: forma ("!") además de color
		var pop := 1.0 + 0.4 * clampf((alert_t - ALERT_SHOW + 0.15) / 0.15, 0.0, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-4 * pop, -body_h - 16), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * pop), Color(1.0, 0.85, 0.2, clampf(alert_t / 0.3, 0.0, 1.0)))
	var w := maxf(maxf(radius * 2.2, 26.0), preload("res://scripts/hitbox.gd").of(self)["rx"] * 1.2)  # las barras de un gigante son más anchas
	draw_rect(Rect2(-w / 2.0, -body_h - 10.0, w, 3.0), Color(0.1, 0.1, 0.14, 0.85))
	draw_rect(Rect2(-w / 2.0, -body_h - 10.0, w * clampf(float(hp) / data["hp"], 0.0, 1.0), 3.0), Color(0.85, 0.2, 0.2))
	if data.get("poise", 0.0) > 0.0:  # barra de postura (amarilla) bajo la vida; llena y parpadeando mientras está abierto
		var pr := 1.0 if staggered else clampf(poise / data["poise"], 0.0, 1.0)
		var pc := Color(1.0, 0.85, 0.3) if (not staggered or fmod(anim_t, 0.3) < 0.15) else Color(1.0, 1.0, 1.0)
		draw_rect(Rect2(-w / 2.0, -body_h - 6.0, w, 3.0), Color(0.1, 0.1, 0.14, 0.85))
		draw_rect(Rect2(-w / 2.0, -body_h - 6.0, w * pr, 3.0), pc)

func _draw_slime(S: float) -> void:
	var lift := 0.0
	if hopping and state != "idle":
		lift = sin(clampf(1.0 - t / data["hop_time"], 0.0, 1.0) * PI) * 14.0
	var sx := 1.0 - 0.12 * lift / 14.0
	var sy := 1.0 + 0.2 * lift / 14.0 + 0.04 * sin(anim_t * 4.0)
	draw_set_transform(Vector2(0, -lift) * S, 0.0, Vector2(sx, sy) * S)
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + i * PI / 16.0
		pts.append(Vector2(cos(a) * 12.0, sin(a) * 10.0))
	draw_colored_polygon(pts, Color("#6fbf3a"))
	_ell(Vector2(-3, -6), 5.0, 2.5, Color("#a6e05a"))  # brillo
	pts.append(pts[0])
	draw_polyline(pts, Color("#2f5a1a"), 1.5)
	draw_rect(Rect2(-5.5 * face - 1.5, -6, 3, 4.5), Color("#2a0f1f"))
	draw_rect(Rect2(3.5 * face - 1.5, -6, 3, 4.5), Color("#2a0f1f"))

func _draw_archer(S: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(S * face, S))
	var bone := Color("#e3dcc0")
	var dark := Color("#3a3426")
	draw_line(Vector2(-4, -30), Vector2(-5, 0), bone, 2.6)  # piernas
	draw_line(Vector2(4, -30), Vector2(5, 0), bone, 2.6)
	draw_rect(Rect2(-6, -34, 12, 5), bone)                    # pelvis
	draw_line(Vector2(0, -34), Vector2(0, -54), bone, 2.4)    # columna
	for y in [-38.0, -43.0, -48.0]:                           # costillas
		draw_line(Vector2(-7, y), Vector2(7, y), bone, 2.0)
	draw_circle(Vector2(0, -61), 7.0, bone)                   # cráneo
	draw_circle(Vector2(2.5, -62), 1.8, dark)
	draw_circle(Vector2(-2.0, -62), 1.8, dark)
	draw_line(Vector2(-3, -56), Vector2(4, -56), dark, 1.2)
	var pull := 6.0 if state == "windup" else 0.0
	draw_line(Vector2(0, -50), Vector2(15, -46), bone, 2.0)   # brazo del arco
	draw_arc(Vector2(18, -46), 15.0, -1.2, 1.2, 10, Color("#7a4a22"), 2.4)  # arco
	var tip := Vector2(18 + 15.0 * cos(1.2), -46 - 15.0 * sin(1.2))
	var bot := Vector2(18 + 15.0 * cos(1.2), -46 + 15.0 * sin(1.2))
	draw_polyline(PackedVector2Array([tip, Vector2(18 - pull, -46), bot]), Color("#d8d2b8"), 1.0)
	if state == "windup":
		draw_line(Vector2(18 - pull, -46), Vector2(36, -46), Color("#d8d2b8"), 1.6)  # flecha lista

func _draw_cyclops(S: float) -> void:
	var k: float = HERO_H * data["size"] / 100.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(S * k * face, S * k))
	var skin := Color("#6f656f")
	var skin2 := Color("#857a85")
	var dark := Color("#2a2d38")
	var raise := 1.0 if state == "windup" else 0.0
	draw_rect(Rect2(-22, -36, 16, 36), Color("#5e5560"))      # piernas
	draw_rect(Rect2(6, -36, 16, 36), Color("#5e5560"))
	draw_rect(Rect2(-25, -4, 20, 4), dark)                    # pies
	draw_rect(Rect2(5, -4, 20, 4), dark)
	_ell(Vector2(0, -58), 31.0, 28.0, skin)                   # torso
	_ell(Vector2(0, -52), 22.0, 18.0, skin2)                  # panza
	_ell(Vector2(-35, -52), 10.0, 24.0, skin)                 # brazo atrás
	_ell(Vector2(33 + 6 * raise, -50 - 40 * raise), 11.0, 24.0, skin)  # brazo que golpea (sube al preparar la onda)
	_ell(Vector2(0, -86), 15.0, 13.0, Color("#7a6f78"))       # cabeza
	draw_rect(Rect2(-40, -77, 80, 5), dark)                   # barra de hierro sobre los hombros
	draw_line(Vector2(-34, -72), Vector2(-34, -40), dark, 2.0)
	draw_line(Vector2(34, -72), Vector2(34, -40), dark, 2.0)
	draw_circle(Vector2(2, -87), 6.0, Color("#8fe8d0"))       # ojo único
	draw_circle(Vector2(3, -87), 2.6, Color("#10202a"))
	draw_rect(Rect2(-7, -79, 14, 3), Color("#8a2a2a"))        # boca

func _draw_mage(S: float) -> void:
	var k: float = HERO_H * data["size"] / 100.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(S * k * face, S * k))
	var cast := 1.0 if state == "windup" else 0.0
	_ell(Vector2(0, -50), 38.0 + 6.0 * sin(anim_t * 3.0), 38.0, Color(0.5, 0.85, 1.0, 0.08 + 0.1 * cast))  # aura
	draw_colored_polygon(PackedVector2Array([Vector2(-20, 0), Vector2(20, 0), Vector2(14, -66), Vector2(-14, -66)]), Color("#aeb8bf"))  # túnica
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -64), Vector2(-4, -64), Vector2(14, -20), Vector2(6, -20)]), Color("#d0d6da"))  # faja cruzada
	_ell(Vector2(0, -66), 23.0, 8.0, Color("#8e99a2"))        # hombros
	_ell(Vector2(0, -80), 12.0, 14.0, Color("#3b4a60"))       # capucha
	draw_rect(Rect2(-6, -84, 12, 8), Color("#14161f"))        # máscara
	var hand_l := Vector2(-28, -42 - 42 * cast)
	var hand_r := Vector2(28, -42 - 42 * cast)
	draw_line(Vector2(-18, -66), hand_l, Color("#8e99a2"), 6.0)
	draw_line(Vector2(18, -66), hand_r, Color("#8e99a2"), 6.0)
	for h in [hand_l, hand_r]:
		draw_circle(h, 5.0 + 3.0 * cast, Color(0.55, 0.9, 1.0, 0.9))
		var rng := RandomNumberGenerator.new()
		rng.seed = int(anim_t * 14.0) + int(h.x)
		for s in 3:  # chispas
			var pts := PackedVector2Array([h])
			var p: Vector2 = h
			for i in 4:
				p += Vector2(rng.randf_range(-9, 9), rng.randf_range(-9, 9))
				pts.append(p)
			draw_polyline(pts, Color(0.8, 0.97, 1.0, 0.9), 1.3)
