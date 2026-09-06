"""Build three visibly distinct, editable motorcycles from our original base asset."""
from pathlib import Path
import bpy, math
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[1]
exec((ROOT/'scripts/build_models.py').read_text().split('# Blender +Y')[0])
ROOT = Path(ROOT)

def reset():
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/models/source/motorcycle.blend'))
 global paint,black,steel,dark,chrome,seat,red,amber,glass,light
 paint=bpy.data.materials['Paint'];black=bpy.data.materials['Rubber'];steel=bpy.data.materials['Brushed steel'];dark=bpy.data.materials['Engine'];chrome=bpy.data.materials['Chrome'];seat=bpy.data.materials['Seat leather'];red=bpy.data.materials['Tail lamp'];amber=bpy.data.materials['Indicator'];glass=bpy.data.materials['Glass'];light=bpy.data.materials['Headlight']

def join_export(name):
 # Keep both wheel nodes separate for the in-game rolling/suspension animation.
 for material in list(bpy.data.materials):
  objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent is None and o.active_material==material]
  if not objects:continue
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();objects[0].name=material.name
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/f'assets/models/source/{name}.blend'))
 bpy.ops.export_scene.gltf(filepath=str(ROOT/f'assets/models/{name}.glb'),export_format='GLB')

reset()
# REVENANT: long muscle-bike silhouette, tall bars, broad tank and swept exhausts.
for obj in bpy.context.scene.objects:
 if obj.type=='EMPTY' and obj.name in ['WheelFront','WheelRear']:
  obj.location.y*=1.18
 elif obj.type=='MESH' and obj.parent is None:
  inverse=obj.matrix_world.inverted()
  for vertex in obj.data.vertices:
   point=obj.matrix_world@vertex.co
   point.y*=1.18
   if point.z>1.02: point.z+=.12
   vertex.co=inverse@point
sphere('Broad muscle tank',(0,.10,.88),(.305,.47,.215),paint)
for side in [-1,1]:
 tube('Handle riser',(side*.10,.60,1.02),(side*.12,.60,1.20),.019,chrome)
 tube('Swept bar',(side*.12,.60,1.20),(side*.43,.50,1.21),.021,chrome)
 tube('Muscle exhaust',(side*.29,-.28,.26),(side*.29,-1.02,.38),.078,chrome)
 tube('Black exhaust tip',(side*.29,-1.02,.38),(side*.29,-1.04,.383),.056,black)
 tube('Engine protection',(side*.32,.32,.65),(side*.34,.34,.30),.020,steel)
 tube('Engine protection',(side*.34,.34,.30),(side*.24,-.1,.27),.020,steel)
 cube('Ribbed side panel',(side*.24,-.40,.61),(.06,.36,.22),dark,.025)
 for j in range(5):cube('Side cover rib',(side*.277,-.54+j*.057,.61),(.012,.015,.17),steel,.004)
cube('Long leather saddle',(0,-.44,.875),(.45,.80,.11),seat,.05)
sphere('Compact flyscreen',(0,.61,1.255),(.22,.07,.20),glass)
join_export('revenant')

reset()
# PHANTOM: compact faired sport bike, nose, screen, vented side panels and belly pan.
def panel(side):
 rings=[(-.38,.19,.35,.70),(-.10,.27,.28,.83),(.24,.32,.31,.97),(.57,.29,.45,1.11),(.82,.17,.66,1.04)]
 vertices=[];faces=[]
 for y,width,bottom,top in rings:
  for t in [0,.25,.65,1]:vertices.append((side*width*(.88+math.sin(t*math.pi)*.12),y,bottom+(top-bottom)*t))
 for row in range(len(rings)-1):
  for col in range(3):
   a=row*4+col;quad=(a,a+1,a+5,a+4)
   faces.append(quad if side==1 else tuple(reversed(quad)))
 mesh=bpy.data.meshes.new('Sport fairing');mesh.from_pydata(vertices,[],faces);mesh.update()
 obj=bpy.data.objects.new('Sport fairing',mesh);bpy.context.collection.objects.link(obj);finish(obj,'Sport fairing',paint)
 bpy.context.view_layer.objects.active=obj;obj.select_set(True)
 smooth=obj.modifiers.new('Formed fairing','SUBSURF');smooth.levels=1;bpy.ops.object.modifier_apply(modifier=smooth.name)
 solid=obj.modifiers.new('Fairing thickness','SOLIDIFY');solid.thickness=.018;bpy.ops.object.modifier_apply(modifier=solid.name)
for side in [-1,1]:
 panel(side)
 for j in range(3):
  vent=cube('Air vent',(side*.308,.28-j*.082,.77-j*.036),(.02,.11,.038),black,.01)
  vent.rotation_euler.x=.28
 tube('Frame spar',(side*.22,.41,.91),(side*.24,-.38,.56),.055,steel)
 cube('Tail fin',(side*.17,-.70,.89),(.15,.40,.10),paint,.045)
cube('Aerodynamic nose',(0,.69,1.055),(.49,.36,.23),paint,.085)
# Projectors sit just in front of the painted nose.
for side in [-1,1]:sphere('Projector glass',(side*.135,.883,1.055),(.086,.022,.047),light)
vertices=[];faces=[]
for j in range(4):
 t=j/3
 for i in range(9):
  u=(i-4)/4
  vertices.append((u*(.23-.06*t),.68-.27*t+.05*(1-u*u),1.14+.31*t-.025*u*u))
for j in range(3):
 for i in range(8):
  a=j*9+i;faces.append((a,a+1,a+10,a+9))
mesh=bpy.data.meshes.new('Curved windshield');mesh.from_pydata(vertices,[],faces);mesh.update()
obj=bpy.data.objects.new('Curved windshield',mesh);bpy.context.collection.objects.link(obj);finish(obj,'Curved windshield',glass)
mod=obj.modifiers.new('Screen thickness','SOLIDIFY');mod.thickness=.006;bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name)
# Remove the naked bike's round lamp where it would poke through the new nose.
import bmesh
for obj in list(bpy.context.scene.objects):
 if obj.type!='MESH' or obj.active_material not in [chrome,light] or obj.name.startswith('Projector'):continue
 bm=bmesh.new();bm.from_mesh(obj.data)
 remove=[]
 for vertex in bm.verts:
  p=obj.matrix_world@vertex.co
  if abs(p.x)<.205 and .52<p.y<.83 and .80<p.z<1.19:remove.append(vertex)
 bmesh.ops.delete(bm,geom=remove,context='VERTS');bm.to_mesh(obj.data);bm.free()
cube('Belly pan',(0,.08,.29),(.43,.73,.12),paint,.05)
cube('Raised passenger pad',(0,-.69,.925),(.28,.26,.075),seat,.035)
join_export('phantom')
print('Distinct muscle and sport motorcycles exported.')
