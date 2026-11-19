"""Seis monstruos nuevos (2 normales, 2 semijefes, 2 jefes) modelados por piezas y renderizados como sprites pixel art.
Blender --background blender/hechicero_floor.blend --python art/monstruos/build_monstruos.py -- [preview|all] [nombres...]
No guarda el .blend. Salida: art/monstruos/<nombre>/<nombre>_<DIR>_<idle|walk|attack|hurt>_<NN>.png
Pixel art: se renderiza a la mitad de resolución (mismo encuadre), se posteriza, se le pone contorno oscuro de 1 px
y se vuelve a agrandar ×2 por vecino más cercano, así todos los monstruos comparten el mismo tamaño de píxel."""
import bpy, math, os, sys
import numpy as np
from mathutils import Vector

ROOT = r'C:/Users/Mateo/Documents/astral/art/'
exec(open(ROOT + 'sprite_common.py', encoding='utf-8').read())

PIX = 2            # tamaño del píxel de arte en píxeles del sprite
LEVELS = 7         # niveles por canal al posterizar
OUTLINE = (0.05, 0.035, 0.06)


def mats():
    base = 'Cel • midnight indigo'

    def r(name, c0, c3):  # rampa de 4 tonos entre una sombra y una luz
        stops = [tuple(c0[i] + (c3[i] - c0[i]) * t for i in range(3)) for t in (0.0, 0.33, 0.66, 1.0)]
        return ramp('Mon • ' + name, base, stops)
    return {
        'ember': r('ember', (0.08, 0.01, 0.0), (0.75, 0.22, 0.04)),
        'glow': r('glow', (0.6, 0.18, 0.0), (1.0, 0.85, 0.3)),
        'shell': r('shell', (0.02, 0.01, 0.01), (0.2, 0.06, 0.04)),
        'stem': r('stem', (0.15, 0.12, 0.08), (0.75, 0.68, 0.52)),
        'cap': r('cap', (0.1, 0.02, 0.12), (0.55, 0.18, 0.6)),
        'spot': r('spot', (0.35, 0.5, 0.25), (0.75, 1.0, 0.55)),
        'ghost': r('ghost', (0.04, 0.07, 0.14), (0.45, 0.65, 0.95)),
        'ghost2': r('ghost2', (0.12, 0.2, 0.35), (0.8, 0.92, 1.0)),
        'eye': r('eye', (0.3, 0.7, 0.8), (0.85, 1.0, 1.0)),
        'red_eye': r('red_eye', (0.5, 0.0, 0.0), (1.0, 0.45, 0.2)),
        'rock': r('rock', (0.03, 0.03, 0.05), (0.3, 0.28, 0.34)),
        'crystal': r('crystal', (0.15, 0.02, 0.3), (0.8, 0.5, 1.0)),
        'bone': r('bone', (0.2, 0.17, 0.1), (0.92, 0.88, 0.72)),
        'robe': r('robe', (0.02, 0.01, 0.04), (0.22, 0.08, 0.3)),
        'gold': r('gold', (0.25, 0.12, 0.0), (1.0, 0.8, 0.25)),
        'soul': r('soul', (0.0, 0.25, 0.15), (0.4, 1.0, 0.6)),
        'chitin': r('chitin', (0.01, 0.01, 0.02), (0.16, 0.12, 0.2)),
        'venom': r('venom', (0.25, 0.0, 0.2), (0.95, 0.2, 0.55)),
        'dark': r('dark', (0.0, 0.0, 0.0), (0.06, 0.05, 0.07)),
    }


# ---------------------------------------------------------------- modelos
# Todos miran hacia -Y. Cada uno devuelve el spec con los pivotes que anima pose().

