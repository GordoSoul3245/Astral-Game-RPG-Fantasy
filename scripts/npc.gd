extends Node2D
# Habitante de un interior: de pie, te mira si te acercas y habla con [E] (data/dialogue.json).
# Usa los sprites del civil (art/fauna) con un tono propio.

const TALK_RANGE := 2.6   # casillas
const LOOK := 140.0       # px de suelo

var main: Node
var id := ""
var display := ""
var pos := Vector2.ZERO
var look := Vector2.DOWN
var spr: AnimatedSprite2D
var hit := {}
var talks := 0            # veces que se ha hablado con él: rota entre sus conversaciones

func _ready() -> void:
	var d: Dictionary = main.dialogue_data[id]
	display = d["name"]
	spr = preload("res://scripts/life_sprite.gd").build(self, main, "res://art/fauna/villager_", {"idle": 1})
	if spr:
		var c: Array = d["tint"]
		spr.modulate = Color(c[0], c[1], c[2])
	hit = preload("res://scripts/life_sprite.gd").hitbox(main, "res://art/fauna/villager_")
	position = pos * main.SCALE
	z_index = int(pos.y)

func in_range() -> bool:
	return main.ground_to_tile(pos).distance_to(main.ground_to_tile(main.pos)) < TALK_RANGE

func _physics_process(_delta: float) -> void:
	if pos.distance_to(main.pos) < LOOK:
		look = main.pos - pos
	if spr:
		preload("res://scripts/life_sprite.gd").show(spr, main, "idle", look)
