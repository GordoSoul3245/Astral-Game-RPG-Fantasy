# Mago de la tormenta (jefe final): 1.5 veces la altura del hechicero, túnica gris con capucha y rayos en las manos.
# Requiere art/sprite_common.py ya ejecutado en el mismo ns. Uso: build(); render(['S'])
OUT = r'C:/Users/Mateo/Documents/astral/art/stormmage/'
HEIGHT = 2.05 * 1.5
K = 2.0                       # cuadro de 256 px; los píxeles por metro son los de los demás sprites
RES = int(128 * K)
FEET = (68 + (RES - 128) / 2, 113.7 + (RES - 128) / 2)
PIVOTS = ['my_body', 'my_head', 'my_armL', 'my_armR', 'my_arcL', 'my_arcR']
FX = []                       # piezas de efecto (rayos, orbes): no cuentan para la altura


def build():
    global FX
    kit = Kit('STORMMAGE', 'my_root')
    ROBE = ramp('Mage • robe', 'Cel • cobalt silk', [(0.07, 0.085, 0.1), (0.15, 0.17, 0.2), (0.27, 0.3, 0.34), (0.45, 0.49, 0.54)])
    HOOD = ramp('Mage • hood', 'Cel • cobalt silk', [(0.025, 0.035, 0.06), (0.06, 0.08, 0.14), (0.12, 0.15, 0.24), (0.2, 0.25, 0.36)])
    TRIM = ramp('Mage • trim', 'Cel • cobalt silk', [(0.2, 0.22, 0.25), (0.34, 0.37, 0.41), (0.55, 0.59, 0.64), (0.8, 0.84, 0.88)])
    BOLT = ramp('Mage • lightning', 'Cel • cobalt silk', [(0.3, 0.8, 1.0), (0.5, 0.95, 1.0), (0.8, 1.0, 1.0), (1.0, 1.0, 1.0)])
    OBS = bpy.data.materials['Cel • obsidian']
    FX = []
    body = kit.pivot('my_body', (0, 0, 1.2))
    kit.beam((0, 0, 0.02), (0, 0, 2.0), 0.62, 0.34, ROBE, body, 12)                      # túnica larga hasta el suelo
    kit.ell((0, 0, 0.08), (0.66, 0.6, 0.1), TRIM, body, 14, 6)                            # dobladillo
    kit.poly([(-0.24, -0.34, 1.95), (0.24, -0.34, 1.95), (0.34, -0.5, 0.12), (-0.34, -0.5, 0.12)], TRIM, body)  # tabardo delantero
    kit.ell((0, 0, 2.2), (0.55, 0.36, 0.42), ROBE, body)                                  # torso
    for sx in (-1, 1):
        kit.ell((sx * 0.52, 0, 2.4), (0.3, 0.27, 0.24), ROBE, body)                       # hombros
        kit.ell((sx * 0.55, 0, 2.5), (0.26, 0.22, 0.1), TRIM, body)                       # hombreras
    kit.beam((-0.42, -0.3, 2.55), (0.32, -0.36, 1.45), 0.09, 0.09, HOOD, body, 6)          # banda cruzada
    kit.ell((0, -0.03, 2.5), (0.32, 0.3, 0.12), TRIM, body)                               # cuello envuelto
    head = kit.pivot('my_head', (0, -0.05, 2.62), body)
    kit.ell((0, 0, 2.82), (0.29, 0.31, 0.36), HOOD, head)                                  # capucha
    kit.beam((0, 0.12, 3.0), (0, 0.32, 3.16), 0.12, 0.0, HOOD, head, 8)                    # punta caída de la capucha
    kit.ell((0, -0.2, 2.78), (0.17, 0.1, 0.22), OBS, head)                                 # máscara
    kit.ell((0, -0.29, 2.84), (0.13, 0.03, 0.03), BOLT, head)                              # visor luminoso
    for sx in (-1, 1):
        al = kit.pivot('my_arm' + ('L' if sx > 0 else 'R'), (sx * 0.58, 0, 2.4), body)
        kit.beam((sx * 0.58, 0, 2.42), (sx * 0.74, -0.05, 1.95), 0.15, 0.12, ROBE, al, 8)  # brazo con manga ancha
        kit.beam((sx * 0.74, -0.05, 1.95), (sx * 0.8, -0.3, 1.45), 0.12, 0.1, ROBE, al, 8)
        kit.ell((sx * 0.8, -0.32, 1.38), (0.12, 0.13, 0.14), OBS, al)                      # guantelete
        hand = (sx * 0.8, -0.34, 1.34)
        orb = kit.ell(hand, (0.05, 0.05, 0.05), BOLT, al)
        orb.name = 'my_fx_orb' + ('L' if sx > 0 else 'R')
        FX.append(orb.name)
        ap = kit.pivot('my_arc' + ('L' if sx > 0 else 'R'), hand, al)
        for j in range(5):                                                                  # chispas en zigzag alrededor de la mano
            a = j * 1.26 + (0.5 if sx > 0 else 0.0)
            d = Vector((math.cos(a) * 0.8, -0.3 + 0.3 * math.sin(a * 2), math.sin(a) * 0.8)).normalized()
            perp = d.cross(Vector((0, 0, 1))).normalized()
            p = [Vector(hand)]
            for i, off in enumerate((0.05, -0.05, 0.04)):
                p.append(Vector(hand) + d * (0.17 * (i + 1)) + perp * off)
            for u, v in zip(p, p[1:]):
                b = kit.beam(u, v, 0.02, 0.012, BOLT, ap, 4)
                b.name = f'my_fx_arc_{j}_{len(FX)}'
                FX.append(b.name)
    for i in range(7):                                                                      # rayo hacia delante al lanzar
        z0 = 2.0 - i * 0.1
        a = Vector(((-1) ** i * 0.13 * (i > 0), -0.7 - i * 0.4, z0))
        b = Vector(((-1) ** (i + 1) * 0.13, -0.7 - (i + 1) * 0.4, z0 - 0.1))
        s = kit.beam(a, b, 0.07, 0.07, BOLT, body, 4)
        s.name = f'my_fx_bolt{i}'
        FX.append(s.name)
    pose('idle', 0)
    kit.normalize(HEIGHT, skip=tuple(FX))
    print('mago listo', 'FEET', FEET, 'RES', RES)


