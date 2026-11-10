# Vida ambiental: conejo, zorro y civil low-poly cel, renderizados a 8 direcciones como los monstruos.
# Uso: blender --background blender/hechicero_floor.blend --python art/fauna/build_fauna.py [-- S SE ...]
# No guarda el .blend. Carga art/sprite_common.py. Adelante del modelo = -Y.
import bpy, math
from mathutils import Vector

ROOT = r'C:/Users/Mateo/Documents/astral/art/'
exec(open(ROOT + 'sprite_common.py', encoding='utf-8').read())
OUT = ROOT + 'fauna/'
RES = 128
ALL = [d[0] for d in DIRS]


def mats(name, stops):  # algo más oscuro: la rampa cel aclara mucho las caras iluminadas
    return ramp('Fauna • ' + name, 'Cel • crimson', [tuple(c * 0.8 for c in s) for s in stops])


class LKit(Kit):
    """Como Kit, pero las coordenadas de pivotes y piezas son locales a su pivote padre."""

    def w(self, parent, p):
        self.upd()
        return tuple((parent or self.root).matrix_world @ Vector(p))

    def pivot(self, name, loc, parent=None):
        return super().pivot(name, self.w(parent, loc), parent)

    def ell(self, loc, sc, mat, parent, seg=12, rings=8):
        return super().ell(self.w(parent, loc), sc, mat, parent, seg, rings)

    def torus(self, loc, major, minor, mat, parent, rot=(0, 0, 0)):
        return super().torus(self.w(parent, loc), major, minor, mat, parent, rot)

    def beam(self, a, b, ra, rb, mat, parent, n=8):
        return super().beam(self.w(parent, a), self.w(parent, b), ra, rb, mat, parent, n)


def rot(name, x=0.0, y=0.0, z=0.0):
    bpy.data.objects[name].rotation_euler = (x, y, z)


def move(name, d):
    o = bpy.data.objects[name]
    o.location = Vector(o['rest']) + Vector(d)


# ---------------- conejo
RB = ['rb_body', 'rb_head', 'rb_ears']


def build_rabbit():
    kit = LKit('RABBIT', 'rb_root')
    FUR = mats('rabbit', [(0.16, 0.1, 0.05), (0.33, 0.22, 0.12), (0.55, 0.4, 0.24), (0.72, 0.58, 0.4)])
    PALE = mats('rabbit pale', [(0.5, 0.46, 0.4), (0.75, 0.7, 0.62), (0.9, 0.87, 0.8), (1, 0.98, 0.94)])
    DRK = bpy.data.materials['Cel • obsidian']
    body = kit.pivot('rb_body', (0, 0, 0))
    kit.ell((0, 0.05, 0.22), (0.17, 0.24, 0.17), FUR, body, 12, 8)         # cuerpo
    kit.ell((0, 0.28, 0.24), (0.07, 0.06, 0.07), PALE, body)               # cola
    for sx in (-1, 1):
        kit.ell((sx * 0.1, 0.12, 0.06), (0.06, 0.13, 0.05), FUR, body)    # patas traseras
        kit.ell((sx * 0.07, -0.15, 0.05), (0.035, 0.05, 0.05), FUR, body) # manos
    head = kit.pivot('rb_head', (0, -0.16, 0.32), body)
    kit.ell((0, -0.12, 0.06), (0.1, 0.12, 0.1), FUR, head)
    kit.ell((0, -0.23, 0.03), (0.03, 0.02, 0.02), PALE, head)              # hocico
    for sx in (-1, 1):
        kit.ell((sx * 0.07, -0.17, 0.09), (0.02, 0.02, 0.025), DRK, head)  # ojos
    ears = kit.pivot('rb_ears', (0, -0.08, 0.13), head)
    for sx in (-1, 1):
        kit.ell((sx * 0.045, 0, 0.16), (0.04, 0.025, 0.17), FUR, ears)
        kit.ell((sx * 0.045, -0.02, 0.16), (0.024, 0.01, 0.13), PALE, ears)
    pose_rabbit('idle', 0)
    kit.normalize(0.6)


def pose_rabbit(kind, k):
    reset(RB)
    bpy.data.objects['rb_body'].scale = (1, 1, 1)
    if kind == 'idle':        # pastando: cabeza baja, orejas tumbadas
        rot('rb_head', x=-0.5)
        rot('rb_ears', x=0.6)
    elif kind == 'watch':     # alerta: erguido, orejas arriba
        rot('rb_body', x=0.25)
        rot('rb_head', x=-0.15)
    elif kind == 'walk':      # un salto por ciclo
        h = [0, 0.04, 0.12, 0.18, 0.16, 0.09, 0.02, 0][k]
        s = [0.9, 1.0, 1.12, 1.15, 1.1, 1.0, 0.92, 0.88][k]
        move('rb_body', (0, 0, h))
        bpy.data.objects['rb_body'].scale = (1, s, 1 / s)
        rot('rb_ears', x=0.35 * (s - 0.9))


