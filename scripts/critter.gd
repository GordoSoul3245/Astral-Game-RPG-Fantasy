extends Node2D
# Presa (conejo): pasta cerca de su madriguera, observa al héroe, huye a la madriguera, se esconde y vuelve.
# No combate ni bloquea (no está en main.enemies). Arte provisional dibujado por código.
# Umbrales distintos para entrar/salir y tiempo mínimo por estado: no oscila en los bordes.

const NOTICE := 120.0      # px de suelo: empieza a observar
const CALM := 160.0        # deja de observar (más lejos que NOTICE: histéresis)
const FLEE := 75.0         # huye
const SAFE_TIME := 3.0     # escondido, sale tras este tiempo con el héroe lejos (> CALM)
const MIN_STATE := 0.6     # s mínimos en cada estado antes de cambiar (salvo huir)
const GRAZE_R := 45.0      # radio de pasto alrededor de la madriguera
const WALK := 18.0
const RUN := 115.0
const R_T := 0.2           # radio de colisión en casillas

var main: Node
var world: Node            # mapa exterior donde vive (no el de la dungeon)
var home := Vector2.ZERO   # madriguera, px de suelo
var pos := Vector2.ZERO
var state := "graze"       # graze, watch, flee, hidden
var state_t := 0.0
var goal := Vector2.ZERO
var wait := 0.0
var face := 1.0
var anim_t := 0.0
var look := Vector2.DOWN   # dirección del sprite
var spr: AnimatedSprite2D  # sprite de Blender; si falta, se dibuja por código

var data := {}             # data/creatures.json "rabbit": vida, botín, reaparición
var hit := {}              # hitbox corporal medida del sprite (hitbox.gd)
var alive := true
var hp := 1
var radius := 6.0
var dead_t := 0.0
var flash_tw: Tween

func take_damage(n: int, charge := true) -> void:  # mismo contrato que enemy.gd (combat.hit lo usa)
	if not alive:
		return
	if charge:
		main.gain_ultimate(minf(n, hp))
	hp -= n
	if flash_tw:
		flash_tw.kill()
	modulate = Color(3, 3, 3)
	flash_tw = create_tween()
	flash_tw.tween_property(self, "modulate", Color.WHITE, 0.15)
	if hp <= 0:
		alive = false
		dead_t = data.get("respawn", 45.0)
		main.on_kill(self)
		visible = false
	elif state != "hidden":
		_flee()

func _ready() -> void:
	data = main.creatures["rabbit"]
	hp = data["hp"]
	radius = data["radius"]
	pos = home
	goal = home
	spr = preload("res://scripts/life_sprite.gd").build(self, main, "res://art/fauna/rabbit_", {"idle": 1, "watch": 1, "walk": 8})
	hit = preload("res://scripts/life_sprite.gd").hitbox(main, "res://art/fauna/rabbit_")
	_place()

func _anim() -> void:
	if spr == null:
		return
	spr.visible = state != "hidden"
	var moving := pos.distance_to(goal) > 2.0
	if state == "watch":
		look = main.pos - pos
	var kind := "walk" if state == "flee" or (state == "graze" and moving) else ("watch" if state == "watch" else "idle")
	preload("res://scripts/life_sprite.gd").show(spr, main, kind, look, 2.0 if state == "flee" else 1.0)

func _to(s: String) -> void:
	state = s
	state_t = 0.0

func _physics_process(delta: float) -> void:
	if not alive:  # reaparece más tarde en su madriguera, escondido
		dead_t -= delta
		if dead_t > 0.0:
			return
		alive = true
		hp = data["hp"]
		pos = home
		_to("hidden")
	visible = not main.in_dungeon
	if main.in_dungeon:
		return
	anim_t += delta
	state_t += delta
	var d: float = _threat()
	match state:
		"graze":
			if d < FLEE:
				_flee()
			elif d < NOTICE and state_t > MIN_STATE:
				_to("watch")
			else:
				_graze(delta)
		"watch":  # se queda quieto mirando
			if absf(main.pos.x - pos.x) > 1.0:
				face = signf(main.pos.x - pos.x)
			if d < FLEE:
				_flee()
			elif d > CALM and state_t > MIN_STATE:
				_to("graze")
		"flee":
			if pos.distance_to(home) < 3.0:
				_to("hidden")
			else:
				_step(home, RUN, delta)
		"hidden":
			if d < CALM:
				state_t = 0.0  # aún hay peligro: el reloj de seguridad vuelve a cero
			elif state_t > SAFE_TIME:
				_to("graze")
	_anim()
	_place()
	queue_redraw()

