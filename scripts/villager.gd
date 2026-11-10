extends Node2D
# Civil: va y viene entre su trabajo y su descanso con pausas variables, mira al héroe cuando se acerca,
# se aparta si se le echa encima, y ante peligro (dragón o depredador activo cerca) huye a su refugio y luego vuelve.
# Su destino pendiente se conserva: al terminar de mirar o de esconderse sigue hacia donde iba. Arte provisional.

const LOOK := 60.0         # empieza a mirar al héroe
const UNLOOK := 90.0       # deja de mirar (histéresis)
const PERSONAL := 20.0     # se aparta si el héroe está así de cerca
const DANGER := 170.0      # huye si un peligro activo está así de cerca
const SAFE_TIME := 3.0
const MIN_STATE := 0.5
const WALK := 22.0
const RUN := 75.0
const R_T := 0.25

var main: Node
var world: Node
var work := Vector2.ZERO
var rest := Vector2.ZERO   # también es su refugio
var stroll := Vector2.ZERO # paseo más lejano: solo cuando el dragón ya no amenaza la zona
const LINES := {
	"dragon": ["¡Ten cuidado! El dragón ronda cerca del castillo.", "No salgo lejos mientras viva esa bestia."],
	"calm": ["Desde que cayó el dragón, por fin puedo pasear.", "Gracias, viajero. Se respira otra cosa."],
	"fox": ["Ese zorro no deja en paz a los conejos.", "No te acerques a la guarida del zorro: muerde."],
}
var talk_i := 0
var pos := Vector2.ZERO
var state := "walk"        # walk, pause, look, flee, hide
var state_t := 0.0
var goal := Vector2.ZERO   # destino pendiente (trabajo o descanso)
var wait := 0.0
var face := 1.0
var anim_t := 0.0

var look := Vector2.DOWN
var spr: AnimatedSprite2D  # sprite de Blender; si falta, se dibuja por código

func _ready() -> void:
	pos = rest
	goal = work
	spr = preload("res://scripts/life_sprite.gd").build(self, main, "res://art/fauna/villager_", {"idle": 1, "hide": 1, "walk": 8, "flee": 8})
	_place()

func _anim() -> void:
	if spr == null:
		return
	if state in ["look", "talk"]:
		look = main.pos - pos
	var kind := "idle"
	match state:
		"walk": kind = "walk"
		"flee": kind = "flee"
		"hide": kind = "hide"
	preload("res://scripts/life_sprite.gd").show(spr, main, kind, look, 1.6 if state == "flee" else 1.0)

func _to(s: String) -> void:
	state = s
	state_t = 0.0

func can_talk() -> bool:
	return state in ["walk", "pause", "look", "talk"]

func talk() -> String:  # detiene la actividad un momento sin perder su destino pendiente
	_to("talk")
	var topic := "calm" if not main.dragon.alive else "dragon"
	if talk_i % 3 == 2:
		topic = "fox"
	var l: Array = LINES[topic]
	talk_i += 1
	return l[talk_i % l.size()]

func _next_goal() -> Vector2:  # trabajo -> descanso -> (paseo si el dragón cayó) -> trabajo
	if goal == work:
		return rest
	if goal == rest and not main.dragon.alive:
		return stroll
	return work

func _danger() -> bool:
	if main.noise_near(pos):
		return true
	if main.dragon.alive and main.dragon.visible and pos.distance_to(main.dragon.pos) < DANGER:
		return true
	for p in main.predators:
		if p.dangerous() and pos.distance_to(p.pos) < DANGER:
			return true
	return false