# ---------------- zorro
FX = ['fo_body', 'fo_head', 'fo_tail', 'fo_leg0', 'fo_leg1', 'fo_leg2', 'fo_leg3']


def build_fox():
    kit = LKit('FOX', 'fo_root')
    FUR = mats('fox', [(0.3, 0.08, 0.02), (0.55, 0.2, 0.05), (0.8, 0.38, 0.12), (0.95, 0.58, 0.26)])
    PALE = mats('fox pale', [(0.55, 0.5, 0.45), (0.8, 0.76, 0.7), (0.93, 0.9, 0.85), (1, 1, 0.97)])
    SOCK = mats('fox sock', [(0.05, 0.03, 0.02), (0.12, 0.07, 0.04), (0.22, 0.13, 0.07), (0.32, 0.2, 0.1)])
    DRK = bpy.data.materials['Cel • obsidian']
    body = kit.pivot('fo_body', (0, 0, 0.36))
    kit.ell((0, 0, 0), (0.15, 0.36, 0.15), FUR, body, 12, 8)               # tronco
    kit.ell((0, -0.15, -0.06), (0.1, 0.18, 0.08), PALE, body)              # pecho
    for i, (sx, y) in enumerate([(-1, -0.24), (1, -0.24), (-1, 0.24), (1, 0.24)]):
        leg = kit.pivot(f'fo_leg{i}', (sx * 0.08, y, -0.05), body)
        kit.beam((0, 0, 0), (0, 0, -0.26), 0.045, 0.03, FUR, leg)
        kit.ell((0, -0.02, -0.29), (0.035, 0.05, 0.03), SOCK, leg)
    head = kit.pivot('fo_head', (0, -0.36, 0.1), body)
    kit.ell((0, -0.06, 0.04), (0.12, 0.12, 0.1), FUR, head)
    kit.beam((0, -0.12, 0.02), (0, -0.28, -0.01), 0.06, 0.02, FUR, head)  # hocico
    kit.ell((0, -0.29, -0.01), (0.025, 0.02, 0.02), DRK, head)             # nariz
    kit.ell((0, -0.14, -0.03), (0.08, 0.08, 0.04), PALE, head)             # carrillos
    for sx in (-1, 1):
        kit.beam((sx * 0.06, -0.02, 0.1), (sx * 0.08, 0.0, 0.25), 0.05, 0.005, FUR, head)  # orejas
        kit.ell((sx * 0.06, -0.15, 0.08), (0.02, 0.015, 0.02), DRK, head)  # ojos
    tail = kit.pivot('fo_tail', (0, 0.34, 0.04), body)
    kit.ell((0, 0.2, -0.04), (0.08, 0.22, 0.08), FUR, tail)
    kit.ell((0, 0.4, -0.06), (0.06, 0.07, 0.06), PALE, tail)
    pose_fox('idle', 0)
    kit.normalize(0.7)


def pose_fox(kind, k):
    reset(FX)
    rot('fo_tail', x=-0.35)
    if kind == 'walk':        # trote: diagonales en fase
        a = math.sin(k / 8 * math.tau) * 0.6
        for i, sgn in enumerate([1, -1, -1, 1]):
            rot(f'fo_leg{i}', x=a * sgn)
        move('fo_body', (0, 0, abs(math.sin(k / 8 * math.tau)) * 0.04))
        rot('fo_tail', x=-0.2 + 0.15 * math.sin(k / 8 * math.tau))
    elif kind == 'rest':      # tumbado, cola enroscada
        move('fo_body', (0, 0, -0.24))
        for i in range(4):
            rot(f'fo_leg{i}', x=-1.4 if i < 2 else 1.4)
        rot('fo_head', x=0.25)
        rot('fo_tail', x=0.1, z=1.2)
    elif kind == 'warn':      # agazapado, cabeza baja, cola tiesa
        move('fo_body', (0, 0, -0.08))
        rot('fo_body', x=0.12)
        rot('fo_head', x=0.3)
        rot('fo_tail', x=0.25)


# ---------------- civil
VI = ['vi_body', 'vi_head', 'vi_legL', 'vi_legR', 'vi_armL', 'vi_armR']


