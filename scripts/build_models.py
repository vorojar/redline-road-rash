"""Generate original, editable motorcycle and articulated rider assets with Blender."""
import bpy, math, os, sys
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def mat(name, color, metallic=0, rough=.5):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*color,1); bs.inputs['Metallic'].default_value=metallic; bs.inputs['Roughness'].default_value=rough
 return m
paint=mat('Paint',(.30,.025,.017),.65,.28); black=mat('Rubber',(.016,.019,.021),0,.85); steel=mat('Brushed steel',(.34,.38,.4),.88,.28); dark=mat('Engine',(.055,.061,.07),.8,.45); chrome=mat('Chrome',(.68,.73,.76),.96,.19); seat=mat('Seat leather',(.023,.021,.02),0,.78); red=mat('Tail lamp',(.6,.009,.005),.2,.2); amber=mat('Indicator',(.88,.25,.01),.2,.24); glass=mat('Glass',(.045,.09,.11),.5,.15); light=mat('Headlight',(.82,.8,.65),.3,.18)

def finish(obj,name,material):
 obj.name=name; obj.data.materials.append(material)
 for p in obj.data.polygons: p.use_smooth=True
 return obj

def sphere(name,loc,scale,material):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=loc); o=bpy.context.object; o.scale=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,material)

def cube(name,loc,scale,material,bevel=.035):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Machined edges','BEVEL');mod.width=bevel;mod.segments=3;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 return finish(o,name,material)

def tube(name,a,b,r,material,vertices=16):
 a,b=Vector(a),Vector(b);d=b-a;bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=d.length,location=(a+b)*.5);o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=d.to_track_quat('Z','Y');return finish(o,name,material)

def torus(name,loc,major,minor,material,rot=(0,math.pi/2,0)):
 bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=48,minor_segments=12,location=loc,rotation=rot);return finish(bpy.context.object,name,material)
