@tool
class_name GrassTile
extends Node2D
# Una casilla de pasto: suelo (rombo) + briznas en un solo MultiMesh. Réplica en 2D del método de Dylearn
# ("How I made grass better than 99% of games"):
#  - briznas = quads con sprite, con origen en la base; viento por ruido en coordenadas del mundo, con dos ruidos y fase por brizna;
#  - movimiento a pocos fotogramas (frame_rate) y empuje de personajes (grupo "grass_char", ver grass_manager.gd);
#  - manchas de color por ruido + briznas de acento (tamaño, altura, color y sprite distintos según su semilla);
#  - falsa perspectiva, nubes y toon híbrido (en shaders/grass.gdshader y grass_floor.gdshader).
# Uso: var t := GrassTile.new(); t.cell = Vector2(128, 64); t.cell_id = Vector2i(i, j); t.position = centro de la casilla; add_child(t)
# El material y los ruidos son uno solo para todas las casillas (GrassTile.material()); cambiar un parámetro ahí cambia todo el pasto.

const BLADE := preload("res://art/grass/blade.png")
const BLADE_SIZE := Vector2(12, 12)

static var _mat: ShaderMaterial
static var _floor_mat: ShaderMaterial

@export var cell := Vector2(128, 64)   # rombo de la casilla en píxeles de pantalla (ancho, alto)
@export var cell_id := Vector2i.ZERO   # casilla (i, j): fija las posiciones de las briznas, siempre iguales
@export var blades := 16             # en una rejilla de 4x4 con algo de azar: cubre toda la casilla
@export var blade_height := 0.8      # altura relativa del sprite: pasto bajo, como un tapiz
@export var blade_scale := 3.0         # tamaño del sprite (12 px -> 36 px en pantalla con 3.0)
@export var accent_chance := 0.0   # >0 vuelve a poner flores de acento

static func _noise_tex(seed_value: int, freq: float) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed_value
	n.frequency = freq
	return ImageTexture.create_from_image(n.get_seamless_image(256, 256))

# material compartido de las briznas; la primera casilla lo crea
static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/grass.gdshader")
		_floor_mat = ShaderMaterial.new()
		_floor_mat.shader = load("res://shaders/grass_floor.gdshader")
		var patch := _noise_tex(11, 0.012)
		var cloud := _noise_tex(23, 0.008)
		for m: ShaderMaterial in [_mat, _floor_mat]:
			m.set_shader_parameter("patch_noise", patch)
			m.set_shader_parameter("cloud_noise", cloud)
		Wind.use(_mat)
		Wind.use(_floor_mat)
		var zeros := PackedVector4Array()
		zeros.resize(64)
		_mat.set_shader_parameter("chars", zeros)
	return _mat

static func floor_material() -> ShaderMaterial:
	material()
	return _floor_mat

static func _h(a: int, b: int, c: int) -> float:  # número estable en 0..1 por casilla y brizna
	var x := (a * 374761393 + b * 668265263 + c * 1274126177 + 12345) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1103515245 + 12345) & 0x7fffffff
	return float((x ^ (x >> 11)) & 0xffff) / 65535.0

func _ready() -> void:  # una sola casilla en rombo (la demo); el valle usa build() con muchas casillas a la vez
	if get_child_count() > 0:
		return
	var hw := cell.x / 2.0
	var hh := cell.y / 2.0
	build([{"q": PackedVector2Array([Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)]), "id": cell_id}])

# Construye el pasto de varias casillas en un solo suelo y un solo MultiMesh (rendimiento: 2 llamadas de dibujo por bloque).
# Cada casilla: {"q": esquinas [c00, c10, c11, c01] en coordenadas de este nodo, "id": Vector2i}. Cada casilla sigue con sus
# mismas briznas (rejilla 4x4 con azar fijo por casilla), así que el resultado es el mismo que un GrassTile por casilla.
func build(cells: Array) -> void:
	var floor_poly := Polygon2D.new()
	var verts := PackedVector2Array()
	var polys: Array = []
	for c: Dictionary in cells:
		var q: PackedVector2Array = c["q"]
		var base := verts.size()
		verts.append_array(q)
		polys.append(PackedInt32Array([base, base + 1, base + 2, base + 3]))
	floor_poly.polygon = verts
	floor_poly.polygons = polys
	floor_poly.material = floor_material()
	add_child(floor_poly)
	# malla de una brizna: base abajo al centro del origen
	var w := BLADE_SIZE.x * blade_scale / 2.0
	var h := BLADE_SIZE.y * blade_scale * blade_height
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	# rendimiento: sin acentos, la brizna solo ocupa las filas 7..11 del sprite: el cuadro se recorta a esa franja con las
	# mismas UV (mismo dibujo y mismo movimiento, que depende de UV.y) y la GPU pinta ~58 % menos píxeles transparentes
	var top := 0.0 if accent_chance > 0.0 else 7.0 / 12.0
	var ht := h * (1.0 - top)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-w, -ht), Vector2(w, -ht), Vector2(w, 0), Vector2(-w, 0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, top), Vector2(1, top), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = blades * cells.size()
	var spots: Array = []
	var g := int(ceil(sqrt(float(blades))))  # rejilla regular dentro de la casilla + desplazamiento aleatorio: pasto parejo
	for c: Dictionary in cells:
		var q: PackedVector2Array = c["q"]
		var id: Vector2i = c["id"]
		for k in blades:
			var u := (float(k % g) + 0.15 + 0.7 * _h(id.x, id.y, k * 3)) / g
			var v := (float(k / g) + 0.15 + 0.7 * _h(id.x, id.y, k * 3 + 1)) / g
			var accent := 1.0 if _h(id.x, id.y, k * 3 + 2) < accent_chance else 0.0
			spots.append([q[0] + (q[1] - q[0]) * u + (q[3] - q[0]) * v, accent, _h(id.y, id.x, k)])
	spots.sort_custom(func(a: Array, b: Array) -> bool: return a[0].y < b[0].y)  # las de atrás se dibujan primero
	for k in spots.size():
		var accent: float = spots[k][1]
		var sx := 1.0 + accent * 0.15
		var sy := 1.0 + accent * 0.45  # los acentos son más altos
		mm.set_instance_transform_2d(k, Transform2D(0.0, Vector2(sx, sy), 0.0, spots[k][0]))
		mm.set_instance_custom_data(k, Color(spots[k][2], accent, 0.0, 0.0))
	var inst := MultiMeshInstance2D.new()
	inst.multimesh = mm
	inst.texture = BLADE
	inst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	inst.material = material()
	add_child(inst)
