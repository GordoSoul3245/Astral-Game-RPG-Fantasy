import bpy, bmesh, math, random, json
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

# Mapa isométrico 20x20 casillas: isla de bosque con lago, casa y castillo. Misma cámara y estilo cel que el hechicero.
# Casilla (i, j) <-> mundo Blender: x = j - 10, y = i - 10 (1 casilla = 1 m). En pantalla i sube hacia arriba-derecha, j hacia abajo-derecha.
# Uso: ns={}; exec(open(RUTA).read(), ns); L=ns['layout'](); ns['build_ground'](L); ns['render_ground'](L)
OUT = r'C:/Users/Mateo/Documents/astral/art/map/'
DATA = r'C:/Users/Mateo/Documents/astral/data/map.json'
N = 50
PXM = 128 / 2.75    # px por metro de los sprites del héroe
CASTLE = (23.0, 23.0, 27.0, 27.0)    # rectángulos de casillas (i0, j0, i1, j1); el castillo queda en el centro
HOUSE = (30.0, 10.5, 34.0, 13.5)
# pueblo junto al inicio (posiciones comprobadas: suelo firme y lejos de los caminos)
VILLAGE = {'house': [(14.0, 37.5, 18.0, 40.5), (18.8, 36.5, 22.8, 39.5)], 'stall': [(12.0, 31.0, 14.4, 32.6)]}
RECTS = [CASTLE, HOUSE] + [r for rs in VILLAGE.values() for r in rs]
START = (7.5, 37.5)                  # se recalcula como la casilla de camino más cercana a (6, 38)
DRAGON = (34.0, 21.0)
CLEAR_R = 14.0                       # radio (casillas) del claro central sin árboles


def tw(i, j, z=0.0):
    return Vector((j - N / 2, i - N / 2, z))


