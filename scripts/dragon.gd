extends AnimatedSprite2D
# Dragón: detecta al héroe, lo sigue manteniendo distancia y le escupe bolas de fuego.

enum State { IDLE, CHASE, ATTACK, TIRED }  # TIRED al final: los valores existentes no cambian

const VOLLEY := 3          # ataques seguidos antes de quedarse sin aliento
const TIRED_TIME := 3.0    # s de ventana de castigo
const TIRED_BONUS := 1.5   # daño recibido mientras respira
var attacks := 0           # ataques desde el último descanso: el 2.º de cada ráfaga es un abanico de 3 bolas
var tired_t := 0.0

const FIRE_FRAME := 4  # fotograma de la animación de ataque en que sale el fuego

var main: Node
var data := {}               # entrada "dragon" de data/creatures.json
var pos := Vector2.ZERO      # pies, en píxeles del suelo original
var radius := 14.0           # contra proyectiles y ataques (como el resto de enemigos)
var hit := {}                # hitbox corporal medida del sprite (hitbox.gd)
var hp := 0
var alive := true
var state := State.IDLE
var facing := "S"
var attack_cd := 0.0
var fired := false
var flash_tween: Tween
var death_tween: Tween
var waypoint := Vector2.ZERO  # siguiente casilla del camino hacia el héroe
var repath := 0.0

func _ready() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for dir in main.DIRS:
		for kind in ["idle", "walk", "attack", "death"]:
			var key := "%s_%s" % [kind, dir]
			frames.add_animation(key)
			frames.set_animation_speed(key, 8.0 if kind == "walk" else 10.0)
			frames.set_animation_loop(key, kind not in ["attack", "death"])
			for i in (1 if kind == "idle" else (12 if kind == "death" else 8)):
				frames.add_frame(key, load("res://art/dragon/dragon_%s_%s_%02d.png" % [dir, kind, i]))
	sprite_frames = frames
	centered = false
	scale = Vector2.ONE * main.SCALE
	hp = data["hp"]
	var HB := preload("res://scripts/hitbox.gd")
	hit = HB.measure(main.DIRS, "res://art/dragon/dragon_%s_idle_00.png", main.FEET)
	frame_changed.connect(_on_frame_changed)
	animation_finished.connect(_on_animation_finished)
	play("idle_S")
	_place()

func _dir_name(v: Vector2) -> String:
	return main.DIRS[posmod(roundi(v.angle() / (PI / 4.0)), 8)]

func _physics_process(delta: float) -> void:
	if not alive:
		return
	attack_cd = maxf(0.0, attack_cd - delta)
	if state == State.TIRED:  # respira: quieto, sin atacar y con el pecho hinchándose; ventana de castigo
		tired_t -= delta
		play("idle_" + facing)
		scale = Vector2(1.0, 1.0 + 0.04 * sin(tired_t * 9.0)) * main.SCALE
		if tired_t <= 0.0:
			state = State.CHASE
			attacks = 0
			scale = Vector2.ONE * main.SCALE
		_place()
		return
	var to: Vector2 = main.pos - pos
	var dist := to.length()
	if state == State.IDLE:
		if dist < data["detect_range"]:
			state = State.CHASE
	elif state == State.CHASE:
		if dist > data["detect_range"] * 1.5:  # perdió al héroe
			state = State.IDLE
			play("idle_" + facing)
			return
		facing = _dir_name(to)
		var keep: float = data["keep_distance"]
		if dist > keep + 10.0:
			repath -= delta
			if repath <= 0.0:  # recalcula el camino cada 0.25 s
				repath = 0.25
				waypoint = main.world.next_waypoint(pos, main.pos, main.DRAGON_R_T)
			var step := waypoint - pos
			_move(step.normalized() if step.length() > 1.0 else to.normalized(), 1.0, delta)
		elif dist < keep - 30.0:
			_move(-to.normalized(), 0.6, delta)  # retrocede si el héroe se acerca demasiado
		else:
			play("idle_" + facing)
		if dist <= data["attack_range"] and attack_cd == 0.0:
			state = State.ATTACK
			fired = false
			facing = _dir_name(to)
			play("attack_" + facing)
	_place()

func _move(dir: Vector2, mult: float, delta: float) -> void:
	play("walk_" + facing)
	var p: Vector2 = main.world.move_collide(pos, pos + dir * data["speed"] * mult * delta * Vector2(1, 0.6), main.DRAGON_R_T)
	var off_h: Vector2 = p - main.pos
	if not main.dashing and off_h.length() < main.HERO_RADIUS + main.DRAGON_RADIUS:  # el héroe en dash lo atraviesa
		p = main.pos + off_h.normalized() * (main.HERO_RADIUS + main.DRAGON_RADIUS)
	pos = p

func _on_frame_changed() -> void:
	if state == State.ATTACK and not fired and animation.begins_with("attack_") and frame == FIRE_FRAME:
		fired = true
		var dir: Vector2 = (main.pos - pos).normalized()
		var fan: Array = [-0.32, 0.0, 0.32] if attacks % VOLLEY == 1 else [0.0]  # el 2.º ataque de cada ráfaga es un abanico
		for a: float in fan:
			var d := dir.rotated(a)
			main.spawn_projectile("dragon", pos + d * 22.0, d, data["projectile"], Color(1.0, 0.45, 0.45))

func _on_animation_finished() -> void:
	if not alive:
		return
	if state == State.ATTACK:
		attacks += 1
		attack_cd = data["attack_cooldown"]
		play("idle_" + facing)
		if attacks >= VOLLEY:  # tras la ráfaga se queda sin aliento: ventana de castigo
			state = State.TIRED
			tired_t = TIRED_TIME
			main.popup(pos - Vector2(0, 30), "¡Sin aliento!", Color(1.0, 0.85, 0.3))
			main.combat.play_at("growl", pos)
		else:
			state = State.CHASE

func take_damage(n: int, charge := true) -> void:
	if not alive:
		return
	if state == State.TIRED:
		n = roundi(n * TIRED_BONUS)  # cansado: recibe más daño
	if charge:  # golpear entidades carga la ultimate (el daño de las propias ultimates no la recarga)
		main.gain_ultimate(minf(n, hp))
	hp -= n
	if state == State.IDLE:
		state = State.CHASE  # un golpe lo alerta aunque esté lejos
	modulate = Color(1.8, 1.8, 1.8)
	if flash_tween:
		flash_tween.kill()
	flash_tween = create_tween()
	flash_tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	if hp <= 0:
		alive = false
		main.on_kill(self)
		offset = Vector2(-16, -16) # El render de muerte añade margen sin cambiar los píxeles por metro.
		play("death_" + facing)
		death_tween = create_tween()
		death_tween.tween_interval(1.6)
		death_tween.tween_property(self, "modulate:a", 0.0, 0.6)

func reset(start: Vector2) -> void:
	if death_tween:
		death_tween.kill()
	if flash_tween:
		flash_tween.kill()
	offset = Vector2.ZERO
	pos = start
	hp = data["hp"]
	alive = true
	attacks = 0
	state = State.IDLE
	modulate = Color.WHITE
	scale = Vector2.ONE * main.SCALE
	play("idle_S")
	_place()

func _place() -> void:
	position = (pos - main.FEET) * main.SCALE
	z_index = int(pos.y)
