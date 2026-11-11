extends "res://scripts/world_map.gd"
# Interior de una casa (data/interiors.json): sala pequeña de suelo de tablas y paredes de madera con muebles dibujados
# por código. Los muebles bloquean (rects de world_map) y se ordenan en profundidad como los edificios del exterior.
# Convención del mapa: i sube hacia arriba-derecha, j hacia abajo-derecha; las paredes del fondo son j = 0 e i = tiles.

const WALL_H := 76.0   # px de suelo (~1.6 m)
const PXM := 128.0 / 2.75  # px de suelo por metro (cámara de los sprites)
var cfg := {}

func setup(data: Dictionary) -> void:
	cfg = data
	tiles = int(data["tiles"])
	walk = []
	for i in tiles:
		walk.append("1".repeat(tiles))
	z_index = -4000
	for f: Dictionary in data["furniture"]:
		var r: Array = f["rect"]
		var rc := Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])
		if f["kind"] != "rug":  # la alfombra se pisa
			rects.append(rc)
		var fn := Furn.new()
		fn.room = self
		fn.kind = f["kind"]
		fn.rect = rc
		fn.h = float(f["h"])
		var y := 0.0
		for corner in [rc.position, rc.end, Vector2(rc.position.x, rc.end.y), Vector2(rc.end.x, rc.position.y)]:
			y = maxf(y, main.tile_to_ground(corner).y)
		fn.z_index = -3000 if f["kind"] == "rug" else int(y)
		fn.z_as_relative = false  # la sala está en z -4000: los muebles se ordenan con el héroe por su posición real
		add_child(fn)
		if f["kind"] == "forge":  # el fuego de la fragua ilumina la sala
			var l: PointLight2D = main.combat.light(Color(1.0, 0.55, 0.2), 0.9, 3.2)
			l.position = (main.tile_to_ground(rc.get_center()) - Vector2(0, 30)) * main.SCALE
			add_child(l)
	queue_redraw()

func _corner(i: float, j: float) -> Vector2:
	return main.tile_to_ground(Vector2(i, j)) * main.SCALE

func _up(p: Vector2, h: float) -> Vector2:
	return p - Vector2(0, h * main.SCALE)

func _draw() -> void:
	var floor_col := Color(cfg["floor"])
	for i in tiles:
		for j in tiles:
			var shade := float((i * 5 + j * 3) % 4) * 0.015
			var quad := PackedVector2Array([_corner(i, j), _corner(i + 1, j), _corner(i + 1, j + 1), _corner(i, j + 1)])
			draw_colored_polygon(quad, floor_col.lightened(shade) if (i + j) % 2 == 0 else floor_col.darkened(0.06 - shade))
			quad.append(quad[0])
			draw_polyline(quad, floor_col.darkened(0.35), 1.5)  # juntas de las tablas
	var wall := Color(cfg["wall"])
	_wall(Vector2(0, 0), Vector2(tiles, 0), wall.darkened(0.1))
	_wall(Vector2(tiles, 0), Vector2(tiles, tiles), wall)
	draw_polyline(PackedVector2Array([_corner(0, 0), _corner(tiles, 0), _corner(tiles, tiles)]), Color("#2a1a0e"), 6.0)

func _wall(a: Vector2, b: Vector2, col: Color) -> void:  # pared con zócalo, vigas y una ventana
	var pa := _corner(a.x, a.y)
	var pb := _corner(b.x, b.y)
	draw_colored_polygon(PackedVector2Array([pa, pb, _up(pb, WALL_H), _up(pa, WALL_H)]), col)
	draw_colored_polygon(PackedVector2Array([pa, pb, _up(pb, 14.0), _up(pa, 14.0)]), col.darkened(0.25))
	draw_polyline(PackedVector2Array([_up(pa, WALL_H), _up(pb, WALL_H)]), col.darkened(0.45), 3.0)
	for k in range(1, 4):
		var m := pa.lerp(pb, k / 4.0)
		draw_line(m, _up(m, WALL_H), col.darkened(0.3), 3.0)
	var w0 := pa.lerp(pb, 0.58)
	var w1 := pa.lerp(pb, 0.78)
	draw_colored_polygon(PackedVector2Array([_up(w0, 30.0), _up(w1, 30.0), _up(w1, 58.0), _up(w0, 58.0)]), Color("#cfe4f2"))
	draw_polyline(PackedVector2Array([_up(w0, 30.0), _up(w1, 30.0), _up(w1, 58.0), _up(w0, 58.0), _up(w0, 30.0)]), Color("#3a2515"), 3.0)