def layout():
    rnd = random.Random(21)
    land = {}
    for i in range(N):
        for j in range(N):
            ci, cj = i + 0.5 - N / 2, j + 0.5 - N / 2
            th = math.atan2(ci, cj)
            R = 22.2 + 2.2 * math.sin(3 * th + 1.0) + 1.6 * math.sin(5 * th + 2.0) + 1.1 * math.sin(2 * th) + 0.8 * math.sin(9 * th + 0.5)
            if math.hypot(ci, cj) < R:
                land[(i, j)] = 'grass'
    for i in range(N):  # lago al noreste (borde derecho de la pantalla), puede salir de la isla como una bahía
        for j in range(N):
            if ((i + 0.5 - 44.5) / 9.0) ** 2 + ((j + 0.5 - 27.5) / 13.5) ** 2 < 1.0 and math.hypot(i + 0.5 - N / 2, j + 0.5 - N / 2) < 25.5:
                land[(i, j)] = 'water'
    for (i, j), k in list(land.items()):
        if k == 'grass' and any(land.get((i + a, j + b)) == 'water' for a in (-1, 0, 1) for b in (-1, 0, 1)):
            land[(i, j)] = 'shore'
    for r in RECTS:  # el suelo bajo los edificios es tierra firme
        for i in range(int(r[0]), math.ceil(r[2])):
            for j in range(int(r[1]), math.ceil(r[3])):
                if land.get((i, j)) in (None, 'shore'):
                    land[(i, j)] = 'grass'
    segs = [[(6, 38), (11, 36.5), (17, 33), (22, 30), (25, 27.9)],                              # sur -> portón del castillo
            [(17, 33), (15, 26), (19, 19), (26, 15.5), (31, 14.2), (32, 13.9)],                   # a la puerta de la casa
            [(25.5, 28), (32, 31), (38, 31.5), (38.5, 31)],                                      # del castillo a la orilla del lago
            [(11, 36.5), (8, 28), (9, 20), (13, 14), (18, 10)],                                  # sendero del oeste
            [(32, 13.9), (30, 7), (28, 3)]]                                                       # sendero del norte
    path = set()
    for pts in segs:
        for a, b in zip(pts, pts[1:]):
            n = int(math.dist(a, b) * 4) + 1
            for k in range(n + 1):
                t = k / n
                p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
                for di in (-1, 0, 1):
                    for dj in (-1, 0, 1):
                        ti, tj = int(p[0]) + di, int(p[1]) + dj
                        if math.hypot(ti + 0.5 - p[0], tj + 0.5 - p[1]) < 0.72 and land.get((ti, tj)) in ('grass', 'shore'):
                            path.add((ti, tj))
    for t in path:
        land[t] = 'path'
    global START   # el héroe empieza en el extremo sur del camino
    st = min(path, key=lambda t: math.dist((t[0] + 0.5, t[1] + 0.5), (6, 38)))
    START = (st[0] + 0.5, st[1] + 0.5)

    def near_rect(i, j, r, m):
        return r[0] - m < i < r[2] + m and r[1] - m < j < r[3] + m

    def free(i, j, m=1.5):
        if any(near_rect(i, j, r, m) for r in RECTS):
            return False
        if math.dist((i, j), DRAGON) < 3.2 or math.dist((i, j), START) < 2.5:
            return False
        return all(math.dist((i, j), (pi + 0.5, pj + 0.5)) > 1.5 for pi, pj in path)

    trees = []
    for (i, j), k in land.items():
        if k != 'grass':
            continue
        edge = sum(1 for a in (-1, 0, 1) for b in (-1, 0, 1) if (i + a, j + b) not in land)
        for _ in range(2):
            if rnd.random() < 0.5 + 0.08 * edge:
                ti, tj = i + 0.5 + rnd.uniform(-0.4, 0.4), j + 0.5 + rnd.uniform(-0.4, 0.4)
                if free(ti, tj) and all(math.dist((ti, tj), (o[0], o[1])) > 0.75 for o in trees):
                    trees.append((ti, tj, rnd.choice('aabbc')))
    keep = round(len(trees) * 0.75)   # raleo del 25%: se quita siempre el árbol más apiñado para que el bosque quede parejo
    while len(trees) > keep:
        k = min(range(len(trees)), key=lambda a: min(math.dist(trees[a][:2], trees[b][:2]) for b in range(len(trees)) if b != a))
        trees.pop(k)
    trees = [t for t in trees if math.dist(t[:2], (N / 2, N / 2)) >= CLEAR_R]   # claro central sin árboles (mapa de pruebas)
    rocks = []
    cand =[(i + 0.5, j + 0.5) for (i, j), k in land.items() if k == 'grass']
    rnd.shuffle(cand)
    for ti, tj in cand:
        if len(rocks) >= 40:
            break
        if free(ti, tj, 1.0) and all(math.dist((ti, tj), (o[0], o[1])) > 0.9 for o in trees + rocks):
            rocks.append((ti, tj, rnd.choice('ab')))
    return dict(land=land, path=path, trees=trees, rocks=rocks)


def mat_ramp(name, stops, src='Cel • obsidian'):
    M = bpy.data.materials
    if name in M:
        return M[name]
    m = M[src].copy()
    m.name = name
    cr = next(n for n in m.node_tree.nodes if n.type == 'VALTORGB')
    for e, c in zip(cr.color_ramp.elements, stops):
        e.color = (*c, 1)
    return m


def scale_stops(stops, f):
    return [(min(1, r * f), min(1, g * f), min(1, b * f)) for r, g, b in stops]


