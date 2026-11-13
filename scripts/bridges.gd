extends Node2D
# Puentes de tablas del valle hacia las regiones vecinas (data/world.json): abren casillas de mar como transitables y se dibujan
# a ras de suelo con barandilla y un cartel. Más allá del borde del mapa se ve un adelanto de la región vecina (suelo y siluetas).
# Funciona en los cuatro lados: w/e (las filas son y) y n/s (las "filas" son x). Cruzar su extremo lleva a la región de al lado.

var main: Node
var cells: Array[Vector2i] = []
var links: Array = []    # {side, rows, cells, color, label}

func _ready() -> void:
	z_index = -3900

func _horiz(side: String) -> bool:
	return side in ["w", "e"]

func _tile(side: String, depth: float, along: float) -> Vector2:  # depth = distancia al borde de su lado; along = posición a lo largo del borde
	var n: float = float(main.world.tiles)
	match side:
		"w": return Vector2(depth, along)
		"e": return Vector2(n - 1.0 - depth, along)
		"n": return Vector2(along, depth)
	return Vector2(along, n - 1.0 - depth)

func add_link(side: String, rows: Array, color := Color("#35682a"), label := "") -> void:  # abre el mar entre la costa y el borde por las filas indicadas
	var n: int = main.world.tiles
	var mine: Array[Vector2i] = []
	for r in range(int(rows[0]), int(rows[1]) + 1):
		for k in n:  # desde el borde hacia dentro, hasta tocar tierra
			var t := _tile(side, float(k), float(r))
			var c := Vector2i(int(t.x), int(t.y))
			if str(main.world.walk[c.x])[c.y] == "1":
				break
			var row: String = main.world.walk[c.x]
			main.world.walk[c.x] = row.substr(0, c.y) + "1" + row.substr(c.y + 1)
			cells.append(c)
			mine.append(c)
	links.append({"side": side, "rows": rows, "cells": mine, "color": color, "label": label})
	queue_redraw()

func _corner(i: float, j: float) -> Vector2:
	return main.tile_to_ground(Vector2(i, j)) * main.SCALE

func _quad(i: float, j: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([_corner(i, j), _corner(i + 1, j), _corner(i + 1, j + 1), _corner(i, j + 1)]), color)

func _draw() -> void:
	var sc: float = main.SCALE
	for l: Dictionary in links:
		var side: String = l["side"]
		var rows: Array = l["rows"]
		var col: Color = l["color"]
		for k in range(1, 9):  # adelanto de la región vecina más allá del borde: suelo y siluetas
			for r in range(int(rows[0]) - 3, int(rows[1]) + 4):
				var t := _tile(side, -float(k), float(r))
				var h := (int(t.x) * 73 + int(t.y) * 31 + 1000) % 100
				_quad(t.x, t.y, col.lightened(float(h % 5) * 0.02) if (int(t.x) + int(t.y)) % 2 == 0 else col.darkened(0.06))
				if h < 11 and k > 1:
					var b := _corner(t.x + 0.5, t.y + 0.5)
					draw_colored_polygon(PackedVector2Array([b + Vector2(-9, 0) * sc, b + Vector2(9, 0) * sc, b + Vector2(0, -34) * sc]), col.darkened(0.45))
		for c: Vector2i in l["cells"]:
			_quad(c.x, c.y, Color("#8a6238") if (c.x + c.y) % 2 == 0 else Color("#7a5530"))
			draw_polyline(PackedVector2Array([_corner(c.x, c.y), _corner(c.x + 1, c.y), _corner(c.x + 1, c.y + 1), _corner(c.x, c.y + 1), _corner(c.x, c.y)]), Color("#3a2410"), 2.0)
		var nrows: int = int(rows[1]) - int(rows[0]) + 1
		var steps: int = l["cells"].size() / nrows  # largo del puente en casillas
		for er: float in [float(rows[0]), float(rows[1]) + 1.0]:  # barandillas en los dos bordes largos y un poste por casilla
			var a := _tile(side, 0.0, er)
			var b2 := _tile(side, float(steps), er)
			if side in ["e", "s"]:  # el origen de una casilla es su esquina superior: ajusta para que la barandilla toque el borde
				a += Vector2(1, 0) if side == "e" else Vector2(0, 1)
				b2 += Vector2(1, 0) if side == "e" else Vector2(0, 1)
			draw_line(_corner(a.x, a.y) - Vector2(0, 16) * sc, _corner(b2.x, b2.y) - Vector2(0, 16) * sc, Color("#4a2e14"), 3.0)
			for st in range(0, steps + 1):
				var q := _tile(side, float(st), er)
				if side in ["e", "s"]:
					q += Vector2(1, 0) if side == "e" else Vector2(0, 1)
				var px := _corner(q.x, q.y)
				draw_line(px, px - Vector2(0, 20) * sc, Color("#3a2410"), 4.0)
		if l["cells"].size() > 0 and l["label"] != "":  # cartel en el extremo de la costa
			var s0 := _tile(side, float(steps), float(rows[0]) - 0.4)
			var shore := _corner(s0.x, s0.y)
			draw_line(shore, shore - Vector2(0, 44) * sc, Color("#3a2410"), 5.0)
			var board := Rect2(shore + Vector2(-58, -70) * sc, Vector2(116, 24) * sc)
			draw_rect(board, Color("#a97a42"))
			draw_rect(board, Color("#3a2410"), false, 3.0)
			draw_string(ThemeDB.fallback_font, board.position + Vector2(10, 18) * sc * 0.9, str(l["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * sc * 0.6), Color("#2a1608"))
