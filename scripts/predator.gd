extends Node2D
# Zorro: depredador de conejos y territorial con el héroe. Arte provisional dibujado por código.
# Descansa en su guarida -> caza un conejo visible con energía limitada -> abandona y vuelve a descansar.
# Si el héroe entra en su territorio: advierte (postura + "!") y, si insiste, embiste; fuera del territorio lo deja.

const TERRITORY := 110.0   # px de suelo alrededor de la guarida: entra en alerta
const LEAVE := 150.0       # sale de la alerta (histéresis)
const STRIKE := 60.0       # tras advertir, embiste si el héroe sigue así de cerca
const WARN_TIME := 1.0
const LUNGE_TIME := 0.35
const RECOVER := 1.0
const BITE := 6
const SPOT := 180.0        # ve conejos fuera de la madriguera a esta distancia
const CHASE_ENERGY := 4.0  # s de persecución antes de rendirse
const TIRED := 6.0         # s de descanso tras cazar o rendirse
const EAT := 3.0
const WALK := 30.0
const RUN := 70.0
const LUNGE := 160.0
const R_T := 0.25
const SIZE := 1.6         # escala del dibujo: legible junto al héroe

var main: Node
var world: Node
var den := Vector2.ZERO
var pos := Vector2.ZERO
var state := "rest"        # rest, hunt, eat, home, warn, lunge, recover
var state_t := 0.0
var prey: Node = null
var energy := CHASE_ENERGY
var cool := 0.0            # descanso tras cazar
var dir := Vector2.RIGHT
var bit := false
var face := 1.0
var anim_t := 0.0

func _ready() -> void:
	pos = den
	_place()

func _to(s: String) -> void:
	state = s
	state_t = 0.0

func dangerous() -> bool:  # para que conejos y civiles huyan
	return state in ["hunt", "warn", "lunge"]

func _physics_process(delta: float) -> void:
	visible = not main.in_dungeon
	if main.in_dungeon:
		return
	anim_t += delta
	state_t += delta
	cool = maxf(0.0, cool - delta)
	var hero_den: float = main.pos.distance_to(den)
	var hero_d: float = main.pos.distance_to(pos)
	# el territorio manda sobre la caza
	if state in ["rest", "hunt", "eat", "home"] and hero_den < TERRITORY and not main.dying:
		prey = null
		_to("warn")
		main.combat.play_at("growl", pos)
	match state:
		"rest":
			if cool == 0.0:
				prey = _find_prey()
				if prey:
					energy = CHASE_ENERGY
					_to("hunt")
		"hunt":
			energy -= delta
			if not is_instance_valid(prey) or prey.state == "hidden" or energy <= 0.0:
				prey = null
				cool = TIRED
				_to("home")
			else:
				_step(prey.pos, RUN, delta)
				if pos.distance_to(prey.pos) < 6.0:
					prey.caught()  # el conejo escapa por poco a su madriguera; el zorro se queda comiendo lo que pilló
					prey = null
					_to("eat")
		"eat":
			if state_t > EAT:
				cool = TIRED
				_to("home")
		"home":
			if pos.distance_to(den) < 3.0:
				_to("rest")
			else:
				_step(den, WALK, delta)
		"warn":  # advierte quieto, mirando al héroe
			_face(main.pos.x - pos.x)
			if hero_den > LEAVE:
				_to("home")
			elif state_t > WARN_TIME and hero_d < STRIKE:
				dir = (main.pos - pos).normalized()
				bit = false
				_to("lunge")
		"lunge":
			_step(pos + dir * 50.0, LUNGE, delta)
			if not bit and pos.distance_to(main.pos) < 14.0:
				bit = true
				main.damage_hero(BITE)
			if state_t > LUNGE_TIME:
				_to("recover")
		"recover":  # ventana de castigo: quieto
			if state_t > RECOVER:
				_to("warn" if hero_den < LEAVE else "home")
	_place()
	queue_redraw()

func _find_prey() -> Node:
	var best: Node = null
	for f in main.fauna:
		if f.state != "hidden" and f.pos.distance_to(pos) < SPOT and (best == null or f.pos.distance_to(pos) < best.pos.distance_to(pos)):
			best = f
	return best

func _face(dx: float) -> void:
	if absf(dx) > 1.0:
		face = signf(dx)

func _step(to: Vector2, speed: float, delta: float) -> void:
	var d := (to - pos).normalized()
	_face(d.x)
	var want := pos + d * minf(speed * delta, pos.distance_to(to)) * Vector2(1, 0.6)
	pos = world.move_collide(pos, want, R_T)

func _place() -> void:
	position = pos * main.SCALE
	z_index = int(pos.y)

func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		pts.append(c + Vector2(cos(i * TAU / 16.0) * rx, sin(i * TAU / 16.0) * ry))
	draw_colored_polygon(pts, col)

func _draw() -> void:  # px de suelo, pies en el origen
	var S: float = main.SCALE
	draw_set_transform((den - pos) * S, 0.0, Vector2.ONE * S)
	_ell(Vector2.ZERO, 9.0, 4.5, Color(0.1, 0.07, 0.05, 0.85))  # guarida
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * S)
	_ell(Vector2.ZERO, 8.0, 3.0, Color(0, 0, 0, 0.3))
	var low := 3.0 if state == "warn" else 0.0           # se agacha al advertir
	var run := absf(sin(anim_t * 16.0)) * 2.5 if state in ["hunt", "lunge"] else 0.0
	draw_set_transform(Vector2(0, low - run) * S, 0.0, Vector2(S * face, S) * SIZE)
	var fur := Color("#c8642a")
	if state == "rest" or state == "eat":  # tumbado
		_ell(Vector2(0, -3), 8.0, 3.2, fur)
		_ell(Vector2(7, -4), 3.0, 2.5, fur)
		_ell(Vector2(-9, -2), 4.0, 1.8, Color("#e9e0d0"))
	else:
		_ell(Vector2(0, -7), 8.0, 3.8, fur)                # cuerpo
		for x in [-5.0, 5.0]:
			draw_line(Vector2(x, -5), Vector2(x, 0), Color("#5a2c14"), 1.6)  # patas
		_ell(Vector2(-10, -8), 4.5, 2.0, fur)              # cola
		_ell(Vector2(-13, -8), 1.8, 1.6, Color("#e9e0d0"))
		_ell(Vector2(9, -10), 3.4, 2.8, fur)               # cabeza
		draw_colored_polygon(PackedVector2Array([Vector2(8, -12), Vector2(9, -16), Vector2(10.5, -12)]), fur)  # oreja
		draw_circle(Vector2(10.5, -10.5), 0.7, Color("#1a1210"))
		if state == "warn":  # dientes
			draw_line(Vector2(11, -8.5), Vector2(13, -8.5), Color.WHITE, 0.8)
	if state == "warn":  # aviso por forma, no solo color
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * S)
		draw_string(ThemeDB.fallback_font, Vector2(-3, -34), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.85, 0.2))