GRASS = [(0.015, 0.06, 0.012), (0.03, 0.11, 0.02), (0.05, 0.18, 0.03), (0.075, 0.26, 0.04)]
DIRT = [(0.06, 0.035, 0.015), (0.12, 0.07, 0.03), (0.2, 0.12, 0.05), (0.3, 0.19, 0.08)]
SAND = [(0.15, 0.13, 0.1), (0.28, 0.25, 0.2), (0.4, 0.37, 0.3), (0.55, 0.52, 0.44)]
WATER = [(0.01, 0.05, 0.12), (0.02, 0.11, 0.25), (0.04, 0.2, 0.4), (0.08, 0.32, 0.55)]
PINE = [(0.005, 0.035, 0.012), (0.01, 0.07, 0.02), (0.02, 0.12, 0.03), (0.035, 0.19, 0.05)]
ROCK = [(0.03, 0.032, 0.04), (0.07, 0.075, 0.09), (0.13, 0.14, 0.16), (0.22, 0.23, 0.26)]
WALL = [(0.12, 0.07, 0.03), (0.25, 0.15, 0.06), (0.4, 0.26, 0.11), (0.55, 0.38, 0.17)]
ROOF = [(0.05, 0.012, 0.01), (0.11, 0.03, 0.025), (0.19, 0.05, 0.04), (0.28, 0.08, 0.06)]
STONE = [(0.03, 0.03, 0.045), (0.07, 0.07, 0.1), (0.14, 0.14, 0.19), (0.24, 0.24, 0.31)]
SOIL = [(0.012, 0.007, 0.004), (0.025, 0.015, 0.008), (0.04, 0.025, 0.012), (0.06, 0.04, 0.02)]


def materials():
    return dict(
        grass_a=mat_ramp('Map • hierba A', GRASS), grass_b=mat_ramp('Map • hierba B', scale_stops(GRASS, 0.8)),
        grass_c=mat_ramp('Map • hierba C', scale_stops(GRASS, 1.25)), tuft=mat_ramp('Map • mata', scale_stops(GRASS, 1.6)),
        dirt=mat_ramp('Map • camino', DIRT), sand=mat_ramp('Map • orilla', SAND), soil=mat_ramp('Map • tierra', SOIL),
        water_a=mat_ramp('Map • agua A', WATER), water_b=mat_ramp('Map • agua B', scale_stops(WATER, 1.35)),
        pine_a=mat_ramp('Map • pino A', PINE), pine_b=mat_ramp('Map • pino B', scale_stops(PINE, 1.45)),
        rock=mat_ramp('Map • roca', ROCK), moss=mat_ramp('Map • musgo', scale_stops(GRASS, 0.9)),
        wall=mat_ramp('Map • muro casa', WALL), roof=mat_ramp('Map • tejado', ROOF), stone=mat_ramp('Map • piedra', STONE),
        wood=bpy.data.materials['Cel • dark wood'], gold=bpy.data.materials['Cel • antique gold'],
        flower=bpy.data.materials['Cel • ivory horn'], dark=bpy.data.materials['Cel • obsidian'])


def new_col(name):
    s = bpy.context.scene
    old = bpy.data.collections.get(name)
    if old:
        for o in list(old.all_objects):
            bpy.data.objects.remove(o, do_unlink=True)
        s.collection.children.unlink(old)
        bpy.data.collections.remove(old)
    c = bpy.data.collections.new(name)
    s.collection.children.link(c)
    return c


def box(bm, c, sx, sy, sz):
    r = bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=r['verts'])
    bmesh.ops.translate(bm, vec=c, verts=r['verts'])


def cone(bm, c, r1, r2, h, segs=7):
    g = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=h)
    bmesh.ops.translate(bm, vec=(c[0], c[1], c[2] + h / 2), verts=g['verts'])


def sphere(bm, c, sx, sy, sz, u=7, v=5):
    g = bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    bmesh.ops.scale(bm, vec=(sx, sy, sz), verts=g['verts'])
    bmesh.ops.translate(bm, vec=c, verts=g['verts'])


