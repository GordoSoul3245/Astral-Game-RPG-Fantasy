import bpy, bmesh, math
from mathutils import Vector

# Dragón rojo articulado para los sprites 2.5D del juego (misma cámara que el hechicero).
# Uso desde Blender: ns={}; exec(open(RUTA).read(), ns); ns['build'](); ns['render'](['S'])
OUT = r'C:/Users/Mateo/Documents/astral/art/dragon/'
SHIFT = Vector((0, -0.675, 0))   # centra la longitud (cabeza a cola) sobre el origen = pies del sprite
DIRS = [('E', 1, 0), ('SE', 1, 1), ('S', 0, 1), ('SW', -1, 1), ('W', -1, 0), ('NW', -1, -1), ('N', 0, -1), ('NE', 1, -1)]
PIVOTS = ['dr_body', 'dr_neck', 'dr_head', 'dr_jaw', 'dr_wingR', 'dr_wingL', 'dr_tail1', 'dr_tail2', 'dr_tail3',
          'dr_legFL', 'dr_legFR', 'dr_legBL', 'dr_legBR']


def build():
    s = bpy.context.scene
    old = bpy.data.collections.get('DRAGON')
    if old:
        for o in list(old.all_objects):
            bpy.data.objects.remove(o, do_unlink=True)
        s.collection.children.unlink(old)
        bpy.data.collections.remove(old)
    col = bpy.data.collections.new('DRAGON')
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

    RED = ramp('Dragon • scale', 'Cel • crimson', [(0.10, 0.012, 0.012), (0.22, 0.03, 0.025), (0.38, 0.05, 0.035), (0.55, 0.07, 0.045)])
    DRK = ramp('Dragon • scale dark', 'Cel • crimson', [(0.05, 0.008, 0.01), (0.11, 0.016, 0.016), (0.2, 0.03, 0.025), (0.3, 0.04, 0.03)])
    WNG = ramp('Dragon • wing', 'Cel • crimson', [(0.08, 0.01, 0.012), (0.18, 0.02, 0.02), (0.32, 0.035, 0.03), (0.46, 0.05, 0.04)])
    BEL = ramp('Dragon • belly', 'Cel • amber cloak', [(0.3, 0.12, 0.03), (0.5, 0.22, 0.05), (0.75, 0.4, 0.1), (0.95, 0.6, 0.18)])
    HRN, OCH, GLD, OBS = MAT['Cel • ivory horn'], MAT['Cel • demon ochre'], MAT['Cel • antique gold'], MAT['Cel • obsidian']
    FIRE, HEART = MAT['Spell • molten orange'], MAT['Spell • warm heart']

    V = lambda p: Vector(p) + SHIFT

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
        e.location = V(loc)
        attach(e, parent)
        e['rest'] = tuple(e.location)
        return e

    def ell(loc, sc, mat, parent):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=1, location=V(loc))
        o = bpy.context.active_object
        o.scale = sc
        return link(o, mat, parent)

    def beam(a, b, ra, rb, mat, parent, n=6):
        a, b = V(a), V(b)
        d = b - a
        bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=ra, radius2=rb, depth=d.length, location=(a + b) / 2)
        o = bpy.context.active_object
        o.rotation_mode = 'QUATERNION'
        o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
        return link(o, mat, parent)

    def poly(pts, mat, parent):
        me = bpy.data.meshes.new('poly')
        bm = bmesh.new()
        bm.faces.new([bm.verts.new(V(p)) for p in pts])
        bm.normal_update()
        bm.to_mesh(me)
        bm.free()
        return link(bpy.data.objects.new('poly', me), mat, parent)

    root = bpy.data.objects.new('dr_root', None)
    col.objects.link(root)

    # --- cuerpo
    body = pivot('dr_body', (0, 0.1, 0.62), root)
    ell((0, -0.05, 0.64), (0.5, 0.62, 0.44), RED, body)
    ell((0, 0.35, 0.62), (0.46, 0.5, 0.4), RED, body)
    ell((0, 0.72, 0.6), (0.44, 0.36, 0.38), RED, body)
    for i in range(7):  # placas del vientre
        ell((0, -0.5 + i * 0.2, 0.27 + 0.01 * (i % 2)), (0.3, 0.1, 0.09), BEL, body)
    for i, y in enumerate((-0.55, -0.35, -0.15, 0.05, 0.25, 0.45, 0.65, 0.85, 1.05)):  # franja y púas del lomo
        ell((0, y, 0.98 - 0.02 * abs(y - 0.2)), (0.2, 0.12, 0.06), DRK, body)
        h = 0.2 + 0.1 * math.sin(i * 1.2) ** 2
        beam((0, y, 1.0 - 0.03 * abs(y - 0.2)), (0, y - 0.06, 1.0 + h), 0.07, 0.0, OCH, body, 4)
    for sx in (-1, 1):
        ell((sx * 0.4, -0.25, 0.6), (0.2, 0.3, 0.3), RED, body)   # hombro
        ell((sx * 0.43, 0.7, 0.52), (0.22, 0.3, 0.3), RED, body)  # anca
        ell((sx * 0.46, 0.2, 0.55), (0.06, 0.4, 0.2), DRK, body)  # banda lateral

    # --- cuello y cabeza
    neck = pivot('dr_neck', (0, -0.55, 0.82), body)
    ell((0, -0.7, 0.9), (0.24, 0.27, 0.22), RED, neck)
    ell((0, -0.74, 0.74), (0.14, 0.13, 0.07), BEL, neck)
    ell((0, -0.9, 0.8), (0.13, 0.1, 0.06), BEL, neck)
    head = pivot('dr_head', (0, -0.9, 0.98), neck)
    ell((0, -1.05, 0.98), (0.3, 0.36, 0.26), RED, head)
    ell((0, -1.3, 0.9), (0.2, 0.24, 0.15), RED, head)
    jaw = pivot('dr_jaw', (0, -1.0, 0.8), head)
    ell((0, -1.2, 0.78), (0.18, 0.27, 0.08), DRK, jaw)
    for x, y in ((0.08, -1.42), (-0.08, -1.42), (0.12, -1.3), (-0.12, -1.3)):
        beam((x, y, 0.83), (x, y, 0.92), 0.018, 0.0, HRN, jaw, 4)
    for sx in (-1, 1):
        ell((sx * 0.14, -1.18, 1.09), (0.1, 0.08, 0.05), DRK, head)    # ceja
        ell((sx * 0.15, -1.2, 1.03), (0.05, 0.05, 0.05), GLD, head)    # ojo
        ell((sx * 0.07, -1.5, 0.96), (0.03, 0.03, 0.03), OBS, head)    # nariz
        beam((sx * 0.16, -0.95, 1.18), (sx * 0.34, -0.55, 1.5), 0.075, 0.045, HRN, head)  # cuerno principal curvo
        beam((sx * 0.34, -0.55, 1.5), (sx * 0.55, -0.2, 1.62), 0.045, 0.01, HRN, head)
        beam((sx * 0.2, -0.75, 1.1), (sx * 0.4, -0.4, 1.28), 0.05, 0.01, HRN, head)         # cuerno corto
        beam((sx * 0.27, -1.05, 0.95), (sx * 0.44, -0.9, 0.9), 0.04, 0.0, HRN, head, 4)     # púas de mejilla
        beam((sx * 0.25, -0.95, 0.88), (sx * 0.4, -0.78, 0.8), 0.035, 0.0, HRN, head, 4)
    # fuego de la boca: solo visible durante el ataque
    core = ell((0, -1.55, 0.86), (0.1, 0.1, 0.1), HEART, head)
    cone = beam((0, -1.5, 0.86), (0, -2.05, 0.88), 0.14, 0.02, FIRE, head)
    core.name, cone.name = 'dr_fire_core', 'dr_fire_cone'

    # --- alas: brazo, tres dedos y membrana festoneada
    for sx, nm in ((1, 'dr_wingR'), (-1, 'dr_wingL')):
        wp = pivot(nm, (sx * 0.22, -0.2, 0.98), body)
        sh, wr = (sx * 0.22, -0.2, 0.98), (sx * 0.7, -0.35, 1.4)
        t1, t2, t3 = (sx * 1.35, -0.65, 1.55), (sx * 1.5, -0.05, 1.72), (sx * 1.12, 0.45, 1.5)
        an = (sx * 0.25, 0.5, 0.95)
        mid = lambda a, b, pull: tuple((a[i] + b[i]) / 2 + (wr[i] - (a[i] + b[i]) / 2) * pull for i in range(3))
        poly([sh, wr, t1, mid(t1, t2, 0.25), t2, mid(t2, t3, 0.25), t3, mid(t3, an, 0.2), an], WNG, wp)
        beam(sh, wr, 0.05, 0.035, DRK, wp)
        for t in (t1, t2, t3):
            beam(wr, t, 0.03, 0.01, DRK, wp, 4)
        beam(wr, (wr[0] + sx * 0.04, wr[1] - 0.13, wr[2] + 0.08), 0.035, 0.0, HRN, wp, 4)  # garra del ala

    # --- cola de 3 tramos con púas y punta
    t1 = pivot('dr_tail1', (0, 0.95, 0.52), body)
    beam((0, 0.95, 0.52), (0, 1.45, 0.46), 0.2, 0.14, RED, t1)
    beam((0, 1.2, 0.64), (0, 1.17, 0.84), 0.06, 0.0, OCH, t1, 4)
    ell((0, 1.2, 0.44), (0.14, 0.2, 0.06), BEL, t1)
    t2 = pivot('dr_tail2', (0, 1.45, 0.46), t1)
    beam((0, 1.45, 0.46), (0, 1.95, 0.36), 0.14, 0.09, RED, t2)
    beam((0, 1.7, 0.52), (0, 1.67, 0.68), 0.05, 0.0, OCH, t2, 4)
    t3 = pivot('dr_tail3', (0, 1.95, 0.36), t2)
    beam((0, 1.95, 0.36), (0, 2.4, 0.3), 0.09, 0.04, RED, t3)
    beam((0, 2.2, 0.41), (0, 2.18, 0.54), 0.04, 0.0, OCH, t3, 4)
    beam((0, 2.38, 0.3), (0, 2.9, 0.28), 0.08, 0.0, OCH, t3, 4)
    for sx in (-1, 1):
        beam((0, 2.45, 0.3), (sx * 0.2, 2.65, 0.3), 0.04, 0.0, OCH, t3, 4)

    # --- patas: cuatro pivotes en la cadera con muslo, caña, pie y garras
    for nm, sx, hy, ky, fy in (('dr_legFL', 1, -0.38, -0.45, -0.52), ('dr_legFR', -1, -0.38, -0.45, -0.52),
                               ('dr_legBL', 1, 0.7, 0.62, 0.5), ('dr_legBR', -1, 0.7, 0.62, 0.5)):
        lp = pivot(nm, (sx * 0.36, hy, 0.52), body)
        fx = sx * 0.42
        beam((sx * 0.36, hy, 0.52), (fx, ky, 0.27), 0.16, 0.1, RED, lp)
        beam((fx, ky, 0.27), (fx, fy, 0.04), 0.1, 0.07, DRK, lp)
        ell((fx, fy - 0.05, 0.035), (0.09, 0.14, 0.04), DRK, lp)
        for dx in (-0.05, 0, 0.05):
            beam((fx + dx, fy - 0.15, 0.04), (fx + dx * 1.4, fy - 0.26, 0.01), 0.028, 0.0, HRN, lp, 4)

    # --- altura final = 1.0 m (la mitad del hechicero), apoyado en el suelo
    pose('idle', 0)
    upd()
    zs = [(o.matrix_world @ Vector(c)).z for o in col.objects if o.type == 'MESH' and not o.name.startswith('dr_fire')
          for c in o.bound_box]
    k = 1.0 / (max(zs) - min(zs))
    root.scale = (k, k, k)
    root.location = (0, 0, -min(zs) * k)
    upd()
    print('altura', round(max(zs) - min(zs), 3), 'escala', round(k, 3))


