import bpy, json, math, os
import numpy as np

# Genera las hojas de sprites de la estela de cada tajo (art/trails/<anim>_<dir>.png) a partir de la calibración del filo
# (data/blade_points.json) y de la ventana de emisión de cada ataque (data/items.json).
# Cada hoja: una fila por tramo del barrido (fotograma i -> i+1) y COLS columnas de edad: nace, se estrecha, se apaga, fragmentos.
# Los tramos se colocan en el mundo al emitirse (scripts/slash_trail.gd), así la cola no se pega al héroe.
# Lienzo de 192 px por celda; el píxel (PAD, PAD) es el (0, 0) del sprite del héroe (pivote común). Blanco/gris: el color lo pone la espada.
# Uso: blender -b -P art/katana/gen_trail_sprites.py
ROOT = 'C:/Users/Mateo/Documents/astral/'
CELL, PAD, COLS = 192, 32, 5
WIDTH_K = [1.0, 0.7, 0.45, 0.25, 0.0]   # ancho relativo por edad
ALPHA_K = [1.0, 0.8, 0.6, 0.4, 0.3]     # opacidad relativa por edad
SHARDS_FROM = 2                          # desde qué edad hay fragmentos
rng = np.random.default_rng(7)

pts = json.load(open(ROOT + 'data/blade_points.json'))
sub = pts['_sub']
items = json.load(open(ROOT + 'data/items.json'))
specs = {}
for it in items.values():
    for m in ('light', 'heavy'):
        s = it.get(m, {})
        if s.get('type') == 'melee' and 'trail_end' in s:
            specs[s['anim']] = s

yy, xx = np.mgrid[0:CELL, 0:CELL]
PX, PY = xx + 0.5 - PAD, yy + 0.5 - PAD   # coordenadas de sprite de cada píxel


def tri(p, a, b, c):  # coordenadas baricéntricas de todos los píxeles respecto al triángulo abc
    d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
    if abs(d) < 1e-6:
        return None
    l1 = ((b[1] - c[1]) * (p[0] - c[0]) + (c[0] - b[0]) * (p[1] - c[1])) / d
    l2 = ((c[1] - a[1]) * (p[0] - c[0]) + (a[0] - c[0]) * (p[1] - c[1])) / d
    return l1, l2, 1 - l1 - l2


def cell(samples, k, n, wk, ak, shards, width):
    """Tramo k de n (muestras k*sub .. (k+1)*sub) con ancho wk y opacidad ak. Devuelve RGBA CELL x CELL."""
    out = np.zeros((CELL, CELL, 4), np.float32)
    tips, ins = [], []
    for j in range(sub + 1):
        bx, by, tx, ty = samples[k * sub + j]
        t = np.array([tx, ty]); b = np.array([bx, by])
        span = b - t
        L = np.linalg.norm(span)
        tips.append(t)
        ins.append(t + span / L * min(width * wk, L) if L > 1e-6 else t)
    if wk > 0:
        for j in range(sub):
            A, B, C, D = tips[j], tips[j + 1], ins[j + 1], ins[j]
            for (v0, v1, v2, kind) in ((A, B, C, 1), (A, C, D, 2)):
                r = tri((PX, PY), v0, v1, v2)
                if r is None:
                    continue
                la, lb, lc = r
                m = (la >= -1e-4) & (lb >= -1e-4) & (lc >= -1e-4)
                if kind == 1:   # A(s0,t0) B(s1,t0) C(s1,t1)
                    s_loc, t_loc = lb + lc, lc
                else:           # A(s0,t0) C(s1,t1) D(s0,t1)
                    s_loc, t_loc = lb, lb + lc
                U = (k + (j + s_loc) / sub) / n   # 0 viejo -> 1 nuevo a lo largo de todo el barrido
                a_q = np.round((0.35 + 0.65 * U) * ak * 4) / 4   # cuatro niveles de opacidad: acabado pixel art
                tone = np.where(t_loc < 0.22, 1.0, np.where(t_loc < 0.6, 0.78, 0.5))  # borde blanco, cuerpo claro, interior tenue
                m &= a_q > 0
                out[m, 0:3] = tone[m][:, None]
                out[m, 3] = a_q[m]
    for _ in range(shards):
        j = rng.integers(0, sub + 1)
        p = tips[j] + (ins[j] - tips[j]) * rng.random() + rng.normal(0, 2.0, 2)
        sz = (2, 1) if rng.random() < 0.5 else (1, 2)
        x0, y0 = int(p[0] + PAD), int(p[1] + PAD)
        if 0 <= x0 < CELL - 2 and 0 <= y0 < CELL - 2:
            out[y0:y0 + sz[1], x0:x0 + sz[0]] = [1, 1, 1, 0.85 * ak + 0.15]
    return out


os.makedirs(ROOT + 'art/trails', exist_ok=True)
for anim, spec in specs.items():
    first, last = spec['trail_frame'], spec['trail_end']
    n = last - first
    for d, samples in pts[anim].items():
        seg = samples[first * sub:last * sub + 1]
        sheet = np.zeros((n * CELL, COLS * CELL, 4), np.float32)   # fila 0 arriba
        per = max(1, spec['trail_shards'] // n + 1)                # fragmentos por tramo
        for k in range(n):
            for c in range(COLS):
                sheet[k * CELL:(k + 1) * CELL, c * CELL:(c + 1) * CELL] = cell(
                    seg, k, n, WIDTH_K[c], ALPHA_K[c], per if c >= SHARDS_FROM else 0, spec['trail_width'])
        img = bpy.data.images.new('t', COLS * CELL, n * CELL, alpha=True)
        img.pixels = np.flipud(sheet).ravel()   # Blender guarda de abajo arriba
        img.filepath_raw = ROOT + 'art/trails/%s_%s.png' % (anim, d)
        img.file_format = 'PNG'
        img.save()
        bpy.data.images.remove(img)
print('TRAILS_OK', list(specs))
