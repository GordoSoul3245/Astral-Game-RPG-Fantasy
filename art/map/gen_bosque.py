# Genera el Bosque del Fogón (zona de inicio) en data/zones.json y su enlace en data/world.json.
# Uso: python art/map/gen_bosque.py   (desde la raíz del proyecto; determinista)
#
# Criterios de diseño (análisis de mapas, nov. 2026):
# - Punto focal al empezar: la fogata (con su humo) aparece arriba en la primera pantalla, a pocos pasos del inicio.
# - Hitos encadenados: fogata -> árbol viejo (grande, en su claro) -> lago -> salida al valle.
# - Camino sinuoso de ~3 casillas con un estrechamiento y aperturas en los claros (ritmo, no una cinta recta).
# - Bosquetes y claros en vez de densidad pareja: denso en el borde, ralo junto al camino, vacío alrededor de los hitos.
# - Borde: franja de 3 casillas de bosque que no se pisa; más allá, region.gd pinta suelo de bosque que se oscurece (sin vacío negro).
# - Recursos agrupados como pequeñas sorpresas a lo largo del recorrido.
# Leyenda del layout: T árbol, . pasto, = camino, ~ agua (fila = j, columna = i). La franja de borde la bloquea "border".
import json
import math
import random

N = 51
BORDER = 3
rng = random.Random(1137)

START = (11.5, 39.5)
FIRE = (16.0, 32.5)                          # a un costado del camino, arriba-izquierda en la primera pantalla
OLD_MAN = (17.4, 32.7)
BIG_TREE = (30.5, 19.5)                     # hito regional: árbol viejo
LAKE = [((19.0, 14.0), 4.6, 3.6), ((16.0, 16.5), 3.2, 2.6), ((21.5, 11.5), 2.4, 2.0)]  # lóbulos (centro, rx, ry)
# camino: del borde sur, pasa junto a la fogata, se estrecha, rodea el árbol viejo, bordea el lago y sale al norte
PATH = [(9, 45), (11, 41), (14, 38), (18, 36.5), (22, 35), (24.5, 32), (25, 28), (24, 24.5), (26, 21.5), (28.5, 18),
        (28, 14), (26.5, 10), (28, 6), (29, 2), (29, -2)]
PINCH = (24.5, 25.5)                         # estrechamiento entre dos bosquetes
CLEARINGS = [(START, 3.0), ((16.5, 32.5), 4.0), (BIG_TREE, 2.6), ((29.5, 25.5), 1.8)]
NODES = [("berry", 14.5, 41.5), ("berry", 15.5, 40.5),          # primera recompensa junto al inicio
         ("mushroom", 21.5, 26.5), ("mushroom", 22.5, 27.5), ("mushroom", 21.5, 28.5),  # corro de hongos a la sombra
         ("herb", 23.5, 13.5), ("herb", 24.5, 15.5)]             # hierbas en la orilla del lago


def seg_dist(p, a, b):
    ax, ay = a; bx, by = b; px, py = p
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def path_dist(p):
    return min(seg_dist(p, a, b) for a, b in zip(PATH, PATH[1:]))


def in_lake(i, j):
    x, y = i + 0.5, j + 0.5
    wob = 0.18 * math.sin(x * 1.7 + y * 0.6) + 0.12 * math.sin(y * 2.3 - x * 0.9)  # orilla irregular
    return any(((x - c[0]) / rx) ** 2 + ((y - c[1]) / ry) ** 2 < 1.0 + wob for c, rx, ry in LAKE)


# bosquetes: manchas de densidad repartidas por el mapa (no una rejilla)
groves = [((rng.uniform(BORDER, N - BORDER), rng.uniform(BORDER, N - BORDER)), rng.uniform(2.5, 5.0)) for _ in range(16)]


def grove(i, j):
    return max(math.exp(-((i - c[0]) ** 2 + (j - c[1]) ** 2) / (2 * r * r)) for c, r in groves)


g = [['.'] * N for _ in range(N)]
for j in range(N):
    for i in range(N):
        p = (i + 0.5, j + 0.5)
        d = path_dist(p)
        width = 1.5 if math.hypot(p[0] - PINCH[0], p[1] - PINCH[1]) < 3 else 2.0  # ~4 casillas; 3 en el estrechamiento
        if in_lake(i, j):
            g[j][i] = '~'
        elif d < width:
            g[j][i] = '='
for j in range(N):
    for i in range(N):
        if g[j][i] != '.':
            continue
        p = (i + 0.5, j + 0.5)
        edge = min(i, j, N - 1 - i, N - 1 - j)
        d = path_dist(p)
        near_water = any(0 <= i + a < N and 0 <= j + b < N and g[j + b][i + a] == '~' for a in range(-2, 3) for b in range(-2, 3))
        if any(math.hypot(p[0] - c[0], p[1] - c[1]) < r for c, r in CLEARINGS) or any(math.hypot(p[0] - x, p[1] - y) < 1.2 for _, x, y in NODES):
            prob = 0.0
        elif edge < BORDER:
            prob = 0.4                                       # muro de bosque en el borde
        else:
            prob = 0.02 + 0.4 * grove(i, j)                  # bosquetes y claros
            if d < 2.6:
                prob *= 0.25                                 # arcén despejado junto al camino
            elif d < 4.0:
                prob *= 0.7
            if math.hypot(p[0] - PINCH[0], p[1] - PINCH[1]) < 4 and d >= 1.5:
                prob = max(prob, 0.55)                       # el estrechamiento: dos bosquetes que lo enmarcan
            if near_water:
                prob *= 0.3                                  # orilla abierta
        if rng.random() < prob:
            g[j][i] = 'T'
lay = [''.join(r) for r in g]

z = json.load(open('data/zones.json', encoding='utf8'))
b = z['bosque']
b.update(tiles=N, border=BORDER, layout=lay, start=list(START),
         camp={'fire': list(FIRE), 'old_man': list(OLD_MAN)},
         trees=[[BIG_TREE[0], BIG_TREE[1], 'tree_arbol1', 1.7]],
         nodes=[{'kind': k, 't': [x, y]} for k, x, y in NODES])
json.dump(z, open('data/zones.json', 'w', encoding='utf8', newline='\n'), ensure_ascii=False, indent='\t')
w = json.load(open('data/world.json', encoding='utf8'))
cols = [i for i, c in enumerate(lay[0]) if c == '=']
for l in w['links']:
    if l['b'] == 'bosque':
        l['rows_b'] = [cols[0], cols[-1]]
json.dump(w, open('data/world.json', 'w', encoding='utf8', newline='\n'), ensure_ascii=False, indent='\t')
assert lay[int(START[1])][int(START[0])] in '.=' and cols, 'inicio en suelo y salida al norte'
print('\n'.join(lay))
print('arboles', sum(r.count('T') for r in lay), '+1 hito; salida', cols)
