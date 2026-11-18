@tool
class_name LivingTree
extends Node2D
# Árbol vivo (docs/ARTE_VIVO.md, ideas 2-8 y 15): anatomía aunque sea estilizado y copa de hojas que respira con el viento.
#  - tronco que se afina, dos ramas gruesas hacia la copa y raíces que se abren (nebari), en 3 tonos y en la rejilla de 3 px;
#  - copa = 3 capas que se achican hacia arriba: un fondo oscuro (la "forma" que evita huecos) y encima muchas hojas-sprite
#    (leaf.gdshader) con su luz precalculada: lado de arriba a la izquierda claro, borde de luz, abajo a la derecha oscuro;
#  - sombra fija en el suelo (no tiembla aunque la copa se mueva) y unas pocas hojas que caen girando.
# El origen del nodo son los pies del tronco. Uso: var t := LivingTree.new(); t.seed_value = n; t.position = pie; add_child(t)

const LEAF := preload("res://art/grass/leaf.png")
const LIGHT := Vector2(-0.6, -0.8)          # de dónde viene la luz (arriba a la izquierda)
const TRUNK := [Color(0.27, 0.17, 0.12), Color(0.40, 0.26, 0.16), Color(0.53, 0.35, 0.20)]
const CORE := [Color(0.09, 0.24, 0.14), Color(0.11, 0.29, 0.16)]

static var _leaf_mat: ShaderMaterial

@export var seed_value := 0
@export var height := 150.0       # px de pantalla, del suelo al arranque de la copa
@export var crown := 92.0         # radio de la copa
@export var leaves_per_layer := 70

var _rng := RandomNumberGenerator.new()
var _layers: Array = []           # [centro, radio x, radio y]

static func leaf_material() -> ShaderMaterial:
	if _leaf_mat == null:
		_leaf_mat = ShaderMaterial.new()
		_leaf_mat.shader = load("res://shaders/leaf.gdshader")
		var g := GrassTile.floor_material()
		_leaf_mat.set_shader_parameter("cloud_noise", g.get_shader_parameter("cloud_noise"))
		_leaf_mat.set_shader_parameter("patch_noise", g.get_shader_parameter("patch_noise"))
		Wind.use(_leaf_mat)
	return _leaf_mat

func _snap(p: Vector2) -> Vector2:
	return p.snapped(Vector2(3, 3))

func _ready() -> void:
	_rng.seed = seed_value
	var h := height * _rng.randf_range(0.9, 1.15)
	var r := crown * _rng.randf_range(0.85, 1.15)
	var top := Vector2(0, -h)
	_layers = [[top + Vector2(0, -r * 0.15), r, r * 0.62], [top + Vector2(r * 0.05, -r * 0.62), r * 0.78, r * 0.5], [top + Vector2(-r * 0.05, -r * 1.0), r * 0.5, r * 0.36]]
	# sombra fija en el suelo, desplazada al lado contrario de la luz
	var shadow := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 16:
		var a := TAU * k / 16.0
		pts.append(_snap(Vector2(r * 0.95 * cos(a) + r * 0.35, r * 0.38 * sin(a) + 6)))
	shadow.polygon = pts
	shadow.color = Color(0.05, 0.12, 0.08, 0.32)
	shadow.z_as_relative = false
	shadow.z_index = -3980  # sobre el pasto, bajo todo lo demás
	add_child(shadow)
	# hojas
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var s := 12.0  # media hoja (8 px de arte x 3)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var spots: Array = []
	var top_y: float = _layers[2][0].y - _layers[2][2]
	var bot_y: float = _layers[0][0].y + _layers[0][2]
	for li in _layers.size():
		var c: Vector2 = _layers[li][0]
		var rx: float = _layers[li][1]
		var ry: float = _layers[li][2]
		for k in leaves_per_layer:
			var a := _rng.randf() * TAU
			var d := sqrt(_rng.randf())
			var n := Vector2(cos(a), sin(a)) * d           # posición normalizada en la capa
			var p := c + Vector2(n.x * rx, n.y * ry)
			var light := clampf(0.5 + 0.55 * n.dot(LIGHT.normalized()) + 0.12 * li - 0.25 * (1.0 - d), 0.0, 1.0)
			var rim := 1.0 if d > 0.82 and n.dot(LIGHT.normalized()) > 0.25 else 0.0
			var hgt := clampf((bot_y - p.y) / (bot_y - top_y), 0.0, 1.0)
			spots.append([_snap(p), Color(_rng.randf(), light, rim, 0.3 + 0.7 * hgt)])
	spots.sort_custom(func(a: Array, b: Array) -> bool: return a[0].y < b[0].y)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = spots.size()
	for k in spots.size():
		mm.set_instance_transform_2d(k, Transform2D(0.0, spots[k][0]))
		mm.set_instance_custom_data(k, spots[k][1])
	var inst := MultiMeshInstance2D.new()
	inst.multimesh = mm
	inst.texture = LEAF
	inst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	inst.material = leaf_material()
	add_child(inst)
	# hojas que caen: pocas, girando con el centro de giro desplazado (órbita) para que parezca turbulencia.
	# Rendimiento: solo uno de cada tres árboles suelta hojas (en un bosque se ven igual y cuesta un tercio)
	if seed_value % 3 != 0:
		queue_redraw()
		return
	var fall := CPUParticles2D.new()
	var at := AtlasTexture.new()
	at.atlas = LEAF
	at.region = Rect2(0, 0, 8, 8)
	fall.texture = at
	fall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fall.amount = 3
	fall.lifetime = 4.5
	fall.preprocess = 4.5
	fall.local_coords = false
	fall.position = _layers[0][0]
	fall.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fall.emission_rect_extents = Vector2(r * 0.8, r * 0.3)
	fall.direction = Wind.DIR.normalized()
	fall.spread = 25.0
	fall.initial_velocity_min = 8.0
	fall.initial_velocity_max = 20.0
	fall.gravity = Vector2(0, 18)
	fall.angular_velocity_min = -120.0
	fall.angular_velocity_max = 120.0
	fall.orbit_velocity_min = -0.04
	fall.orbit_velocity_max = 0.04
	fall.scale_amount_min = 2.4
	fall.scale_amount_max = 3.0
	fall.color = Color(0.45, 0.66, 0.3)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	fall.color_ramp = fade
	add_child(fall)
	queue_redraw()

