"""Fit the CC0 MakeHuman topology and skin weights to REDLINE's gameplay rig.

Executed by build_rider.py inside Blender. No MakeHuman application code is used.
"""
import json
from pathlib import Path
from collections import defaultdict
from mathutils import Matrix
source_dir=Path(ROOT)/'assets/models/source/makehuman'
raw=[];source_faces=[];group=''
for line in (source_dir/'base.obj').read_text().splitlines():
 fields=line.split()
 if not fields:continue
 if fields[0]=='v':raw.append(Vector(tuple(map(float,fields[1:4]))))
 elif fields[0]=='g':group=fields[1]
 elif fields[0]=='f' and group=='body':source_faces.append(tuple(int(x.split('/')[0])-1 for x in fields[1:]))
# Adult body proportions, with a restrained athletic build beneath protective leathers.
for name,amount in [('caucasian-male-young.target',1.0),('universal-male-young-maxmuscle-averageweight.target',.35)]:
 for line in (source_dir/name).read_text().splitlines():
  fields=line.split()
  if len(fields)==4 and not line.startswith('#'):raw[int(fields[0])]+=Vector(tuple(map(float,fields[1:])))*amount
schema=json.loads((source_dir/'default.mhskel').read_text())
source_weights=json.loads((source_dir/'default_weights.mhw').read_text())['weights']
# MakeHuman is Y up, +Z forward; Blender is Z up, +Y forward.
def convert(v):return Vector((v.x*.11,v.z*.11,(v.y+8.4488)*.11))
raw=[convert(v) for v in raw]
def joint(bone,endpoint):
 ids=schema['joints'][schema['bones'][bone][endpoint]]
 return sum((raw[i] for i in ids),Vector())/len(ids)
source_segments={
 'hips':(Vector((0,0,.93)),Vector((0,0,1.08))),
 'spine':(joint('spine05','head'),joint('neck01','head')-Vector((0,0,.02))),
 'head':(joint('neck01','head'),joint('neck01','head')+Vector((0,0,.37)))
}
for side in ['L','R']:
 # MakeHuman L is positive X, the gameplay rig calls negative X L.
 mh='R' if side=='L' else 'L'
 source_segments['upper_arm_'+side]=(joint('upperarm01.'+mh,'head'),joint('lowerarm01.'+mh,'head'))
 source_segments['forearm_'+side]=(joint('lowerarm01.'+mh,'head'),joint('wrist.'+mh,'head').lerp((joint('finger2-1.'+mh,'head')+joint('finger5-1.'+mh,'head'))*.5,.7))
 source_segments['thigh_'+side]=(joint('upperleg01.'+mh,'head'),joint('lowerleg01.'+mh,'head'))
 source_segments['shin_'+side]=(joint('lowerleg01.'+mh,'head'),joint('foot.'+mh,'head'))
# Curl the mature mesh's articulated fingers into a handlebar / weapon grip.
# Apply the source finger weights before collapsing them to the gameplay hand segment.
grip_sources={side:(joint('finger2-1.'+('R' if side=='L' else 'L'),'head'),joint('finger5-1.'+('R' if side=='L' else 'L'),'head')) for side in ['L','R']}
finger_transforms={}
for mh in ['L','R']:
 axis=(joint('finger2-1.'+mh,'head')-joint('finger5-1.'+mh,'head')).normalized()
 for digit in range(1,6):
  parent=Matrix.Identity(4)
  for segment,angle in [(1,42),(2,65),(3,48)]:
   name='finger%d-%d.%s'%(digit,segment,mh)
   pivot=joint(name,'head')
   curl=math.radians(angle*(1.2 if digit==1 else 1))
   transform=parent@Matrix.Translation(pivot)@Matrix.Rotation(curl,4,axis)@Matrix.Translation(-pivot)
   finger_transforms[name]=transform;parent=transform
finger_offsets=[Vector() for _ in raw]
for name,transform in finger_transforms.items():
 for index,value in source_weights[name]:finger_offsets[index]+=(transform@raw[index]-raw[index])*value
raw=[v+offset for v,offset in zip(raw,finger_offsets)]
weights=[defaultdict(float) for _ in raw]
for name,values in source_weights.items():
 side='R' if name.endswith('.L') else 'L'
 if name.startswith(('upperarm',)):mapping={'upper_arm_'+side:1}
 elif name.startswith(('lowerarm','wrist','finger','metacarpal')):mapping={'forearm_'+side:1}
 elif name.startswith('upperleg'):mapping={'thigh_'+side:1}
 elif name.startswith(('lowerleg','foot','toe')):mapping={'shin_'+side:1}
 elif name.startswith(('clavicle','shoulder')):mapping={'spine':.72,'upper_arm_'+side:.28}
 elif name.startswith('neck01'):mapping={'spine':.70,'head':.30}
 elif name.startswith('neck02'):mapping={'spine':.30,'head':.70}
 elif name.startswith('neck03'):mapping={'head':1}
 elif name.startswith(('root','pelvis','spine05','spine04')):mapping={'hips':.65,'spine':.35}
 elif name.startswith(('spine','breast')):mapping={'spine':1}
 else:mapping={'head':1}
 for index,value in values:
  for target,factor in mapping.items():weights[index][target]+=value*factor
