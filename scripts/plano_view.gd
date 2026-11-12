extends Control
# Plano de alquimia dibujado por código: pergamino rasgado, frasco con el color de la poción, un símbolo propio (corazón, estrella,
# hoja, llama, rayo, calavera) y un círculo por ingrediente unido al frasco con líneas de puntos. Cada plano tiene su dibujo.

var main: Node
var plano_id := ""
var placed: Dictionary = {}   # ingrediente -> true cuando ya está sobre la mesa (el círculo se ilumina)
var compact := false          # en la lista de planos: sin ingredientes ni títulos pequeños
var glow := 0.0               # 0..1 brillo del frasco mientras se prepara

func _bp() -> Dictionary:
	return main.crafting.cfg["blueprints"][plano_id] if plano_id != "" else {}

func _draw() -> void:
	var sz := size
	var paper := Color("#e6d5a6")
	var ink := Color("#3a2a1a")
	# pergamino con bordes irregulares (determinista por plano)
	var pts := PackedVector2Array()
	var seed_v := float(plano_id.hash() % 1000)
	var n := 14
	for i in n:
		pts.append(Vector2(sz.x * float(i) / n, 3.0 + 4.0 * fposmod(sin(seed_v + i * 3.7) * 99.0, 1.0)))
	for i in n:
		pts.append(Vector2(sz.x - 3.0 - 4.0 * fposmod(sin(seed_v + i * 5.1) * 99.0, 1.0), sz.y * float(i) / n))
	for i in n:
		pts.append(Vector2(sz.x * (1.0 - float(i) / n), sz.y - 3.0 - 4.0 * fposmod(sin(seed_v + i * 2.3) * 99.0, 1.0)))
	for i in n:
		pts.append(Vector2(3.0 + 4.0 * fposmod(sin(seed_v + i * 4.4) * 99.0, 1.0), sz.y * (1.0 - float(i) / n)))
	draw_colored_polygon(pts, paper)
	draw_polyline(pts + PackedVector2Array([pts[0]]), ink.lightened(0.3), 2.0)
	if plano_id == "":
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(10, sz.y * 0.5 - 8), "Añade un plano", HORIZONTAL_ALIGNMENT_CENTER, sz.x - 20, 18, ink.lightened(0.2))
		draw_string(f, Vector2(10, sz.y * 0.5 + 14), "desde tu colección", HORIZONTAL_ALIGNMENT_CENTER, sz.x - 20, 14, ink.lightened(0.3))
		return
	var bp := _bp()
	var col := Color(bp["color"])
	var f2 := ThemeDB.fallback_font
	var cx := sz.x * 0.5
	var cy := sz.y * (0.42 if not compact else 0.5)
	var r := minf(sz.x, sz.y) * (0.2 if not compact else 0.27)
	# rejilla de plano técnico
	var grid := Color(0.35, 0.25, 0.1, 0.12)
	for gx in range(1, 8):
		draw_line(Vector2(sz.x * gx / 8.0, 8), Vector2(sz.x * gx / 8.0, sz.y - 8), grid, 1.0)
	for gy in range(1, 10):
		draw_line(Vector2(8, sz.y * gy / 10.0), Vector2(sz.x - 8, sz.y * gy / 10.0), grid, 1.0)
	# frasco: panza, cuello y borde, con el líquido a media altura
	var body := Vector2(cx, cy + r * 0.35)
	var flask := PackedVector2Array()
	for i in 25:
		var a := PI * 0.5 + 0.55 + (TAU - 1.1) * float(i) / 24.0
		flask.append(body + Vector2(cos(a), sin(a)) * r)
	flask.append(Vector2(cx + r * 0.3, cy - r * 0.55))
	flask.append(Vector2(cx + r * 0.3, cy - r * 1.05))
	flask.append(Vector2(cx - r * 0.3, cy - r * 1.05))
	flask.append(Vector2(cx - r * 0.3, cy - r * 0.55))
	var liquid := PackedVector2Array()
	for i in 25:
		var a := float(i) / 24.0 * PI
		liquid.append(body + Vector2(cos(a), sin(a)) * (r - 3.0))
	var wave := sin(Time.get_ticks_msec() / 220.0) * 1.5 * (1.0 + glow * 3.0)
	liquid.append(body + Vector2(-(r - 3.0), wave))
	var fill := col
	fill.a = 0.75 + glow * 0.25
	draw_colored_polygon(liquid, fill)
	draw_polyline(flask + PackedVector2Array([flask[0]]), ink, 2.5)
	draw_line(Vector2(cx - r * 0.38, cy - r * 1.05), Vector2(cx + r * 0.38, cy - r * 1.05), ink, 3.0)
	_glyph(bp["glyph"], body + Vector2(0, -r * 0.15), r * 0.5, ink)
	# ingredientes: círculos alrededor, unidos al frasco con puntos
	if not compact:
		var ids: Array = bp["inputs"].keys()
		for i in ids.size():
			var ang := PI * 0.5 + (float(i) + 0.5) / ids.size() * PI * 1.0 + PI * 0.5 - PI * 0.5
			var pos := Vector2(sz.x * (0.18 + 0.64 * (float(i) + 0.5) / ids.size()), sz.y * 0.78)
			var line_from := body + Vector2(0, r)
			for k in 8:
				var q := line_from.lerp(pos + Vector2(0, -22), (float(k) + 0.5) / 8.0)
				draw_circle(q, 1.6, ink.lightened(0.15))
			var have: bool = placed.get(ids[i], false)
			draw_circle(pos, 22.0, Color(1.0, 0.9, 0.5, 0.9) if have else Color(0.85, 0.78, 0.6, 0.8))
			draw_arc(pos, 22.0, 0.0, TAU, 24, ink if not have else Color("#b8860b"), 2.5 if not have else 3.5)
			var tex: Texture2D = load(main.crafting.icon(ids[i]))
			draw_texture_rect(tex, Rect2(pos - Vector2(18, 18), Vector2(36, 36)), false, Color(1, 1, 1, 1.0 if have else 0.55))
			var need: int = int(bp["inputs"][ids[i]])
			if need > 1:
				draw_string(f2, pos + Vector2(8, 24), "×%d" % need, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
		draw_string(f2, Vector2(8, 22), bp["name"].replace("Plano: ", ""), HORIZONTAL_ALIGNMENT_CENTER, sz.x - 16, 17, ink)
		draw_string(f2, Vector2(8, sz.y - 10), "→ %s ×%d" % [main.crafting.item_name(bp["output"]), int(bp["qty"])], HORIZONTAL_ALIGNMENT_CENTER, sz.x - 16, 15, ink.lightened(0.1))
	else:
		draw_string(f2, Vector2(4, sz.y - 8), bp["name"].replace("Plano: ", ""), HORIZONTAL_ALIGNMENT_CENTER, sz.x - 8, 13, ink)

func _glyph(kind: String, c: Vector2, s: float, ink: Color) -> void:
	match kind:
		"heart":
			var h := PackedVector2Array()
			for i in 33:
				var a := float(i) / 32.0 * TAU
				h.append(c + Vector2(16.0 * pow(sin(a), 3.0), -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))) * s / 18.0)
			draw_colored_polygon(h, Color(1, 1, 1, 0.55))
			draw_polyline(h, ink, 2.0)
		"star":
			var st := PackedVector2Array()
			for i in 10:
				var rr := s if i % 2 == 0 else s * 0.45
				st.append(c + Vector2.from_angle(-PI / 2.0 + float(i) / 10.0 * TAU) * rr)
			draw_colored_polygon(st, Color(1, 1, 1, 0.55))
			draw_polyline(st + PackedVector2Array([st[0]]), ink, 2.0)
		"leaf":
			var lf := PackedVector2Array()
			for i in 17:
				var a := float(i) / 16.0 * PI
				lf.append(c + Vector2(cos(a) * s * 0.5, -sin(a) * s))
			for i in 17:
				var a := float(i) / 16.0 * PI
				lf.append(c + Vector2(-cos(a) * s * 0.5, sin(a) * s))
			draw_colored_polygon(lf, Color(1, 1, 1, 0.5))
			draw_polyline(lf + PackedVector2Array([lf[0]]), ink, 2.0)
			draw_line(c + Vector2(0, -s), c + Vector2(0, s), ink, 2.0)
		"flame":
			var fl := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.55, -s * 0.1), c + Vector2(s * 0.35, s * 0.8), c + Vector2(0, s), c + Vector2(-s * 0.4, s * 0.7), c + Vector2(-s * 0.5, 0.0), c + Vector2(-s * 0.15, -s * 0.35)])
			draw_colored_polygon(fl, Color(1, 1, 1, 0.55))
			draw_polyline(fl + PackedVector2Array([fl[0]]), ink, 2.0)
		"bolt":
			var bl := PackedVector2Array([c + Vector2(s * 0.2, -s), c + Vector2(-s * 0.5, s * 0.1), c + Vector2(-s * 0.05, s * 0.1), c + Vector2(-s * 0.3, s), c + Vector2(s * 0.5, -s * 0.2), c + Vector2(s * 0.05, -s * 0.2)])
			draw_colored_polygon(bl, Color(1, 1, 1, 0.55))
			draw_polyline(bl + PackedVector2Array([bl[0]]), ink, 2.0)
		"skull":
			draw_circle(c + Vector2(0, -s * 0.15), s * 0.7, Color(1, 1, 1, 0.55))
			draw_arc(c + Vector2(0, -s * 0.15), s * 0.7, 0.0, TAU, 24, ink, 2.0)
			draw_rect(Rect2(c + Vector2(-s * 0.35, s * 0.4), Vector2(s * 0.7, s * 0.4)), Color(1, 1, 1, 0.55))
			draw_circle(c + Vector2(-s * 0.28, -s * 0.2), s * 0.17, ink)
			draw_circle(c + Vector2(s * 0.28, -s * 0.2), s * 0.17, ink)
