from pathlib import Path
exec((Path(__file__).with_name('build_models.py')).read_text().split('# Blender +Y')[0])
# Detailed 1990s civilian sedan, +Y forward.
cube('Lower body',(0,0,.67),(1.8,4.05,.57),paint,.13)
cube('Hood',(0,1.25,1.01),(1.73,1.32,.12),paint,.08)
cube('Trunk',(0,-1.50,.99),(1.72,.75,.12),paint,.08)
# Cabin with sloped front and rear glass.
verts=[(-.79,-1.1,.95),(.79,-1.1,.95),(-.79,.8,.95),(.79,.8,.95),(-.66,-.78,1.57),(.66,-.78,1.57),(-.66,.30,1.57),(.66,.30,1.57)]
faces=[(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5),(4,5,7,6)]
mesh=bpy.data.meshes.new('Cabin');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Window glass',mesh);bpy.context.collection.objects.link(o);finish(o,'Window glass',glass)
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
 for y in [-.67,.28]:cube('Door handle',(x*1.48,y,1.0),(.035,.17,.035),steel,.015)
for y in [-2.08,2.08]:
 cube('Bumper',(0,y,.48),(1.72,.09,.17),dark,.06)
 cube('Plate',(0,y*1.01,.72),(.36,.025,.14),light,.01)
for x in range(-5,6):cube('Grille',(x*.045,2.07,.85),(.023,.025,.16),dark,.003)
for material in [paint,black,steel,dark,chrome,seat,red,amber,glass,light]:
 objs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.active_material==material]
 if not objs:continue
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();objs[0].name=material.name
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'assets/models/sedan.glb'),export_format='GLB')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'assets/models/source/sedan.blend'))
