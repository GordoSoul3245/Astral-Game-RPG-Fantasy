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
	idle_t = 0.0 if moving else idle_t + delta
	queue_redraw()
	if spr:
		preload("res://scripts/life_sprite.gd").show(spr, main, "walk" if moving else "idle", look, 1.6 if moving else 1.0)

var idle_t := 0.0

func _draw() -> void:  # pañuelo de su color y un corazón de vez en cuando: se nota que es tu mascota
	var sc: float = main.SCALE
	var col := Color(0.9, 0.2, 0.25) if kind == "rabbit" else Color(0.25, 0.5, 0.95)
	draw_colored_polygon(PackedVector2Array([Vector2(-8, -20) * sc, Vector2(8, -20) * sc, Vector2(6, -15) * sc, Vector2(0, -12) * sc, Vector2(-6, -15) * sc]), col)
	if idle_t > 3.0 and fmod(idle_t, 6.0) < 1.5:
		draw_string(ThemeDB.fallback_font, Vector2(-8, -34) * sc, "♥", HORIZONTAL_ALIGNMENT_CENTER, -1, int(14 * sc), Color(1.0, 0.4, 0.55))
