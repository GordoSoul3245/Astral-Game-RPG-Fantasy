import bpy, math, os
import numpy as np
from mathutils import Vector

# El viejo gaucho (lámina art/gaucho/referencia_gaucho.png, encargo art/gaucho/PROMPT_CLAUDE.md), con el pipeline del héroe:
# misma cámara ortográfica SpriteCam, mismas luces, materiales cel "Cel •" (rampas de 4 tonos), 128 px, filtro 0, origen en los pies,
# frente hacia -Y (como el rig del héroe: _facing gira en Z). Piezas separadas: sombrero, poncho (franja y fleco), camisa, bombachas,
# botas, funda con cuchilla en la cadera DERECHA del personaje (-X con el frente hacia -Y). Masas simples y legibles a 128 px.
# Pixel art: tras renderizar, un contorno exterior de 1 px (guía docs/ARTE_VIVO.md, idea 11) y ningún espejado entre direcciones.
# Uso: blender -b blender/hechicero_floor.blend -P art/gaucho/build_gaucho.py
ROOT = 'C:/Users/Mateo/Documents/astral/'
OUT = ROOT + 'art/gaucho/'
ns = {}
exec(open(ROOT + 'art/katana/build_katana.py').read(), ns)
mat_ramp = ns['mat_ramp']

def M(name, rgb, src='Cel • obsidian'):  # rampa de 4 tonos alrededor de un color (sombra profunda .. luz)
    r, g, b = rgb
    stops = [(r * 0.30, g * 0.30, b * 0.34), (r * 0.52, g * 0.52, b * 0.56), (r * 0.78, g * 0.78, b * 0.8), (r, g, b)]
    return mat_ramp('Gaucho • ' + name, src, stops)