const GROUP := 90.0  # al huir, los conejos cercanos que pastan levantan las orejas y miran

func _flee() -> void:  # chillido y aviso al grupo (no los hace huir: solo ponerse alerta)
	_to("flee")
	main.combat.play_at("squeak", pos)
	for f in main.fauna:
		if f != self and f.state == "graze" and f.pos.distance_to(pos) < GROUP:
			f._to("watch")

func _threat() -> float:  # distancia a la amenaza más cercana: el héroe, un depredador activo o un ruido de combate
	if main.noise_near(pos):
		return 0.0
	var d: float = pos.distance_to(main.pos)
	for p in main.predators:
		if p.alive and p.dangerous():
			d = minf(d, pos.distance_to(p.pos))
	return d

func caught() -> void:  # el depredador lo alcanzó: escapa por poco y se mete en la madriguera
	pos = home
	_to("hidden")

func _graze(delta: float) -> void:
	wait -= delta
	if pos.distance_to(goal) > 2.0:
		_step(goal, WALK, delta)
	elif wait <= 0.0:  # pausa variable y nuevo bocado cerca de casa
		wait = randf_range(1.0, 2.5)
		goal = home + Vector2.from_angle(randf() * TAU) * randf_range(10.0, GRAZE_R)

func _step(to: Vector2, speed: float, delta: float) -> void:
	var dir := (to - pos).normalized()
	if absf(dir.x) > 0.1:
		face = signf(dir.x)
	if dir != Vector2.ZERO:
		look = dir
	var want := pos + dir * minf(speed * delta, pos.distance_to(to)) * Vector2(1, 0.6)  # suelo aplastado en Y, como los enemigos
	if want.distance_to(to) < 0.5:
		want = to
	var p: Vector2 = world.move_collide(pos, want, R_T)
	if p.distance_to(pos) < 0.01 and state == "graze":
		goal = pos  # bloqueado: elige otro bocado
	pos = p

func _place() -> void:
	position = pos * main.SCALE
	z_index = int(pos.y)

func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		pts.append(c + Vector2(cos(i * TAU / 16.0) * rx, sin(i * TAU / 16.0) * ry))
	draw_colored_polygon(pts, col)

func _draw() -> void:  # unidades: px de suelo, pies en el origen
	var S: float = main.SCALE
	draw_set_transform((home - pos) * S, 0.0, Vector2.ONE * S)
	_ell(Vector2.ZERO, 6.0, 3.0, Color(0.12, 0.08, 0.05, 0.9))  # madriguera
	var fur := Color("#9b7a55")
	if state == "hidden":
		if fmod(anim_t, 2.0) < 0.6:  # asoma las orejas de vez en cuando
			draw_line(Vector2(-1.5, -1), Vector2(-2, -6), fur, 1.6)
			draw_line(Vector2(1.5, -1), Vector2(2, -6), fur, 1.6)
		return
	if spr:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * S)
		_ell(Vector2.ZERO, 5.0, 2.2, Color(0, 0, 0, 0.3))  # sombra
		return
	var moving := pos.distance_to(goal) > 2.0
	var hop := 0.0
	if state == "flee":
		hop = absf(sin(anim_t * 18.0)) * 4.0
	elif state == "graze" and moving:
		hop = absf(sin(anim_t * 9.0)) * 2.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * S)
	_ell(Vector2.ZERO, 5.0, 2.2, Color(0, 0, 0, 0.3))  # sombra
	draw_set_transform(Vector2(0, -hop) * S, 0.0, Vector2(S * face, S) * 1.3)
	var head_y := -6.0 if state == "graze" and not moving else -9.0  # baja la cabeza al pastar
	_ell(Vector2(-1, -4), 5.5, 4.0, fur)                    # cuerpo
	_ell(Vector2(-6, -5), 1.8, 1.8, Color("#efe6d8"))       # cola
	_ell(Vector2(4, head_y + 2), 3.0, 2.6, fur)              # cabeza
	var ear := 7.0 if state == "watch" else 5.0             # orejas erguidas al observar
	draw_line(Vector2(3, head_y), Vector2(2, head_y - ear), fur, 1.6)
	draw_line(Vector2(5, head_y), Vector2(5.5, head_y - ear), fur, 1.6)
	draw_circle(Vector2(5.5, head_y + 1.5), 0.7, Color("#1a1210"))  # ojo