def escarabajo(K, m):  # escarabajo de brasa: caparazón con grietas encendidas, cuerno y seis patas
    body = K.pivot('mo_body', (0, 0, 0.7))
    K.ell((0, 0.15, 0.75), (0.95, 1.2, 0.55), m['shell'], body)
    K.ell((0, 0.15, 1.05), (0.75, 1.0, 0.3), m['ember'], body)          # lomo encendido
    for x, y in ((-0.35, -0.2), (0.35, 0.1), (0.0, 0.5), (-0.3, 0.75), (0.3, 0.6)):
        K.ell((x, y, 1.28), (0.12, 0.2, 0.05), m['glow'], body)          # grietas
    head = K.pivot('mo_head', (0, -0.95, 0.75), body)
    K.ell((0, -1.15, 0.7), (0.45, 0.4, 0.35), m['shell'], head)
    K.beam((0, -1.35, 0.85), (0, -1.75, 1.45), 0.13, 0.0, m['ember'], head, 6)   # cuerno
    for sx in (-1, 1):
        K.ell((sx * 0.22, -1.48, 0.78), (0.08, 0.05, 0.08), m['glow'], head)
        K.beam((sx * 0.25, -1.4, 0.55), (sx * 0.1, -1.8, 0.5), 0.07, 0.01, m['dark'], head, 5)  # mandíbulas
    legs = []
    for i, y in enumerate((-0.6, 0.1, 0.8)):
        for sx in (-1, 1):
            n = f'mo_leg{i}{"L" if sx > 0 else "R"}'
            p = K.pivot(n, (sx * 0.7, y, 0.55), body)
            K.beam((sx * 0.7, y, 0.55), (sx * 1.2, y - 0.1, 0.45), 0.08, 0.06, m['shell'], p, 5)
            K.beam((sx * 1.2, y - 0.1, 0.45), (sx * 1.35, y - 0.15, 0.0), 0.06, 0.02, m['shell'], p, 5)
            legs.append((n, ((i + (sx > 0)) % 2) * math.pi, 'z', 0.35 * sx))
    return {'height': 0.9, 'res': 128, 'legs': legs, 'arms': []}


def hongo(K, m):  # hongo de esporas: sombrero enorme con pecas luminosas, cara en el tallo y bracitos
    body = K.pivot('mo_body', (0, 0, 0.6))
    K.beam((0, 0, 0.3), (0, 0, 1.6), 0.55, 0.42, m['stem'], body, 10)
    K.ell((0, 0, 0.45), (0.6, 0.6, 0.3), m['stem'], body)
    for sx in (-1, 1):
        K.ell((sx * 0.2, -0.47, 1.25), (0.1, 0.05, 0.13), m['dark'], body)  # ojos
        K.ell((sx * 0.2, -0.5, 1.28), (0.04, 0.03, 0.05), m['spot'], body)
    K.ell((0, -0.48, 0.95), (0.16, 0.04, 0.06), m['dark'], body)         # boca
    head = K.pivot('mo_head', (0, 0, 1.6), body)
    K.ell((0, 0, 1.9), (1.25, 1.25, 0.6), m['cap'], head)
    K.ell((0, 0, 1.6), (1.15, 1.15, 0.12), m['stem'], head)             # láminas bajo el sombrero
    for a in range(9):
        ang = a * 2 * math.pi / 9
        rr = 0.75 if a % 2 else 0.45
        K.ell((math.cos(ang) * rr, math.sin(ang) * rr, 2.2 + (0.15 if a % 2 == 0 else 0)), (0.18, 0.18, 0.1), m['spot'], head)
    K.ell((0, 0, 2.45), (0.2, 0.2, 0.12), m['spot'], head)
    arms = []
    for n, sx in (('mo_armL', 1), ('mo_armR', -1)):
        p = K.pivot(n, (sx * 0.5, 0, 1.1), body)
        K.beam((sx * 0.5, 0, 1.1), (sx * 0.85, -0.2, 0.7), 0.1, 0.07, m['stem'], p, 6)
        K.ell((sx * 0.88, -0.22, 0.65), (0.12, 0.12, 0.12), m['stem'], p)
        arms.append((n, sx))
    legs = []
    for n, sx, ph in (('mo_legL', 1, 0), ('mo_legR', -1, math.pi)):
        p = K.pivot(n, (sx * 0.3, 0, 0.35), body)
        K.ell((sx * 0.32, -0.1, 0.12), (0.25, 0.32, 0.14), m['stem'], p)
        legs.append((n, ph, 'x', 0.4))
    return {'height': 1.4, 'res': 128, 'legs': legs, 'arms': arms}


