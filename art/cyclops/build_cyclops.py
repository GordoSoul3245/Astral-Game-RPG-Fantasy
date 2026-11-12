import bpy, bmesh, math
from mathutils import Vector

# Cíclope (minijefe) articulado para los sprites 2.5D: 2.5 veces la altura del hechicero (2.05 m).
# Misma cámara que el hechicero y el dragón; el encuadre crece (K) para que los px por metro sean los mismos.
# Uso desde Blender: ns={}; exec(open(RUTA).read(), ns); ns['build'](); ns['render'](['S'])
OUT = r'C:/Users/Mateo/Documents/astral/art/cyclops/'
HEIGHT = 2.05 * 2.5
K = 3.5                          # el cuadro es K veces mayor que el de 128 px (448 px)
RES = int(128 * K)
FEET = (68 + (RES - 128) / 2, 113.7 + (RES - 128) / 2)   # píxel de los pies dentro del sprite (FEET del juego + desplazamiento)
DIRS = [('E', 1, 0), ('SE', 1, 1), ('S', 0, 1), ('SW', -1, 1), ('W', -1, 0), ('NW', -1, -1), ('N', 0, -1), ('NE', 1, -1)]
PIVOTS = ['cy_body', 'cy_head', 'cy_armL', 'cy_armR', 'cy_legL', 'cy_legR']


