extends "res://scripts/world_map.gd"
# Piso de dungeon generado (dungeon_gen.gd): suelo de losas en las casillas transitables y bloques de muro alrededor.
# Reusa las colisiones y el pathfinding de world_map.gd: lo que no es transitable ('0') bloquea al héroe y a los monstruos.

const WALL_H := 34.0  # px de suelo; bajo, para que no tape al héroe

var sconces: Array[PointLight2D] = []
var flame_time := 0.0

func _process(delta: float) -> void:
	flame_time += delta
	for i in sconces.size():
		sconces[i].energy = 0.72 + 0.08*sin(flame_time*3.1+i) + 0.04*sin(flame_time*5.3+i)

func setup(data: Dictionary) -> void:
	tiles = int(data["tiles"])
	if data.has("walk"):
		walk = data["walk"]
	else:
		walk = []
		for i in tiles:
			walk.append("1".repeat(tiles))
	z_index = -4000  # siempre por debajo de héroe y entidades
	if sconces.is_empty():
		for spot in [Vector2(2,tiles/2),Vector2(tiles-2,tiles/2),Vector2(tiles/2-2,1),Vector2(tiles/2+2,1),Vector2(tiles/2-2,tiles-1),Vector2(tiles/2+2,tiles-1)]:
			var light: PointLight2D = main.combat.light(Color("#f7aa69"),0.75,3.5)
			light.range_z_min = -4096
			light.position = _corner(spot.x,spot.y)
			add_child(light)
			sconces.append(light)
	floor_mesh = null  # piso nuevo: se rearman las mallas
	queue_redraw()

func _corner(i: int, j: int) -> Vector2:
	return main.tile_to_ground(Vector2(i, j)) * main.SCALE

func _floor(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < tiles and j < tiles and str(walk[i])[j] == "1"

func _near_floor(i: int, j: int) -> bool:  # muro visible: casilla bloqueada que toca el suelo
	for di in range(-1, 2):
		for dj in range(-1, 2):
			if _floor(i + di, j + dj):
				return true
	return false

# Rendimiento: el piso entero va en dos mallas (suelo y muros) y una tanda de líneas (juntas), no ~1700 polígonos sueltos por cuadro.
var floor_mesh: ArrayMesh
var wall_mesh: ArrayMesh
var joints := PackedVector2Array()

func _tri_mesh(verts: PackedVector2Array, cols: PackedColorArray) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	var m := ArrayMesh.new()
	if not verts.is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func _quad(verts: PackedVector2Array, cols: PackedColorArray, q: Array, col: Color) -> void:
	for k: int in [0, 1, 2, 0, 2, 3]:
		verts.append(q[k])
		cols.append(col)

func _build_meshes() -> void:
	var fv := PackedVector2Array()
	var fc := PackedColorArray()
	joints = PackedVector2Array()
	for i in tiles:
		for j in tiles:
			if not _floor(i, j):
				continue
			var v := float((i * 7 + j * 13) % 5) * 0.012  # variación leve entre losas
			var base := Color("#2b2f4a") if (i + j) % 2 == 0 else Color("#32375a")
			var q := [_corner(i, j), _corner(i + 1, j), _corner(i + 1, j + 1), _corner(i, j + 1)]
			_quad(fv, fc, q, base.lightened(v))
			for k in 4:  # juntas
				joints.append(q[k])
				joints.append(q[(k + 1) % 4])
	floor_mesh = _tri_mesh(fv, fc)
	var wv := PackedVector2Array()
	var wc := PackedColorArray()
	var up := Vector2(0, WALL_H * main.SCALE)
	for s in range(0, tiles * 2):  # de atrás hacia delante, para que cada bloque tape al de detrás
		for i in range(maxi(0, s - tiles + 1), mini(s, tiles - 1) + 1):
			var j := s - i
			if _floor(i, j) or not _near_floor(i, j):
				continue
			var a := _corner(i, j)
			var b := _corner(i + 1, j)
			var c := _corner(i + 1, j + 1)
			var d := _corner(i, j + 1)
			_quad(wv, wc, [a, d, d - up, a - up], Color("#1d2038"))
			_quad(wv, wc, [d, c, c - up, d - up], Color("#262a47"))
			_quad(wv, wc, [a - up, b - up, c - up, d - up], Color("#3b4068"))
	wall_mesh = _tri_mesh(wv, wc)

func _draw() -> void:
	if floor_mesh == null:
		_build_meshes()
	draw_mesh(floor_mesh, null)
	draw_multiline(joints, Color("#171a2c"), 2.0)
	draw_mesh(wall_mesh, null)
	var rim := PackedVector2Array([_corner(0, 0), _corner(tiles, 0), _corner(tiles, tiles), _corner(0, tiles), _corner(0, 0)])
	draw_polyline(rim, Color("#0a0c18"), 8.0)

	for lamp in sconces:
		var pos := lamp.position
		draw_set_transform(pos,0,Vector2.ONE*main.SCALE)
		draw_rect(Rect2(-6,-2,12,3),Color("#494153"))
		draw_rect(Rect2(-5,-5,10,4),Color("#897368"))
		draw_rect(Rect2(-3,-9,6,5),Color("#d38851"))
		draw_rect(Rect2(-1,-11,2,6),Color("#ffe7a2"))
		draw_set_transform(Vector2.ZERO)