def lobo(K, m):  # lobo espectral: cuerpo de humo azul, melena de llamas frías, ojos blancos
    body = K.pivot('mo_body', (0, 0, 1.0))
    K.ell((0, 0.2, 1.15), (0.5, 1.05, 0.48), m['ghost'], body)
    K.ell((0, -0.55, 1.35), (0.58, 0.55, 0.6), m['ghost2'], body)        # pecho
    for i, (y, z) in enumerate(((-0.6, 1.85), (-0.25, 1.75), (0.15, 1.62), (0.5, 1.5))):
        K.beam((0, y, z - 0.25), (0, y + 0.25, z + 0.25), 0.22 - i * 0.03, 0.0, m['ghost2'], body, 5)  # melena
    tail = K.pivot('mo_tail', (0, 1.15, 1.3), body)
    K.beam((0, 1.15, 1.3), (0, 1.9, 1.9), 0.22, 0.04, m['ghost2'], tail, 6)
    head = K.pivot('mo_head', (0, -0.9, 1.6), body)
    K.ell((0, -1.1, 1.75), (0.38, 0.42, 0.36), m['ghost'], head)
    K.beam((0, -1.35, 1.65), (0, -1.85, 1.55), 0.2, 0.12, m['ghost'], head, 6)  # hocico
    K.ell((0, -1.88, 1.58), (0.08, 0.06, 0.06), m['dark'], head)
    K.beam((0, -1.7, 1.45), (0, -1.75, 1.38), 0.1, 0.03, m['bone'], head, 4)   # colmillos
    for sx in (-1, 1):
        K.beam((sx * 0.2, -1.0, 2.0), (sx * 0.28, -0.95, 2.4), 0.11, 0.0, m['ghost'], head, 4)  # orejas
        K.ell((sx * 0.18, -1.42, 1.85), (0.08, 0.04, 0.05), m['eye'], head)
    legs = []
    for i, (y, sx) in enumerate(((-0.55, 1), (-0.55, -1), (0.75, 1), (0.75, -1))):
        n = f'mo_leg{i}'
        p = K.pivot(n, (sx * 0.32, y, 1.0), body)
        K.beam((sx * 0.32, y, 1.0), (sx * 0.34, y + 0.1, 0.45), 0.15, 0.1, m['ghost'], p, 6)
        K.beam((sx * 0.34, y + 0.1, 0.45), (sx * 0.34, y - 0.05, 0.05), 0.09, 0.06, m['ghost2'], p, 6)
        K.ell((sx * 0.34, y - 0.12, 0.05), (0.12, 0.17, 0.06), m['ghost2'], p)
        legs.append((n, (0 if i in (0, 3) else math.pi), 'x', 0.55))
    return {'height': 2.3, 'res': 256, 'legs': legs, 'arms': [], 'tail': 'mo_tail'}