if '--rider-only' not in sys.argv:
 # Blender +Y is forward, Z up. glTF conversion produces Godot -Z forward.
 for y in [-.79,.79]:
  before=set(bpy.context.scene.objects)
  wheel_root=bpy.data.objects.new('WheelRear' if y<0 else 'WheelFront',None);bpy.context.collection.objects.link(wheel_root);wheel_root.location=(0,y,.34)
  torus('Performance tire',(0,y,.34),.258,.087,black)
  torus('Sidewall ridge',(0,y,.34),.282,.028,black)
  for x in [-.065,.065]:
   torus('Alloy rim',(x,y,.34),.213,.015,steel)
   tube('Axle',(x-.03,y,.34),(x+.03,y,.34),.056,dark)
   for i in range(6):
    t=i*math.tau/6
    tube('Alloy spoke',(x,y,.34),(x,y+math.cos(t)*.208,.34+math.sin(t)*.208),.014,steel)
  torus('Brake rotor',(.105,y,.34),.15,.018,steel)
  cube('Brake caliper',(.125,y+.12,.36),(.065,.08,.11),dark,.01)
  # Fine transverse tread bands visible around tire crown.
  for i in range(36):
   a=i*math.tau/36
   tube('Tread',( -.061,y+math.cos(a)*.337,.34+math.sin(a)*.337),(.061,y+math.cos(a+.035)*.337,.34+math.sin(a+.035)*.337),.0025,dark,6)
  for obj in set(bpy.context.scene.objects)-before:
   if obj.type=='MESH' and 'caliper' not in obj.name:
    world=obj.matrix_world.copy();obj.parent=wheel_root;obj.matrix_world=world
 for x in [-.18,.18]:
  tube('Main frame',(x,-.55,.62),(x,.37,1.0),.036,steel)
  tube('Lower frame',(x,-.58,.56),(x,.25,.35),.027,dark)
  tube('Frame down tube',(x,.25,.35),(x,.42,.92),.032,dark)
  tube('Swingarm',(x,-.79,.34),(x,-.15,.48),.034,steel)
  tube('Rear shock',(x,-.60,.38),(x,-.4,.8),.026,chrome)
  for k in range(10):
   torus('Shock coil',(x,-.56+k*.013,.43+k*.025),.038,.007,dark,rot=(.45,0,0))
  tube('Fork lower',(x,.79,.34),(x,.7,.7),.027,chrome)
  tube('Fork upper',(x,.7,.7),(x,.57,1.08),.035,steel)
 sphere('Sculpted fuel tank',(0,.12,.87),(.27,.43,.22),paint)
 cube('Seat',(0,-.37,.84),(.38,.63,.10),seat,.05)
 sphere('Rear cowl',(0,-.70,.78),(.24,.23,.12),paint)
 sphere('Front fender',(0,.79,.61),(.115,.36,.08),paint)
 cube('Crankcase',(0,-.02,.46),(.4,.38,.28),dark,.09)
 for y in [-.14,.04,.19]:
  cube('Engine cylinder',(0,y,.60),(.38,.12,.24),dark,.02)
  for z in range(7):
   cube('Cooling fin',(0,y,.51+z*.029),(.43,.135,.011),steel,.002)
 for x in [-.235,.235]:
  tube('Header',(x,.21,.52),(x,.31,.23),.023,chrome)
  tube('Exhaust bend',(x,.31,.23),(x,-.29,.25),.023,chrome)
  tube('Exhaust muffler',(x,-.29,.25),(x,-.89,.40),.06,steel)
  tube('Exhaust outlet',(x,-.89,.40),(x,-.91,.405),.043,black)
  tube('Foot peg',(x,-.18,.41),(x*1.65,-.18,.41),.022,dark)
  tube('Handlebar',(x*.4,.57,1.06),(x*1.8,.5,1.08),.016,chrome)
  tube('Grip',(x*1.5,.5,1.08),(x*2,.5,1.08),.023,black)
  tube('Mirror stalk',(x*1.5,.55,1.08),(x*1.85,.55,1.30),.008,chrome)
  sphere('Mirror',(x*1.85,.55,1.32),(.074,.026,.05),dark)
  cube('Mirror glass',(x*1.85,.525,1.32),(.105,.008,.06),steel,.015)
  cube('Turn signal',(x*1.3,-.88,.77),(.07,.08,.045),amber,.02)
 sphere('Headlight shell',(0,.61,1.0),(.19,.14,.18),chrome)
 sphere('Headlight lens',(0,.722,1.0),(.157,.025,.15),light)
 cube('Taillight',(0,-.9,.78),(.22,.03,.065),red,.008)
 cube('License plate',(0,-.88,.66),(.2,.013,.115),light,.006)
 sphere('Instrument cluster',(0,.42,1.11),(.13,.10,.04),dark)
 for x in [-.061,.061]:
  sphere('Gauge',(x,.41,1.142),(.043,.052,.01),glass)
 # Functional cables, side covers, seat stitching and tank pinstripes.
 for x in [-.22,.22]:
  cube('Side cover',(x,-.35,.64),(.045,.3,.16),paint,.025)
  for j in range(7):tube('Seat stitch',(x*.72,-.61+j*.065,.893),(x*.86,-.59+j*.065,.893),.002,steel,6)
  for y in [-.05,.04,.13,.22]:tube('Tank pinstripe',(x,y,.98),(x*.88,y+.045,1.025),.004,light,8)
  tube('Brake cable',(x,.49,1.06),(x,.55,.61),.006,black,8)
 # Join static geometry by material to reduce draw calls.
 for group in [None]+[o for o in bpy.context.scene.objects if o.name in ("WheelFront","WheelRear")]:
  for material in [paint,black,steel,dark,chrome,seat,red,amber,glass,light]:
   objs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.active_material==material and o.parent==group]
   if not objs:continue
   bpy.ops.object.select_all(action='DESELECT')
   for o in objs:o.select_set(True)
   bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();objs[0].name=material.name
 bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'assets/models/source/motorcycle.blend'))
 bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'assets/models/motorcycle.glb'),export_format='GLB')
# Articulated rider, all limbs weighted to named bones. Standing rest pose.
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
leather=mat('Jacket leather',(.038,.033,.03),.05,.68);denim=mat('Worn denim',(.09,.13,.18),0,.87);trim=mat('Jacket seam',(.18,.15,.11),0,.8);helm=mat('Helmet',(.56,.53,.46),.25,.28)
bones={'hips':((0,0,.93),(0,0,1.08)), 'spine':((0,0,1.06),(0,0,1.52)), 'head':((0,0,1.54),(0,0,1.91))}
for side,x in [('L',-.26),('R',.26)]:
 bones['upper_arm_'+side]=((x,0,1.47),(x*1.14,0,1.16));bones['forearm_'+side]=((x*1.14,0,1.16),(x*1.2,0,.88));bones['thigh_'+side]=((x*.5,0,.98),(x*.54,0,.55));bones['shin_'+side]=((x*.54,0,.55),(x*.56,0,.13))
bpy.ops.object.armature_add();rig=bpy.context.object;rig.name='RiderRig';bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0]);root=rig.data.edit_bones.new('root');root.head=(0,0,0);root.tail=(0,0,.2)
for name,(a,b) in bones.items():
 eb=rig.data.edit_bones.new(name);eb.head=a;eb.tail=b;eb.parent=root
