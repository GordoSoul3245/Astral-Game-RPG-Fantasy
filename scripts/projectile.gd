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
var aoe := 0.0              # radio de explosión en px de suelo; 0 = daño solo por impacto directo
var sprite: AnimatedSprite2D
var dead := false
var glow: PointLight2D
const HB := preload("res://scripts/hitbox.gd")  # hitbox del cuerpo (silueta del sprite), no un círculo en el suelo

func _burn(e: Node) -> void:  # golpe de fuego del héroe: daña y deja la marca de Ignis si sobrevive
	main.combat.hit(e, damage, "magic", ground)
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
