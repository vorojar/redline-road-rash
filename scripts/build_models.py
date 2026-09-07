"""Generate editable motorcycles and invoke the CC0-based anatomical rider builder."""
import bpy, math, os, sys
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def mat(name, color, metallic=0, rough=.5):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*color,1); bs.inputs['Metallic'].default_value=metallic; bs.inputs['Roughness'].default_value=rough
 return m
def mapped(name, atlas, rough, metallic=0):
 m=mat(name,(1,1,1),metallic,rough);nodes=m.node_tree.nodes;links=m.node_tree.links;bs=nodes.get('Principled BSDF')
 for suffix, socket in [('albedo','Base Color'),('roughness','Roughness'),('normal','Normal')]:
  tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(os.path.join(ROOT,'assets/textures/vehicles',atlas+'_'+suffix+'.png'));tex.image.pack()
  if suffix!='albedo':tex.image.colorspace_settings.name='Non-Color'
  if suffix=='normal':
   normal=nodes.new('ShaderNodeNormalMap');links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],bs.inputs[socket])
  else:links.new(tex.outputs['Color'],bs.inputs[socket])
 return m
paint=mapped('Paint','bike_livery',.28,.55); black=mat('Rubber',(.016,.019,.021),0,.85); steel=mat('Brushed steel',(.19,.22,.25),.82,.34); dark=mat('Engine',(.055,.061,.07),.8,.45); chrome=mat('Chrome',(.68,.73,.76),.96,.19); seat=mat('Seat leather',(.023,.021,.02),0,.78); red=mat('Tail lamp',(.6,.009,.005),.2,.2); amber=mat('Indicator',(.88,.25,.01),.2,.24); glass=mat('Glass',(.045,.09,.11),.5,.15); light=mat('Headlight',(.82,.8,.65),.3,.18)

def finish(obj,name,material):
 obj.name=name; obj.data.materials.append(material)
 for p in obj.data.polygons: p.use_smooth=True
 if material==paint:
  obj.data.update();uv=obj.data.uv_layers.active or obj.data.uv_layers.new(name='UVMap')
  for p in obj.data.polygons:
   for idx in p.loop_indices:
    v=obj.matrix_world@obj.data.vertices[obj.data.loops[idx].vertex_index].co
    uv.data[idx].uv=(((1.15-v.y) if p.normal.x<0 else (v.y+1.15))/2.3*.5+(.5 if p.normal.x<0 else 0),(v.z-.20)/1.05)
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
def body_form(name,rings,material):
 verts=[];faces=[];n=32
 for y,rx,rz,cz in rings:
  for i in range(n):
   a=i*math.tau/n
   # A broad crown and tucked lower edge form stamped bodywork rather than a ball.
   verts.append((rx*math.cos(a),y,cz+rz*math.sin(a)))
 for j in range(len(rings)-1):
  for i in range(n):
   k=j*n+i;faces.append((k,j*n+(i+1)%n,(j+1)*n+(i+1)%n,k+n))
 faces.extend([tuple(reversed(range(n))),tuple((len(rings)-1)*n+i for i in range(n))])
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
 # Ring order is along +Y, so reverse outward winding from the XY loft convention.
 for p in mesh.polygons:p.flip()
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
 sub=obj.modifiers.new('Sculpted bodywork','SUBSURF');sub.levels=1;bpy.ops.object.modifier_apply(modifier=sub.name)
 return finish(obj,name,material)

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
 body_form('Sculpted fuel tank',[(-.29,.11,.075,.875),(-.20,.205,.13,.89),(-.04,.268,.16,.90),(.17,.258,.157,.90),(.36,.191,.12,.90),(.48,.077,.048,.91)],paint)
 cube('Seat',(0,-.37,.84),(.38,.63,.10),seat,.05)
 body_form('Rear cowl',[(-.97,.05,.025,.81),(-.87,.147,.065,.81),(-.66,.202,.070,.81),(-.50,.176,.045,.82)],paint)
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
# Keep the rider generator independently reproducible.
exec(compile(open(os.path.join(ROOT,'scripts/build_rider.py')).read(),os.path.join(ROOT,'scripts/build_rider.py'),'exec'))