def pose(kind, k):
    O = bpy.data.objects
    for n in PIVOTS:
        O[n].rotation_euler = (0, 0, 0)
        O[n].location = Vector(O[n]['rest'])

    def rot(n, x=0.0, y=0.0, z=0.0):
        O[n].rotation_euler = (x, y, z)

    def mv(n, dx=0.0, dy=0.0, dz=0.0):
        O[n].location = Vector(O[n]['rest']) + Vector((dx, dy, dz))

    wing_up, fire = 0.12, 0.0
    if kind == 'death':
        # Recoil, knees give way, then head and tail settle with a delayed follow-through.
        t = k / 11.0
        fall = min(1.0, max(0.0, (t - 0.18) / 0.55))
        fall = fall * fall * (3 - 2 * fall)
        recoil = math.sin(min(t / 0.3, 1.0) * math.pi) * (1 - fall)
        mv('dr_body', 0, 0.08 * recoil, -0.32 * fall)
        rot('dr_body', -0.12 * recoil + 0.10 * fall, 0, 0.12 * fall)
        rot('dr_neck', -0.3 * recoil + 0.48 * fall)
        rot('dr_head', 0.18 * fall)
        rot('dr_jaw', 0.20 * (1 - t))
        for n in ('dr_legFL', 'dr_legFR', 'dr_legBL', 'dr_legBR'):
            rot(n, -0.65 * fall)
        for j in range(1, 4):
            rot('dr_tail'+str(j), 0, 0, 0.15*math.sin(t*5-j*0.6)*(1-t)+0.12*fall)
        wing_up = 0.12 + 0.35 * recoil - 0.28 * fall
    elif kind == 'walk':
        ph = 2 * math.pi * k / 8
        a = 0.5 * math.sin(ph)
        rot('dr_legFL', a); rot('dr_legBR', a); rot('dr_legFR', -a); rot('dr_legBL', -a)
        mv('dr_body', 0, 0, 0.025 * math.cos(2 * ph))
        rot('dr_body', 0.02 * math.sin(2 * ph), 0, 0.04 * math.sin(ph))
        rot('dr_neck', 0.08 * math.sin(2 * ph + 1))
        rot('dr_tail1', 0, 0, 0.2 * math.sin(ph))
        rot('dr_tail2', 0, 0, 0.28 * math.sin(ph - 0.9))
        rot('dr_tail3', 0, 0, 0.34 * math.sin(ph - 1.8))
        wing_up = 0.15 + 0.15 * math.sin(2 * ph)
    elif kind == 'attack':  # 8 fotogramas: preparar, echar la cabeza atrás, escupir fuego (fotograma 4), recuperar
        neck = [0, -0.15, -0.35, -0.5, 0.35, 0.45, 0.2, 0][k]
        pitch = [0, -0.06, -0.12, -0.16, 0.06, 0.08, 0.03, 0][k]
        lunge = [0, 0.03, 0.06, 0.08, -0.1, -0.12, -0.05, 0][k]
        jawo = [0, 0.15, 0.35, 0.55, 0.6, 0.5, 0.25, 0][k]
        legs = [0, -0.05, -0.1, -0.15, 0.1, 0.12, 0.05, 0][k]
        rot('dr_neck', neck); rot('dr_body', pitch); mv('dr_body', 0, lunge, 0); rot('dr_jaw', jawo)
        rot('dr_legFL', legs); rot('dr_legFR', legs)
        rot('dr_tail1', 0, 0, 0.12 * math.sin(k * 0.9))
        rot('dr_tail2', 0, 0, 0.18 * math.sin(k * 0.9 - 0.8))
        wing_up = [0.12, 0.3, 0.6, 0.8, 0.55, 0.4, 0.25, 0.12][k]
        fire = [0, 0, 0, 0, 0.45, 0.65, 0.35, 0][k]
    rot('dr_wingR', 0, -wing_up, 0)
    rot('dr_wingL', 0, wing_up, 0)
    for n, f in (('dr_fire_core', 0.3), ('dr_fire_cone', 0.7)):
        O[n].hide_render = fire == 0
        O[n].scale = (max(fire * f, 0.01),) * 3


def render(names, res=128, prefix='dragon_', kinds=(('idle', 1), ('walk', 8), ('attack', 8))):
    s = bpy.context.scene
    root, col, cam = bpy.data.objects['dr_root'], bpy.data.collections['DRAGON'], bpy.data.objects['SpriteCam']
    q = cam.matrix_world.to_quaternion()
    fwd = q @ Vector((0, 0, -1)); fwd.z = 0; fwd.normalize()
    right = q @ Vector((1, 0, 0)); right.z = 0; right.normalize()
    toward = -fwd
    r = s.render
    saved = (s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath)
    keep = {o.name for o in col.all_objects}
    hidden = {}
    for o in s.objects:
        if o.type in ('MESH', 'CURVE') and o.name not in keep:
            hidden[o] = o.hide_render
            o.hide_render = True
    s.camera = cam
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
    for o, v in hidden.items():
        o.hide_render = v
    s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath = saved
