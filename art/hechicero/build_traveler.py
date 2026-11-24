"""Viajero de Ignis: pelo castaño revuelto, lino oliva remendado, capucha caída,
capa de lana raída, pantalón holgado y botas envueltas. Luz cálida, sin armadura."""
from pathlib import Path
import bpy, math, sys, runpy
from mathutils import Vector, Matrix
ROOT = Path(__file__).resolve().parents[2]
P = runpy.run_path(str(ROOT/'art/render_polish.py'))
rig, B, K = P['RIG'], P['B'], P['K']
scene = bpy.context.scene
P['reset']()
rig.rotation_euler.z = 0
for o in list(rig.children):
    if o.name.startswith(('Swept horn','Elven ear','Gold','Greave gold','Chest wing','Shoulder armor','Mantle gold','Mantle side','Bracer filigree','Hem ornamental','Belt sun','Ruby clasp','Split coat','Hood','Cheek marking','Staff','Flame ribbon','Spell heart','Fire bounce')):
        bpy.data.objects.remove(o, do_unlink=True)

def material(name, rgb):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb,1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*rgb,1)
    bsdf.inputs['Roughness'].default_value = .93
    bsdf.inputs['Specular IOR Level'].default_value = .10
    return mat

skin=material('Piel tostada',(.64,.39,.24))
hair=material('Castaño cobrizo',(.14,.052,.027))
wool=material('Lana de nogal',(.115,.067,.040))
leather=material('Cuero encerado',(.125,.070,.039))
thread=material('Ataduras de lino',(.33,.232,.139))
pants=material('Calzas de tierra',(.14,.105,.080))
wood=material('Avellana oscura',(.053,.028,.019))
linen=material('Lino pintado en Krita',(.32,.26,.166))
im=bpy.data.images.load(str(ROOT/'blender/lino_viajero.png'))
im.pack()
tex=linen.node_tree.nodes.new('ShaderNodeTexImage')
tex.image=im
tex.interpolation='Closest'
linen.node_tree.links.new(tex.outputs['Color'],linen.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
for o in rig.children:
    if o.type!='MESH' or o.parent_bone: continue
    m=skin if o.name.startswith(('Angular','Pointed chin','Throat','Finger','Thumb','Palm','Nose','Bracer')) else hair if o.name.startswith(('Hair','Sculpted hair','Swept fringe','Brow')) else wood if o.name.startswith(('Eye','Burning','Mouth')) else wool if 'mantle' in o.name else pants if o.name.startswith(('Trouser','Pelvis')) else linen if o.name.startswith(('Upper sleeve','Sculpted cuirass')) else leather
    if o.data.materials: o.data.materials[0]=m

# Anillos con UV longitudinales; cada hilera sigue su articulación.
def cloth(name, rows, mat, n=12, rag=False):
    vertices=[]; faces=[]
    for j,(x,y,z,rx,ry,bone) in enumerate(rows):
        for i in range(n):
            a=math.tau*i/n
            vertices.append((x+rx*math.sin(a),y-ry*math.cos(a),z-(.033*(i%3) if rag and j==0 else 0)))
    for j in range(len(rows)-1):
        for i in range(n):
            k=j*n+i; q=j*n+(i+1)%n
            faces.append((k,q,q+n,k+n))
    faces.extend([tuple(reversed(range(n))),tuple(range(len(vertices)-n,len(vertices)))])
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(vertices,[],faces); mesh.update()
    o=bpy.data.objects.new(name,mesh); rig.users_collection[0].objects.link(o); o.parent=rig
    mesh.materials.append(mat)
    uv=mesh.uv_layers.new()
    for j,poly in enumerate(mesh.polygons[:-2]):
        u=(j%n)/n; v=(j//n)/(len(rows)-1)
        for idx,xy in zip(poly.loop_indices,[(u,v),(u+1/n,v),(u+1/n,v+1/(len(rows)-1)),(u,v+1/(len(rows)-1))]): uv.data[idx].uv=xy
    for j,row in enumerate(rows):
        g=o.vertex_groups.get(row[-1]) or o.vertex_groups.new(name=row[-1])
        g.add(list(range(j*n,(j+1)*n)),1,'REPLACE')
    mod=o.modifiers.new('Costura al esqueleto','ARMATURE'); mod.object=rig
    return o

bpy.context.view_layer.objects.active=rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for name,parent,head,tail in [('hood.fold','chest',(0,.12,1.68),(0,.22,1.52)),('cape.hem','cape',(0,.24,1.13),(0,.33,.7)),('pouch','root',(.22,0,1.1),(.25,0,.88))]:
    bone=rig.data.edit_bones.new(name); bone.head=head; bone.tail=tail; bone.parent=rig.data.edit_bones[parent]
neck=rig.data.edit_bones.new('neck')
neck.head=(0,0,1.61); neck.tail=(0,0,1.70)
neck.parent=rig.data.edit_bones['chest']; rig.data.edit_bones['head'].parent=neck
for side in ['L','R']:
    foot=rig.data.edit_bones['foot.'+side]
    toe=rig.data.edit_bones.new('toe.'+side)
    toe.head=foot.head.lerp(foot.tail,.58)
    toe.tail=foot.tail.copy()
    toe.parent=foot
    for i in range(4):
        obj=bpy.data.objects['Finger '+side+str(i)]
        points=[obj.matrix_world@v.co for v in obj.data.vertices]
        center=sum(points,Vector())/len(points)
        finger=rig.data.edit_bones.new(f'digit.{i}.{side}')
        finger.head=center+Vector((0,0,.025)); finger.tail=center-Vector((0,0,.025))
        finger.parent=rig.data.edit_bones['hand.'+side]
        obj.vertex_groups['hand.'+side].name=finger.name
bpy.ops.object.mode_set(mode='OBJECT')
for side in ('L','R'):
    foot_name='foot.'+side
    toe=rig.data.bones['toe.'+side]
    axis=toe.tail_local-toe.head_local
    for obj in rig.children:
        if obj.type!='MESH' or not obj.vertex_groups.get(foot_name): continue
        base=obj.vertex_groups[foot_name]
        tip=obj.vertex_groups.new(name=toe.name)
        for vert in obj.data.vertices:
            original=next((g.weight for g in vert.groups if g.group==base.index),0)
            if original<=0: continue
            local=rig.matrix_world.inverted() @ obj.matrix_world @ vert.co
            weight=original*min(1,max(0,(local-toe.head_local).dot(axis)/axis.length_squared))
            if weight:
                tip.add([vert.index],weight,'REPLACE')
                base.add([vert.index],original-weight,'REPLACE')
cape=bpy.data.objects.get('Flowing midnight mantle')
if cape:
    group=cape.vertex_groups.new(name='cape.hem')
    for v in cape.data.vertices:
        z=(cape.matrix_world@v.co).z
        weight=min(1,max(0,(1.22-z)/.48))
        if weight: group.add([v.index],weight,'REPLACE')
cloth('Túnica de viaje',[(0,0,.91,.29,.20,'root'),(0,0,1.11,.229,.171,'root'),(0,0,1.31,.263,.185,'spine'),(0,0,1.59,.307,.192,'chest'),(0,0,1.68,.14,.124,'chest')],linen,16,True)
cloth('Cinturón',[(0,0,1.09,.249,.186,'root'),(0,0,1.16,.25,.188,'root')],leather)
cloth('Capucha recogida',[(0,.142,1.48,.19,.127,'hood.fold'),(0,.10,1.63,.278,.18,'hood.fold'),(0,.04,1.70,.245,.186,'chest'),(0,.02,1.73,.151,.139,'chest')],wool)
cloth('Bolsa',[(.25,-.04,.9,.084,.07,'pouch'),(.26,-.05,1.055,.097,.082,'pouch'),(.24,-.035,1.12,.059,.055,'root')],leather,8)
for side,k in [('L',1),('R',-1)]:
    thigh='thigh.'+side; shin='shin.'+side; arm='upper_arm.'+side; fore='forearm.'+side
    cloth('Bombacha '+side,[(k*.17,0,.32,.083,.083,shin),(k*.17,.008,.43,.119,.128,shin),(k*.16,0,.59,.108,.12,shin),(k*.15,0,.81,.14,.145,thigh),(k*.13,0,1.035,.135,.125,thigh)],pants)
    cloth('Manga '+side,[(k*.445,-.016,1.25,.083,.084,fore),(k*.427,0,1.31,.116,.112,arm),(k*.36,0,1.47,.122,.123,arm),(k*.295,0,1.62,.113,.12,arm)],linen)
    cloth('Puño '+side,[(k*.442,-.014,1.25,.093,.094,fore),(k*.432,-.009,1.305,.108,.103,fore)],thread)
    for j in range(3):
        z=.20+.061*j
        cloth('Vuelta de bota '+side+str(j),[(k*.174,0,z,.095,.111,shin),(k*.174,.0,z+.026,.101,.114,shin)],thread)
    cloth('Oreja '+side,[(k*.144,-.03,1.922,.019,.024,'head'),(k*.15,-.024,1.973,.031,.037,'head'),(k*.148,-.02,2.005,.021,.028,'head')],skin,8)
# Resting eyes, with a small warm catchlight instead of the old spell glow.
for side,k in [('L',1),('R',-1)]:
    cloth('Reflejo '+side,[(k*.056,-.17,2.012,.009,.004,'head'),(k*.056,-.17,2.023,.009,.004,'head')],thread,6)
# Cabeza humana y mechones cortos con puntas independientes para la vista de perfil.
for o in list(rig.children):
    if o.name.startswith(('Angular demon','Pointed chin','Hair crown','Sculpted hair','Swept fringe','Eye socket','Burning eye','Brow ','Mouth','Reflejo','Nose bridge','Sculpted cuirass','Upper sleeve')):
        bpy.data.objects.remove(o,do_unlink=True)
def head_part(name,rows,mat,n=12):
    obj=cloth(name,[(*row,'head') for row in rows],mat,n)
    for poly in obj.data.polygons: poly.use_smooth=True
    return obj
head_part('Rostro',[(0,-.063,1.804,.041,.047),(0,-.061,1.828,.082,.077),(0,-.049,1.886,.119,.097),(0,-.043,1.956,.151,.12),(0,-.040,2.03,.152,.12),(0,-.023,2.103,.145,.127),(0,-.008,2.15,.097,.096)],skin,24)
almond=material('Marfil del ojo',(.72,.64,.49))
iris=material('Iris avellana',(.12,.072,.025))
lip=material('Sombra de labios',(.27,.114,.075))
for side,k in [('L',1),('R',-1)]:
    x=k*.066
    head_part('Ojo '+side,[(x,-.151,1.986,.017,.008),(x,-.153,1.998,.043,.014),(x,-.151,2.011,.034,.009)],almond)
    head_part('Iris '+side,[(x,-.165,1.986,.009,.004),(x,-.166,1.998,.014,.005),(x,-.165,2.011,.01,.004)],iris)
    head_part('Pupila '+side,[(x,-.171,1.993,.006,.002),(x,-.171,2.006,.006,.002)],wood)
    head_part('Ceja '+side,[(x,-.149,2.022,.038,.009),(x+k*.004,-.150,2.034,.042,.009),(x+k*.009,-.147,2.038,.023,.007)],hair)
head_part('Nariz',[(0,-.162,1.933,.023,.015),(0,-.173,1.945,.024,.022),(0,-.16,1.967,.014,.016),(0,-.151,2.003,.010,.012)],skin)
head_part('Labios',[(0,-.146,1.899,.027,.005),(0,-.150,1.905,.039,.006),(0,-.148,1.909,.028,.004)],lip)
head_part('Cabello',[(0,.019,2.012,.153,.127),(0,.013,2.103,.169,.144),(0,.016,2.172,.137,.134),(-.019,.023,2.211,.050,.063)],hair,20)
auburn=material('Mechas al sol',(.174,.065,.03))
for i in range(21):
    a=math.tau*i/21
    x,y=math.sin(a),-math.cos(a)
    crown=2.144+.027*math.sin(i*2.31)
    fringe=2.057 if y<-.48 else 1.995 if y<.2 else 1.954
    end=fringe+.036*math.sin(i*1.93)
    head_part('Mechón '+str(i),[(.17*x+.027*math.cos(a),.014+.145*y,end,.005,.005),(.159*x,.014+.137*y,end+.065,.042,.039),(.133*x-.016,.018+.121*y,crown,.046,.042),(.068*x-.018,.025+.062*y,crown+.049,.017,.016)],auburn if i%4==1 else hair,7)
# Cordones cruzados y escote abierto sobre el frente de la túnica.
def patch(name, pts, bone, mat):
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(pts,[],[tuple(range(len(pts)))])
    o=bpy.data.objects.new(name,mesh); rig.users_collection[0].objects.link(o); o.parent=rig
    mesh.materials.append(mat); g=o.vertex_groups.new(name=bone); g.add(list(range(len(pts))),1,'REPLACE')
    o.modifiers.new('Costura','ARMATURE').object=rig
patch('Escote de lino',[(-.095,-.165,1.67),(.092,-.165,1.67),(0,-.207,1.46)],'chest',skin)
for k in [-1,1]:
    patch('Solapa',[(k*.115,-.157,1.683),(k*.081,-.175,1.678),(.0,-.214,1.461),(k*.024,-.21,1.455)],'chest',thread)
    for z in [1.52,1.56]:
        patch('Lazada',[(k*-.042,-.213,z+.024),(k*.040,-.213,z),(k*.040,-.213,z+.012),(k*-.042,-.213,z+.036)],'chest',leather)
patch('Remiendo',[(-.25,-.112,.994),(-.12,-.191,.985),(-.115,-.197,.918),(-.24,-.125,.907)],'root',wool)
# Abertura irregular de la capa; se conserva la malla con sus pesos de piel.
for v in cape.data.vertices:
    world=cape.matrix_world@v.co
    if world.z<1.0:
        amount=(1.0-world.z)/.4
        world.z-=amount*(.11+.09*math.sin(world.x*39)+.05*math.sin(world.x*61))
        v.co=cape.matrix_world.inverted()@world
for side in ('L','R'):
    for i in range(4):
        pb=B[f'digit.{i}.{side}']
        pb.rotation_mode='XYZ'
        curve=pb.driver_add('rotation_euler',0)
        driver=curve.driver
        var=driver.variables.new(); var.name='bend'; var.type='TRANSFORMS'
        target=var.targets[0]; target.id=rig; target.bone_target='forearm.'+side
        target.transform_type='ROT_X'; target.transform_space='LOCAL_SPACE'
        driver.expression='min(0.48,abs(bend)*0.24)'
bpy.data.objects['Cool rim'].data.energy=200
bpy.data.objects['Face fill'].data.color=(.97,.90,.80)
bpy.context.view_layer.update()
scene.render.film_transparent=True
scene.render.filter_size=.01
scene.eevee.taa_render_samples=4
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/viajero_ignis.blend'))