bpy.ops.object.mode_set(mode='OBJECT')
def bind(o,bone):
 vg=o.vertex_groups.new(name=bone);vg.add(list(range(len(o.data.vertices))),1,'REPLACE');mod=o.modifiers.new('Rig deformation','ARMATURE');mod.object=rig;o.parent=rig
def torso_mesh():
 rings=[(1.045,.165,.10),(1.10,.18,.115),(1.20,.19,.132),(1.32,.218,.145),(1.43,.243,.139),(1.49,.242,.115),(1.53,.19,.097),(1.565,.077,.071)]
 verts=[];faces=[];n=32
 for z,xr,yr in rings:
  for i in range(n):
   a=i*math.tau/n
   verts.append((xr*math.cos(a),yr*math.sin(a),z))
 for j in range(len(rings)-1):
  for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
 faces.extend([tuple(reversed(range(n))),tuple((len(rings)-1)*n+i for i in range(n))])
 mesh=bpy.data.meshes.new('Tailored leather jacket');mesh.from_pydata(verts,[],faces);mesh.update()
 obj=bpy.data.objects.new('Jacket torso',mesh);bpy.context.collection.objects.link(obj);finish(obj,'Jacket torso',leather)
 mod=obj.modifiers.new('Tailored smoothing','SUBSURF');mod.levels=1;bpy.context.view_layer.objects.active=obj;obj.select_set(True);bpy.ops.object.modifier_apply(modifier=mod.name)
 return obj
bind(cube('Pelvis',(0,0,.985),(.34,.225,.22),denim,.07),'hips')
bind(torso_mesh(),'spine')
# Seams and a restrained back patch rather than a toy-colored body.
bind(cube('Back panel',(0,-.139,1.36),(.21,.01,.07),leather,.01),'spine')
for z in [1.09,1.13]:bind(tube('Waist stitching',(-.16,-.096,z),(.16,-.096,z),.003,trim),'spine')
for x in [-.082,.082]:bind(cube('Back pocket',(x,-.114,.99),(.11,.008,.09),denim,.01),'hips')
for x in [-.21,.21]:bind(tube('Back seam',(x,-.08,1.10),(x,-.095,1.49),.005,trim),'spine')
bind(sphere('Neck',(0,0,1.59),(.075,.076,.11),leather),'head')
bind(sphere('Helmet shell',(0,.008,1.765),(.145,.177,.168),helm),'head')
bind(sphere('Dark visor',(0,.140,1.785),(.137,.065,.071),glass),'head')
bind(sphere('Chin guard',(0,.103,1.668),(.132,.129,.055),helm),'head')
def tailored_limb(name,a,b,radius,material):
 # Vary cross-section along the limb; asymmetrical folds avoid capsule joints.
 direction=(b-a).normalized();basis=direction.to_track_quat('Z','Y')
 profile=[(-.04,.78),(.02,.97),(.17,1.03),(.33,.96),(.50,.90),(.63,.93),(.74,.83),(.85,.88),(.97,.69),(1.04,.57)]
 verts=[];faces=[];n=24
 for j,(t,width) in enumerate(profile):
  for k in range(n):
   angle=k*math.tau/n
   fold=1+.035*math.sin(angle*3+j*1.9)
   v=Vector((radius*width*math.cos(angle)*fold,radius*.86*width*math.sin(angle)*fold,t*(b-a).length))
   verts.append(tuple(a+basis@v))
 for j in range(len(profile)-1):
  for k in range(n):faces.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
 faces.extend([tuple(reversed(range(n))),tuple((len(profile)-1)*n+k for k in range(n))])
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);finish(o,name,material)
 return o
for side in ['L','R']:
 for part,radius,material in [('upper_arm',.095,leather),('forearm',.079,leather),('thigh',.115,denim),('shin',.089,denim)]:
  name=part+'_'+side;a,b=map(Vector,bones[name]);bind(tailored_limb(name,a,b,radius,material),name)
  for f in [.75,.85]:
   pos=a.lerp(b,f);bind(tube('Garment fold',pos+Vector((-.04,-radius*.83,.006)),pos+Vector((.04,-radius*.83,-.006)),.003,material,8),name)
  if part=='forearm':
   bind(cube('Leather glove',b,(.12,.105,.13),black,.03),name)
   for dx in [-.036,0,.036]:bind(cube('Knuckle pad',b+Vector((dx,.055,.02)),(.025,.018,.045),dark,.006),name)
  if part=='shin':
   bind(cube('Riding boot',(b.x,.062,.115),(.155,.29,.17),seat,.035),name)
   bind(cube('Boot sole',(b.x,.066,.041),(.159,.30,.027),black,.009),name)
   for z in [.125,.16]:bind(tube('Boot strap',(b.x-.07,.05,z),(b.x+.07,.05,z),.007,dark,8),name)
  if part=='upper_arm':bind(sphere('Shoulder armor',a,(.095,.087,.065),leather),name)
