extends Node2D
# Vista previa del pasto por casillas: una rejilla de GrassTile (rombos 128x64) y un personaje de prueba que se mueve solo
# (o con las flechas / WASD) para ver cómo se aparta el pasto. Abre scenes/grass_demo.tscn y pulsa F6.

const N := 10
const CELL := Vector2(128, 64)

var hero := Node2D.new()
var auto := true

func _ready() -> void:
	var tiles := Node2D.new()
	tiles.y_sort_enabled = true
	add_child(tiles)
	for j in N:
		for i in N:
			var t := GrassTile.new()
			t.cell = CELL
			t.cell_id = Vector2i(i, j)
			t.position = Vector2(i - j, i + j) * CELL / 2.0
			tiles.add_child(t)
	var c := Camera2D.new()
	c.position = Vector2(0, (N - 1) * CELL.y / 2.0)
	add_child(c)
	hero.add_to_group("grass_char")
	hero.set_meta("grass_radius", 110.0)
	hero.position = Vector2(0, N * CELL.y / 2.0)
	hero.z_index = 100
	add_child(hero)
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
		hero.position = Vector2(sin(t * 0.8) * 260.0, N * CELL.y / 2.0 + cos(t * 0.8) * 90.0)
