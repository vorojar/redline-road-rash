extends SceneTree
const Actor=preload("res://game/vehicles/bike_actor.gd")
var failures=0
func check(ok: bool,label: String):
 if ok: print("[PASS] "+label)
 else: failures+=1;printerr("FAIL: "+label)
func _initialize(): call_deferred("run")
func run():
 var actor=Actor.new();root.add_child(actor)
 var body=actor.rider.find_child("Continuous racing suit",true,false)
 var samples=0
 var hip_weight=0.0
 var back_extent=0.0
 var matte_panels=0
 for surface in range(body.mesh.get_surface_count()):
  var material=body.mesh.surface_get_material(surface)
  if material.resource_name=="Seat reinforcement" and material.roughness>=.75: matte_panels+=1
  var arrays=body.mesh.surface_get_arrays(surface)
  var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
  var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  for i in range(vertices.size()):
   var v=vertices[i]
   if v.y<.98 or v.y>1.05 or absf(v.x)>.12 or v.z<.065: continue
   samples+=1;back_extent=maxf(back_extent,v.z)
   for influence in range(4):
    if body.skin.get_bind_name(bones[i*4+influence])==&"hips": hip_weight+=weights[i*4+influence]
 check(samples>15,"臀部后片保留实际连续网格")
 check(samples>0 and hip_weight/samples>=.80,"臀部后片主要随骨盆运动，避免屈腿时被大腿拉鼓")
 check(back_extent<=.086,"赛车裤后片轮廓收平，不形成过度突出的双球")
 check(matte_panels==1,"臀部采用独立哑光加固后片，不使用高光条纹")
 actor.queue_free();await process_frame
 print("SEATED_POSE_RESULT: %d failures"%failures)
 quit(1 if failures else 0)
