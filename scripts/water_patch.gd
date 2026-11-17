class_name WaterPatch
extends Node2D
# Agua viva sobre un conjunto de casillas (shaders/water.gdshader). Cada esquina guarda su distancia a tierra (0 en la orilla,
# 1 a DEPTH_TILES casillas o más) para el degradado de profundidad y la espuma de orilla.
# Uso: var w := WaterPatch.new(); w.build(casillas_agua, func(i, j) -> Vector2: return esquina_en_pantalla); add_child(w)

const DEPTH_TILES := 3.0

static var _mat: ShaderMaterial

static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/water.gdshader")
		var g := GrassTile.floor_material()
		_mat.set_shader_parameter("cloud_noise", g.get_shader_parameter("cloud_noise"))
		_mat.set_shader_parameter("patch_noise", g.get_shader_parameter("patch_noise"))
		Wind.use(_mat)
	return _mat

func build(water: Dictionary, corner: Callable) -> void:
	# distancia (en casillas) de cada casilla de agua a la tierra más cercana
	var dist := {}
	var queue: Array[Vector2i] = []
	for c: Vector2i in water:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not water.has(c + d):
				dist[c] = 1
				queue.append(c)
				break
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := c + d
			if water.has(q) and not dist.has(q):
				dist[q] = dist[c] + 1
				queue.append(q)
	var poly := Polygon2D.new()
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var polys: Array = []
	for c: Vector2i in water:
		var base := verts.size()
		for k: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
			var g := c + k  # esquina de la rejilla: su profundidad es la media de las casillas que la tocan (tierra = 0)
			var dsum := 0.0
			for o: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
				var cell := g + o
				dsum += float(dist.get(cell, 0))
			verts.append(corner.call(g.x, g.y))
			cols.append(Color(clampf(dsum / 4.0 / DEPTH_TILES, 0.0, 1.0), 0, 0))
		polys.append(PackedInt32Array([base, base + 1, base + 2, base + 3]))
	poly.polygon = verts
	poly.vertex_colors = cols
	poly.polygons = polys
	poly.material = material()
	add_child(poly)
	# espuma de orilla: una línea de 1 px de arte en cada borde agua-tierra, partida en tramos que aparecen y se apagan
	var foam := _Foam.new()
	for c: Vector2i in water:
		for side: Array in [[Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 1)], [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1)],
				[Vector2i(0, 1), Vector2i(0, 1), Vector2i(1, 1)], [Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0)]]:
			if water.has(c + side[0]):
				continue
			var a: Vector2 = corner.call(c.x + side[1].x, c.y + side[1].y)
			var b: Vector2 = corner.call(c.x + side[2].x, c.y + side[2].y)
			var inward: Vector2 = (corner.call(c.x + 0.5, c.y + 0.5) - (a + b) / 2.0).normalized() * 3.0
			for k in 4:
				foam.segs.append([a.lerp(b, k / 4.0) + inward, a.lerp(b, (k + 1) / 4.0) + inward, float(((c.x * 73 + c.y * 151 + k * 37) % 97)) / 97.0])
	add_child(foam)

class _Foam extends Node2D:
	var segs: Array = []   # [desde, hasta, fase]
	var tick := -1
	func _process(_d: float) -> void:
		var t := int(Time.get_ticks_msec() / 160)  # pocos fotogramas, como el resto de la escena
		if t != tick:
			tick = t
			queue_redraw()
	func _draw() -> void:
		var pts := PackedVector2Array()
		for s: Array in segs:
			if fmod(s[2] + tick * 0.07, 1.0) > 0.25:  # la espuma va y viene a lo largo de la orilla
				pts.append(s[0].snapped(Vector2(3, 3)))
				pts.append(s[1].snapped(Vector2(3, 3)))
		if not pts.is_empty():
			draw_multiline(pts, Color(0.9, 0.97, 1.0, 0.9), 3.0)
