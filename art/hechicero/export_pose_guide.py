"""Export projected rig joints and tool sockets, without rendering a single mesh."""
import bpy
import json
import os
import runpy
import sys
from pathlib import Path
from types import ModuleType, SimpleNamespace
from mathutils import Vector

root = Path(__file__).resolve().parents[2]
scene = bpy.context.scene
rig = bpy.data.objects['HECHICERO_RIG']
frames = {}

def capture(**kwargs):
    bpy.context.view_layer.update()
    cam = scene.camera
    size = scene.render.resolution_x
    if size == 448:
        return
    matrix = cam.matrix_world.inverted()
    def project(world):
        v = matrix @ world
        return [round(size*(.5+v.x/cam.data.ortho_scale),2), round(size*(.5-v.y/cam.data.ortho_scale),2), round(-v.z,4)]
    def bone(name, tail=False):
        b = rig.pose.bones[name]
        return project(rig.matrix_world @ (b.tail if tail else b.head))
    joints = {name:bone(name) for name in ('root','spine','chest','head','hood.fold','pouch','cape.hem')}
    joints['crown'] = bone('head', True)
    joints['hem'] = bone('cape.hem', True)
    for side in ('L','R'):
        for name in ('upper_arm','forearm','hand','thigh','shin','foot'):
            joints[name+'.'+side] = bone(name+'.'+side)
        joints['toe.'+side] = bone('toe.'+side,True)
        joints['fingers.'+side] = bone('hand.'+side,True)
    blade = bpy.data.objects['hd_sword'].matrix_world
    joints['blade'] = project(blade @ Vector((0,.735,.024)))
    joints['hilt'] = project(blade @ Vector((0,.12,0)))
    rod = bpy.data.objects['rodH'].matrix_world
    joints['rod'] = project(rod @ Vector((0,.85,0)))
    for key,name in [('axe','axeH'),('pick','pickH')]:
        tool=bpy.data.objects[name]
        pts=[o.matrix_world@v.co for o in tool.children if o.type=='MESH' for v in o.data.vertices]
        joints[key]=project(max(pts,key=lambda p:(p-tool.matrix_world.translation).length))
    frames[Path(scene.render.filepath).name] = [size,joints]

# The original pose samplers call one Blender render operator per game frame.
# Substitute only that operator in this background process so both paths sample identical poses.
class Operators:
    render = SimpleNamespace(render=capture)
    def __getattr__(self, name):
        return getattr(bpy.ops, name)
proxy=ModuleType('bpy')
proxy.__dict__.update(bpy.__dict__)
proxy.ops=Operators()
sys.modules['bpy']=proxy
runpy.run_path(str(root/'art/hechicero/render_traveler.py'))
assert len(frames)==1328, len(frames)
Path(os.environ['ASTRAL_POSES']).write_text(json.dumps(frames,separators=(',',':')),encoding='utf8')
