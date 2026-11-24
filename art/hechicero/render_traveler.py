"""Run on viajero_ignis.blend. Bake the exact clips and sockets used by Godot."""
import bpy, math, json, runpy, sys
from mathutils import Vector
from pathlib import Path
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[2]
P=runpy.run_path(str(ROOT/'art/render_polish.py'))
K,B,rig,scene=P['K'],P['B'],P['RIG'],P['SCENE']
rotate=P['rotate']
cam,right,toward=K['_cam_vecs']()
scene.camera=cam
scene.render.resolution_percentage=100
scene.render.resolution_x=scene.render.resolution_y=128
out=ROOT/'art/hechicero'
names=[d[0] for d in K['DIRS']]
def cloth_motion(t,amount):
    rotate('hood.fold',amount*math.sin(t-.5))
    rotate('cape.hem',amount*2*math.sin(t-.8),0,amount*.4*math.cos(t))
    rotate('pouch',amount*math.cos(t),0,amount*.7*math.sin(t))
base_pose=P['pose_hero']
def locomotion(kind, phase):
    base_pose(kind,phase)
    if kind in ('walk','run'):
        for side,offset in [('L',0),('R',math.pi)]:
            roll=max(0,math.sin(phase*math.tau+offset))
            rotate('toe.'+side,-roll*(17 if kind=='run' else 10))
    cloth_motion(phase*math.tau,{'run':6,'walk':3,'idle':1}.get(kind,2))
P['render_hero'].__globals__['pose_hero']=locomotion
def utilities(only=None):
    tips_path=ROOT/'data/rod_tips.json'
    tips=json.loads(tips_path.read_text()) if only else {}
    for anim,n,prop in [('fish_wait',8,'ROD_HAND'),('fish_cast',6,'ROD_HAND'),('fish_reel',8,'ROD_HAND'),('chop_pick',6,'TOOL_PICK'),('chop_axe',6,'TOOL_AXE'),('pluck',6,None),('eat',6,'ITEM_FOOD'),('drink',6,'ITEM_FLASK')]:
        if only and anim not in only: continue
        hidden=K['_prep']([bpy.data.collections[prop]] if prop else [])
        fishing=anim.startswith('fish')
        size=224 if anim=='fish_cast' else (192 if fishing or anim.startswith('chop') else 128)
        scene.render.resolution_x=scene.render.resolution_y=size
        cam.data.ortho_scale=2.75*size/128
        if fishing: bpy.data.objects['Cylinder.013'].hide_render=True  # Godot draws the line to the float.
        for d,dx,dy in K['DIRS']:
            K['_facing']((right*dx+toward*dy).normalized(),rig)
            key=f'{anim}_{d}'
            if anim.startswith('fish'): tips[key]=[]
            for i in range(n):
                phase=i/max(1,n-1)
                a=math.sin(phase*math.pi)
                P['reset']()
                if anim=='fish_wait':
                    wave=math.sin(math.tau*i/n)
                    shoulder,elbow,lean=-25-2*wave,-34+2*wave,4+wave
                elif anim=='fish_cast':
                    shoulder=(-30,-70,-120,-90,-48,-24)[i]
                    elbow=(-34,-56,-68,-42,-20,-34)[i]
                    lean=(3,-3,-8,2,12,4)[i]
                elif anim=='fish_reel':
                    wave=math.cos(math.tau*i/n)
                    shoulder=-38+8*wave; elbow=-55+13*wave; lean=-1+4*wave
                elif anim.startswith('chop'):
                    shoulder=(-20,-85,-132,-84,-38,-20)[i]; elbow=(-22,-55,-70,-26,-12,-22)[i]; lean=(3,-4,-9,9,19,3)[i]
                elif anim=='pluck':
                    shoulder=-25-45*a; elbow=-24-8*a; lean=6+37*a
                else:
                    shoulder=-24-38*a; elbow=-25-77*a; lean=-5*a
                rotate('spine',lean*.55); rotate('chest',lean*.45)
                rotate('head',-lean*.25); rotate('clavicle.R',shoulder*.09)
                rotate('upper_arm.R',shoulder,0,-9); rotate('forearm.R',elbow)
                rotate('upper_arm.L',-12-8*a,0,8); rotate('forearm.L',-20-13*a)
                cloth_motion(i/n*math.tau if anim in ('fish_wait','fish_reel') else phase*math.tau,2)
                bpy.context.view_layer.update()
                if anim.startswith('fish'):
                    shaft=bpy.data.objects['Cylinder.011']
                    grip=bpy.data.objects['rodH']
                    local=grip.matrix_world.inverted()@shaft.matrix_world
                    end=max((local@v.co).y for v in shaft.data.vertices)
                    tip=grip.matrix_world@Vector((0,end,0))
                    uv=world_to_camera_view(scene,cam,tip)
                    pad=(size-128)/2
                    tips[key].append([round(size*uv.x-pad,2),round(size*(1-uv.y)-pad,2)])
                scene.render.filepath=str(out/f'{key}_{i:02d}.png')
                bpy.ops.render.render(write_still=True)
        for obj,old in hidden.items(): obj.hide_render=old
    (ROOT/'data/rod_tips.json').write_text(json.dumps(tips,separators=(',',':')))
def swings():
    K['_pose']=P['articulated']
    cam.data.ortho_scale=2.75*192/128
    K['OUT_H']=str(out/'polished')+'/'
    for fire in [False,True]:
        K['render_slash'](names,res=192,prefix='f' if fire else '',fire=fire)
    for side in ('R','L'):
        B['shin.'+side].constraints['Plant ankle'].influence=0
    P['reset']()
    K['OUT_H']=str(out)+'/'
    K['render_megadash'](names,res=192)
    cam.data.ortho_scale=2.75

if 'cast_rod' in sys.argv:
    utilities(['fish_cast'])
elif 'fishing' in sys.argv:
    utilities(['fish_cast','fish_reel','fish_wait'])
elif 'wide' in sys.argv:
    P['render_hero'](names,False,only=['run'])
    swings()
    utilities(['chop_pick','chop_axe'])
elif 'portrait' not in sys.argv:
    P['render_hero'](names,False)
    swings()
    K['render_cast'](names)
    K['render_dash'](names)
    utilities()
K['_prep']([])
K['_facing']((right+toward).normalized(),rig)
locomotion('idle',0.2)
# El diálogo usa un busto, con el rostro dirigido hacia el interlocutor.
forward=cam.matrix_world.to_quaternion() @ Vector((0,0,-1))
cam.location=Vector((0,0,1.81))-forward*8
cam.data.ortho_scale=1.06
scene.render.resolution_x=scene.render.resolution_y=448
scene.eevee.taa_render_samples=32
scene.render.filepath=str(ROOT/'blender/viajero_busto_base.png')
bpy.ops.render.render(write_still=True)
print('TRAVELER_COMPLETE')