col = bpy.data.collections.get('GAUCHO')
if col:
    for o in list(col.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.context.scene.collection.children.unlink(col)
    bpy.data.collections.remove(col)
col = bpy.data.collections.new('GAUCHO')
bpy.context.scene.collection.children.link(col)
root = bpy.data.objects.new('GAUCHO_ROOT', None)
col.objects.link(root)
root.scale = (1.12, 1.12, 1.12)  # a la altura del héroe

LEATHER = M('cuero botas', (0.16, 0.10, 0.07))
TROUSER = M('bombachas', (0.33, 0.22, 0.13))
BELT = M('cinto', (0.30, 0.18, 0.09))
SHIRT = M('camisa marfil', (0.86, 0.80, 0.66))
PONCHO = M('poncho bordo', (0.38, 0.05, 0.08))
STRIPE = M('franja carbon', (0.11, 0.09, 0.09))
FRINGE = M('fleco negro', (0.07, 0.06, 0.06))
SKIN = M('piel curtida', (0.70, 0.47, 0.33))
GRAY = M('canas', (0.70, 0.68, 0.64))
HAT = M('sombrero', (0.15, 0.12, 0.11))
BAND = M('cinta sombrero', (0.30, 0.22, 0.15))
WOOD = M('mango madera', (0.52, 0.32, 0.16))
SHEATH = M('funda cuero', (0.24, 0.14, 0.08))


def add(obj, mat):
    obj.data.materials.append(mat)
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    col.objects.link(obj)
    obj.parent = root
    return obj


def sphere(loc, sc, mat, seg=14):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=max(6, seg // 2), radius=1, location=loc)
    o = bpy.context.active_object
    o.scale = sc
    bpy.ops.object.shade_smooth()
    return add(o, mat)


def cyl(loc, r, h, mat, v=16, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=v, radius=r, depth=h, location=loc, rotation=rot)
    return add(bpy.context.active_object, mat)


def cone(loc, r1, r2, h, mat, v=4, rot=(0, 0, 0), sc=(1, 1, 1)):
    bpy.ops.mesh.primitive_cone_add(vertices=v, radius1=r1, radius2=r2, depth=h, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = sc
    return add(o, mat)


R = -1.0  # lado DERECHO del personaje = -X (frente hacia -Y)
# --- botas gastadas, con puntera
for sx in (1, -1):
    cyl((0.17 * sx, 0.0, 0.22), 0.105, 0.44, LEATHER)
    sphere((0.17 * sx, -0.07, 0.07), (0.11, 0.17, 0.075), LEATHER)
    cyl((0.17 * sx, 0.0, 0.43), 0.118, 0.04, LEATHER)           # caña doblada
# --- bombachas holgadas recogidas sobre la bota
for sx in (1, -1):
    sphere((0.17 * sx, 0.0, 0.66), (0.21, 0.2, 0.27), TROUSER)
cyl((0.0, 0.0, 0.86), 0.24, 0.16, TROUSER)
cyl((0.0, 0.0, 0.94), 0.255, 0.06, BELT)
# --- camisa marfil (cuello y puños asoman) y tronco algo encorvado
cyl((0.0, 0.02, 1.15), 0.16, 0.5, SHIRT)
cyl((0.0, 0.0, 1.57), 0.085, 0.06, SHIRT)                     # cuello
# --- poncho largo que cae hasta la rodilla: rombo con puntas delante, detrás y a los lados; franja carbón y fleco negro
PZ0, PZ1, PR0, PR1 = 0.83, 1.58, 0.56, 0.16                    # borde de abajo / arriba y sus radios


def pr(z):  # radio del poncho a una altura
    return PR0 + (z - PZ0) / (PZ1 - PZ0) * (PR1 - PR0)


cone((0, 0.02, (PZ0 + PZ1) / 2), PR0, PR1, PZ1 - PZ0, PONCHO, sc=(1.0, 0.86, 1.0))
cone((0, 0.02, 1.16), pr(1.13) + 0.012, pr(1.19) + 0.012, 0.06, STRIPE, sc=(1.0, 0.86, 1.0))
cone((0, 0.02, PZ0 + 0.025), PR0 + 0.018, PR0 + 0.005, 0.05, FRINGE, sc=(1.0, 0.86, 1.0))
for k in range(28):  # fleco: dientes que cuelgan por todo el borde del rombo
    a = k / 28.0 * math.tau
    d = Vector((math.cos(a), math.sin(a)))
    rr = PR0 / (abs(d.x) + abs(d.y))  # el borde en rombo
    cone((d.x * rr, d.y * rr * 0.86 + 0.02, PZ0 - 0.04), 0.03, 0.0, 0.09, FRINGE, v=4, rot=(math.pi, 0, 0))
# --- brazos: mangas arremangadas y manos que asoman bajo el poncho, a los lados
for sx in (1, -1):
    cyl((0.33 * sx, 0.0, 0.86), 0.06, 0.14, SHIRT)
    cyl((0.33 * sx, 0.0, 0.8), 0.066, 0.04, SHIRT)            # puño
    sphere((0.33 * sx, -0.01, 0.73), (0.055, 0.05, 0.065), SKIN)
# --- cabeza curtida: cara visible (ojos, cejas, nariz), pelo canoso a la nuca, barba tupida que no llega al pecho, bigote
sphere((0.0, 0.0, 1.78), (0.15, 0.15, 0.17), SKIN)
sphere((0.0, -0.145, 1.77), (0.032, 0.04, 0.04), SKIN, seg=8)  # nariz
for sx in (1, -1):
    sphere((0.055 * sx, -0.135, 1.81), (0.018, 0.012, 0.016), FRINGE, seg=6)   # ojos
    sphere((0.06 * sx, -0.135, 1.845), (0.035, 0.012, 0.012), GRAY, seg=6)     # cejas
sphere((0.0, 0.07, 1.82), (0.15, 0.12, 0.13), GRAY)            # pelo (detrás, deja ver la cara)
sphere((0.0, 0.1, 1.7), (0.14, 0.07, 0.09), GRAY)              # nuca
sphere((0.0, -0.09, 1.65), (0.11, 0.08, 0.09), GRAY)           # barba
sphere((0.0, -0.15, 1.735), (0.07, 0.025, 0.02), GRAY, seg=8)  # bigote
# --- sombrero oscuro de ala ancha con cinta
cyl((0.0, 0.0, 1.95), 0.37, 0.025, HAT, v=24)
cone((0.0, 0.0, 2.04), 0.19, 0.16, 0.17, HAT, v=20)
cyl((0.0, 0.0, 1.98), 0.192, 0.035, BAND, v=20)
# --- cuchilla envainada en la cadera derecha (-X), mango de madera visible
sh = cyl((0.33 * R, -0.16, 0.66), 0.045, 0.28, SHEATH, v=8, rot=(0.0, math.radians(14), 0.0))
cyl((0.355 * R, -0.16, 0.84), 0.032, 0.11, WOOD, v=8, rot=(0.0, math.radians(14), 0.0))

# --- render: cámara y luces del héroe, solo el gaucho visible
s = bpy.context.scene
r = s.render
r.resolution_x = r.resolution_y = 128
r.resolution_percentage = 100
r.film_transparent = True
r.filter_size = 0.0
s.camera = bpy.data.objects['SpriteCam']
keep = {o.name for o in col.all_objects}
for o in s.objects:
    if o.type in ('MESH', 'CURVE') and o.name not in keep:
        o.hide_render = True
for n in ('Staff glow', 'Fire bounce'):  # luces propias del bastón del héroe
    if n in bpy.data.objects:
        bpy.data.objects[n].hide_render = True
cam, right, toward = ns['_cam_vecs']()


def outline(path):  # contorno exterior de 1 px: el borde transparente que toca la figura toma su color muy oscurecido
    img = bpy.data.images.load(path)
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    op = a[..., 3] > 0.5
    out = a.copy()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nb = np.roll(np.roll(op, dy, 0), dx, 1)
        src = np.roll(np.roll(a, dy, 0), dx, 1)
        edge = nb & ~op & (out[..., 3] < 0.5)
        out[edge, :3] = src[edge, :3] * 0.3
        out[edge, 3] = 1.0
    out[op, 3] = 1.0  # sin bordes semitransparentes: pixel art limpio
    img.pixels = out.ravel()
    img.filepath_raw = path
    img.save()
    bpy.data.images.remove(img)


for name, dx, dy in ns['DIRS']:
    ns['_facing']((right * dx + toward * dy).normalized(), root)
    bpy.context.view_layer.update()
    r.filepath = OUT + 'gaucho_idle_%s.png' % name
    bpy.ops.render.render(write_still=True)
    outline(r.filepath)
root.rotation_euler[2] = 0
# hoja de contacto: las 8 direcciones x4 en fila (orden del proyecto: E SE S SW W NW N NE)
sheet = np.zeros((128 * 4, 128 * 4 * 8, 4), np.float32)
for k, (name, dx, dy) in enumerate(ns['DIRS']):
    im = bpy.data.images.load(OUT + 'gaucho_idle_%s.png' % name)
    a = np.array(im.pixels[:], dtype=np.float32).reshape(128, 128, 4)
    sheet[:, k * 512:(k + 1) * 512] = a.repeat(4, 0).repeat(4, 1)
    bpy.data.images.remove(im)
img = bpy.data.images.new('hoja', 128 * 4 * 8, 128 * 4, alpha=True)
img.pixels = sheet.ravel()
img.filepath_raw = OUT + 'gaucho_contacto.png'
img.file_format = 'PNG'
img.save()
bpy.ops.wm.save_as_mainfile(filepath=ROOT + 'blender/gaucho.blend', copy=True)
print('GAUCHO_OK')
