from pathlib import Path
exec((Path(__file__).with_name('build_models.py')).read_text().split("if '--rider-only'")[0])
# Plain automotive paint: racing-bike decals do not belong on civilian cars.
paint.name='Unused motorcycle paint'
paint=mat('Paint',(.32,.38,.43),.48,.25)
# Opaque glass and a dark upper tint hide the deliberately unmodeled interior.
glass=mat('Window glass',(.025,.047,.061),.52,.16)
sunstrip=mat('Window sunstrip',(.008,.016,.023),.18,.25)
mirror=mat('Mirror glass',(.19,.25,.29),.85,.12)
# Detailed 1990s civilian sedan, +Y forward.
body=cube('Lower body',(0,0,.67),(1.8,4.05,.57),paint,.13)
# Wheel openings cut through the fenders instead of burying tires in a box.
for y in [-1.27,1.25]:
 bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.415,depth=2.3,location=(0,y,.39),rotation=(0,math.pi/2,0))
 cutter=bpy.context.object
 bpy.context.view_layer.objects.active=body
 mod=body.modifiers.new('Wheel arch','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
 bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
cube('Hood',(0,1.25,1.01),(1.73,1.32,.12),paint,.08)
cube('Trunk',(0,-1.50,.99),(1.72,.75,.12),paint,.08)
# Cabin with sloped front and rear glass.
verts=[(-.79,-1.1,.95),(.79,-1.1,.95),(-.79,.8,.95),(.79,.8,.95),(-.66,-.78,1.57),(.66,-.78,1.57),(-.66,.30,1.57),(.66,.30,1.57)]
faces=[(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5),(4,5,7,6)]
mesh=bpy.data.meshes.new('Cabin');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Window glass',mesh);bpy.context.collection.objects.link(o);finish(o,'Window glass',glass)
# A narrow band follows the actual sloped windshield, without z-fighting.
strip=[Vector(verts[2]).lerp(Vector(verts[6]),.77),Vector(verts[3]).lerp(Vector(verts[7]),.77),Vector(verts[7]),Vector(verts[6])]
mesh=bpy.data.meshes.new('Windshield upper tint');mesh.from_pydata([p+Vector((0,.007,.004)) for p in strip],[],[(0,3,2,1)]);mesh.update()
o=bpy.data.objects.new('Windshield upper tint',mesh);bpy.context.collection.objects.link(o);finish(o,o.name,sunstrip)
cube('Roof',(0,-.23,1.585),(1.39,1.16,.075),paint,.07)
for a,b in [(verts[0],verts[4]),(verts[1],verts[5]),(verts[2],verts[6]),(verts[3],verts[7])]:tube('Window pillar',a,b,.035,paint)
for x in [-.78,.78]:
 tube('B pillar',(x,-.24,1),(x*.87,-.24,1.56),.026,paint)
for x in [-.94,.94]:
 for y in [-1.27,1.25]:
  torus('Tire',(x,y,.39),.26,.10,black)
  torus('Wheel rim',(x*1.06,y,.39),.205,.014,steel)
  tube('Wheel hub',(x,y,.39),(x*1.09,y,.39),.10,steel)
  for i in range(6):
   a=i*math.tau/6;tube('Wheel spoke',(x*1.07,y,.39),(x*1.07,y+math.sin(a)*.20,.39+math.cos(a)*.20),.016,steel)
for x in [-.61,.61]:
 cube('Headlight',(x,2.045,.80),(.48,.035,.20),light,.02)
 cube('Tail lamp',(x,-2.045,.82),(.43,.035,.17),red,.02)
 cube('Side mirror',(x*1.55,.52,1.18),(.21,.24,.13),paint,.06)
 cube('Mirror insert',(x*1.55,.389,1.18),(.16,.012,.084),mirror,.019)
 for y in [-.67,.28]:cube('Door handle',(x*1.48,y,1.0),(.035,.17,.035),steel,.015)
for y in [-2.08,2.08]:
 cube('Bumper',(0,y,.48),(1.72,.09,.17),dark,.06)
 cube('Plate',(0,y*1.01,.72),(.36,.025,.14),light,.01)
for x in range(-5,6):cube('Grille',(x*.045,2.07,.85),(.023,.025,.16),dark,.003)
# Thin shut lines and rubber window seals give panels readable edges.
for side in [-1,1]:
 x=side*.904
 for y in [-1.02,-.23,.72]:tube('Door shut line',(x,y,.46),(x,y,.97),.005,black,6)
 tube('Sill trim',(x,-.98,.43),(x,.87,.43),.014,dark,8)
 tube('Window belt',(side*.795,-1.06,1.0),(side*.795,.74,1.0),.014,black,8)
 for a,b in [(verts[0 if side<0 else 1],verts[4 if side<0 else 5]),(verts[2 if side<0 else 3],verts[6 if side<0 else 7])]:
  tube('Glass gasket',Vector(a)+Vector((0,0,.012)),Vector(b)+Vector((0,0,.012)),.013,black,8)
 cube('Turn signal',(side*.87,1.75,.8),(.027,.16,.065),amber,.008)
cube('Rear center reflector',(0,-2.04,.85),(.34,.025,.07),red,.007)
for material in [paint,black,steel,dark,chrome,seat,red,amber,glass,light,sunstrip,mirror]:
 objs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.active_material==material]
 if not objs:continue
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();objs[0].name=material.name
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'assets/models/sedan.glb'),export_format='GLB')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'assets/models/source/sedan.blend'))

