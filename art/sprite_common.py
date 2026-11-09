import bpy, bmesh, math
from mathutils import Vector

# Ayudantes compartidos por los scripts de criaturas (art/<criatura>/build_*.py) para los sprites 2.5D del juego.
# Uso: ns={}; exec(open('.../art/sprite_common.py').read(), ns); exec(open('.../build_<criatura>.py').read(), ns)
DIRS = [('E', 1, 0), ('SE', 1, 1), ('S', 0, 1), ('SW', -1, 1), ('W', -1, 0), ('NW', -1, -1), ('N', 0, -1), ('NE', 1, -1)]


def ramp(name, src, stops):
    """Material cel nuevo: copia de un 'Cel • ...' con las 4 paradas de color dadas."""
    MAT = bpy.data.materials
    if name in MAT:
        MAT.remove(MAT[name])
    m = MAT[src].copy()
    m.name = name
    cr = next(n for n in m.node_tree.nodes if n.type == 'VALTORGB')
    for e, c in zip(cr.color_ramp.elements, stops):
        e.color = (*c, 1)
    return m


class Kit:
    """Crea una colección con raíz y pivotes; ell/beam/poly modelan piezas y las cuelgan de un pivote."""

    def __init__(self, col_name, root_name):
        s = bpy.context.scene
        old = bpy.data.collections.get(col_name)
        if old:
            for o in list(old.all_objects):
                bpy.data.objects.remove(o, do_unlink=True)
            s.collection.children.unlink(old)
            bpy.data.collections.remove(old)
        self.col = bpy.data.collections.new(col_name)
        s.collection.children.link(self.col)
        self.root = bpy.data.objects.new(root_name, None)
        self.col.objects.link(self.root)

    def upd(self):
        bpy.context.view_layer.update()

    def attach(self, o, parent):
        self.upd()
        o.parent = parent
        o.matrix_parent_inverse = parent.matrix_world.inverted()

    def link(self, o, mat, parent):
        if mat:
            o.data.materials.append(mat)
        for c in list(o.users_collection):
            c.objects.unlink(o)
        self.col.objects.link(o)
        self.attach(o, parent)
        return o

    def pivot(self, name, loc, parent=None):
        e = bpy.data.objects.new(name, None)
        self.col.objects.link(e)
        e.location = Vector(loc)
        self.attach(e, parent or self.root)
        e['rest'] = tuple(e.location)
        return e

    def ell(self, loc, sc, mat, parent, seg=12, rings=8):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=1, location=loc)
        o = bpy.context.active_object
        o.scale = sc
        return self.link(o, mat, parent)

    def torus(self, loc, major, minor, mat, parent, rot=(0, 0, 0)):
        bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=32, minor_segments=10, location=loc, rotation=rot)
        return self.link(bpy.context.active_object, mat, parent)

    def box(self, loc, size, mat, parent):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
        o = bpy.context.active_object
        o.scale = size
        return self.link(o, mat, parent)

    def beam(self, a, b, ra, rb, mat, parent, n=8):
        a, b = Vector(a), Vector(b)
        d = b - a
        bpy.ops.mesh.primitive_cone_add(vertices=n, radius1=ra, radius2=rb, depth=d.length, location=(a + b) / 2)
        o = bpy.context.active_object
        o.rotation_mode = 'QUATERNION'
        o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
        return self.link(o, mat, parent)

    def poly(self, pts, mat, parent):
        me = bpy.data.meshes.new('poly')
        bm = bmesh.new()
        bm.faces.new([bm.verts.new(Vector(p)) for p in pts])
        bm.normal_update()
        bm.to_mesh(me)
        bm.free()
        return self.link(bpy.data.objects.new('poly', me), mat, parent)

    def normalize(self, height, skip=()):
        """Escala la raíz para que la criatura mida `height` m y apoya sus pies en z=0."""
        self.upd()
        zs = [(o.matrix_world @ Vector(c)).z for o in self.col.objects if o.type == 'MESH' and o.name not in skip
              for c in o.bound_box]
        k = height / (max(zs) - min(zs))
        self.root.scale = (k, k, k)
        self.root.location = (0, 0, -min(zs) * k)
        self.upd()
        return k


def render_sprites(col_name, root_name, pose, out, prefix, names, res, kinds):
    """Renderiza <prefix><DIR>_<tipo>_<NN>.png con la cámara del juego; res/128 agranda el encuadre manteniendo los px por metro."""
    s = bpy.context.scene
    root, col, cam = bpy.data.objects[root_name], bpy.data.collections[col_name], bpy.data.objects['SpriteCam']
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
    cam.data.ortho_scale = ortho * res / 128.0
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
                r.filepath = out + f'{prefix}{name}_{kind}_{k:02d}.png'
                bpy.ops.render.render(write_still=True)
    pose('idle', 0)
    root.rotation_euler[2] = 0
    cam.data.ortho_scale = ortho
    for o, v in hidden.items():
        o.hide_render = v
    s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath = saved


def tile_yaw():
    """Giro (rad) que alinea el eje local X de un objeto con el eje x de las casillas del juego, no con el X de Blender.
    El suelo del juego tiene su propia proyección: esto hace que el borde inferior del objeto quede paralelo al borde del suelo."""
    from bpy_extras.object_utils import world_to_camera_view
    s, cam = bpy.context.scene, bpy.data.objects['SpriteCam']

    def px(p):
        v = world_to_camera_view(s, cam, Vector(p))
        return Vector((v.x * 128, (1 - v.y) * 128))
    o = px((0, 0, 0))
    ex, ey = px((1, 0, 0)) - o, px((0, 1, 0)) - o
    # dirección en pantalla de una casilla en x: (23.83, -16.53) px (data/map.json e1 / tiles)
    want = Vector((23.834, -16.535))
    best = min((abs((ex * math.cos(a) + ey * math.sin(a)).normalized().dot(Vector((-want.y, want.x)).normalized())), a)
               for a in [i * math.pi / 3600 for i in range(3600)])
    return best[1]


def render_fixed(col_name, root_name, pose, out, prefix, yaw, res, kinds):
    """Como render_sprites pero con un giro fijo (puertas, cofres): escribe <prefix><tipo>_<NN>.png."""
    s = bpy.context.scene
    root, col, cam = bpy.data.objects[root_name], bpy.data.collections[col_name], bpy.data.objects['SpriteCam']
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
    cam.data.ortho_scale = ortho * res / 128.0
    r.resolution_x = r.resolution_y = res
    r.resolution_percentage = 100
    r.film_transparent = True
    r.filter_size = 0.0
    root.rotation_euler[2] = yaw
    for kind, n in kinds:
        for k in range(n):
            pose(kind, k)
            r.filepath = out + f'{prefix}{kind}_{k:02d}.png'
            bpy.ops.render.render(write_still=True)
    pose('idle', 0)
    cam.data.ortho_scale = ortho
    for o, v in hidden.items():
        o.hide_render = v
    s.camera, r.resolution_x, r.resolution_y, r.resolution_percentage, r.film_transparent, r.filter_size, r.filepath = saved


def reset(pivots):
    for n in pivots:
        o = bpy.data.objects[n]
        o.rotation_euler = (0, 0, 0)
        o.location = Vector(o['rest'])
        o.scale = (1, 1, 1)