def commit(col, name, mat, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    return o


def build_ground(L):
    M = materials()
    col = new_col('MAP_GROUND')
    rnd = random.Random(5)
    B = {k: bmesh.new() for k in ('soil', 'grass_a', 'grass_b', 'grass_c', 'dirt', 'sand', 'water_a', 'water_b', 'tuft', 'flower')}
    for (i, j), k in L['land'].items():
        c = tw(i + 0.5, j + 0.5)
        if k == 'water':
            box(B['water_a' if rnd.random() < 0.7 else 'water_b'], (c.x, c.y, -0.2), 1.0, 1.0, 0.03)
            continue
        box(B['soil'], (c.x, c.y, -0.22), 1.0, 1.0, 0.34)
        kind = {'grass': rnd.choice(['grass_a', 'grass_a', 'grass_b', 'grass_c']), 'path': 'dirt', 'shore': 'sand'}[k]
        box(B[kind], (c.x, c.y, -0.03 if k == 'grass' else -0.045), 0.998, 0.998, 0.06)
        if k == 'grass':
            for _ in range(rnd.choice([0, 1, 1, 2])):
                cone(B['tuft'], (c.x + rnd.uniform(-0.4, 0.4), c.y + rnd.uniform(-0.4, 0.4), 0.0), 0.05, 0.0, rnd.uniform(0.1, 0.2), 4)
            if rnd.random() < 0.08:
                sphere(B['flower'], (c.x + rnd.uniform(-0.35, 0.35), c.y + rnd.uniform(-0.35, 0.35), 0.03), 0.035, 0.035, 0.035)
    for k, bm in B.items():
        commit(col, 'ground_' + k, M[{'soil': 'soil', 'dirt': 'dirt', 'sand': 'sand', 'tuft': 'tuft', 'flower': 'flower'}.get(k, k)], bm)
    return col


def _setup_lights():
    """Sol único para todo el mapa (las luces de área del héroe solo iluminan cerca del origen)."""
    s = bpy.context.scene
    state = {o: o.hide_render for o in s.objects if o.type == 'LIGHT'}
    for o in state:
        o.hide_render = True
    sun = bpy.data.objects.get('MapSun')
    if not sun:
        ld = bpy.data.lights.new('MapSun', 'SUN')
        sun = bpy.data.objects.new('MapSun', ld)
        s.collection.objects.link(sun)
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(52), 0, math.radians(-35))
    sun.hide_render = False
    return state


def _restore_lights(state):
    for o, v in state.items():
        o.hide_render = v
    bpy.data.objects['MapSun'].hide_render = True


def _hide_others(keep_cols):
    s = bpy.context.scene
    keep = {o.name for c in keep_cols for o in c.all_objects}
    hidden = {}
    for o in s.objects:
        if o.type in ('MESH', 'CURVE') and o.name not in keep:
            hidden[o] = o.hide_render
            o.hide_render = True
    return hidden


def _cam(name, ortho):
    s = bpy.context.scene
    sc = bpy.data.objects['SpriteCam']
    cam = bpy.data.objects.get(name)
    if not cam:
        cd = bpy.data.cameras.new(name)
        cam = bpy.data.objects.new(name, cd)
        s.collection.objects.link(cam)
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = ortho
    cam.data.clip_start, cam.data.clip_end = 0.1, 400
    # en ortográfica, alejar la cámara por su eje no cambia la imagen pero evita recortar lo que queda "detrás" (mapas grandes)
    cam.location = sc.location - (sc.matrix_world.to_quaternion() @ Vector((0, 0, -1))) * 80
    cam.rotation_euler = sc.rotation_euler
    cam.data.shift_x = cam.data.shift_y = 0.0
    return cam


def _px(cam, res, p):
    uv = world_to_camera_view(bpy.context.scene, cam, Vector(p))
    return (uv.x * res[0], (1 - uv.y) * res[1])