def build():
    s = bpy.context.scene
    old = bpy.data.collections.get('CYCLOPS')
    if old:
        for o in list(old.all_objects):
            bpy.data.objects.remove(o, do_unlink=True)
        s.collection.children.unlink(old)
        bpy.data.collections.remove(old)
    col = bpy.data.collections.new('CYCLOPS')
    s.collection.children.link(col)
    MAT = bpy.data.materials

    def ramp(name, src, stops):
        if name in MAT:
            MAT.remove(MAT[name])
        m = MAT[src].copy()
        m.name = name
        cr = next(n for n in m.node_tree.nodes if n.type == 'VALTORGB')
        for e, c in zip(cr.color_ramp.elements, stops):
            e.color = (*c, 1)
        return m

    SKIN = ramp('Cyclops • skin', 'Cel • midnight indigo', [(0.03, 0.026, 0.032), (0.065, 0.055, 0.065), (0.115, 0.095, 0.11), (0.19, 0.16, 0.18)])
    SKIN2 = ramp('Cyclops • belly', 'Cel • midnight indigo', [(0.05, 0.042, 0.05), (0.1, 0.085, 0.1), (0.17, 0.14, 0.16), (0.27, 0.23, 0.26)])
    DRK = ramp('Cyclops • dark', 'Cel • midnight indigo', [(0.02, 0.018, 0.025), (0.05, 0.045, 0.055), (0.09, 0.08, 0.1), (0.14, 0.12, 0.15)])
    EYE = ramp('Cyclops • eye', 'Cel • cobalt silk', [(0.1, 0.5, 0.45), (0.2, 0.8, 0.7), (0.45, 1.0, 0.9), (0.8, 1.0, 0.95)])
    HRN, OBS, WOOD = MAT['Cel • ivory horn'], MAT['Cel • obsidian'], MAT['Cel • dark wood']

    def upd():
        bpy.context.view_layer.update()

    def attach(o, parent):
        upd()
        o.parent = parent
        o.matrix_parent_inverse = parent.matrix_world.inverted()

    def link(o, mat, parent):
        if mat:
            o.data.materials.append(mat)
        for c in list(o.users_collection):
            c.objects.unlink(o)
        col.objects.link(o)
        attach(o, parent)
        return o

    def pivot(name, loc, parent):
        e = bpy.data.objects.new(name, None)
        col.objects.link(e)
        e.location = Vector(loc)
        attach(e, parent)
        e['rest'] = tuple(e.location)
        return e

    def ell(loc, sc, mat, parent):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1, location=loc)
        o = bpy.context.active_object
        o.scale = sc
        return link(o, mat, parent)

    def beam(a, b, ra, rb, mat, parent, n=8):
        a, b = Vector(a), Vector(b)
        d = b - a
        bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=ra, radius2=rb, depth=d.length, location=(a + b) / 2)
        o = bpy.context.active_object
        o.rotation_mode = 'QUATERNION'
        o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
        return link(o, mat, parent)

    def poly(pts, mat, parent):
        me = bpy.data.meshes.new('poly')
        bm = bmesh.new()
        bm.faces.new([bm.verts.new(Vector(p)) for p in pts])
        bm.normal_update()
        bm.to_mesh(me)
        bm.free()
        return link(bpy.data.objects.new('poly', me), mat, parent)

    root = bpy.data.objects.new('cy_root', None)
    col.objects.link(root)
    body = pivot('cy_body', (0, 0, 2.0), root)

    # --- torso encorvado: panza, pecho, espalda con placas y hombros enormes
    ell((0, 0.05, 2.65), (1.15, 0.95, 0.95), SKIN2, body)
    ell((0, 0.0, 3.3), (1.3, 0.9, 0.8), SKIN, body)
    ell((0, 0.45, 3.25), (1.0, 0.6, 0.8), SKIN, body)
    ell((0, 0.1, 4.2), (0.62, 0.55, 0.68), SKIN, body)            # cuello y trapecios: unen la cabeza con el torso
    ell((0, 0.35, 3.95), (1.0, 0.6, 0.6), SKIN, body)             # joroba de la espalda
    ell((0, 0.2, 4.45), (0.5, 0.45, 0.4), SKIN, body)             # base de la nuca
    for i, (x, z) in enumerate(((-0.6, 3.5), (0.5, 3.35), (-0.2, 3.0), (0.7, 2.8), (-0.7, 2.7))):
        ell((x, 0.85, z), (0.28, 0.12, 0.22), DRK, body)          # placas oscuras en la espalda
    for sx in (-1, 1):
        ell((sx * 1.4, 0.0, 3.6), (0.6, 0.6, 0.5), SKIN, body)    # hombros
        ell((sx * 0.5, -0.78, 3.5), (0.45, 0.2, 0.3), SKIN2, body)    # pectorales
    poly([(-0.75, -0.55, 2.1), (0.75, -0.55, 2.1), (0.55, -0.65, 1.15), (0.2, -0.7, 0.95), (-0.25, -0.68, 1.05), (-0.55, -0.65, 1.2)], WOOD, body)  # taparrabos raído

    # --- yugo de hierro sobre los hombros con dos cadenas colgando
    beam((-1.85, -0.5, 3.75), (1.85, -0.5, 3.75), 0.11, 0.11, OBS, body)
    for sx in (-1, 1):
        beam((sx * 1.55, -0.5, 3.75), (sx * 1.55, -0.62, 2.6), 0.05, 0.05, OBS, body, 6)
        ell((sx * 1.55, -0.62, 2.52), (0.1, 0.1, 0.1), OBS, body)

    # --- cabeza pequeña adelantada con un solo ojo
    head = pivot('cy_head', (0, -0.6, 4.3), body)
    ell((0, -0.8, 4.75), (0.55, 0.58, 0.52), SKIN, head)
    ell((0, -0.35, 4.55), (0.42, 0.45, 0.4), SKIN, head)          # nuca
    ell((0, -1.28, 4.8), (0.3, 0.12, 0.27), DRK, head)            # cuenca
    ell((0, -1.38, 4.8), (0.22, 0.1, 0.22), EYE, head)             # ojo
    ell((0, -1.48, 4.8), (0.07, 0.03, 0.15), OBS, head)            # pupila
    ell((0, -1.3, 4.42), (0.34, 0.14, 0.1), DRK, head)             # boca
    for x in (-0.2, -0.07, 0.07, 0.2):
        beam((x, -1.38, 4.46), (x, -1.38, 4.32), 0.04, 0.0, HRN, head, 4)  # dientes
    for sx in (-1, 1):
        ell((sx * 0.58, -0.7, 4.75), (0.1, 0.16, 0.2), SKIN2, head)  # orejas
        ell((sx * 0.25, -0.8, 5.2), (0.2, 0.22, 0.12), SKIN2, head)  # frente abultada

    # --- brazos largos y gruesos, manos enormes
    for nm, sx in (('cy_armL', 1), ('cy_armR', -1)):
        ap = pivot(nm, (sx * 1.5, 0.0, 3.6), body)
        ell((sx * 1.75, 0.0, 2.9), (0.58, 0.58, 0.95), SKIN, ap)
        ell((sx * 1.9, -0.1, 1.9), (0.52, 0.52, 0.9), SKIN, ap)
        ell((sx * 1.95, -0.2, 1.1), (0.55, 0.5, 0.5), SKIN2, ap)
        for dx in (-0.25, 0.0, 0.25):
            ell((sx * 1.95 + dx, -0.35, 0.8), (0.14, 0.14, 0.26), SKIN2, ap)  # dedos

    # --- piernas macizas con pies anchos
    for nm, sx in (('cy_legL', 1), ('cy_legR', -1)):
        lp = pivot(nm, (sx * 0.62, 0.0, 2.0), body)
        ell((sx * 0.62, 0.0, 1.4), (0.55, 0.55, 0.8), SKIN, lp)
        ell((sx * 0.62, -0.05, 0.55), (0.46, 0.5, 0.65), SKIN, lp)
        ell((sx * 0.62, -0.25, 0.16), (0.55, 0.78, 0.22), SKIN2, lp)
        for dx in (-0.3, 0.0, 0.3):
            ell((sx * 0.62 + dx, -0.85, 0.12), (0.14, 0.14, 0.1), HRN, lp)   # uñas de los pies

    # --- altura final = 2.5 veces el hechicero, apoyado en el suelo
    pose('idle', 0)
    upd()
    zs = [(o.matrix_world @ Vector(c)).z for o in col.objects if o.type == 'MESH' for c in o.bound_box]
    k = HEIGHT / (max(zs) - min(zs))
    root.scale = (k, k, k)
    root.location = (0, 0, -min(zs) * k)
    upd()
    print('altura', round(max(zs) - min(zs), 3), 'escala', round(k, 3), 'FEET', FEET, 'RES', RES)


