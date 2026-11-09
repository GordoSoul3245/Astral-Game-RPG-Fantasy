import bpy, bmesh, math
from mathutils import Vector, Matrix

# Katana (hoja oscura con hamon, tsuka naranja, tsuba negra, saya negra con cordón) + tajos del hechicero.
# Uso desde Blender: ns={}; exec(open(RUTA).read(), ns); ns['build_all'](); ns['render_icon'](); ns['render_slash'](['S'])
OUT_K = r'C:/Users/Mateo/Documents/astral/art/katana/'
OUT_H = r'C:/Users/Mateo/Documents/astral/art/hechicero/'
DIRS = [('E', 1, 0), ('SE', 1, 1), ('S', 0, 1), ('SW', -1, 1), ('W', -1, 0), ('NW', -1, -1), ('N', 0, -1), ('NE', 1, -1)]
HIDE_FOR_SLASH = ['Staff shaft', 'Staff ring', 'Staff ember', 'Staff glow', 'Spell heart', 'Fire bounce'] + ['Flame ribbon %d' % i for i in range(9)]

# Poses (grados, ejes locales de cada hueso): brazo derecho (ua = x,z), antebrazo (fa = x),
# columna (sp = inclinación x, giro y), muslos (th = izquierdo, derecho)
SLASH = {
    'light': [  # 6 fotogramas: guardia, armar sobre el hombro, arrancar, corte, seguir, recuperar
        dict(ua=(-40, 15), fa=-60, sp=(5, -10), th=(0, 0)),
        dict(ua=(-140, 35), fa=-80, sp=(-5, -30), th=(5, -5)),
        dict(ua=(-110, 10), fa=-50, sp=(10, -10), th=(-10, 8)),
        dict(ua=(-70, -25), fa=-20, sp=(15, 25), th=(-22, 14)),
        dict(ua=(-40, -60), fa=0, sp=(20, 45), th=(-25, 16)),
        dict(ua=(-40, -10), fa=-40, sp=(5, 15), th=(-8, 5)),
    ],
    'heavy': [  # 8 fotogramas: guardia, subir, tope, mantener, bajar, impacto, final, recuperar
        dict(ua=(-40, 15), fa=-60, sp=(5, -10), th=(0, 0)),
        dict(ua=(-170, 20), fa=-90, sp=(-15, -30), th=(8, -8)),
        dict(ua=(-185, 25), fa=-100, sp=(-20, -35), th=(10, -10)),
        dict(ua=(-185, 25), fa=-100, sp=(-22, -35), th=(10, -10)),
        dict(ua=(-140, 10), fa=-60, sp=(10, -10), th=(-12, 8)),
        dict(ua=(-60, -5), fa=-10, sp=(35, 10), th=(-30, 18)),
        dict(ua=(-35, -20), fa=0, sp=(40, 20), th=(-32, 20)),
        dict(ua=(-40, 0), fa=-40, sp=(10, 0), th=(-8, 5)),
    ],
}


def mat_ramp(name, src, stops):
    M = bpy.data.materials
    if name in M:   # build_all() las borra antes; así la espada del icono y la de la mano comparten material
        return M[name]
    m = M[src].copy()
    m.name = name
    cr = next(n for n in m.node_tree.nodes if n.type == 'VALTORGB')
    for e, c in zip(cr.color_ramp.elements, stops):
        e.color = (*c, 1)
    return m