def golem(K, m):  # gólem de cristal: bloques de roca con racimos de cristal en hombros y espalda, núcleo brillante
    body = K.pivot('mo_body', (0, 0, 2.0))
    K.box((0, 0, 3.0), (2.2, 1.4, 1.6), m['rock'], body)
    K.box((0, 0, 2.1), (1.5, 1.1, 0.8), m['rock'], body)
    K.ell((0, -0.72, 3.0), (0.35, 0.1, 0.35), m['crystal'], body)          # núcleo
    for x, y, z, h in ((-0.6, 0.5, 3.8, 1.3), (0.2, 0.6, 3.9, 1.6), (0.8, 0.45, 3.7, 1.0), (-0.1, 0.75, 3.4, 1.1)):
        K.beam((x, y, z - 0.2), (x * 1.2, y + 0.4, z + h), 0.28, 0.0, m['crystal'], body, 6)
    head = K.pivot('mo_head', (0, -0.2, 3.8), body)
    K.box((0, -0.25, 4.15), (0.8, 0.75, 0.6), m['rock'], head)
    for sx in (-1, 1):
        K.box((sx * 0.2, -0.64, 4.2), (0.18, 0.05, 0.08), m['crystal'], head)
    arms = []
    for n, sx in (('mo_armL', 1), ('mo_armR', -1)):
        p = K.pivot(n, (sx * 1.3, 0, 3.4), body)
        K.box((sx * 1.55, 0, 3.4), (0.9, 0.9, 0.8), m['rock'], p)          # hombro
        K.beam((sx * 1.4, 0.0, 3.9), (sx * 1.9, 0.2, 4.9), 0.3, 0.0, m['crystal'], p, 6)
        K.box((sx * 1.65, -0.05, 2.5), (0.6, 0.6, 1.1), m['rock'], p)
        K.box((sx * 1.7, -0.15, 1.5), (0.85, 0.85, 0.9), m['rock'], p)     # puño
        K.beam((sx * 1.7, -0.6, 1.5), (sx * 1.75, -1.1, 1.4), 0.2, 0.0, m['crystal'], p, 5)
        arms.append((n, sx))
    legs = []
    for n, sx, ph in (('mo_legL', 1, 0), ('mo_legR', -1, math.pi)):
        p = K.pivot(n, (sx * 0.55, 0, 1.8), body)
        K.box((sx * 0.6, 0, 1.15), (0.75, 0.8, 1.2), m['rock'], p)
        K.box((sx * 0.6, -0.15, 0.25), (0.9, 1.1, 0.5), m['rock'], p)
        legs.append((n, ph, 'x', 0.35))
    return {'height': 4.6, 'res': 448, 'legs': legs, 'arms': arms}