# caja isométrica sobre un rectángulo de casillas: tapa y las dos caras que ve la cámara (i = i0 y j = j1)
func box(canvas: CanvasItem, rc: Rect2, h_m: float, top: Color, left: Color, right: Color) -> void:
	var h := h_m * PXM  # metros -> px de suelo
	var i0 := rc.position.x
	var j0 := rc.position.y
	var i1 := rc.end.x
	var j1 := rc.end.y
	canvas.draw_colored_polygon(PackedVector2Array([_corner(i0, j0), _corner(i0, j1), _up(_corner(i0, j1), h), _up(_corner(i0, j0), h)]), left)
	canvas.draw_colored_polygon(PackedVector2Array([_corner(i0, j1), _corner(i1, j1), _up(_corner(i1, j1), h), _up(_corner(i0, j1), h)]), right)
	canvas.draw_colored_polygon(PackedVector2Array([_up(_corner(i0, j0), h), _up(_corner(i1, j0), h), _up(_corner(i1, j1), h), _up(_corner(i0, j1), h)]), top)

class Furn extends Node2D:
	var room: Node2D
	var kind := ""
	var rect := Rect2()
	var h := 1.0

	func _draw() -> void:
		match kind:
			"table":
				room.box(self, Rect2(rect.position + Vector2(0.1, 0.1), rect.size - Vector2(0.2, 0.2)), h, Color("#b98b57"), Color("#7a5530"), Color("#8a6038"))
			"shelf":
				room.box(self, rect, h, Color("#8a5f35"), Color("#5e3d20"), Color("#6e4727"))
				room.box(self, Rect2(rect.position + Vector2(0.12, 0.05), Vector2(rect.size.x - 0.24, rect.size.y * 0.45)), h * 0.5, Color("#c98a5a"), Color("#a86a40"), Color("#b87a4c"))
			"forge":
				room.box(self, rect, h, Color("#4a4a52"), Color("#33333a"), Color("#3d3d45"))
				room.box(self, Rect2(rect.position + Vector2(0.25, 0.4), rect.size - Vector2(0.5, 0.8)), h + 0.02, Color("#ff9a2a"), Color("#c24b10"), Color("#e06a18"))
			"anvil":
				room.box(self, rect, h * 0.6, Color("#5a5a64"), Color("#3a3a42"), Color("#464650"))
				room.box(self, Rect2(rect.position + Vector2(0.1, 0.15), rect.size - Vector2(0.2, 0.3)), h, Color("#6b6b76"), Color("#44444c"), Color("#50505a"))
			"barrel":
				room.box(self, rect, h, Color("#9a6b3b"), Color("#6a4524"), Color("#7b5129"))
			"chest":
				room.box(self, rect, h, Color("#a97a42"), Color("#6b4524"), Color("#80532b"))
			"bed":
				room.box(self, rect, h * 0.55, Color("#d8d2c0"), Color("#8a6038"), Color("#9a6c3f"))
				room.box(self, Rect2(rect.position + Vector2(0.05, 0.7), Vector2(rect.size.x - 0.1, rect.size.y - 0.75)), h * 0.62, Color("#a8342e"), Color("#7a2420"), Color("#8e2b26"))
			"rug":
				room.box(self, rect, h, Color("#8e3b34"), Color("#6a2a25"), Color("#6a2a25"))
				room.box(self, Rect2(rect.position + Vector2(0.25, 0.25), rect.size - Vector2(0.5, 0.5)), h + 0.01, Color("#c9a24a"), Color("#c9a24a"), Color("#c9a24a"))
			_:
				room.box(self, rect, h, Color.GRAY, Color.DIM_GRAY, Color.DIM_GRAY)
