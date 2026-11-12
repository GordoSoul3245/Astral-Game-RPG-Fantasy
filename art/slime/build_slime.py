# Slime verde (monstruo básico): salta hacia el héroe. Requiere art/sprite_common.py ya ejecutado en el mismo ns.
# Uso: exec(sprite_common); exec(este archivo); build(); render(['S'])
OUT = r'C:/Users/Mateo/Documents/astral/art/slime/'
RES = 128                    # mismo cuadro que el héroe: FEET = (68, 113.7)
PIVOTS = ['sl_body']


def build():
    kit = Kit('SLIME', 'sl_root')
    GRN = ramp('Slime • body', 'Cel • crimson', [(0.02, 0.12, 0.015), (0.05, 0.26, 0.03), (0.12, 0.45, 0.06), (0.25, 0.65, 0.12)])
    LGT = ramp('Slime • shine', 'Cel • crimson', [(0.1, 0.4, 0.05), (0.2, 0.6, 0.1), (0.4, 0.85, 0.2), (0.7, 1.0, 0.4)])
    DRK = bpy.data.materials['Cel • obsidian']
    body = kit.pivot('sl_body', (0, 0, 0))
    kit.ell((0, 0, 0.3), (0.5, 0.5, 0.32), GRN, body, 16, 10)
    kit.ell((-0.14, -0.1, 0.5), (0.16, 0.12, 0.07), LGT, body)           # brillo
    kit.ell((-0.3, -0.05, 0.4), (0.06, 0.05, 0.04), LGT, body)
    for sx in (-1, 1):
        kit.ell((sx * 0.15, -0.44, 0.34), (0.06, 0.03, 0.1), DRK, body)   # ojos
    kit.ell((0, -0.47, 0.2), (0.1, 0.03, 0.03), DRK, body)                # boca
    pose('idle', 0)
    kit.normalize(0.75)   # ~0.6 m de ancho, algo menos de la mitad de alto que el héroe
    print('slime listo')


def pose(kind, k):
    reset(PIVOTS)
    b = bpy.data.objects['sl_body']
    if kind == 'walk':  # un salto completo en 8 fotogramas: agacharse, estirarse en el aire, aplastarse al caer
        h = [0, 0, 0.22, 0.42, 0.42, 0.22, 0, 0][k]
        sz = [0.78, 0.84, 1.12, 1.2, 1.15, 1.08, 0.8, 0.9][k]
        b.location = Vector(b['rest']) + Vector((0, 0, h))
        b.scale = (1 / math.sqrt(sz), 1 / math.sqrt(sz), sz)
    elif kind == 'hurt':  # gelatina golpeada: se aplasta fuerte y tiembla hasta asentarse
        sz = [0.62, 1.22, 0.86, 1.05][k]
        b.scale = (1 / math.sqrt(sz), 1 / math.sqrt(sz), sz)


def render(names, kinds=(('idle', 1), ('walk', 8), ('hurt', 4))):
    render_sprites('SLIME', 'sl_root', pose, OUT, 'slime_', names, RES, kinds)
