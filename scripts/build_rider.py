"""Fit racing leathers and original equipment to the CC0 MakeHuman anatomical body."""
import os
exec(open(os.path.join(os.path.dirname(__file__), 'build_models.py')).read().split("if '--rider-only'")[0])

leather=mapped('Jacket leather','rider_suit',.61)
limb=mapped('Suit limbs','rider_limb',.65)
helm=mapped('Helmet','rider_helmet',.24,.18)
trim=mat('Jacket seam',(.24,.26,.27),0,.65)
glass=mat('Glass',(.022,.053,.072),.72,.095)
armor=mat('Molded protectors',(.035,.042,.050),.04,.48)
bones={'hips':((0,0,.93),(0,0,1.08)), 'spine':((0,0,1.06),(0,0,1.52)), 'head':((0,0,1.54),(0,0,1.91))}
for side,x in [('L',-.21),('R',.21)]:
 bones['upper_arm_'+side]=((x,0,1.47),(x*1.14,0,1.16));bones['forearm_'+side]=((x*1.14,0,1.16),(x*1.2,0,.88));bones['thigh_'+side]=((-.13 if side=='L' else .13,0,.98),(-.1404 if side=='L' else .1404,0,.55));bones['shin_'+side]=((-.1404 if side=='L' else .1404,0,.55),(-.1456 if side=='L' else .1456,0,.13))
bpy.ops.object.armature_add();rig=bpy.context.object;rig.name='RiderRig';bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0]);root=rig.data.edit_bones.new('root');root.head=(0,0,0);root.tail=(0,0,.2)
for name,(a,b) in bones.items():
 eb=rig.data.edit_bones.new(name);eb.head=a;eb.tail=b;eb.parent=root
bpy.ops.object.mode_set(mode='OBJECT')
def bind(o,bone):
 vg=o.vertex_groups.new(name=bone);vg.add(list(range(len(o.data.vertices))),1,'REPLACE');mod=o.modifiers.new('Rig deformation','ARMATURE');mod.object=rig;o.parent=rig
 return o

def loft(name,rings,material,bone,origin=Vector((0,0,0)),basis=None):
 # Duplicated seam vertices keep decals continuous around the cylindrical UV wrap.
 n=40;verts=[];faces=[];uvs=[]
 for j,(z,rx,ry,cy) in enumerate(rings):
  for i in range(n+1):
   a=i*math.tau/n;v=Vector((rx*math.cos(a),cy+ry*math.sin(a),z))
   verts.append(tuple(origin+(basis@v if basis else v)));uvs.append((i/n*(2 if name.startswith(('upper_arm','forearm','thigh','shin')) else 1),1-j/(len(rings)-1) if name.startswith(('upper_arm','forearm','thigh','shin')) else j/(len(rings)-1)))
 for j in range(len(rings)-1):
  for i in range(n):
   k=j*(n+1)+i;faces.append((k,k+1,k+n+2,k+n+1))
 faces.extend([tuple(reversed(range(n))),tuple((len(rings)-1)*(n+1)+i for i in range(n))])
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();uv=mesh.uv_layers.new(name='UVMap')
 for p in mesh.polygons:
  for idx in p.loop_indices:uv.data[idx].uv=uvs[mesh.loops[idx].vertex_index]
 obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);finish(obj,name,material)
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
 sub=obj.modifiers.new('Tailored surface','SUBSURF');sub.levels=1;bpy.ops.object.modifier_apply(modifier=sub.name)
 return bind(obj,bone)
exec(compile(open(os.path.join(ROOT,'scripts/build_human_body.py')).read(),os.path.join(ROOT,'scripts/build_human_body.py'),'exec'))
# A single full-face shell: narrow jaw, swept chin and crown. Visor conforms to shell.
loft('Full face shell',[(1.64,.096,.117,.027),(1.67,.122,.149,.027),(1.71,.136,.158,.016),(1.755,.143,.157,.007),(1.80,.139,.157,0),(1.85,.119,.139,-.008),(1.89,.075,.095,-.014),(1.906,.008,.012,-.015)],helm,'head')
verts=[];faces=[]
for z,rx,ry,cy in [(1.735,.142,.162,.012),(1.775,.145,.163,.007),(1.821,.132,.155,-.001)]:
 for i in range(25):
  a=.10+(math.pi-.20)*i/24;verts.append((rx*math.cos(a),cy+ry*math.sin(a),z))
for j in range(2):
 for i in range(24):
  k=j*25+i;faces.append((k,k+1,k+26,k+25))
