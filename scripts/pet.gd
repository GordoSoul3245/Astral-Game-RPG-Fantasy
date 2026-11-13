extends Node2D
# Mascota domada (conejo o zorro): sigue al héroe a corta distancia con el mismo arte de la fauna salvaje.
# Los bonus los aplica main.gd según main.pets (conejo: a veces un recurso extra; zorro: más daño cuerpo a cuerpo).

var main: Node
var kind := "rabbit"
var pos := Vector2.ZERO
var look := Vector2.DOWN
var spr: AnimatedSprite2D
var slot := 0            # 0 o 1: se coloca a un lado distinto del héroe

func _ready() -> void:
	spr = preload("res://scripts/life_sprite.gd").build(self, main, "res://art/fauna/%s_" % kind, {"idle": 1, "walk": 8})
	pos = main.pos + Vector2(-30 + 60 * slot, 20)
	position = pos * main.SCALE

func _physics_process(delta: float) -> void:
	visible = not main.in_interior and not (main.in_dungeon and not main.in_mine)
	var goal: Vector2 = main.pos + Vector2(-34.0 + 68.0 * float(slot), 22.0)
	var d: Vector2 = goal - pos
	var moving := false
	if d.length() > 600.0:  # cambió de región: se coloca junto al héroe
		pos = goal
	elif d.length() > 26.0:
		var speed := 120.0 if d.length() < 140.0 else 190.0
		pos += d.normalized() * speed * delta
		look = d
		moving = true
	position = pos * main.SCALE
	z_index = int(pos.y)
	if spr:
		preload("res://scripts/life_sprite.gd").show(spr, main, "walk" if moving else "idle", look, 1.6 if moving else 1.0)