def rey(K, m):  # rey osario: esqueleto gigante con túnica rasgada, corona de oro y báculo de almas
    body = K.pivot('mo_body', (0, 0, 1.6))
    K.beam((0, 0, 0.1), (0, 0, 2.6), 1.1, 0.55, m['robe'], body, 10)     # túnica
    for a in range(8):
        ang = a * 2 * math.pi / 8 + 0.2
        K.beam((math.cos(ang) * 1.05, math.sin(ang) * 1.05, 0.35), (math.cos(ang) * 1.15, math.sin(ang) * 1.15, -0.02), 0.18, 0.0, m['robe'], body, 4)  # jirones
    K.ell((0, 0, 3.1), (0.75, 0.55, 0.75), m['bone'], body)               # costillar
    for z in (2.75, 3.0, 3.25, 3.5):
        K.ell((0, -0.4, z), (0.7, 0.18, 0.06), m['dark'], body)
    K.ell((0, -0.2, 3.1), (0.18, 0.15, 0.16), m['soul'], body)            # alma en el pecho
    K.beam((-1.2, 0.2, 3.7), (1.2, 0.2, 3.7), 0.35, 0.35, m['robe'], body, 8)  # capa sobre los hombros
    K.poly([(-1.1, 0.5, 3.8), (1.1, 0.5, 3.8), (1.4, 0.75, 0.3), (-1.4, 0.75, 0.3)], m['robe'], body)
    head = K.pivot('mo_head', (0, -0.1, 3.9), body)
    K.ell((0, -0.15, 4.4), (0.48, 0.5, 0.52), m['bone'], head)
    K.ell((0, -0.4, 4.05), (0.32, 0.25, 0.18), m['bone'], head)           # mandíbula
    for sx in (-1, 1):
        K.ell((sx * 0.18, -0.6, 4.45), (0.13, 0.06, 0.13), m['dark'], head)
        K.ell((sx * 0.18, -0.65, 4.45), (0.06, 0.03, 0.06), m['soul'], head)
    K.torus((0, -0.1, 4.8), 0.42, 0.07, m['gold'], head)
    for a in range(6):
        ang = a * 2 * math.pi / 6
        K.beam((math.cos(ang) * 0.42, -0.1 + math.sin(ang) * 0.42, 4.8), (math.cos(ang) * 0.45, -0.1 + math.sin(ang) * 0.45, 5.25), 0.08, 0.0, m['gold'], head, 4)
    arms = []
    for n, sx in (('mo_armL', 1), ('mo_armR', -1)):
        p = K.pivot(n, (sx * 1.0, 0, 3.6), body)
        K.beam((sx * 1.0, 0, 3.6), (sx * 1.35, -0.2, 2.6), 0.12, 0.1, m['bone'], p, 6)
        K.beam((sx * 1.35, -0.2, 2.6), (sx * 1.45, -0.7, 2.1), 0.1, 0.08, m['bone'], p, 6)
        K.ell((sx * 1.47, -0.8, 2.0), (0.16, 0.16, 0.18), m['bone'], p)
        if sx < 0:  # báculo en la mano derecha
            K.beam((sx * 1.5, -0.85, 0.0), (sx * 1.5, -0.85, 4.6), 0.07, 0.07, m['dark'], p, 6)
            K.torus((sx * 1.5, -0.85, 4.7), 0.25, 0.05, m['gold'], p, (math.pi / 2, 0, 0))
            K.ell((sx * 1.5, -0.85, 4.7), (0.2, 0.2, 0.2), m['soul'], p)
        arms.append((n, sx))
    return {'height': 4.4, 'res': 448, 'legs': [], 'arms': arms, 'float': True}


def arana(K, m):  # reina araña: abdomen enorme con marcas de veneno, corona de ojos rojos y ocho patas articuladas
    body = K.pivot('mo_body', (0, 0, 1.4))
    K.ell((0, 1.4, 1.9), (1.35, 1.6, 1.15), m['chitin'], body)            # abdomen
    for y, z, s in ((0.8, 2.9, 0.35), (1.4, 3.0, 0.45), (2.0, 2.75, 0.3)):
        K.ell((0, y, z), (s, s * 0.8, 0.12), m['venom'], body)            # marcas
    K.ell((0, -0.2, 1.5), (0.85, 0.95, 0.6), m['chitin'], body)           # tórax
    head = K.pivot('mo_head', (0, -1.0, 1.6), body)
    K.ell((0, -1.2, 1.75), (0.6, 0.55, 0.5), m['chitin'], head)
    K.beam((-0.5, -1.0, 2.1), (0.5, -1.0, 2.1), 0.14, 0.14, m['venom'], head, 6)  # diadema
    for x, z, s in ((-0.2, 1.95, 0.11), (0.2, 1.95, 0.11), (-0.4, 1.85, 0.08), (0.4, 1.85, 0.08), (-0.1, 2.15, 0.07), (0.1, 2.15, 0.07)):
        K.ell((x, -1.68, z), (s, s * 0.6, s), m['red_eye'], head)
    for sx in (-1, 1):
        K.beam((sx * 0.2, -1.6, 1.45), (sx * 0.12, -1.9, 1.0), 0.12, 0.0, m['venom'], head, 5)  # quelíceros
    legs, arms = [], []
    for i, (y, sp) in enumerate(((-0.75, -0.6), (-0.35, -0.2), (0.05, 0.25), (0.45, 0.7))):
        for sx in (-1, 1):
            n = f'mo_leg{i}{"L" if sx > 0 else "R"}'
            p = K.pivot(n, (sx * 0.6, y, 1.5), body)
            knee = (sx * 2.0, y + sp * 1.2, 2.6)
            foot = (sx * 2.9, y + sp * 2.0, 0.0)
            K.beam((sx * 0.6, y, 1.5), knee, 0.16, 0.11, m['chitin'], p, 6)
            K.ell(knee, (0.14, 0.14, 0.14), m['venom'], p)
            K.beam(knee, foot, 0.11, 0.02, m['chitin'], p, 6)
            legs.append((n, ((i + (sx > 0)) % 2) * math.pi, 'z', 0.25 * sx))
            if i == 0:
                arms.append((n, sx))   # el par delantero se alza al atacar
    return {'height': 3.3, 'res': 448, 'legs': legs, 'arms': arms}