def render_ground(L, W=3360, H=1480, path=OUT + 'ground.png'):
    s = bpy.context.scene
    r = s.render
    saved = (s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath)
    r.resolution_x, r.resolution_y, r.resolution_percentage = W, H, 100
    cam = _cam('MapCam', W / PXM)
    corners = [tw(0, 0), tw(N, 0), tw(0, N), tw(N, N)]
    pts = [_px(cam, (W, H), c) for c in corners]
    cx = (min(p[0] for p in pts) + max(p[0] for p in pts)) / 2
    cy = (min(p[1] for p in pts) + max(p[1] for p in pts)) / 2
    cam.data.shift_x = (cx - W / 2) / W
    cam.data.shift_y = -(cy - (H / 2 + 20)) / W
    bpy.context.view_layer.update()
    c1 = _px(cam, (W, H), tw(0, 0))
    e1 = _px(cam, (W, H), tw(N, 0))
    e2 = _px(cam, (W, H), tw(0, N))
    info = dict(image='res://art/map/ground.png', size=[W, H], c1=list(c1), e1=[e1[0] - c1[0], e1[1] - c1[1]], e2=[e2[0] - c1[0], e2[1] - c1[1]])
    hid = _hide_others([bpy.data.collections['MAP_GROUND']])
    lights = _setup_lights()
    s.camera = cam
    r.film_transparent = True
    r.filter_size = 0.0
    r.filepath = path
    bpy.ops.render.render(write_still=True)
    for o, v in hid.items():
        o.hide_render = v
    _restore_lights(lights)
    s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath = saved
    return info


# ---------------------------------------------------------------- objetos (cada uno con su base en el origen del mundo)
SPRITES = {'tree_a': 192, 'tree_b': 192, 'tree_c': 192, 'rock_a': 96, 'rock_b': 96, 'house': 320, 'castle': 576, 'stall': 192}
TREES = {'a': [(0.5, 0.85, 1.0), (1.1, 0.68, 0.95), (1.65, 0.5, 0.85), (2.15, 0.32, 0.8)],
         'b': [(0.45, 0.7, 0.9), (0.95, 0.52, 0.85), (1.4, 0.34, 0.8)],
         'c': [(0.5, 0.6, 1.0), (1.2, 0.5, 1.0), (1.9, 0.4, 0.95), (2.5, 0.28, 0.9)]}


def _poly(bm, pts):
    bm.faces.new([bm.verts.new(p) for p in pts])