# Retarget rest geometry with exactly the same linear skinning used by the game.
def fitted(point,key):
 a,b=source_segments[key];c,d=map(Vector,bones[key]);axis=(b-a).normalized();rotation=(b-a).rotation_difference(d-c)
 delta=point-a
 # Keep anatomical cross-sections; only segment length changes to match the rig.
 delta+=axis*delta.dot(axis)*((d-c).length/(b-a).length-1)
 return c+rotation@delta
# Export the anatomical knuckle axis so runtime wrist rotation can align to each grip.
for side,(index,little) in grip_sources.items():
 axis=(fitted(index,'forearm_'+side)-fitted(little,'forearm_'+side)).normalized()
 helper=bpy.data.objects.new('GripAxis_'+side,None);bpy.context.collection.objects.link(helper)
 helper.location=axis
used=sorted({i for face in source_faces for i in face});remap={v:i for i,v in enumerate(used)}
vertices=[]
for i in used:
 total=sum(weights[i].values())
 if total<=0:raise RuntimeError('Unweighted anatomical vertex '+str(i))
 weights[i]={k:v/total for k,v in weights[i].items()}
 vertices.append(sum((fitted(raw[i],key)*value for key,value in weights[i].items()),Vector()))
mesh=bpy.data.meshes.new('Continuous anatomical topology');mesh.from_pydata(vertices,[],[tuple(remap[i] for i in reversed(f)) for f in source_faces]);mesh.update()
body=bpy.data.objects.new('Continuous racing suit',mesh);bpy.context.collection.objects.link(body)
# Clothing allowance preserves anatomical shoulders / trapezius while covering skin.
for vertex in mesh.vertices:
 vertex.co+=vertex.normal*(.010 if vertex.co.z<1.54 else .002)
mesh.update()
for material in [leather,limb,black]:mesh.materials.append(material)
uv=mesh.uv_layers.new(name='UVMap')
for polygon in mesh.polygons:
 center=polygon.center;influences=defaultdict(float)
 for i in polygon.vertices:
  for key,value in weights[used[i]].items():influences[key]+=value
 key=max(influences,key=influences.get)
 is_limb=key.startswith(('upper_arm','forearm','thigh','shin'))
 # Gloves, boots and the balaclava are part of the continuous human surface.
 if key=='head' or (key=='shin_L' or key=='shin_R') and center.z<.28:
  polygon.material_index=2
 elif key.startswith('forearm') and (center-Vector(bones[key][0])).length>.25:
  polygon.material_index=2
 else:polygon.material_index=1 if is_limb else 0
 coords=[]
 for loop in polygon.loop_indices:
  p=mesh.vertices[mesh.loops[loop].vertex_index].co
  if is_limb:
   a,b=map(Vector,bones[key]);basis=(b-a).to_track_quat('Z','Y');local=basis.inverted()@(p-a)
   u=(math.atan2(local.y,local.x)/math.tau)%1;v=1-local.z/(b-a).length
  else:
   u=(math.atan2(p.y,p.x)/math.tau)%1;v=(p.z-1.0)/.57
  coords.append([loop,u,v])
 if max(c[1] for c in coords)-min(c[1] for c in coords)>.5:
  for c in coords:
   if c[1]<.5:c[1]+=1
 for loop,u,v in coords:uv.data[loop].uv=(u*2 if is_limb else u,v)
 polygon.use_smooth=True
for key in bones:
 vg=body.vertex_groups.new(name=key)
 for local_index,source_index in enumerate(used):
  value=weights[source_index].get(key,0)
  if value>0:vg.add([local_index],value,'REPLACE')
mod=body.modifiers.new('Anatomical skinning','ARMATURE');mod.object=rig;body.parent=rig
# Remove under-helmet facial detail from rendering, keeping the neck in the body mesh.
# The editable original CC0 head remains available in base.obj.
import bmesh
bm=bmesh.new();bm.from_mesh(mesh)
inside=[v for v in bm.verts if v.co.z>1.655 or v.co.z<.19]
bmesh.ops.delete(bm,geom=inside,context='VERTS');bm.to_mesh(mesh);bm.free();mesh.update()
print('Continuous human vertices:',len(mesh.vertices),'polygons:',len(mesh.polygons))
