extends Node2D
# Objeto fijo del pueblo con el que se interactúa: mesa de alquimia, fogata (4 fotogramas con luz que parpadea) o entrada de la mina.
# Sprites y puntos de los pies en data/crafting.json "world_sprites"; la colisión la añade main.gd al mapa del exterior.

var main: Node
var sprite_key := "alchemy_table"
var tile := Vector2.ZERO
var light_col := Color.TRANSPARENT
var spr: Sprite2D
var frames: Array[Texture2D] = []
var fps := 8.0
var light: PointLight2D
var t := 0.0

func _ready() -> void:
	var spec: Dictionary = main.crafting.cfg["world_sprites"][sprite_key]
	for path: String in spec["paths"]:
		frames.append(load(path))
	fps = float(spec.get("fps", 8.0))
	var g: Vector2 = main.tile_to_ground(tile)
	spr = Sprite2D.new()
	spr.texture = frames[0]
	spr.centered = false
	spr.scale = Vector2.ONE * main.SCALE
	spr.position = -Vector2(spec["feet"][0], spec["feet"][1]) * main.SCALE
	add_child(spr)
	position = g * main.SCALE
	z_index = int(g.y)
	if light_col != Color.TRANSPARENT:
		light = main.combat.light(light_col, 0.9, 2.4)
		light.position = Vector2(0, -22) * main.SCALE
		add_child(light)

func _process(delta: float) -> void:
	visible = not main.in_dungeon  # solo existe en el exterior
	if not visible:
		return
	t += delta
	if frames.size() > 1:
		spr.texture = frames[int(t * fps) % frames.size()]
	if light:
		light.energy = 0.85 + 0.2 * sin(t * 13.0) + 0.1 * sin(t * 7.3)
