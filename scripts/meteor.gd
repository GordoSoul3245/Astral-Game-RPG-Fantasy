extends Node2D
# Meteoro: una esfera de fuego cae del cielo sobre un área de casillas y explota; el suelo avisa mientras cae.

const SKY := 320.0   # altura inicial sobre el suelo, en px de sprite

var main: Node
var cell := Vector2.ZERO     # casilla central del impacto
var spec := {}               # entrada "ultimate" del grimorio (data/items.json)
var t := 0.0
var target := Vector2.ZERO   # centro de la casilla, en px de suelo
var fall: AnimatedSprite2D
var marker: Node2D

func _ready() -> void:
	var n: float = spec["aoe_tiles"]
	var half := floorf(n / 2.0)
	target = main.tile_to_ground(cell + Vector2(0.5, 0.5))
	marker = Node2D.new()
	marker.set_script(load("res://scripts/tile_marker.gd"))
	marker.main = main
	marker.rect = Rect2(cell - Vector2(half, half), Vector2(n, n))
	marker.color = Color(1.0, 0.3, 0.1)
	marker.z_index = -3000
	add_child(marker)
	fall = AnimatedSprite2D.new()
	fall.sprite_frames = main.fx_frames
	fall.scale = Vector2.ONE * main.SCALE * 5.0
	fall.rotation = PI / 2.0     # la cola de la bola apunta hacia arriba
	fall.modulate = Color(1.0, 0.75, 0.45)
	fall.z_index = 3000
	add_child(fall)
	fall.play("fly")
	_place()

func _place() -> void:
	var p := clampf(t / spec["fall_time"], 0.0, 1.0)
	fall.position = (target - Vector2(0, SKY * (1.0 - p * p))) * main.SCALE  # cae acelerando

func _process(delta: float) -> void:
	t += delta
	_place()
	if t >= spec["fall_time"]:
		set_process(false)
		_explode()

func _explode() -> void:
	var n: float = spec["aoe_tiles"]
	var center: Vector2 = cell + Vector2(0.5, 0.5)
	for e in main.targets():  # daño en área: todo lo que esté dentro del cuadrado de n x n casillas
		if not e.alive:
			continue
		var tt: Vector2 = main.ground_to_tile(e.pos)
		if absf(tt.x - center.x) <= n / 2.0 + 0.35 and absf(tt.y - center.y) <= n / 2.0 + 0.35:
			main.combat.hit(e, roundi(spec["damage"] * main.prog.magic_mult()), "blast", target, false)
	main.shake(14.0)
	main.combat.flash(target, Color(1.0, 0.5, 0.15), 2.0, 6.0, 0.7)
	marker.queue_free()
	fall.rotation = 0.0
	fall.scale = Vector2.ONE * main.SCALE * n
	fall.position = (target - Vector2(0, 6)) * main.SCALE
	fall.play("impact")
	fall.animation_finished.connect(queue_free)
