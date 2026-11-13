extends Node2D
# Puentes de tablas del valle hacia las regiones vecinas (data/world.json): abren casillas de mar como transitables y se dibujan
# a ras de suelo. Cruzar su extremo lleva a la región de al lado (main._check_edges).

var main: Node
var cells: Array[Vector2i] = []

func _ready() -> void:
	z_index = -3900

func add_link(side: String, rows: Array) -> void:  # abre el mar entre la costa y el borde del mapa por las filas indicadas
	var n: int = main.world.tiles
	for r in range(int(rows[0]), int(rows[1]) + 1):
		var seq: Array[Vector2i] = []
		for k in n:  # desde el borde hacia dentro, hasta tocar tierra
			var c := Vector2i(k, r) if side == "w" else Vector2i(n - 1 - k, r)
			if str(main.world.walk[c.x])[c.y] == "1":
				break
			seq.append(c)
		for c: Vector2i in seq:
			var row: String = main.world.walk[c.x]
			main.world.walk[c.x] = row.substr(0, c.y) + "1" + row.substr(c.y + 1)
			cells.append(c)
	queue_redraw()

func _corner(i: float, j: float) -> Vector2:
	return main.tile_to_ground(Vector2(i, j)) * main.SCALE

func _draw() -> void:
	for c: Vector2i in cells:
		var quad := PackedVector2Array([_corner(c.x, c.y), _corner(c.x + 1, c.y), _corner(c.x + 1, c.y + 1), _corner(c.x, c.y + 1)])
		draw_colored_polygon(quad, Color("#8a6238") if (c.x + c.y) % 2 == 0 else Color("#7a5530"))
		quad.append(quad[0])
		draw_polyline(quad, Color("#3a2410"), 2.0)