# Separate box truck with a short cab, twin rear wheels, framed doors and steps.
# Godot footprint remains x +/-1.08, z -2.15..3.9 for existing contacts.
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
cargo=mat('Cargo enamel',(.54,.58,.57),.15,.58)
cube('Truck chassis',(0,-.85,.52),(1.75,5.75,.22),dark,.05)
cube('Cab',(0,1.21,1.05),(1.96,1.6,1.05),paint,.10)
cube('Cab roof',(0,1.10,2.03),(1.96,1.68,.16),paint,.06)
cube('Windshield',(0,1.95,1.68),(1.69,.032,.47),glass,.045)
cube('Truck windshield upper tint',(0,1.971,1.856),(1.64,.012,.10),sunstrip,.018)
for side in [-1,1]:
 cube('Cab side glass',(side*.986,1.17,1.68),(.028,1.05,.47),glass,.04)
 cube('Cab door handle',(side*.999,.82,1.25),(.03,.19,.05),steel,.01)
 cube('Cab step',(side*.96,1.07,.44),(.23,1.10,.11),steel,.035)
 tube('Mirror arm',(side*.97,1.8,1.72),(side*1.13,1.65,1.65),.018,dark)
 cube('Truck mirror',(side*1.12,1.61,1.64),(.13,.19,.29),dark,.035)
 cube('Truck mirror insert',(side*1.12,1.512,1.64),(.09,.012,.23),mirror,.018)
 cube('Cab lamp',(side*.64,2.025,.96),(.4,.035,.18),light,.015)
 cube('Cab signal',(side*.89,2.023,.97),(.14,.039,.16),amber,.012)
 for y in [1.35,-2.77]:
  for x in ([side*.97] if y>0 else [side*.84,side*1.02]):
   torus('Truck tire',(x,y,.43),.285,.125,black)
   tube('Truck steel wheel',(x,y,.43),(x+side*.065,y,.43),.225,steel)
   tube('Truck hub',(x+side*.07,y,.43),(x+side*.095,y,.43),.082,dark)
cube('Cargo box',(0,-1.45,1.85),(2.12,4.86,2.30),cargo,.04)
for side in [-1,1]:
 for y in [-3.84,-2.9,-1.95,-1,.0,.95]:cube('Cargo rib',(side*1.071,y,1.86),(.021,.025,2.23),steel,.006)
 for z in [.75,2.98]:cube('Cargo frame',(side*1.075,-1.45,z),(.028,4.87,.065),steel,.009)
 for y in [-3.5,-1.4,.7]:cube('Side marker',(side*1.09,y,.92),(.015,.13,.075),amber,.01)
 cube('Rear door',(side*.51,-3.9,1.86),(.98,.036,2.08),cargo,.02)
 tube('Door locking bar',(side*.50,-3.933,.88),(side*.50,-3.933,2.78),.016,steel)
 for z in [1.02,2.63]:cube('Door hinge',(side*.97,-3.931,z),(.15,.033,.065),steel,.01)
 cube('Rear lamp',(side*.65,-3.94,.73),(.32,.035,.17),red,.01)
 cube('Rear mudflap',(side*.88,-3.28,.3),(.36,.035,.37),black,.006)
cube('Rear underride bar',(0,-3.91,.38),(2.08,.13,.14),steel,.015)
cube('Front bumper',(0,2.08,.63),(2.02,.15,.2),dark,.04)
cube('Cab grille',(0,2.035,1.02),(.68,.025,.31),dark,.012)
for z in [.92,1.02,1.12]:cube('Grille strip',(0,2.06,z),(.65,.018,.023),steel,.006)
for material in [paint,black,steel,dark,glass,light,amber,red,cargo,sunstrip,mirror]:
 objs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.active_material==material]
 if not objs:continue
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();objs[0].name=material.name
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'assets/models/truck.glb'),export_format='GLB')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'assets/models/source/truck.blend'))
