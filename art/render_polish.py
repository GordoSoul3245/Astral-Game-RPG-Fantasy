"""Blender --background blender/hechicero_floor.blend --python art/render_polish.py -- [preview|all]."""
import bpy
import math
import sys
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
K = {}
exec((ROOT / 'art/katana/build_katana.py').read_text(encoding='utf-8'), K)
RIG = bpy.data.objects['HECHICERO_RIG']
B = RIG.pose.bones
SCENE = bpy.context.scene
OUT = ROOT / 'art/hechicero/polished'
OUT.mkdir(exist_ok=True)


def reset():
    RIG.animation_data.action = None
    for b in B:
        b.rotation_mode = 'XYZ'
        b.matrix_basis = Matrix.Identity(4)


def rotate(name, x=0, y=0, z=0):
    B[name].rotation_euler = tuple(math.radians(v) for v in (x, y, z))


def root_offset(x=0, y=0, z=0):
    B['root'].location = B['root'].bone.matrix_local.to_3x3().inverted() @ Vector((x, y, z))


def place_bone(name, head, tail):
    b = B[name]
    rest = b.bone
    q = (rest.tail_local - rest.head_local).rotation_difference(tail - head)
    orientation = q.to_matrix() @ rest.matrix_local.to_3x3()
    b.matrix = Matrix.Translation(head) @ orientation.to_4x4()
    bpy.context.view_layer.update()


def leg(side, ankle):
    """Two-bone solve: planted ankle stays fixed while the pelvis shifts."""
    bpy.context.view_layer.update()
    thigh, shin, foot = (B[n + '.' + side] for n in ('thigh', 'shin', 'foot'))
    parent = B['root'].matrix @ B['root'].bone.matrix_local.inverted()
    hip = parent @ thigh.bone.head_local
    delta = ankle - hip
    length = delta.length
    assert length < thigh.length + shin.length, (side, length, 'unreachable foot')
    axis = delta.normalized()
    along = (thigh.length**2 - shin.length**2 + length**2) / (2 * length)
    bend = Vector((0, -1, 0))
    bend = (bend - axis * bend.dot(axis)).normalized()
    knee = hip + axis * along + bend * math.sqrt(max(0, thigh.length**2 - along**2))
    place_bone(thigh.name, hip, knee)
    place_bone(shin.name, knee, ankle)
    foot.matrix = Matrix.Translation(ankle) @ foot.bone.matrix_local.to_3x3().to_4x4()
    bpy.context.view_layer.update()


def pose_hero(kind, phase):
    reset()
    p = phase * math.tau
    running = kind == 'run'
    idle = kind in ('idle', 'hurt', 'death')
    sway = 0 if idle else 0.025 * math.cos(p)
    root_offset(sway, 0, -0.035 if idle else (-0.24 if running else -0.18) - 0.02 * math.cos(2*p))
    rotate('spine', (1.5 * math.sin(p) if idle else (12 if running else 4)),
           0 if idle else 4 * math.cos(p), 0 if idle else -2 * math.cos(p))
    rotate('head', -0.7 * math.sin(p - 0.4) if idle else -3, 0, 0)
    for side, offset, sign in [('L', 0, 1), ('R', 0.5, -1)]:
        q = (phase + offset) % 1.0
        stride = 1.12 if running else 0.96
        stance = 0.52 if running else 0.62
        if idle:
            y, lift = 0.01, 0.0
        elif q < stance:
            y, lift = -stride/2 + stride*q/stance, 0.0
        else:
            u = (q-stance)/(1-stance)
            y = stride/2 - stride*(u*u*(3-2*u))
            lift = (0.18 if running else 0.10) * math.sin(math.pi*u)
        leg(side, Vector((sign * 0.18, y, 0.16 + lift)))
        arm = (-18 if running else -8) + (0 if idle else 12 * math.cos(p + offset*math.tau))
        rotate('upper_arm.'+side, arm + 1.4*math.sin(p-0.6), 0, sign*6)
        rotate('forearm.'+side, -35 if running else -18)
        rotate('hand.'+side, 2*math.sin(p-1.0+offset), 0, 0)
    rotate('cape', (12 if running else 3) + (2 if idle else 5)*math.sin(p-0.8), 0, 1.5*math.sin(p-1.1))
    for i in range(8):
        rotate('coat.'+str(i), (1.4 if idle else 4)*math.sin(p-0.65-i*0.45), 0,
               (0.8 if idle else 2)*math.sin(p-i*0.45))
    if kind in ('hurt', 'death'):
        t = phase
        amount = math.sin(math.pi*t) if kind == 'hurt' else t*t*(3-2*t)
        root_offset(0, 0, -0.035 - (0.06 if kind == 'hurt' else 0.48)*amount)
        rotate('spine', (-12 if kind == 'hurt' else 65)*amount)
        rotate('head', 18*amount)
        rotate('upper_arm.L', -30*amount, 0, 12)
        rotate('upper_arm.R', -25*amount, 0, -12)
        bpy.context.view_layer.update()
        for side, sign in [('L',1),('R',-1)]:
            leg(side, Vector((sign*0.18, 0.01, 0.16)))
    bpy.context.view_layer.update()


