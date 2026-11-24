import bpy, json, math
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

# Calibra los dos puntos del filo (cerca de la base y cerca de la punta) a lo largo de cada tajo, para las 8 direcciones.
# Usa las mismas poses y cámara que build_katana.render_slash, así que coincide con los PNG de art/hechicero/polished.
# Entre un fotograma y el siguiente interpola la pose SUB veces: da la curva del barrido; en cada fotograma entero el punto es
# exactamente el filo que se ve en el sprite. Una espada con otra animación: añade su tabla a SLASH en build_katana.py y repite.
# Uso: blender -b blender/hechicero_floor.blend -P art/katana/calibrate_blade.py
# Escribe data/blade_points.json: {"_sub": SUB, "slash_<tipo>": {dir: [[bx, by, tx, ty] por muestra]}}; la muestra i*SUB es el fotograma i.
# Coordenadas en píxeles de un sprite de 128 px (origen arriba a la izquierda); pueden salirse del lienzo si la hoja sale del encuadre.
from pathlib import Path
from runpy import run_path
polish = run_path(str(Path(__file__).resolve().parents[1] / 'render_polish.py'))
ns = polish['K']
if 'KATANA_HAND' not in bpy.data.collections:
    ns['build_all']()
OUT = r'C:/Users/Mateo/Documents/astral/data/blade_points.json'
RES, SUB = 128, 4
BASE_Y, TIP_Y = 0.12, 0.735   # a lo largo de la hoja (m, ejes locales de la espada; la hoja mide 0.70 + punta)
SORI = 0.024                  # la hoja se curva hacia +Z: z = SORI * t^2

s = bpy.context.scene
s.render.resolution_x = s.render.resolution_y = RES
s.render.resolution_percentage = 100
rig = bpy.data.objects['HECHICERO_RIG']
sword = bpy.data.objects['hd_sword']
cam, right, toward = ns['_cam_vecs']()
rig.animation_data.action = None


def blade_pt(y):
    t = min(y / 0.70, 1.0)
    w = sword.matrix_world @ Vector((0, y, SORI * t * t))
    v = world_to_camera_view(s, cam, w)
    return [round(v.x * RES, 1), round((1.0 - v.y) * RES, 1)]


def lerp_pose(a, b, u):
    f = lambda x, y: x + (y - x) * u
    return {k: tuple(f(x, y) for x, y in zip(a[k], b[k])) if isinstance(a[k], tuple) else f(a[k], b[k]) for k in a}


def sample(p):
    polish['articulated'](rig, p)
    return blade_pt(BASE_Y) + blade_pt(TIP_Y)


out = {'_sub': SUB}
for kind, poses in ns['SLASH'].items():
    out['slash_' + kind] = {}
    for name, dx, dy in ns['DIRS']:
        ns['_facing']((right * dx + toward * dy).normalized(), rig)
        pts = [sample(lerp_pose(poses[k], poses[k + 1], j / SUB)) for k in range(len(poses) - 1) for j in range(SUB)]
        pts.append(sample(poses[-1]))
        out['slash_' + kind][name] = pts
with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(out, f, separators=(',', ':'))
    f.write('\n')
print('CALIB_OK', OUT)