def pose(kind, k):
    reset(PIVOTS)
    O = bpy.data.objects

    def rot(n, x=0.0, y=0.0, z=0.0):
        O[n].rotation_euler = (x, y, z)

    raise_, charge, bolt, arcs = 0.0, 0.0, False, 0.35
    if kind == 'idle':
        raise_ = 0.15
    elif kind == 'walk':  # flota: sube y baja con la túnica balanceándose
        ph = 2 * math.pi * k / 8
        O['my_body'].location = Vector(O['my_body']['rest']) + Vector((0, 0, 0.05 * math.sin(ph)))
        rot('my_body', 0.04, 0.03 * math.sin(ph), 0.04 * math.sin(ph))
        raise_ = 0.2 + 0.1 * math.sin(ph)
    elif kind == 'attack':  # alza ambas manos cargando energía y lanza el rayo en el fotograma 5
        raise_ = [0.15, 0.7, 1.4, 2.0, 2.4, 1.3, 0.8, 0.3][k]
        charge = [0, 0.4, 0.7, 1.0, 1.4, 0.4, 0, 0][k]
        bolt = k in (5, 6)
        arcs = [0.5, 0.7, 0.9, 1.0, 1.1, 1.0, 0.8, 0.5][k]
        rot('my_body', -0.05 * (k >= 5), 0, 0)
    for n in ('my_armL', 'my_armR'):
        O[n].rotation_euler = (-raise_, 0, 0)
    for side in 'LR':
        O['my_arc' + side].rotation_euler = (0.9 * k, 1.3 * k, 0.7 * k)    # las chispas cambian de forma en cada fotograma
        O['my_arc' + side].scale = (arcs * 3,) * 3
        orb = O['my_fx_orb' + side]
        orb.scale = (max(charge * 0.18, 0.001),) * 3
        orb.hide_render = charge == 0
    for nm in FX:
        if nm.startswith('my_fx_arc'):
            j = int(nm.split('_')[3])
            O[nm].hide_render = (j + k) % 3 == 0 and kind != 'attack'
        elif nm.startswith('my_fx_bolt'):
            O[nm].hide_render = not bolt


def render(names, kinds=(('idle', 1), ('walk', 8), ('attack', 8))):
    render_sprites('STORMMAGE', 'my_root', pose, OUT, 'stormmage_', names, RES, kinds)