def build_objects():
    M = materials()
    for name in SPRITES:
        col = new_col('MAPOBJ_' + name)
        B = {}

        def bm(key):
            if key not in B:
                B[key] = bmesh.new()
            return B[key]

        if name.startswith('tree'):
            cone(bm('wood'), (0, 0, 0), 0.1, 0.08, 0.75, 6)
            for k, (z0, r, h) in enumerate(TREES[name[-1]]):
                cone(bm('pine_a' if k % 2 == 0 else 'pine_b'), (0, 0, z0), r, 0.05, h, 7)
        elif name == 'rock_a':
            sphere(bm('rock'), (0, 0, 0.26), 0.55, 0.45, 0.38)
            sphere(bm('rock'), (0.5, 0.25, 0.13), 0.28, 0.24, 0.18)
            sphere(bm('moss'), (0.02, 0, 0.5), 0.34, 0.28, 0.1)
        elif name == 'rock_b':
            sphere(bm('rock'), (-0.2, 0.0, 0.2), 0.34, 0.3, 0.28)
            sphere(bm('rock'), (0.22, 0.12, 0.16), 0.3, 0.26, 0.22)
            sphere(bm('rock'), (0.05, -0.28, 0.1), 0.2, 0.18, 0.14)
        elif name == 'house':   # x: 3 m (eje j), y: 4 m (eje i); puerta en +X (cara visible hacia abajo-derecha)
            box(bm('stone'), (0, 0, 0.1), 3.3, 4.3, 0.2)
            box(bm('wall'), (0, 0, 1.2), 3.0, 4.0, 2.0)
            for sx in (-1, 1):
                for sy in (-1, 1):
                    box(bm('wood'), (sx * 1.5, sy * 2.0, 1.2), 0.2, 0.2, 2.0)
            for z in (0.75, 1.75):
                box(bm('wood'), (0, 2.0, z), 3.0, 0.1, 0.1)
                box(bm('wood'), (0, -2.0, z), 3.0, 0.1, 0.1)
                box(bm('wood'), (1.5, 0, z), 0.1, 4.0, 0.1)
                box(bm('wood'), (-1.5, 0, z), 0.1, 4.0, 0.1)
            box(bm('wood'), (1.53, 0, 0.95), 0.07, 0.85, 1.55)          # puerta
            sphere(bm('gold'), (1.58, 0.28, 0.95), 0.04, 0.04, 0.04)
            box(bm('stone'), (1.85, 0, 0.14), 0.5, 1.4, 0.16)           # escalón
            for y in (-1.3, 1.3):
                box(bm('gold'), (1.52, y, 1.3), 0.06, 0.62, 0.72)
                box(bm('dark'), (1.55, y, 1.3), 0.06, 0.5, 0.6)
            for x in (-0.8, 0.8):
                box(bm('gold'), (x, -2.02, 1.3), 0.62, 0.06, 0.72)
                box(bm('dark'), (x, -2.05, 1.3), 0.5, 0.06, 0.6)
            r = bpy.data.meshes.new('roof')
            b = bmesh.new()
            ex, ey, z0, rz, rl = 1.95, 2.45, 2.2, 3.6, 1.4
            _poly(b, [(-ex, -ey, z0), (-ex, ey, z0), (0, rl, rz), (0, -rl, rz)])
            _poly(b, [(ex, ey, z0), (ex, -ey, z0), (0, -rl, rz), (0, rl, rz)])
            _poly(b, [(ex, -ey, z0), (-ex, -ey, z0), (0, -rl, rz)])
            _poly(b, [(-ex, ey, z0), (ex, ey, z0), (0, rl, rz)])
            _poly(b, [(-ex, ey, z0), (-ex, -ey, z0), (ex, -ey, z0), (ex, ey, z0)])
            bmesh.ops.recalc_face_normals(b, faces=b.faces)
            B['roof'] = b
            box(bm('stone'), (0.75, 0.9, 3.1), 0.5, 0.5, 1.6)           # chimenea
            box(bm('dark'), (0.75, 0.9, 3.95), 0.62, 0.62, 0.12)
        elif name == 'stall':   # puesto del mercader 1.6 (j) x 2.4 (i) m; el mostrador mira a +X
            box(bm('stone'), (0, 0, 0.05), 1.7, 2.5, 0.1)
            box(bm('wood'), (0.45, 0, 0.5), 0.5, 2.2, 0.9)               # mostrador
            box(bm('wall'), (0.45, 0, 0.98), 0.62, 2.3, 0.06)
            for sy in (-1, 1):
                box(bm('wood'), (-0.55, sy * 1.1, 1.1), 0.1, 0.1, 2.2)   # postes traseros
                box(bm('wood'), (0.72, sy * 1.1, 1.0), 0.1, 0.1, 2.0)    # postes delanteros
            box(bm('wood'), (-0.55, 0, 0.7), 0.08, 2.1, 1.3)            # panel trasero
            for k, y in enumerate((-0.9, -0.3, 0.3, 0.9)):
                box(bm('roof' if k % 2 == 0 else 'wall'), (0.1, y, 2.18), 1.8, 0.6, 0.06)  # toldo a rayas
            for y in (-0.7, 0.0, 0.7):
                sphere(bm('gold'), (0.5, y, 1.14), 0.1, 0.1, 0.1)       # mercancía
        elif name == 'castle':  # 4x4 m; portón en +X
            box(bm('stone'), (0, 0, 0.12), 4.0, 4.0, 0.24)
            box(bm('stone'), (0, 0, 1.75), 3.1, 3.1, 3.0)
            for t in range(-3, 4):
                for side in (-1, 1):
                    box(bm('stone'), (t * 0.42, side * 1.5, 3.4), 0.26, 0.26, 0.3)
                    box(bm('stone'), (side * 1.5, t * 0.42, 3.4), 0.26, 0.26, 0.3)
            for sx in (-1, 1):
                for sy in (-1, 1):
                    cone(bm('stone'), (sx * 1.65, sy * 1.65, 0.0), 0.62, 0.62, 4.1, 10)
                    cone(bm('roof'), (sx * 1.65, sy * 1.65, 4.1), 0.85, 0.0, 1.5, 10)
            cone(bm('stone'), (0, 0, 3.0), 0.95, 0.95, 2.0, 10)
            cone(bm('roof'), (0, 0, 5.0), 1.2, 0.0, 1.8, 10)
            box(bm('dark'), (1.58, 0, 0.85), 0.08, 1.0, 1.5)          # portón
            box(bm('wood'), (1.6, 0, 0.8), 0.06, 0.9, 1.4)
            box(bm('gold'), (1.62, 0, 0.45), 0.05, 0.9, 0.06)
            box(bm('dark'), (1.56, -1.0, 2.2), 0.08, 0.2, 0.6)
            box(bm('dark'), (1.56, 1.0, 2.2), 0.08, 0.2, 0.6)
            box(bm('dark'), (-1.0, -1.56, 2.2), 0.2, 0.08, 0.6)
            for sx in (-1, 1):
                for sy in (-1, 1):
                    box(bm('dark'), (sx * 1.65 + 0.58 * (1 if sx > 0 else 0), sy * 1.65, 2.4), 0.06, 0.18, 0.5)
        for key, b in B.items():
            commit(col, f'{name}_{key}', M[key if key != 'roof' else 'roof'], b)