MONSTERS = {'escarabajo_brasa': escarabajo, 'hongo_espora': hongo, 'lobo_espectral': lobo,
            'golem_cristal': golem, 'rey_osario': rey, 'reina_arana': arana}
SPEC = {}


def build(name):
    K = Kit('MONSTRUO', 'mo_root')
    spec = MONSTERS[name](K, mats())
    SPEC.clear()
    SPEC.update(spec)
    pose('idle', 0)
    K.normalize(spec['height'])
    return spec


# ---------------------------------------------------------------- poses
def pose(kind, k):
    spec = SPEC
    O = bpy.data.objects
    reset([o.name for o in bpy.data.collections['MONSTRUO'].objects if o.type == 'EMPTY' and o.name != 'mo_root'])

    def rot(n, x=0.0, y=0.0, z=0.0):
        if n in O:
            O[n].rotation_euler = (x, y, z)

    def mv(n, dx=0.0, dy=0.0, dz=0.0):
        if n in O:
            O[n].location = Vector(O[n]['rest']) + Vector((dx, dy, dz))
    fl = 0.12 if spec.get('float') else 0.0
    legs = {l[0] for l in spec['legs']}
    if kind == 'idle':
        mv('mo_body', 0, 0, fl)
        for n, sx in spec['arms']:
            if n not in legs:
                rot(n, 0.05, 0, 0.08 * sx)
    elif kind == 'walk':
        ph = 2 * math.pi * k / 8
        for n, off, ax, amp in spec['legs']:
            a = amp * math.sin(ph + off)
            rot(n, a if ax == 'x' else 0, 0, a if ax == 'z' else 0)
        for n, sx in spec['arms']:
            if n not in legs:
                rot(n, -0.35 * math.sin(ph) * sx, 0, 0.08 * sx)
        mv('mo_body', 0, 0, fl + 0.06 * math.cos(2 * ph) + (0.1 * math.sin(ph) if spec.get('float') else 0))
        rot('mo_body', 0.03 * math.sin(2 * ph), 0, 0.05 * math.sin(ph))
        rot('mo_head', 0.06 * math.sin(2 * ph + 1))
        rot(spec.get('tail', ''), 0, 0.35 * math.sin(ph))
    elif kind == 'attack':  # preparar (0-4), golpe en el fotograma 5, recuperar
        lean = [0.0, -0.06, -0.12, -0.18, -0.22, 0.28, 0.14, 0.0][k]
        arm = [0.0, -0.5, -1.1, -1.7, -2.1, -0.3, -0.1, 0.0][k]
        fwd = [0, 0.04, 0.08, 0.12, 0.15, -0.35, -0.18, 0][k]
        rot('mo_body', lean)
        rot('mo_head', lean * 0.8)
        mv('mo_body', 0, fwd, fl + [0, 0.02, 0.05, 0.08, 0.1, -0.08, -0.03, 0][k])
        for n, sx in spec['arms']:
            if n in legs:  # patas delanteras de la araña: se alzan
                rot(n, 0, -arm * 0.35 * sx, 0)
            else:
                rot(n, arm, 0, 0.15 * sx)
        rot(spec.get('tail', ''), -lean * 2)
    elif kind == 'hurt':
        r = [1.0, 0.65, 0.3, 0.08][k]
        rot('mo_body', -0.16 * r)
        mv('mo_body', 0, 0.12 * r, fl - 0.04 * r)
        rot('mo_head', -0.25 * r, 0, 0.12 * r)
        for n, sx in spec['arms']:
            if n not in legs:
                rot(n, 0.35 * r, 0, (0.1 + 0.35 * r) * sx)