mesh=bpy.data.meshes.new('Wraparound visor');mesh.from_pydata(verts,[],faces);mesh.update();obj=bpy.data.objects.new('Wraparound visor',mesh);bpy.context.collection.objects.link(obj);finish(obj,obj.name,glass);bind(obj,'head')
for side in [-1,1]:
 bind(tube('Visor hinge',(side*.141,.022,1.776),(side*.147,.022,1.776),.016,dark),'head')
 bind(cube('Chin intake',(side*.035,.171,1.678),(.044,.008,.012),black,.004),'head')
 bind(cube('Crown vent',(side*.047,.098,1.877),(.025,.032,.009),black,.004),'head')
# Fit the helmet shell to the anatomical head, leaving a short fabric-covered neck.
for obj in bpy.context.scene.objects:
 if obj.type=='MESH' and obj!=body:
  inverse=obj.matrix_world.inverted()
  for vertex in obj.data.vertices:
   p=obj.matrix_world@vertex.co
   p.x*=.94;p.y*=.94;p.z=1.54+(p.z-1.54)*.86
   vertex.co=inverse@p
# Tailor protectors to the actual skinned body, sharing its blended weights.
# Surface patches avoid floating rigid shells when shoulders and knees flex.
def fitted_protector(name,center,radius,material,depth):
 center=Vector(center);radius=Vector(radius)
 selected=[]
 for face in body.data.polygons:
  q=face.center-center
  distance=sum((q[i]/radius[i])**2 for i in range(3))
  if distance<1:selected.append(face)
 indices=sorted({i for face in selected for i in face.vertices})
 if not indices:raise RuntimeError('Empty fitted protector: '+name)
 remap={old:new for new,old in enumerate(indices)}
 verts=[]
 for index in indices:
  v=body.data.vertices[index];q=v.co-center
  distance=min(1,sum((q[i]/radius[i])**2 for i in range(3)))
  verts.append(v.co+v.normal*(.003+depth*(1-distance)))
 mesh=bpy.data.meshes.new(name)
 mesh.from_pydata(verts,[],[tuple(remap[i] for i in face.vertices) for face in selected]);mesh.update()
 obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);finish(obj,name,material)
 uv=mesh.uv_layers.new(name='UVMap')
 for new_face,old_face in zip(mesh.polygons,selected):
  for new_loop,old_loop in zip(new_face.loop_indices,old_face.loop_indices):
   uv.data[new_loop].uv=body.data.uv_layers.active.data[old_loop].uv
 for group in body.vertex_groups:
  vg=obj.vertex_groups.new(name=group.name)
  for index in indices:
   for influence in body.data.vertices[index].groups:
    if influence.group==group.index:vg.add([remap[index]],influence.weight,'REPLACE')
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
 sub=obj.modifiers.new('Rounded protector boundary','SUBSURF');sub.levels=2;bpy.ops.object.modifier_apply(modifier=sub.name)
 mod=obj.modifiers.new('Shared anatomical skinning','ARMATURE');mod.object=rig;obj.parent=rig
 return obj
fitted_protector('Tailored back hump',(0,-.075,1.415),(.105,.12,.10),leather,.022)
for side,sign in [('L',-1),('R',1)]:
 fitted_protector('Shoulder armor '+side,(sign*.24,0,1.44),(.085,.11,.072),armor,.009)
 fitted_protector('Elbow reinforcement '+side,(sign*.24,-.045,1.18),(.063,.065,.065),armor,.006)
 fitted_protector('Knee slider '+side,(sign*.14,.065,.575),(.073,.065,.062),armor,.012)
 fitted_protector('Glove protection '+side,(sign*.25,-.018,.915),(.06,.05,.047),armor,.004)
# Structured motorcycle boots cover the anatomical ankles with a toe box and cuff.
for side in ['L','R']:
 x=-.1456 if side=='L' else .1456
 name='shin_'+side
 boot=body_form('Racing boot '+side,[(-.09,.045,.045,.095),(-.035,.074,.067,.108),(.055,.077,.061,.100),(.155,.073,.042,.080),(.225,.045,.032,.073)],seat)
 boot.location.x=x;bind(boot,name)
 loft('Boot cuff '+side,[(.14,.074,.083,0),(.20,.071,.078,0),(.28,.065,.068,0),(.32,.055,.057,0)],black,name,Vector((x,0,0)))
 bind(cube('Boot sole '+side,(x,.06,.039),(.15,.30,.022),black,.012),name)
# Keep each material batched, preserving the weighted animation groups.
for material in [leather,limb,helm,trim,black,steel,dark,seat,glass,armor]:
 objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.active_material==material and o!=body]
 if not objects:continue
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();objects[0].name='Rider '+material.name
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'assets/models/source/rider.blend'))
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'assets/models/rider.glb'),export_format='GLB',export_animations=False)
