extends Node2D
# Bola de fuego: viaja en línea recta sin límite de alcance hasta chocar con el borde del suelo o un obstáculo.

signal hit(ground_pos: Vector2)

var main: Node            # main.gd: expone SCALE, fx_frames, floor_contains() y hits_obstacle()
var dir := Vector2.RIGHT
var speed := 260.0
var radius := 6.0         # px del suelo original
var height := 40.0        # altura de la mano sobre el suelo, en px del sprite
var ground := Vector2.ZERO  # posición en el suelo, px del suelo original (misma unidad que `pos` del héroe)
var source := "hero"       # quién disparó: "hero" daña al dragón, "dragon" daña al héroe
var damage := 0
var tint := Color.WHITE
var scale_mult := 1.0       # tamaño del sprite (la esfera pesada es más grande)
var effect := "fire"        # fire (marca de Ignis), slow (hielo: ralentiza) o chain (rayo: salta a otros enemigos)
var aoe := 0.0              # radio de explosión en px de suelo; 0 = daño solo por impacto directo
var sprite: AnimatedSprite2D
var dead := false
var trail_points: Array[Vector2] = []
var trail_distance := 0.0
var glow: PointLight2D
var t := 0.0               # reloj de la animación de energía (órbitas y pulso del halo)
const HB := preload("res://scripts/hitbox.gd")  # hitbox del cuerpo (silueta del sprite), no un círculo en el suelo

func _burn(e: Node) -> void:  # golpe del héroe: daña y, según el hechizo, marca (fuego), ralentiza (hielo) o encadena (rayo)
	main.combat.hit(e, damage, "magic", ground)
	match effect:
		"slow":
			if "slow_t" in e:
				e.slow_t = 3.0
				main.popup(e.pos, "❄", Color(0.6, 0.9, 1.0))
		"chain":
			var n := 0
			for o in main.targets():  # el rayo salta a los 2 enemigos más cercanos con un 60 % del daño
				if n >= 2:
					break
				if o != e and o.alive and o.pos.distance_to(e.pos) < 130.0:
					main.combat.hit(o, roundi(float(damage) * 0.6), "magic", e.pos, false)
					main.popup(o.pos, "⚡", Color(0.85, 0.75, 1.0))
					n += 1
		_:
			main.combat.mark(e)

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = main.fx_frames
	sprite.scale = Vector2.ONE * main.SCALE * scale_mult
	sprite.rotation = dir.angle()
	sprite.modulate = tint
	add_child(sprite)
	sprite.play("fly")
	glow = main.combat.light(tint if tint != Color.WHITE else Color(1.0, 0.6, 0.25), 0.5 * scale_mult, 0.9 * scale_mult)
	glow.position = Vector2(0, height * 0.6) * main.SCALE  # ilumina el suelo bajo la bola
	add_child(glow)
	_sync()

func _sync() -> void:
	position = (ground - Vector2(0, height)) * main.SCALE
	z_index = int(ground.y) + 5

func _physics_process(delta: float) -> void:
	if dead:
		return
	trail_distance += speed * delta
	t += delta
	if trail_distance >= 5.0:
		trail_distance = 0.0
		trail_points.push_front((ground - Vector2(0, height)) * main.SCALE)
		if trail_points.size() > 7:
			trail_points.pop_back()
	queue_redraw()
	var step := dir * speed * delta
	# subdivide para no atravesar obstáculos a velocidad alta
	var n := maxi(1, ceili(step.length() / 4.0))
	for i in n:
		ground += step / n
		if not main.floor_contains(ground) or main.hits_obstacle(ground):
			_explode()
			return
		var air := ground - Vector2(0, height)  # donde se ve la bola en pantalla (misma unidad que las hitbox)
		if source == "hero":
			for e in main.targets():
				if e.alive and HB.dist(e, air) < radius:
					if aoe == 0.0:
						_burn(e)
					_explode()
					return
		elif not main.dashing and HB.dist(main, air) < radius:  # en dash la bola lo atraviesa
			main.damage_hero(damage)
			_explode()
			return
	_sync()

func _explode() -> void:
	dead = true
	if aoe > 0.0 and source == "hero":
		for e in main.targets():  # explosión en área: alcanza a los enemigos cercanos aunque no sean impacto directo
			if e.alive and HB.foot_dist(e, ground) < aoe:
				_burn(e)
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE * main.SCALE * maxf(1.5, aoe / 20.0)
	sprite.play("impact")
	glow.create_tween().tween_property(glow, "energy", 0.0, 0.3)
	sprite.animation_finished.connect(queue_free)
	hit.emit(ground)
	_sync()

func _draw() -> void:
	if dead:
		return
	for i in trail_points.size():
		var strength := 1.0 - float(i) / 7.0
		var col := Color(1.0, 0.45, 0.12, strength * 0.65) * tint
		var size := 3.0 * maxf(1.0, roundf(strength * scale_mult * 2.0))
		var point := (trail_points[i] - position).snapped(Vector2(3, 3))
		draw_rect(Rect2(point - Vector2.ONE * size * 0.5, Vector2.ONE * size), col)
	_draw_energy()

# capas de una bola de energía (de fuera a dentro): cola de cometa que se afila, halo que pulsa,
# chispas que orbitan en elipse (plano del suelo) y el sprite como núcleo. Todo en px de arte (múltiplos de 3).
func _draw_energy() -> void:
	var base := Color(1.0, 0.55, 0.2) * tint
	var r: float = radius * main.SCALE * scale_mult
	var n := trail_points.size()
	if n >= 2:
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for i in n:
			var p := trail_points[i] - position
			var d := (trail_points[maxi(i - 1, 0)] - trail_points[mini(i + 1, n - 1)]).normalized()
			var w: float = r * 0.9 * (1.0 - float(i) / n)
			left.append(p + d.orthogonal() * w)
			right.append(p - d.orthogonal() * w)
		right.reverse()
		var tail := left + right
		var tc := base
		tc.a = 0.35
		if Geometry2D.triangulate_polygon(tail).size() > 0:
			draw_colored_polygon(tail, tc)
	var halo := base
	halo.a = 0.3
	draw_arc(Vector2.ZERO, r * (1.25 + 0.15 * sin(t * 22.0)), 0.0, TAU, 16, halo, 3.0)
	var spark := base.lightened(0.5)
	for k in 3:
		var a := t * 9.0 + k * TAU / 3.0
		var o: Vector2 = (Vector2(cos(a), sin(a) * 0.5) * r * 1.5).snapped(Vector2(3, 3))
		draw_rect(Rect2(o - Vector2(3, 3), Vector2(6, 6)), spark)
