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
@export var blades := 7
@export var blade_scale := 3.0         # tamaño del sprite (12 px -> 36 px en pantalla con 3.0)
@export var accent_chance := 0.08

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
		var wind := _noise_tex(5, 0.02)
		for m: ShaderMaterial in [_mat, _floor_mat]:
			m.set_shader_parameter("patch_noise", patch)
			m.set_shader_parameter("cloud_noise", cloud)
		_mat.set_shader_parameter("wind_noise", wind)
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

func _ready() -> void:
	var hw := cell.x / 2.0
	var hh := cell.y / 2.0
	var floor_poly := Polygon2D.new()
	floor_poly.polygon = PackedVector2Array([Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)])
	floor_poly.material = floor_material()
	add_child(floor_poly)
	# malla de una brizna: base abajo al centro del origen
	var w := BLADE_SIZE.x * blade_scale / 2.0
	var h := BLADE_SIZE.y * blade_scale
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, 0), Vector2(-w, 0)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = blades
	var spots: Array = []
	for k in blades:
		var u := 0.12 + 0.76 * _h(cell_id.x, cell_id.y, k * 3)
		var v := 0.12 + 0.76 * _h(cell_id.x, cell_id.y, k * 3 + 1)
		var accent := 1.0 if _h(cell_id.x, cell_id.y, k * 3 + 2) < accent_chance else 0.0
		spots.append([Vector2((u - v) * hw, (u + v - 1.0) * hh), accent, _h(cell_id.y, cell_id.x, k)])
	spots.sort_custom(func(a: Array, b: Array) -> bool: return a[0].y < b[0].y)  # las de atrás se dibujan primero
	for k in blades:
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
