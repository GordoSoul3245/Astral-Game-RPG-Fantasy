extends "res://scripts/world_map.gd"
# Zona exterior escrita a mano (data/zones.json): un mapa finito con suelo de colores, charcas, caminos, árboles o rocas colocados
# uno a uno y recursos en sitios fijos. Reusa colisiones, rutas y recolección de world_map.gd; los objetos usan los mismos sprites
# del mapa principal. Los monstruos, el cofre y las puertas los pone main._enter_zone.

var cfg := {}
var water := {}        # Vector2i -> true: charcas, bloquean como el mar
var floor_node: Node2D

class _Floor extends Node2D:
	var zone: Node2D

	func _draw() -> void:
		zone.paint(self)

func setup(data: Dictionary) -> void:
	cfg = data
	var n := int(data["tiles"])
	for r: Array in data["water_rects"]:
		for i in range(int(r[0]), int(r[2])):
			for j in range(int(r[1]), int(r[3])):
				water[Vector2i(i, j)] = true
	var rows: Array = []
	for i in n:
		var row := ""
		for j in n:
			var edge := i < 1 or j < 1 or i >= n - 1 or j >= n - 1  # el borde es el límite del mapa
			row += "0" if (edge or water.has(Vector2i(i, j))) else "1"
		rows.append(row)
	var sprites: Dictionary = main._read_json("res://data/map.json")["sprites"]
	var objs: Array = []
	for t: Array in data["trees"]:
		objs.append(_object(str(t[2]), float(t[0]), float(t[1])))
	for l: Dictionary in data["tree_lines"]:
		var a := Vector2(l["line"][0], l["line"][1])
		var b := Vector2(l["line"][2], l["line"][3])
		var steps := maxi(1, roundi(a.distance_to(b) / float(l["step"])))
		for k in steps + 1:
			var p := a.lerp(b, float(k) / float(steps))
			objs.append(_object(str(l["sprite"]), p.x, p.y))
	super.setup({"tiles": n, "walk": rows, "objects": objs, "sprites": sprites})
	floor_node = _Floor.new()
	floor_node.zone = self
	floor_node.z_index = -4000
	add_child(floor_node)
	var specs: Dictionary = main.crafting.cfg["world_sprites"]
	var glow := {"crystal": Color(0.65, 0.45, 1.0), "mushroom": Color(0.35, 1.0, 0.8)}
	for nd: Dictionary in data["nodes"]:
		var kind: String = nd["kind"]
		var key: String = {"herb": "herb_bush", "berry": "berry_bush"}.get(kind, "node_" + kind)
		var spec: Dictionary = specs[key]
		add_resource(kind, Vector2(nd["t"][0], nd["t"][1]), spec["paths"][0], spec["feet"], 0.0 if kind in ["mushroom", "herb", "berry"] else 0.45, glow.get(kind, Color.TRANSPARENT))

func _object(sprite: String, x: float, y: float) -> Dictionary:
	var r := 0.3 if sprite.begins_with("tree") else 0.5
	return {"sprite": sprite, "tile": [x, y], "circle": r, "pcircle": 0.55 if sprite.begins_with("tree") else r}

func spawn_tile() -> Vector2:
	return Vector2(cfg["start"][0], cfg["start"][1])

func _corner(i: float, j: float) -> Vector2:
	return main.tile_to_ground(Vector2(i, j)) * main.SCALE

func _in_rects(i: int, j: int, key: String) -> bool:
	for r: Array in cfg[key]:
		if i >= int(r[0]) and i < int(r[2]) and j >= int(r[1]) and j < int(r[3]):
			return true
	return false

func paint(ci: CanvasItem) -> void:  # suelo de losas de colores: mullido, caminos y charcas que brillan
	var g: Array = cfg["ground"]
	var t := Time.get_ticks_msec() * 0.001
	for i in tiles:
		for j in tiles:
			var quad := PackedVector2Array([_corner(i, j), _corner(i + 1, j), _corner(i + 1, j + 1), _corner(i, j + 1)])
			var col: Color
			if water.has(Vector2i(i, j)):
				col = Color(cfg["water"]).lerp(Color(cfg["water2"]), 0.5 + 0.5 * sin(t * 1.5 + i * 0.7 + j * 0.9))
			elif _in_rects(i, j, "path_rects"):
				col = Color(cfg["path"]).lightened(float((i * 7 + j * 13) % 5) * 0.012)
			else:
				col = Color(g[(i + j) % 2]).lightened(float((i * 5 + j * 3) % 4) * 0.012)
			ci.draw_colored_polygon(quad, col)

func _process(delta: float) -> void:
	super._process(delta)
	if floor_node and not water.is_empty():
		floor_node.queue_redraw()  # las charcas brillan