def pose(kind, k):
    O = bpy.data.objects
    for n in PIVOTS:
        O[n].rotation_euler = (0, 0, 0)
        O[n].location = Vector(O[n]['rest'])

    def rot(n, x=0.0, y=0.0, z=0.0):
        O[n].rotation_euler = (x, y, z)

    def mv(n, dx=0.0, dy=0.0, dz=0.0):
        O[n].location = Vector(O[n]['rest']) + Vector((dx, dy, dz))

    if kind == 'idle':
        rot('cy_armL', 0.05, 0, 0.1)
        rot('cy_armR', 0.05, 0, -0.1)
    elif kind == 'walk':  # paso pesado: piernas y brazos opuestos, cuerpo que sube y baja
        ph = 2 * math.pi * k / 8
        a = 0.45 * math.sin(ph)
        rot('cy_legL', a); rot('cy_legR', -a)
        rot('cy_armL', -0.35 * math.sin(ph), 0, 0.1); rot('cy_armR', 0.35 * math.sin(ph), 0, -0.1)
        mv('cy_body', 0, 0, 0.07 * math.cos(2 * ph))
        rot('cy_body', 0.03 * math.sin(2 * ph), 0.05 * math.sin(ph), 0.06 * math.sin(ph))
        rot('cy_head', 0.05 * math.sin(2 * ph + 1))
    elif kind == 'attack':  # 8 fotogramas: alza el brazo (preparar), golpea el suelo (fotograma 5), recupera
        arm_r = [0.0, -0.8, -1.6, -2.3, -2.8, -0.9, -0.3, 0.0][k]
        arm_l = [0.0, -0.3, -0.6, -0.9, -1.0, -0.4, -0.1, 0.0][k]
        lean = [0.0, -0.05, -0.1, -0.13, -0.14, 0.2, 0.12, 0.0][k]
        rot('cy_armR', arm_r, 0, -0.1); rot('cy_armL', arm_l, 0, 0.1)
        rot('cy_body', lean); rot('cy_head', lean * 0.5)
        mv('cy_body', 0, [0, 0, 0, 0, 0, -0.18, -0.1, 0][k], [0, 0.02, 0.05, 0.08, 0.1, -0.12, -0.05, 0][k])
    elif kind == 'hurt':  # golpe recibido: retrocede el torso, la cabeza se sacude y los brazos se abren
        r = [1.0, 0.65, 0.3, 0.08][k]
        rot('cy_body', -0.18 * r); mv('cy_body', 0, 0.12 * r, -0.04 * r)
        rot('cy_head', -0.22 * r, 0, 0.1 * r)
        rot('cy_armL', 0.35 * r, 0, 0.1 + 0.35 * r); rot('cy_armR', 0.35 * r, 0, -0.1 - 0.35 * r)


def render(names, res=RES, prefix='cyclops_', kinds=(('idle', 1), ('walk', 8), ('attack', 8), ('hurt', 4))):
    s = bpy.context.scene
    root, col, cam = bpy.data.objects['cy_root'], bpy.data.collections['CYCLOPS'], bpy.data.objects['SpriteCam']
    q = cam.matrix_world.to_quaternion()
    fwd = q @ Vector((0, 0, -1)); fwd.z = 0; fwd.normalize()
    right = q @ Vector((1, 0, 0)); right.z = 0; right.normalize()
    toward = -fwd
    r = s.render
    ortho = cam.data.ortho_scale
    saved = (s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath)
    keep = {o.name for o in col.all_objects}
    hidden = {}
    for o in s.objects:
        if o.type in ('MESH', 'CURVE') and o.name not in keep:
            hidden[o] = o.hide_render
            o.hide_render = True
    s.camera = cam
    cam.data.ortho_scale = ortho * res / 128.0     # mismos px por metro que el resto de sprites
    r.resolution_x = r.resolution_y = res
    r.resolution_percentage = 100
    r.film_transparent = True
    r.filter_size = 0.0
    for name, dx, dy in DIRS:
        if name not in names:
            continue
        f = (right * dx + toward * dy).normalized()
        root.rotation_euler[2] = math.atan2(f.y, f.x) + math.pi / 2
        for kind, n in kinds:
            for k in range(n):
                pose(kind, k)
                r.filepath = OUT + f'{prefix}{name}_{kind}_{k:02d}.png'
                bpy.ops.render.render(write_still=True)
    pose('idle', 0)
    root.rotation_euler[2] = 0
    cam.data.ortho_scale = ortho
    for o, v in hidden.items():
        o.hide_render = v
    s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath = saved