# ---------------------------------------------------------------- render pixel art
def pixelize(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    solid = a[:, :, 3] > 0.45
    rgb = np.where(a[:, :, 3:4] > 0, a[:, :, :3] / np.maximum(a[:, :, 3:4], 1e-4), 0)
    rgb = np.round(np.clip(rgb, 0, 1) * (LEVELS - 1)) / (LEVELS - 1)
    edge = np.zeros_like(solid)
    edge[1:, :] |= solid[:-1, :]
    edge[:-1, :] |= solid[1:, :]
    edge[:, 1:] |= solid[:, :-1]
    edge[:, :-1] |= solid[:, 1:]
    edge &= ~solid
    out = np.zeros((h, w, 4), dtype=np.float32)
    out[solid, :3] = rgb[solid]
    out[solid, 3] = 1.0
    out[edge, :3] = OUTLINE
    out[edge, 3] = 1.0
    out = out.repeat(PIX, 0).repeat(PIX, 1)
    bpy.data.images.remove(img)
    big = bpy.data.images.new('px', w * PIX, h * PIX, alpha=True)
    big.pixels.foreach_set(out.ravel())
    big.filepath_raw = path
    big.file_format = 'PNG'
    big.save()
    bpy.data.images.remove(big)


def render(name, dirs, kinds):
    res = SPEC['res']
    out = ROOT + f'monstruos/{name}/'
    os.makedirs(out, exist_ok=True)
    s = bpy.context.scene
    root, col, cam = bpy.data.objects['mo_root'], bpy.data.collections['MONSTRUO'], bpy.data.objects['SpriteCam']
    q = cam.matrix_world.to_quaternion()
    fwd = q @ Vector((0, 0, -1)); fwd.z = 0; fwd.normalize()
    right = q @ Vector((1, 0, 0)); right.z = 0; right.normalize()
    r = s.render
    keep = {o.name for o in col.all_objects}
    for o in s.objects:
        if o.type in ('MESH', 'CURVE') and o.name not in keep:
            o.hide_render = True
    s.camera = cam
    ortho = cam.data.ortho_scale
    cam.data.ortho_scale = ortho * res / 128.0     # mismos metros por píxel que el resto de sprites
    r.resolution_x = r.resolution_y = res // PIX
    r.resolution_percentage = 100
    r.film_transparent = True
    r.filter_size = 0.0
    try:
        s.eevee.taa_render_samples = 64   # menos grano en las caras planas: al posterizar el ruido se vuelve moteado
    except AttributeError:
        pass
    for dname, dx, dy in DIRS:
        if dname not in dirs:
            continue
        f = (right * dx - fwd * dy).normalized()
        root.rotation_euler[2] = math.atan2(f.y, f.x) + math.pi / 2
        for kind, n in kinds:
            for k in range(n):
                pose(kind, k)
                p = out + f'{name}_{dname}_{kind}_{k:02d}.png'
                r.filepath = p
                bpy.ops.render.render(write_still=True)
                pixelize(p)
    cam.data.ortho_scale = ortho


if __name__ == '__main__':
    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else ['preview']
    mode, names = args[0], (args[1:] or list(MONSTERS))
    for nm in names:
        build(nm)
        if mode == 'preview':
            render(nm, ['S', 'SE'], [('idle', 1), ('attack', 8)])
        else:
            render(nm, [d[0] for d in DIRS], [('idle', 1), ('walk', 8), ('attack', 8), ('hurt', 4)])
        print('OK', nm, SPEC['res'])