def render_sprites(names=None, prefix=''):
    """Un PNG por objeto con la cámara de los sprites del héroe; devuelve el píxel de los pies (origen del mundo)."""
    s = bpy.context.scene
    r = s.render
    saved = (s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath)
    lights = _setup_lights()
    info = {}
    for name, F in SPRITES.items():
        if names and name not in names:
            continue
        col = bpy.data.collections['MAPOBJ_' + name]
        r.resolution_x = r.resolution_y = F
        r.resolution_percentage = 100
        cam = _cam('ObjCam', F / PXM)
        bpy.context.view_layer.update()
        hid = _hide_others([col])
        s.camera = cam
        r.film_transparent = True
        r.filter_size = 0.0
        r.filepath = OUT + prefix + name + '.png'
        bpy.ops.render.render(write_still=True)
        for o, v in hid.items():
            o.hide_render = v
        fx, fy = _px(cam, (F, F), (0, 0, 0))
        info[name] = dict(path=f'res://art/map/{name}.png', frame=[F, F], feet=[round(fx, 1), round(fy, 1)])
    _restore_lights(lights)
    s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath = saved
    return info


def export_map(L, ground, sprites):
    """data/map.json: cuadrícula transitable, objetos con su hitbox (círculo o rectángulo, en casillas) y datos de proyección."""
    land = L['land']
    walk = [''.join('1' if land.get((i, j)) in ('grass', 'path', 'shore') else '0' for j in range(N)) for i in range(N)]
    objs = []
    for ti, tj, v in L['trees']:
        objs.append(dict(sprite='tree_' + v, tile=[round(ti, 3), round(tj, 3)], circle=0.3))   # solo el tronco bloquea
    for ti, tj, v in L['rocks']:
        objs.append(dict(sprite='rock_' + v, tile=[round(ti, 3), round(tj, 3)], circle=0.5 if v == 'a' else 0.45))
    for nm, r in [('house', HOUSE), ('castle', CASTLE)] + [(k, r) for k, rs in VILLAGE.items() for r in rs]:
        objs.append(dict(sprite=nm, tile=[(r[0] + r[2]) / 2, (r[1] + r[3]) / 2], rect=[r[0] + 0.1, r[1] + 0.1, r[2] - 0.1, r[3] - 0.1]))
    data = dict(tiles=N, image=ground['image'], size=ground['size'], c1=ground['c1'], e1=ground['e1'], e2=ground['e2'],
                walk=walk, sprites=sprites, objects=objs, start=list(START), dragon=list(DRAGON))
    with open(DATA, 'w', encoding='utf8') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print('start walkable:', walk[int(START[0])][int(START[1])], 'dragon walkable:', walk[int(DRAGON[0])][int(DRAGON[1])], 'objetos:', len(objs))