var _v: PackedVector2Array
var _c: PackedColorArray
var _mesh: ArrayMesh

func _draw() -> void:  # rendimiento: todos los polígonos van a una malla (una llamada de dibujo por árbol, no ~12)
	_v = PackedVector2Array()
	_c = PackedColorArray()
	var h: float = -_layers[0][0].y
	var w0 := 15.0
	var w1 := 9.0
	# raíces (nebari): se abren a los lados y se hunden en el suelo
	for side in [-1.0, 1.0]:
		var c := TRUNK[0] if side > 0 else TRUNK[1]
		_poly(PackedVector2Array([_snap(Vector2(side * w0 * 0.4, -18)), _snap(Vector2(side * (w0 + 18), 3)), _snap(Vector2(side * (w0 + 6), 6)), _snap(Vector2(side * w0 * 0.2, 2))]), c)
	_poly(PackedVector2Array([_snap(Vector2(-6, -10)), _snap(Vector2(4, 9)), _snap(Vector2(-2, 9))]), TRUNK[0])
	# tronco que se afina: lado iluminado (izquierda) más claro
	_poly(PackedVector2Array([_snap(Vector2(-w0, 0)), _snap(Vector2(w0, 0)), _snap(Vector2(w1, -h)), _snap(Vector2(-w1, -h))]), TRUNK[1])
	_poly(PackedVector2Array([_snap(Vector2(w0 * 0.25, 0)), _snap(Vector2(w0, 0)), _snap(Vector2(w1, -h)), _snap(Vector2(w1 * 0.25, -h))]), TRUNK[0])
	_poly(PackedVector2Array([_snap(Vector2(-w0, 0)), _snap(Vector2(-w0 * 0.55, 0)), _snap(Vector2(-w1 * 0.55, -h)), _snap(Vector2(-w1, -h))]), TRUNK[2])
	# dos ramas gruesas que entran en la copa (el flujo del árbol)
	for side in [-1.0, 1.0]:
		var b0 := Vector2(0, -h * 0.82)
		var b1 := Vector2(side * crown * 0.55, -h - crown * 0.25)
		_poly(PackedVector2Array([_snap(b0 + Vector2(-5, 0)), _snap(b0 + Vector2(5, 0)), _snap(b1 + Vector2(3, 0)), _snap(b1 + Vector2(-3, 0))]), TRUNK[1] if side < 0 else TRUNK[0])
	# fondo de la copa: la forma oscura sobre la que se reparten las hojas (sin huecos)
	for li in _layers.size():
		var c: Vector2 = _layers[li][0]
		var pts := PackedVector2Array()
		for k in 20:
			var a := TAU * k / 20.0
			pts.append(_snap(c + Vector2(cos(a) * _layers[li][1] * 0.9, sin(a) * _layers[li][2] * 0.9)))
		_poly(pts, CORE[mini(li, 1)])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _v
	arr[Mesh.ARRAY_COLOR] = _c
	_mesh = ArrayMesh.new()  # se guarda: el lienzo solo referencia la malla
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	draw_mesh(_mesh, null)

func _poly(pts: PackedVector2Array, col: Color) -> void:
	for k in Geometry2D.triangulate_polygon(pts):
		_v.append(pts[k])
		_c.append(col)