def render_hero(names, preview):
    cam, right, toward = K['_cam_vecs']()
    hidden = K['_prep']([])
    SCENE.camera = cam
    for name, dx, dy in K['DIRS']:
        if name not in names:
            continue
        K['_facing']((right*dx+toward*dy).normalized(), RIG)
        for kind, count in [('idle',16), ('walk',16), ('run',16), ('hurt',6), ('death',12)]:
            if 'locomotion' in sys.argv and kind not in ('walk', 'run'):
                continue
            if 'hero_death' in sys.argv and kind != 'death':
                continue
            size = 192 if kind == 'death' else 128
            SCENE.render.resolution_x = SCENE.render.resolution_y = size
            cam.data.ortho_scale = 2.75 * size / 128
            for i in (range(0,count, max(1,count//4)) if preview else range(count)):
                pose_hero(kind, i/(count-1) if kind in ('hurt','death') else i/count)
                SCENE.render.filepath = str(OUT / f'{kind}_{name}_{i:02d}.png')
                bpy.ops.render.render(write_still=True)
    SCENE.render.resolution_x = SCENE.render.resolution_y = 128
    cam.data.ortho_scale = 2.75
    for o, v in hidden.items():
        o.hide_render = v


def render_attacks(names):
    # Keep hit-frame indices; add torso follow-through and delayed fabric at existing poses.
    original = K['_pose']
    def articulated(rig, p):
        original(rig, p)
        t = p['sp'][1]
        rotate('head', -p['sp'][0]*0.3, -t*0.3, 0)
        rotate('cape', 5 + abs(t)*0.14, 0, -t*0.15)
        for j in range(8):
            rotate('coat.'+str(j), 3 + abs(t)*0.07, 0, -t*0.09)
        root_offset(0.025*t/45, 0, -0.045)
        bpy.context.view_layer.update()
        for side, sign in [('L',1),('R',-1)]:
            leg(side, Vector((sign*0.18, -0.08 if side == 'R' else 0.08, 0.16)))
    K['_pose'] = articulated
    K['OUT_H'] = str(OUT) + '/'
    if 'KATANA_HAND' not in bpy.data.collections:
        K['build_all']()
    K['render_slash'](names)
    if 'KATANA_FLAME' not in bpy.data.collections:
        K['add_flames']()
    K['render_slash'](names, prefix='f', fire=True)


def render_dragon(names, preview):
    d = {}
    exec((ROOT/'art/dragon/build_dragon.py').read_text(encoding='utf-8'), d)
    if 'dr_root' not in bpy.data.objects:
        d['build']()
    cam = bpy.data.objects['SpriteCam']
    cam.data.ortho_scale *= 1.25
    d['render'](names, res=160, kinds=(('death',12),))
    cam.data.ortho_scale /= 1.25


if __name__ == '__main__':
    preview = 'preview' in sys.argv
    SCENE.render.resolution_x = SCENE.render.resolution_y = 128
    SCENE.render.resolution_percentage = 100
    SCENE.render.film_transparent = True
    SCENE.render.filter_size = 0.0
    SCENE.eevee.taa_render_samples = 16
    names = ['S'] if preview else [v[0] for v in K['DIRS']]
    render_hero(names, preview)
    if 'locomotion' not in sys.argv and 'hero_death' not in sys.argv:
        render_attacks(names)
        render_dragon(names, preview)
    print('POLISH_RENDER_COMPLETE', flush=True)