for x in [-.12,.12]:
 bind(tube('Jacket yoke',(x,-.135,1.41),(x*.6,-.117,1.49),.004,trim),'spine')
 bind(cube('Chest pocket',(x,.128,1.36),(.12,.012,.075),leather,.006),'spine')
bind(tube('Jacket zipper',(0,.113,1.11),(0,.138,1.47),.0035,steel),'spine')
for j in range(16):
 angle=-.8+j*.12
 a=(0,.005+math.sin(angle)*.163,1.765+math.cos(angle)*.168)
 b=(0,.005+math.sin(angle+.12)*.163,1.765+math.cos(angle+.12)*.168)
 bind(tube('Helmet stripe',a,b,.009,trim,8),'head')
# Protective riding gear: articulated panels, helmet trim/vents, fingers and boot hardware.
for side in [-1,1]:
 suffix='L' if side<0 else 'R'
 bind(sphere('Helmet cheek', (side*.116,.074,1.712),(.027,.093,.067),helm),'head')
 bind(cube('Helmet brow vent',(side*.054,.153,1.866),(.045,.016,.012),black,.004),'head')
 bind(cube('Chin air intake',(side*.04,.222,1.678),(.052,.01,.017),black,.004),'head')
 bind(tube('Visor hinge',(side*.137,.048,1.786),(side*.146,.048,1.786),.018,steel),'head')
 bind(tube('Helmet lower trim',(side*.126,.03,1.645),(side*.093,.18,1.655),.009,black),'head')
 bind(cube('Jacket reflective shoulder',(side*.205,-.112,1.461),(.069,.01,.025),steel,.008),'spine')
 bind(cube('Elbow armor',(side*.292,-.063,1.195),(.098,.035,.105),dark,.028),'upper_arm_'+suffix)
 bind(cube('Knee protector',(side*.14,.076,.566),(.131,.036,.135),dark,.034),'thigh_'+suffix)
 bind(cube('Boot ankle armor',(side*.216,.014,.167),(.022,.091,.087),dark,.015),'shin_'+suffix)
 wrist=Vector(bones['forearm_'+suffix][1])
 for digit in range(4):
  x=wrist.x+(digit-1.5)*.026
  bind(tube('Glove finger',(x,wrist.y+.017,wrist.z-.014),(x,wrist.y+.053,wrist.z-.079),.012,black,12),'forearm_'+suffix)
  bind(tube('Finger seam',(x,wrist.y+.039,wrist.z-.036),(x,wrist.y+.049,wrist.z-.061),.0025,trim,8),'forearm_'+suffix)
 bind(tube('Glove thumb',(wrist.x-side*.049,.025,wrist.z+.026),(wrist.x-side*.074,.056,wrist.z-.015),.019,black),'forearm_'+suffix)
# Subtle back protector follows torso; segmented shape avoids a featureless mannequin back.
for j in range(6):
 bind(cube('Back protector lamella',(0,-.145,1.19+j*.039),(.113+math.sin(j/5*math.pi)*.045,.026,.034),leather,.012),'spine')
bind(tube('Collar seal',(-.07,0,1.569),(.07,0,1.569),.032,seat),'spine')
# Blend garment end rings across shoulder/elbow/knee seams while keeping rigid armor separate.
for o in list(bpy.context.scene.objects):
 if o.type!='MESH':continue
 bone_name=o.name
 if bone_name not in bones:continue
 side=bone_name[-1:]
 neighbor=('spine' if bone_name.startswith('upper_arm_') else 'upper_arm_'+side if bone_name.startswith('forearm_') else 'hips' if bone_name.startswith('thigh_') else 'thigh_'+side)
 a,b=map(Vector,bones[bone_name]);axis=(b-a).normalized();length=(b-a).length
 vg=o.vertex_groups.get(bone_name);adj=o.vertex_groups.new(name=neighbor)
 for vertex in o.data.vertices:
  t=(vertex.co-a).dot(axis)/length
  blend=max(0,min(.28,(.13-t)*1.9))
  if blend>0:
   vg.add([vertex.index],1-blend,'REPLACE');adj.add([vertex.index],blend,'REPLACE')
# Batch skinned clothing by material; vertex groups preserve the independent bone weights.
for material in [leather,denim,trim,helm,black,steel,dark,seat,glass]:
 objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.active_material==material]
 if not objects:continue
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 bpy.ops.object.join()
 objects[0].name='Rider '+material.name
# Export bones without animation; Godot drives poses continuously for combat and recovery.
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'assets/models/source/rider.blend'))
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'assets/models/rider.glb'),export_format='GLB',export_animations=False)
print('Original motorcycle and rigged rider generated.')
