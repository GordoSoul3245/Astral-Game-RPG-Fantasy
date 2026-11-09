# Esqueleto arquero: huesos, arco de madera y carcaj. Requiere art/sprite_common.py ya ejecutado en el mismo ns.
# Uso: exec(sprite_common); exec(este archivo); build(); render(['S'])
OUT = r'C:/Users/Mateo/Documents/astral/art/skeleton/'
RES = 128                    # FEET = (68, 113.7)
PIVOTS = ['sk_body', 'sk_head', 'sk_armL', 'sk_armR', 'sk_foreR', 'sk_legL', 'sk_legR']


def build():
    kit = Kit('SKELETON', 'sk_root')
    BONE = ramp('Skeleton • bone', 'Cel • amber cloak', [(0.22, 0.19, 0.13), (0.42, 0.37, 0.26), (0.68, 0.62, 0.46), (0.9, 0.84, 0.66)])
    DRK, WOOD = bpy.data.materials['Cel • obsidian'], bpy.data.materials['Cel • dark wood']
    body = kit.pivot('sk_body', (0, 0, 1.0))
    kit.ell((0, 0, 1.02), (0.22, 0.14, 0.12), BONE, body)                    # pelvis
    kit.beam((0, 0, 1.05), (0, 0, 1.58), 0.04, 0.04, BONE, body, 6)         # columna
    for i, z in enumerate((1.22, 1.32, 1.42, 1.52)):                        # costillas
        kit.ell((0, -0.02, z), (0.21 - 0.012 * i, 0.12, 0.028), BONE, body)
    kit.beam((-0.3, 0, 1.6), (0.3, 0, 1.6), 0.035, 0.035, BONE, body, 6)    # clavículas
    kit.beam((0.12, 0.17, 1.25), (0.17, 0.2, 1.78), 0.075, 0.07, WOOD, body, 8)   # carcaj
    for dx in (-0.03, 0.0, 0.03):
        kit.beam((0.17 + dx, 0.2, 1.78), (0.17 + dx, 0.2, 1.95), 0.012, 0.0, BONE, body, 4)  # plumas de flecha
    head = kit.pivot('sk_head', (0, 0, 1.66), body)
    kit.ell((0, -0.02, 1.8), (0.15, 0.17, 0.17), BONE, head)                 # cráneo
    kit.ell((0, -0.1, 1.67), (0.09, 0.08, 0.045), BONE, head)                # mandíbula
    for sx in (-1, 1):
        kit.ell((sx * 0.065, -0.16, 1.82), (0.045, 0.03, 0.05), DRK, head)   # cuencas
    kit.ell((0, -0.18, 1.74), (0.02, 0.02, 0.03), DRK, head)                 # nariz
    # brazo del arco (izquierdo): el arco cuelga de la mano con las puntas a lo largo de su eje local X
    al = kit.pivot('sk_armL', (0.3, 0, 1.58), body)
    kit.beam((0.3, 0, 1.58), (0.3, 0, 1.3), 0.035, 0.03, BONE, al, 6)
    kit.beam((0.3, 0, 1.3), (0.3, 0, 1.04), 0.03, 0.025, BONE, al, 6)
    kit.ell((0.3, 0, 1.0), (0.04, 0.04, 0.05), BONE, al)
    pts = [(0.3 + a, 0.0, 1.02 + 0.22 * (a / 0.6) ** 2) for a in [x * 0.1 for x in range(-6, 7)]]
    for p, q in zip(pts, pts[1:]):
        kit.beam(p, q, 0.028, 0.028, WOOD, al, 5)
    kit.beam(pts[0], pts[-1], 0.006, 0.006, BONE, al, 3)                      # cuerda
    # brazo de tensar (derecho) con codo
    ar = kit.pivot('sk_armR', (-0.3, 0, 1.58), body)
    kit.beam((-0.3, 0, 1.58), (-0.3, 0, 1.3), 0.035, 0.03, BONE, ar, 6)
    fr = kit.pivot('sk_foreR', (-0.3, 0, 1.3), ar)
    kit.beam((-0.3, 0, 1.3), (-0.3, 0, 1.04), 0.03, 0.025, BONE, fr, 6)
    kit.ell((-0.3, 0, 1.0), (0.04, 0.04, 0.05), BONE, fr)
    arrow = kit.beam((-0.3, 0, 1.55), (1.0, 0, 1.55), 0.012, 0.012, WOOD, body, 4)
    arrow.name = 'sk_arrow'
    tip = kit.beam((1.0, 0, 1.55), (1.1, 0, 1.55), 0.025, 0.0, DRK, body, 4)
    tip.name = 'sk_arrow_tip'
    for nm, sx in (('sk_legL', 1), ('sk_legR', -1)):
        lp = kit.pivot(nm, (sx * 0.12, 0, 1.0), body)
        kit.beam((sx * 0.12, 0, 1.0), (sx * 0.12, -0.02, 0.52), 0.05, 0.035, BONE, lp, 6)
        kit.ell((sx * 0.12, -0.02, 0.52), (0.045, 0.045, 0.045), BONE, lp)
        kit.beam((sx * 0.12, -0.02, 0.52), (sx * 0.12, 0, 0.07), 0.035, 0.03, BONE, lp, 6)
        kit.ell((sx * 0.12, -0.08, 0.04), (0.06, 0.14, 0.035), BONE, lp)
    pose('idle', 0)
    kit.normalize(1.9, skip=('sk_arrow', 'sk_arrow_tip'))
    print('esqueleto listo')


def pose(kind, k):
    reset(PIVOTS)
    O = bpy.data.objects

    def rot(n, x=0.0, y=0.0, z=0.0):
        O[n].rotation_euler = (x, y, z)

    show_arrow = False
    if kind == 'idle':
        rot('sk_armL', 0, -0.35, 0)
    elif kind == 'walk':
        ph = 2 * math.pi * k / 8
        a = 0.5 * math.sin(ph)
        rot('sk_legL', a); rot('sk_legR', -a)
        rot('sk_armR', 0.4 * math.sin(ph)); rot('sk_armL', 0, -0.35, 0)
        O['sk_body'].location = Vector(O['sk_body']['rest']) + Vector((0, 0, 0.025 * math.cos(2 * ph)))
        rot('sk_body', 0.02, 0, 0.05 * math.sin(ph))
    elif kind == 'attack':  # gira de lado, estira el arco, tensa y suelta la flecha en el fotograma 4
        twist = [0, -0.8, -1.57, -1.57, -1.57, -1.4, -0.8, 0][k]
        psi_l = [-0.35, -0.7, -1.57, -1.57, -1.57, -1.3, -0.7, -0.35][k]
        draw = [0, 0.3, 0.85, 1.0, 0.35, 0.1, 0, 0][k]
        rot('sk_body', 0, 0, twist)
        rot('sk_head', 0, 0, -twist)
        rot('sk_armL', 0, psi_l, 0)
        rot('sk_armR', 0, 1.57 * draw, 0)
        rot('sk_foreR', 0, -3.14 * draw, 0)
        show_arrow = k in (1, 2, 3)
    for n in ('sk_arrow', 'sk_arrow_tip'):
        O[n].hide_render = not show_arrow


def render(names, kinds=(('idle', 1), ('walk', 8), ('attack', 8))):
    render_sprites('SKELETON', 'sk_root', pose, OUT, 'skeleton_', names, RES, kinds)
