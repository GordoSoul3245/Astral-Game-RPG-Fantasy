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
var look := Vector2.DOWN
var adir := "S"              # dirección fija durante el ataque
var aim := Vector2.DOWN      # dirección del disparo, fijada al empezar el aviso (no persigue al héroe)
var kb := Vector2.ZERO       # empuje recibido, px de suelo/s
var zones: Array = []        # avisos pendientes: se cancelan si muere antes del golpe
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

const ALERT_RANGE := 110.0  # px de suelo: avisa solo a los compañeros cercanos

# alerta compartida: pasa la posición aproximada del evento a los compañeros en reposo cercanos.
# No encadena (los avisados no avisan) y no da acceso continuo al héroe: luego cada uno usa su propia vista.
func _alert() -> void:
	for o in main.enemies:
		if o == self or not o.alive or not (o.get("state") is String) or o.state != "idle":
			continue
		if pos.distance_to(o.pos) < ALERT_RANGE:
			o.state = "chase"
			o.last_seen = last_seen
			o.lost_t = 0.0

func _search(delta: float) -> void:  # sin ver al héroe: va a donde lo vio por última vez y, si no aparece, se rinde
	lost_t += delta
	var d := last_seen - pos
	if data["kind"] == "slime":
		_slime(d, d.length(), delta)
	elif d.length() > 6.0:
		look = d
		_move(d.normalized(), 1.0, delta)
		_anim("walk")
	else:
		_anim("idle")
	if lost_t >= SEARCH_TIME:
		state = "idle"
		_anim("idle")

func knock(v: Vector2, heavy: bool) -> void:  # empuje (menos en los pesados) y, en los ligeros, interrumpe el aviso
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
	spr = AnimatedSprite2D.new()
	spr.sprite_frames = frames
	spr.centered = false
	spr.scale = Vector2.ONE * main.SCALE
	var f: Array = data["sprites"]["feet"]
	spr.position = -Vector2(f[0], f[1]) * main.SCALE
	add_child(spr)
	spr.play("idle_S")

func _anim(kind: String) -> void:  # animación en bucle hacia donde mira (sin cortar un ataque en curso)
	if spr:
		if spr.animation.begins_with("attack") and spr.is_playing():
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
	cd = maxf(0.0, cd - delta)
	contact_cd = maxf(0.0, contact_cd - delta)
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
	if state == "recover":  # recuperación castigable: no se mueve ni ataca
		t -= delta
		if t <= 0.0:
			state = "chase"
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
	_separate()
	_place()
	queue_redraw()

func _move(dir: Vector2, mult: float, delta: float) -> void:
	var p: Vector2 = main.world.move_collide(pos, pos + dir * data["speed"] * mult * delta * Vector2(1, 0.6), data["r_t"])
	var off: Vector2 = p - main.pos
	var min_d: float = radius + main.HERO_RADIUS
	if not main.dashing and off.length() < min_d:  # el héroe en dash los atraviesa
		p = main.pos + off.normalized() * min_d
	pos = p

func _separate() -> void:  # los enemigos no se montan unos sobre otros
	for o in main.enemies:
		if o == self or not o.alive:
			continue
		var d: Vector2 = pos - o.pos
		var min_d: float = radius + o.radius
		if d.length() < min_d:
			pos += (d.normalized() if d.length() > 0.01 else Vector2.RIGHT) * (min_d - d.length()) * 0.5

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
		_move(to.normalized(), 2.0, delta)
	if dist < radius + main.HERO_RADIUS + 4.0 and contact_cd == 0.0:
		main.damage_hero(data["contact_damage"])
		contact_cd = data["contact_cooldown"]

func _archer(to: Vector2, dist: float, delta: float) -> void:
	if state == "windup":
		t -= delta
		if t <= 0.0:
			main.spawn_projectile("enemy", pos + aim * 10.0, aim, data["projectile"])
			cd = data["attack_cooldown"]
			state = "recover"
			t = data.get("recover", 0.4)
		return
	if dist < data["flee_distance"]:
		_move(-to.normalized(), 1.1, delta)
		_anim("walk")
	elif dist > data["keep_distance"] + 15.0:
		_move(to.normalized(), 1.0, delta)
		_anim("walk")
	else:
		_anim("idle")
	if cd == 0.0 and main.can_prepare(self):
		state = "windup"
		t = data["windup"]
		aim = to.normalized()
		_play_attack(to, 4, t)  # la flecha sale en el fotograma 4

func _brute(to: Vector2, dist: float, delta: float) -> void:
	if state == "windup":
		t -= delta
		if t <= 0.0:
			state = "recover"
			t = data.get("recover", 0.7)
		return
	if dist > data["attack_range"]:
		_move(to.normalized(), 1.0, delta)
		_anim("walk")
	elif cd == 0.0 and main.can_prepare(self):
		state = "windup"
		t = data["windup"]
		cd = data["attack_cooldown"]
		_play_attack(to, 5, data["windup"])
		_spawn_zone(pos + to.normalized() * 32.0, data["slam_radius"], data["windup"], data["slam_damage"], false, Color(1.0, 0.35, 0.2))
	else:
		_anim("idle")

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
		_move(-to.normalized(), 1.0, delta)
		_anim("walk")
	elif dist > keep + 20.0:
		_move(to.normalized(), 1.0, delta)
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
	else:
		var n := 3 if enraged else 1
		for i in n:
			var a := to.normalized().rotated((i - (n - 1) / 2.0) * 0.3)
			main.spawn_projectile("enemy", pos + a * 12.0, a, data["orb"])

func take_damage(n: int, charge := true) -> void:
	if not alive:
		return
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
	modulate = Color(1.8, 1.8, 1.8)
	flash_tw = create_tween()
	flash_tw.tween_property(self, "modulate", Color.WHITE, 0.15)
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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * S)
	if state == "windup" and data["kind"] in ["archer", "mage"]:  # línea de tiro fijada: el héroe puede salirse
		var k := 1.0 - clampf(t / data.get("windup", 0.7), 0.0, 1.0)
		draw_line(aim * radius, aim * (radius + 40.0 + 120.0 * k), Color(1.0, 0.3, 0.2, 0.35 + 0.5 * k), 1.5)
	var w := maxf(radius * 2.2, 26.0)
	draw_rect(Rect2(-w / 2.0, -body_h - 10.0, w, 3.0), Color(0.1, 0.1, 0.14, 0.85))
	draw_rect(Rect2(-w / 2.0, -body_h - 10.0, w * clampf(float(hp) / data["hp"], 0.0, 1.0), 3.0), Color(0.85, 0.2, 0.2))

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