def ring_mesh(name, rings, tip=None, cap=True):
    """Superficie por anillos de vértices (lista de listas de Vector); opcionalmente cierra con punta y tapa."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vr = [[bm.verts.new(v) for v in ring] for ring in rings]
    n = len(vr[0])
    for a, b in zip(vr, vr[1:]):
        for j in range(n):
            bm.faces.new([a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]])
    if tip is not None:
        t = bm.verts.new(tip)
        for j in range(n):
            bm.faces.new([vr[-1][j], vr[-1][(j + 1) % n], t])
    if cap:
        bm.faces.new(vr[0][::-1])
        if tip is None:
            bm.faces.new(vr[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    return bpy.data.objects.new(name, me)


def ellipse_ring(cx, y, cz, rx, rz, n=10):
    return [Vector((cx + rx * math.cos(2 * math.pi * i / n), y, cz + rz * math.sin(2 * math.pi * i / n))) for i in range(n)]


def make_katana(col, tag, with_saya):
    """Hoja a lo largo de +Y desde y=0 (habaki), mango hacia -Y, curva hacia +Z. Devuelve (raíz espada, raíz saya|None)."""
    STEEL = mat_ramp('Katana • acero', 'Cel • obsidian', [(0.004, 0.005, 0.01), (0.012, 0.014, 0.024), (0.03, 0.035, 0.055), (0.07, 0.08, 0.12)])
    HAMON = mat_ramp('Katana • hamon', 'Cel • obsidian', [(0.12, 0.14, 0.2), (0.3, 0.34, 0.44), (0.55, 0.62, 0.74), (0.85, 0.92, 1.0)])
    MARBLE = mat_ramp('Katana • veta', 'Cel • obsidian', [(0.02, 0.025, 0.04), (0.06, 0.07, 0.1), (0.14, 0.16, 0.22), (0.26, 0.3, 0.4)])
    ITO = mat_ramp('Katana • ito', 'Cel • amber cloak', [(0.12, 0.045, 0.005), (0.25, 0.1, 0.012), (0.42, 0.18, 0.03), (0.58, 0.26, 0.05)])
    GOLD, IVORY, OBS = bpy.data.materials['Cel • antique gold'], bpy.data.materials['Cel • ivory horn'], bpy.data.materials['Cel • obsidian']

    def add(o, mat, parent):
        if mat:
            o.data.materials.append(mat)
        for c in list(o.users_collection):
            c.objects.unlink(o)
        col.objects.link(o)
        o.parent = parent
        return o

    def ell(loc, sc, mat, parent):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=1, location=loc)
        o = bpy.context.active_object
        o.scale = sc
        return add(o, mat, parent)

    def cyl(loc, r, depth, mat, parent, rot=(math.pi / 2, 0, 0)):
        bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=r, depth=depth, location=loc, rotation=rot)
        return add(bpy.context.active_object, mat, parent)

    root = bpy.data.objects.new(f'{tag}_sword', None)
    col.objects.link(root)

    # --- hoja: 5 vértices por sección (filo, hombros, lomo); la punta sube hacia el lomo (sori)
    L, W0, TH, SORI = 0.70, 0.034, 0.0045, 0.024
    N = 16
    zc = lambda t: SORI * t * t
    wd = lambda t: W0 * (1 - 0.28 * t)
    rings = []
    for i in range(N + 1):
        t = i / N
        y, c, w = L * t, zc(t), wd(t)
        rings.append([Vector((0, y, c - w * 0.5)), Vector((TH, y, c - w * 0.1)), Vector((TH * 0.8, y, c + w * 0.5)),
                      Vector((-TH * 0.8, y, c + w * 0.5)), Vector((-TH, y, c - w * 0.1))])
    add(ring_mesh(f'{tag}_blade', rings, tip=Vector((0, L + 0.035, zc(1) + wd(1) * 0.15))), STEEL, root)
    # hamon ondulado sobre el bisel del filo y veta en la cara plana
    for sx in (1, -1):
        for nm, mat, u0, amp, freq, half in (('hamon', HAMON, 0.42, 0.14, 36, 0.09), ('veta', MARBLE, 0.78, 0.1, 22, 0.1)):
            me = bpy.data.meshes.new(f'{tag}_{nm}')
            bm = bmesh.new()
            prev = None
            for i in range(N * 3 + 1):
                t = i / (N * 3)
                if t > 0.97:
                    break
                y, c, w = L * t, zc(t), wd(t)
                u = u0 + amp * math.sin(t * freq)
                pts = []
                for du in (-half, half):
                    uu = min(max(u + du, 0.02), 0.98)
                    if nm == 'hamon':   # filo -> hombro
                        pts.append(bm.verts.new((sx * uu * TH * 1.02, y, c - w * 0.5 + uu * w * 0.4)))
                    else:               # hombro -> lomo
                        pts.append(bm.verts.new((sx * (TH - uu * TH * 0.2) * 1.03, y, c - w * 0.1 + uu * w * 0.6)))
                if prev:
                    bm.faces.new([prev[0], prev[1], pts[1], pts[0]])
                prev = pts
            bm.to_mesh(me)
            bm.free()
            add(bpy.data.objects.new(f'{tag}_{nm}{sx}', me), mat, root)

    # --- habaki, tsuba, mango, remates
    ell((0, 0.016, 0), (0.0095, 0.017, 0.02), GOLD, root)
    cyl((0, -0.004, 0), 0.047, 0.006, OBS, root)
    cyl((0, -0.0075, 0), 0.050, 0.003, GOLD, root)
    for a in range(0, 360, 90):
        r = math.radians(a)
        ell((0.033 * math.cos(r), -0.0045, 0.033 * math.sin(r)), (0.006, 0.004, 0.006), GOLD, root)
    handle = []
    for i in range(13):
        t = i / 12
        y = -0.02 - 0.28 * t
        bulge = 1 + 0.12 * math.sin(math.pi * t)
        handle.append(ellipse_ring(0, y, 0, 0.0155 * bulge, 0.0125 * bulge))
    add(ring_mesh(f'{tag}_tsuka', handle), ITO, root)
    for k in range(9):  # rombos de samegawa entre el trenzado
        y = -0.045 - 0.028 * k
        for sx in (1, -1):
            ell((sx * 0.0168, y, 0.0), (0.0035, 0.011, 0.0105), IVORY, root)
            ell((sx * 0.0165, y - 0.014, 0.0), (0.0025, 0.006, 0.006), IVORY, root)
    cyl((0, -0.022, 0), 0.0185, 0.012, GOLD, root)
    ell((0, -0.305, 0), (0.0165, 0.013, 0.0135), GOLD, root)

    saya = None
    if with_saya:
        saya = bpy.data.objects.new(f'{tag}_saya', None)
        col.objects.link(saya)
        sr = []
        for i in range(N + 1):
            t = i / N
            sr.append(ellipse_ring(0, 0.01 + 0.74 * t, zc(t), 0.0155 * (1 - 0.18 * t), 0.024 * (1 - 0.3 * t), 12))
        add(ring_mesh(f'{tag}_sayabody', sr), OBS, saya)
        ell((0, 0.01, 0), (0.019, 0.01, 0.028), GOLD, saya)                   # koiguchi
        ell((0, 0.755, zc(1.0)), (0.011, 0.02, 0.016), GOLD, saya)            # kojiri
        for yy in (0.2, 0.45):  # franjas doradas finas
            ell((0, yy, zc(yy / 0.74)), (0.0165, 0.004, 0.0255), GOLD, saya)
        cord = bpy.data.materials['Katana • ito']
        bpy.ops.mesh.primitive_torus_add(major_radius=0.026, minor_radius=0.004, location=(0, 0.13, zc(0.13 / 0.74)), rotation=(math.pi / 2, 0, 0))
        add(bpy.context.active_object, cord, saya)
        ell((0, 0.13, zc(0.13 / 0.74) + 0.03), (0.012, 0.018, 0.012), cord, saya)   # kurikata
        for dx, dz in ((0.03, 0.05), (-0.01, 0.075), (0.02, 0.095)):                 # lazo del cordón
            ell((dx, 0.13, zc(0.13 / 0.74) + dz), (0.008, 0.012, 0.008), cord, saya)
    return root, saya


def build_all():
    s = bpy.context.scene
    for n in ('KATANA_ICON', 'KATANA_HAND'):
        c = bpy.data.collections.get(n)
        if c:
            for o in list(c.all_objects):
                bpy.data.objects.remove(o, do_unlink=True)
            s.collection.children.unlink(c)
            bpy.data.collections.remove(c)
    for m in [m for m in bpy.data.materials if m.name.startswith('Katana •')]:
        bpy.data.materials.remove(m)
    ci = bpy.data.collections.new('KATANA_ICON'); s.collection.children.link(ci)
    ch = bpy.data.collections.new('KATANA_HAND'); s.collection.children.link(ch)
    # --- icono: espada y saya en paralelo, diagonal, vista frontal
    sword, saya = make_katana(ci, 'ic', True)
    for o, loc in ((sword, (0.30, 0, 0.30)), (saya, (0.44, 0.02, 0.06))):
        o.rotation_mode = 'XZY'   # primero girar la hoja hacia -X, luego inclinar la punta hacia abajo
        o.rotation_euler = (0, math.radians(-40), math.radians(90))
        o.location = loc
    cam = bpy.data.objects.get('IconCam')
    if not cam:
        cd = bpy.data.cameras.new('IconCam'); cd.type = 'ORTHO'
        cam = bpy.data.objects.new('IconCam', cd); s.collection.objects.link(cam)
    cam.data.ortho_scale = 1.25
    cam.location = (0.0, -6, 0.05)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    # --- espada en mano: hijo del hueso hand.R
    hand, _ = make_katana(ch, 'hd', False)
    rig = bpy.data.objects['HECHICERO_RIG']
    hand.parent = rig
    hand.parent_type = 'BONE'
    hand.parent_bone = 'hand.R'
    hand.matrix_parent_inverse = Matrix.Identity(4)
    hand.location = (0, 0.13, 0)   # el centro del mango (≈ y=-0.13 de la espada) queda en la mano
    hand.rotation_euler = (math.radians(-20), 0, 0)
    hand.scale = (2.4, 1.35, 2.4)   # exagerada: a 46 px/m una katana real mide ~1 px de ancho y no se lee
    bpy.context.view_layer.update()
    print('ok')


def _prep(keep_cols, hide_names=()):
    s = bpy.context.scene
    rig = bpy.data.objects['HECHICERO_RIG']
    keep = {o.name for c in keep_cols for o in c.all_objects} | {o.name for o in rig.children}
    hidden = {}
    for o in s.objects:
        if (o.type in ('MESH', 'CURVE') and o.name not in keep) or o.name in hide_names:
            hidden[o] = o.hide_render
            o.hide_render = True
    return hidden


def _pose(rig, p):
    B = rig.pose.bones
    for pb in B:
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    r = math.radians
    B['upper_arm.R'].rotation_euler = (r(p['ua'][0]), 0, r(p['ua'][1]))
    B['forearm.R'].rotation_euler = (r(p['fa']), 0, 0)
    B['hand.R'].rotation_euler = (r(-15), 0, 0)
    B['spine'].rotation_euler = (r(p['sp'][0]), r(p['sp'][1]), 0)
    B['upper_arm.L'].rotation_euler = (r(-35), 0, r(-8))
    B['forearm.L'].rotation_euler = (r(-70), 0, 0)
    B['thigh.L'].rotation_euler = (r(p['th'][0]), 0, 0)
    B['thigh.R'].rotation_euler = (r(p['th'][1]), 0, 0)
    bpy.context.view_layer.update()


def _facing(f, rig):
    rig.rotation_euler[2] = math.atan2(f.y, f.x) + math.pi / 2


def _cam_vecs():
    cam = bpy.data.objects['SpriteCam']
    q = cam.matrix_world.to_quaternion()
    fwd = q @ Vector((0, 0, -1)); fwd.z = 0; fwd.normalize()
    right = q @ Vector((1, 0, 0)); right.z = 0; right.normalize()
    return cam, right, -fwd


def render_icon(res=128, name='katana_icon.png'):
    s = bpy.context.scene
    r = s.render
    saved = (s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath)
    rig = bpy.data.objects['HECHICERO_RIG']
    hidden = _prep([bpy.data.collections['KATANA_ICON']])
    for o in rig.children:   # solo la espada: oculta también al hechicero
        if o not in hidden:
            hidden[o] = o.hide_render
            o.hide_render = True
    s.camera = bpy.data.objects['IconCam']
    r.resolution_x = r.resolution_y = res
    r.resolution_percentage = 100
    r.film_transparent = True
    r.filter_size = 0.0
    r.filepath = OUT_K + name
    bpy.ops.render.render(write_still=True)
    for o, v in hidden.items():
        o.hide_render = v
    s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath = saved


def render_slash(names, res=128, prefix='', kinds=('light', 'heavy'), fire=False):
    s = bpy.context.scene
    r = s.render
    rig = bpy.data.objects['HECHICERO_RIG']
    cam, right, toward = _cam_vecs()
    saved = (s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath)
    old_action = rig.animation_data.action
    keep = [bpy.data.collections['KATANA_HAND']] + ([bpy.data.collections['KATANA_FLAME']] if fire else [])
    hidden = _prep(keep, HIDE_FOR_SLASH)
    rig.animation_data.action = None
    s.camera = cam
    r.resolution_x = r.resolution_y = res
    r.resolution_percentage = 100
    r.film_transparent = True
    r.filter_size = 0.0
    for name, dx, dy in DIRS:
        if name not in names:
            continue
        _facing((right * dx + toward * dy).normalized(), rig)
        for kind in kinds:
            for k, p in enumerate(SLASH[kind]):
                _pose(rig, p)
                r.filepath = OUT_H + f'{prefix}slash_{kind}_{name}_{k:02d}.png'
                bpy.ops.render.render(write_still=True)
    for pb in rig.pose.bones:
        pb.rotation_euler = (0, 0, 0)
    rig.rotation_euler[2] = 0
    rig.animation_data.action = old_action
    for o, v in hidden.items():
        o.hide_render = v
    s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath = saved


def render_cast(names, res=128, prefix=''):
    s = bpy.context.scene
    r = s.render
    rig = bpy.data.objects['HECHICERO_RIG']
    cam, right, toward = _cam_vecs()
    saved = (s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath, s.frame_current)
    old_action = rig.animation_data.action
    hidden = _prep([])
    rig.animation_data.action = bpy.data.actions['Cast']
    s.camera = cam
    r.resolution_x = r.resolution_y = res
    r.resolution_percentage = 100
    r.film_transparent = True
    r.filter_size = 0.0
    for name, dx, dy in DIRS:
        if name not in names:
            continue
        _facing((right * dx + toward * dy).normalized(), rig)
        for k, f in enumerate([1, 7, 13, 19, 25, 31, 37, 43]):
            s.frame_set(f)
            r.filepath = OUT_H + f'{prefix}cast_{name}_{k:02d}.png'
            bpy.ops.render.render(write_still=True)
    rig.rotation_euler[2] = 0
    rig.animation_data.action = old_action
    for o, v in hidden.items():
        o.hide_render = v
    s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath, fc = saved
    s.frame_set(fc)


# Dash: 6 fotogramas (agacharse, impulso, estirado, zancada contraria, caída, recuperar)
# sp = inclinación del torso, th = muslos (izq, der), sh = espinillas (izq, der), ua = brazos hacia atrás, cape = capa
DASH = [
    dict(sp=15, th=(-20, -20), sh=(30, 30), ua=10, cape=5),
    dict(sp=35, th=(-50, 35), sh=(15, 70), ua=45, cape=20),
    dict(sp=45, th=(-65, 50), sh=(10, 85), ua=60, cape=35),
    dict(sp=45, th=(40, -60), sh=(80, 10), ua=60, cape=35),
    dict(sp=28, th=(-30, 10), sh=(40, 30), ua=30, cape=15),
    dict(sp=8, th=(-10, -5), sh=(10, 10), ua=5, cape=3),
]


def render_dash(names, res=128, prefix=''):
    s = bpy.context.scene
    r = s.render
    rig = bpy.data.objects['HECHICERO_RIG']
    cam, right, toward = _cam_vecs()
    saved = (s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath)
    old_action = rig.animation_data.action
    hidden = _prep([])
    rig.animation_data.action = None
    s.camera = cam
    r.resolution_x = r.resolution_y = res
    r.resolution_percentage = 100
    r.film_transparent = True
    r.filter_size = 0.0
    d = math.radians
    B = rig.pose.bones
    for name, dx, dy in DIRS:
        if name not in names:
            continue
        _facing((right * dx + toward * dy).normalized(), rig)
        for k, p in enumerate(DASH):
            for pb in B:
                pb.rotation_mode = 'XYZ'
                pb.rotation_euler = (0, 0, 0)
                pb.location = (0, 0, 0)
            B['spine'].rotation_euler = (d(p['sp']), 0, 0)
            B['thigh.L'].rotation_euler = (d(p['th'][0]), 0, 0)
            B['thigh.R'].rotation_euler = (d(p['th'][1]), 0, 0)
            B['shin.L'].rotation_euler = (d(p['sh'][0]), 0, 0)
            B['shin.R'].rotation_euler = (d(p['sh'][1]), 0, 0)
            B['upper_arm.L'].rotation_euler = (d(p['ua']), 0, d(8))
            B['upper_arm.R'].rotation_euler = (d(p['ua']), 0, d(-8))
            B['forearm.L'].rotation_euler = (d(-25), 0, 0)
            B['forearm.R'].rotation_euler = (d(-25), 0, 0)
            B['cape'].rotation_euler = (d(p['cape']), 0, 0)
            bpy.context.view_layer.update()
            r.filepath = OUT_H + f'{prefix}dash_{name}_{k:02d}.png'
            bpy.ops.render.render(write_still=True)
    for pb in B:
        pb.rotation_euler = (0, 0, 0)
    rig.rotation_euler[2] = 0
    rig.animation_data.action = old_action
    for o, v in hidden.items():
        o.hide_render = v
    s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath = saved


def add_flames():
    """Llamas a lo largo de la hoja de la katana en mano (colección KATANA_FLAME, solo se renderiza con fire=True)."""
    s = bpy.context.scene
    old = bpy.data.collections.get('KATANA_FLAME')
    if old:
        for o in list(old.all_objects):
            bpy.data.objects.remove(o, do_unlink=True)
        s.collection.children.unlink(old)
        bpy.data.collections.remove(old)
    col = bpy.data.collections.new('KATANA_FLAME')
    s.collection.children.link(col)
    root = bpy.data.objects['hd_sword']
    FIRE, HEART = bpy.data.materials['Spell • molten orange'], bpy.data.materials['Spell • warm heart']

    def flame(loc, rot, r, h, mat):
        bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=r, radius2=0.0, depth=h, location=loc, rotation=rot)
        o = bpy.context.active_object
        o.data.materials.append(mat)
        for c in list(o.users_collection):
            c.objects.unlink(o)
        col.objects.link(o)
        o.parent = root
        return o

    for i in range(10):
        y = 0.05 + 0.07 * i
        zc = 0.024 * (y / 0.7) ** 2
        h = 0.07 + 0.035 * (i % 3)
        flame((0, y, zc + 0.017 + h / 2), (0, 0, 0), 0.016, h, FIRE)                       # hacia el lomo
        flame((0, y + 0.01, zc - 0.017 - 0.025), (math.pi, 0, 0), 0.012, 0.05, FIRE)        # hacia el filo
    flame((0, 0.74 + 0.05, 0.03), (-math.pi / 2, 0, 0), 0.02, 0.1, FIRE)                   # punta
    flame((0, 0.36, 0.03), (0, 0, 0), 0.007, 0.07, HEART)                                  # núcleo claro
    bpy.context.view_layer.update()


# Mega dash: estocada con la katana hacia delante (6 fotogramas)
MEGA = [
    dict(sp=10, th=(-15, 10), sh=(20, 30), uar=(-20, 10), far=-100, ual=10, cape=5),
    dict(sp=25, th=(-40, 25), sh=(15, 50), uar=(-55, 0), far=-50, ual=25, cape=15),
    dict(sp=40, th=(-55, 45), sh=(10, 80), uar=(-85, 0), far=-5, ual=45, cape=35),
    dict(sp=42, th=(45, -55), sh=(80, 10), uar=(-85, 0), far=-5, ual=45, cape=35),
    dict(sp=35, th=(-45, 35), sh=(20, 60), uar=(-80, -5), far=-8, ual=35, cape=25),
    dict(sp=12, th=(-15, 5), sh=(15, 15), uar=(-45, 0), far=-45, ual=10, cape=5),
]


def render_megadash(names, res=128, prefix=''):
    s = bpy.context.scene
    r = s.render
    rig = bpy.data.objects['HECHICERO_RIG']
    cam, right, toward = _cam_vecs()
    saved = (s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath)
    old_action = rig.animation_data.action
    hidden = _prep([bpy.data.collections['KATANA_HAND'], bpy.data.collections['KATANA_FLAME']], HIDE_FOR_SLASH)
    rig.animation_data.action = None
    s.camera = cam
    r.resolution_x = r.resolution_y = res
    r.resolution_percentage = 100
    r.film_transparent = True
    r.filter_size = 0.0
    d = math.radians
    B = rig.pose.bones
    for name, dx, dy in DIRS:
        if name not in names:
            continue
        _facing((right * dx + toward * dy).normalized(), rig)
        for k, p in enumerate(MEGA):
            for pb in B:
                pb.rotation_mode = 'XYZ'
                pb.rotation_euler = (0, 0, 0)
                pb.location = (0, 0, 0)
            B['spine'].rotation_euler = (d(p['sp']), 0, 0)
            B['thigh.L'].rotation_euler = (d(p['th'][0]), 0, 0)
            B['thigh.R'].rotation_euler = (d(p['th'][1]), 0, 0)
            B['shin.L'].rotation_euler = (d(p['sh'][0]), 0, 0)
            B['shin.R'].rotation_euler = (d(p['sh'][1]), 0, 0)
            B['upper_arm.R'].rotation_euler = (d(p['uar'][0]), 0, d(p['uar'][1]))
            B['forearm.R'].rotation_euler = (d(p['far']), 0, 0)
            B['hand.R'].rotation_euler = (d(-15), 0, 0)
            B['upper_arm.L'].rotation_euler = (d(p['ual']), 0, d(8))
            B['forearm.L'].rotation_euler = (d(-25), 0, 0)
            B['cape'].rotation_euler = (d(p['cape']), 0, 0)
            bpy.context.view_layer.update()
            r.filepath = OUT_H + f'{prefix}megadash_{name}_{k:02d}.png'
            bpy.ops.render.render(write_still=True)
    for pb in B:
        pb.rotation_euler = (0, 0, 0)
    rig.rotation_euler[2] = 0
    rig.animation_data.action = old_action
    for o, v in hidden.items():
        o.hide_render = v
    s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath = saved