func _physics_process(delta: float) -> void:
	visible = not main.in_dungeon
	if main.in_dungeon:
		return
	anim_t += delta
	state_t += delta
	var hero_d: float = pos.distance_to(main.pos)
	if state != "flee" and state != "hide" and _danger():
		_to("flee")
		main.combat.play_at("shout", pos)
	match state:
		"walk":
			if hero_d < LOOK and state_t > MIN_STATE:
				_to("look")
			elif pos.distance_to(goal) < 2.0:
				wait = randf_range(4.0, 7.0) if goal == rest else randf_range(2.0, 4.0)  # descansa más de lo que trabaja
				_to("pause")
			else:
				_step(goal, WALK, delta)
		"pause":  # trabaja o descansa un rato y cambia de destino
			if hero_d < LOOK:
				_to("look")
			elif state_t > wait:
				goal = _next_goal()
				_to("walk")
		"talk":  # se queda mirando al héroe mientras habla
			if absf(main.pos.x - pos.x) > 1.0:
				face = signf(main.pos.x - pos.x)
			if state_t > 3.0 or hero_d > UNLOOK:
				_to("walk")
		"look":  # se gira hacia el héroe; si se le echa encima, da un paso al lado
			if absf(main.pos.x - pos.x) > 1.0:
				face = signf(main.pos.x - pos.x)
			if hero_d < PERSONAL:
				var away: Vector2 = (pos - main.pos).normalized()
				_step(pos + away.orthogonal() * 10.0 + away * 4.0, WALK * 1.5, delta)
			elif hero_d > UNLOOK and state_t > MIN_STATE:
				_to("walk")  # retoma el destino que tenía
		"flee":
			if pos.distance_to(rest) < 3.0:
				_to("hide")
			else:
				_step(rest, RUN, delta)
		"hide":
			if _danger():
				state_t = 0.0
			elif state_t > SAFE_TIME:
				_to("walk")
	_anim()
	_place()
	queue_redraw()

func _step(to: Vector2, speed: float, delta: float) -> void:
	var d := (to - pos).normalized()
	if absf(d.x) > 0.1 and state != "look":
		face = signf(d.x)
	if d != Vector2.ZERO and state != "look":
		look = d
	var want := pos + d * minf(speed * delta, pos.distance_to(to)) * Vector2(1, 0.6)
	if want.distance_to(to) < 0.5:
		want = to
	pos = world.move_collide(pos, want, R_T)

func _place() -> void:
	position = pos * main.SCALE
	z_index = int(pos.y)

func _draw() -> void:  # px de suelo, pies en el origen
	var S: float = main.SCALE
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * S)
	var sh := PackedVector2Array()
	for i in 16:
		sh.append(Vector2(cos(i * TAU / 16.0) * 7.0, sin(i * TAU / 16.0) * 3.0))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.3))
	if spr:
		return
	var moving := state in ["walk", "flee"] or (state == "look" and pos.distance_to(main.pos) < PERSONAL)
	var bob := absf(sin(anim_t * (14.0 if state == "flee" else 8.0))) * 1.5 if moving else 0.0
	var crouch := 8.0 if state == "hide" else 0.0
	draw_set_transform(Vector2(0, -bob + crouch) * S, 0.0, Vector2(S * face, S))
	var step := sin(anim_t * (14.0 if state == "flee" else 8.0)) * 3.0 if moving else 0.0
	draw_line(Vector2(-2, -18), Vector2(-2 + step, 0), Color("#4a3a2a"), 2.4)  # piernas
	draw_line(Vector2(2, -18), Vector2(2 - step, 0), Color("#4a3a2a"), 2.4)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -18), Vector2(6, -18), Vector2(5, -36), Vector2(-5, -36)]), Color("#6b8f5a"))  # túnica
	draw_rect(Rect2(-6, -22, 12, 2), Color("#5a3b22"))  # cinturón
	var arm := -40.0 if state == "flee" else -28.0      # brazos arriba al huir
	draw_line(Vector2(4, -34), Vector2(8, arm + 12), Color("#e0b98f"), 2.0)
	draw_circle(Vector2(0, -41), 5.0, Color("#e0b98f"))  # cabeza
	draw_colored_polygon(PackedVector2Array([Vector2(-6, -43), Vector2(6, -43), Vector2(0, -50)]), Color("#b89a5a"))  # sombrero de paja
	draw_circle(Vector2(2.5, -41.5), 0.8, Color("#1a1210"))  # ojo