def build_villager():
    kit = LKit('VILLAGER', 'vi_root')
    TUNIC = mats('tunic', [(0.1, 0.16, 0.08), (0.22, 0.32, 0.17), (0.38, 0.5, 0.3), (0.52, 0.64, 0.42)])
    SKIN = mats('skin', [(0.4, 0.24, 0.16), (0.65, 0.45, 0.32), (0.85, 0.66, 0.5), (0.95, 0.8, 0.66)])
    PANTS = mats('pants', [(0.08, 0.06, 0.04), (0.18, 0.14, 0.1), (0.3, 0.24, 0.17), (0.4, 0.33, 0.24)])
    STRAW = mats('straw', [(0.35, 0.26, 0.1), (0.6, 0.48, 0.22), (0.8, 0.68, 0.36), (0.93, 0.84, 0.55)])
    BELT = bpy.data.materials['Cel • dark wood']
    DRK = bpy.data.materials['Cel • obsidian']
    body = kit.pivot('vi_body', (0, 0, 0.9))
    kit.beam((0, 0, -0.1), (0, 0, 0.5), 0.2, 0.16, TUNIC, body)           # torso
    kit.beam((0, 0, -0.32), (0, 0, -0.08), 0.24, 0.2, TUNIC, body)        # falda de la túnica
    kit.torus((0, 0, -0.06), 0.2, 0.03, BELT, body)
    for nm, sx in (('vi_legL', -1), ('vi_legR', 1)):
        leg = kit.pivot(nm, (sx * 0.09, 0, -0.1), body)
        kit.beam((0, 0, 0), (0, 0, -0.74), 0.07, 0.055, PANTS, leg)
        kit.ell((0, -0.05, -0.78), (0.06, 0.1, 0.04), BELT, leg)          # botas
    for nm, sx in (('vi_armL', -1), ('vi_armR', 1)):
        arm = kit.pivot(nm, (sx * 0.2, 0, 0.44), body)
        kit.beam((0, 0, 0), (sx * 0.04, 0, -0.52), 0.055, 0.045, TUNIC, arm)
        kit.ell((sx * 0.045, 0, -0.56), (0.045, 0.045, 0.05), SKIN, arm)
    head = kit.pivot('vi_head', (0, 0, 0.6), body)
    kit.ell((0, 0, 0.12), (0.13, 0.13, 0.15), SKIN, head)
    for sx in (-1, 1):
        kit.ell((sx * 0.05, -0.12, 0.14), (0.018, 0.012, 0.02), DRK, head)
    kit.beam((0, 0, 0.2), (0, 0, 0.42), 0.3, 0.02, STRAW, head, 12)       # sombrero de paja
    pose_villager('idle', 0)
    kit.normalize(1.65)


def pose_villager(kind, k):
    reset(VI)
    if kind == 'walk':
        a = math.sin(k / 8 * math.tau) * 0.5
        rot('vi_legL', x=a)
        rot('vi_legR', x=-a)
        rot('vi_armL', x=-a * 0.8)
        rot('vi_armR', x=a * 0.8)
        move('vi_body', (0, 0, abs(math.cos(k / 8 * math.tau)) * 0.03))
    elif kind == 'hide':      # agachado, cubriéndose la cabeza
        move('vi_body', (0, 0, -0.35))
        rot('vi_body', x=0.35)
        rot('vi_legL', x=-1.3)
        rot('vi_legR', x=-1.3)
        rot('vi_armL', x=-2.4)
        rot('vi_armR', x=-2.4)
    elif kind == 'flee':      # corre con los brazos arriba
        a = math.sin(k / 8 * math.tau) * 0.8
        rot('vi_legL', x=a)
        rot('vi_legR', x=-a)
        rot('vi_armL', x=-2.6 + 0.2 * a)
        rot('vi_armR', x=-2.6 - 0.2 * a)
        rot('vi_body', x=0.15)


build_rabbit()
build_fox()
build_villager()
import sys
only = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
dirs = only or ALL
render_sprites('RABBIT', 'rb_root', pose_rabbit, OUT, 'rabbit_', dirs, RES, (('idle', 1), ('watch', 1), ('walk', 8)))
render_sprites('FOX', 'fo_root', pose_fox, OUT, 'fox_', dirs, RES, (('idle', 1), ('rest', 1), ('warn', 1), ('walk', 8)))
render_sprites('VILLAGER', 'vi_root', pose_villager, OUT, 'villager_', dirs, RES, (('idle', 1), ('hide', 1), ('walk', 8), ('flee', 8)))
print('FAUNA OK')
