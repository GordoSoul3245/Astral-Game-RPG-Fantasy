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
