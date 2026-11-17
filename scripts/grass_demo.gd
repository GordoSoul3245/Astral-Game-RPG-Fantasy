extends Node2D
# Vista previa de la naturaleza viva: pradera por casillas (GrassTile), estanque (WaterPatch) y árboles (LivingTree), todo con
# el mismo viento (Wind). Un personaje de prueba se mueve solo (o con las flechas) y aparta el pasto. Abre scenes/grass_demo.tscn y F6.

const N := 14
const CELL := Vector2(128, 64)
const POND_C := Vector2(9.5, 4.5)
const TREES := [Vector2i(3, 3), Vector2i(4, 9), Vector2i(10, 10), Vector2i(12, 11), Vector2i(2, 12)]

var hero := Node2D.new()
var auto := true

func _corner(i: float, j: float) -> Vector2:
	return Vector2(i - j, i + j - 1.0) * CELL / 2.0

func _ready() -> void:
	var water := {}
	var cells: Array = []
	for j in N:
		for i in N:
			if Vector2(i + 0.5, j + 0.5).distance_to(POND_C) < 3.2:
				water[Vector2i(i, j)] = true
				continue
			var q := PackedVector2Array([_corner(i, j), _corner(i + 1, j), _corner(i + 1, j + 1), _corner(i, j + 1)])
			cells.append({"q": q, "id": Vector2i(i, j)})
	var grass := GrassTile.new()
	grass.z_index = -10
	grass.build(cells)
	add_child(grass)
	var pond := WaterPatch.new()
	pond.z_index = -11
	pond.build(water, _corner)
	add_child(pond)
	var things := Node2D.new()  # árboles y personaje se ordenan por su y
	things.y_sort_enabled = true
	add_child(things)
	for k in TREES.size():
		var t := LivingTree.new()
		t.seed_value = k * 7 + 3
		t.position = _corner(TREES[k].x + 0.5, TREES[k].y + 0.5)
		things.add_child(t)
	var c := Camera2D.new()
	c.position = Vector2(0, (N - 2) * CELL.y / 2.0)
	add_child(c)
	hero.add_to_group("grass_char")
	hero.set_meta("grass_radius", 110.0)
	hero.position = Vector2(-200, N * CELL.y / 2.0)
	things.add_child(hero)
	add_child(GrassManager.new())
	var body := Polygon2D.new()  # personaje de prueba: un rombo oscuro (marcador)
	body.polygon = PackedVector2Array([Vector2(0, -60), Vector2(14, -30), Vector2(10, 0), Vector2(-10, 0), Vector2(-14, -30)])
	body.color = Color(0.15, 0.2, 0.45)
	hero.add_child(body)

func _process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if dir != Vector2.ZERO:
		auto = false
		hero.position += dir * 240.0 * delta
	elif auto:
		var t := Time.get_ticks_msec() / 1000.0
		hero.position = Vector2(-150.0 + sin(t * 0.8) * 260.0, N * CELL.y / 2.0 + cos(t * 0.8) * 90.0)
