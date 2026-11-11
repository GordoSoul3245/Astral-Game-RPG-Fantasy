extends Node2D
# Mercader del pueblo: está de pie junto a su puesto, te mira si te acercas y te vende pociones con [E].
# Usa los sprites del civil (art/fauna) con otro tono para distinguirlo. Se dibuja por código si faltan.

const TALK_RANGE := 2.8   # casillas
const LOOK := 150.0       # px de suelo

var main: Node
var pos := Vector2.ZERO
var look := Vector2.DOWN
var hit := {}             # hitbox corporal medida del sprite (hitbox.gd)
var spr: AnimatedSprite2D
var anim_t := 0.0

func _ready() -> void:
	spr = preload("res://scripts/life_sprite.gd").build(self, main, "res://art/fauna/villager_", {"idle": 1})
	hit = preload("res://scripts/life_sprite.gd").hitbox(main, "res://art/fauna/villager_")
	if spr:
		spr.modulate = Color(1.0, 0.78, 0.62)  # otro tono de ropa que el de Elda
	look = main.tile_to_ground(Vector2(1, 0)) - main.tile_to_ground(Vector2.ZERO)  # mira hacia el frente del mostrador (+j)
	_place()

func in_range() -> bool:
	return not main.in_dungeon and main.ground_to_tile(pos).distance_to(main.ground_to_tile(main.pos)) < TALK_RANGE

func _physics_process(delta: float) -> void:
	visible = not main.in_dungeon
	anim_t += delta
	if main.in_dungeon:
		return
	if pos.distance_to(main.pos) < LOOK:
		look = main.pos - pos
	if spr:
		preload("res://scripts/life_sprite.gd").show(spr, main, "idle", look)
	queue_redraw()

func _place() -> void:
	position = pos * main.SCALE
	z_index = int(pos.y)

func _draw() -> void:
	var S: float = main.SCALE
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * S)
	draw_string(ThemeDB.fallback_font, Vector2(-4, -86 + sin(anim_t * 3.0) * 2.0), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.85, 0.2))  # indica que vende
