extends RefCounted
# Minijuego de pesca (estilo Stardew Valley). Una barra sube mientras se mantiene el clic y cae al soltarlo; hay que mantener al pez
# dentro de ella. El medidor de progreso sube con el pez dentro y baja si se escapa. Todo en 0..1 (0 = fondo). Lógica pura: la dibuja fishing.gd.

const GRAVITY := 2.1
const LIFT := 3.6
const MAX_V := 1.5
const GAIN := 0.22        # progreso por segundo con el pez dentro
const START := 0.3

var move := "mixed"       # mixed, dart, smooth, sinker o floater
var diff := 30.0          # 0..100: más rápido, más nervioso y pierde progreso antes
var size := 0.25          # alto de la barra
var bar := 0.0            # borde inferior de la barra
var bar_v := 0.0
var fish := 0.5
var target := 0.5
var retarget := 0.0
var gain_mult := 1.0      # el carrete de la caña llena el medidor más rápido
var boost := 1.0          # los dardos del pez multiplican su velocidad un rato
var progress := START
var perfect := true       # nunca perdió al pez
var done := false
var won := false
var rng := RandomNumberGenerator.new()
# cofre del fondo (opcional): aparece tras un rato; mantener la barra sobre él lo llena, salir lo vacía
var chest := -1.0         # altura del cofre (-1 = no hay)
var chest_wait := 0.0     # segundos hasta que aparece
var chest_progress := 0.0
var chest_got := false
var chest_fill := 0.45
var chest_drain := 0.25
var t := 0.0

func setup(move_kind: String, difficulty: float, bar_size: float) -> void:
	move = move_kind
	diff = difficulty
	size = bar_size
	rng.randomize()
	fish = rng.randf_range(0.2, 0.8)
	target = fish
	bar = clampf(fish - size * 0.5, 0.0, 1.0 - size)

func with_chest(delay: float, fill: float, drain: float) -> void:
	chest_wait = delay
	chest_fill = fill
	chest_drain = drain
	chest = -2.0  # pendiente de aparecer

func chest_inside() -> bool:
	return chest >= 0.0 and chest >= bar and chest <= bar + size

func inside() -> bool:
	return fish >= bar and fish <= bar + size

func step(dt: float, hold: bool) -> void:
	if done:
		return
	bar_v = clampf(bar_v + (LIFT if hold else -GRAVITY) * dt, -MAX_V, MAX_V)
	bar += bar_v * dt
	if bar < 0.0:
		bar = 0.0
		bar_v = -bar_v * 0.35  # rebota un poco en el fondo
	elif bar > 1.0 - size:
		bar = 1.0 - size
		bar_v = 0.0
	t += dt
	if chest == -2.0 and t >= chest_wait:
		chest = rng.randf_range(0.1, 0.9)
	if chest >= 0.0 and not chest_got:
		chest_progress = clampf(chest_progress + (chest_fill if chest_inside() else -chest_drain) * dt, 0.0, 1.0)
		if chest_progress >= 1.0:
			chest_got = true
	retarget -= dt
	if retarget <= 0.0:
		_pick_target()
	fish = move_toward(fish, target, (0.18 + diff / 100.0 * 0.7) * boost * dt)
	if inside():
		progress += GAIN * gain_mult * dt
	else:
		progress -= (0.12 + diff / 100.0 * 0.1) * dt
		perfect = false
	progress = clampf(progress, 0.0, 1.0)
	if progress >= 1.0 or progress <= 0.0:
		done = true
		won = progress >= 1.0

func _pick_target() -> void:
	boost = 1.0
	var calm := 1.3 - diff / 150.0   # los peces difíciles cambian de idea antes
	match move:
		"dart":
			if rng.randf() < 0.35:  # dardo: cruza la barra a toda velocidad
				target = 1.0 - fish if absf(1.0 - fish - fish) > 0.3 else rng.randf()
				boost = 2.6
				retarget = 0.45
			else:
				target = clampf(fish + rng.randf_range(-0.15, 0.15), 0.03, 0.97)
				retarget = rng.randf_range(0.3, 0.7) * calm
		"smooth":
			target = clampf(fish + rng.randf_range(-0.25, 0.25), 0.03, 0.97)
			retarget = rng.randf_range(0.9, 1.8) * calm
		"sinker":  # tiende al fondo y de vez en cuando salta
			target = rng.randf_range(0.0, 0.45) if rng.randf() < 0.75 else rng.randf_range(0.5, 0.95)
			retarget = rng.randf_range(0.6, 1.4) * calm
		"floater":  # tiende a subir
			target = rng.randf_range(0.55, 0.97) if rng.randf() < 0.75 else rng.randf_range(0.05, 0.5)
			retarget = rng.randf_range(0.6, 1.4) * calm
		_:
			target = rng.randf_range(0.04, 0.96)
			retarget = rng.randf_range(0.5, 1.4) * calm
