extends SceneTree
const Actor = preload("res://game/vehicles/bike_actor.gd")
var failures = 0
func check(ok: bool, label: String) -> void:
	if ok: print("[PASS] "+label)
	else:
		failures += 1
		printerr("FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var actor = Actor.new()
	root.add_child(actor)
	var triangles = 0
	for mesh in actor.rider.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			triangles += mesh.mesh.surface_get_array_index_len(surface)/3
	check(triangles<200000,"骑手含头盔与装备低于 20 万三角面，限制同屏六人负担")
	for suffix in ["L","R"]:
		var name = "forearm_"+suffix
		var elbow = Vector3(.30,1.15,0)
		var hand = Vector3(.39,1.09,-.25)
		actor.bone(name,elbow,hand,0)
		var neutral = actor.skeleton.get_bone_pose_rotation(actor.bone_ids[name])
		actor.bone(name,elbow,hand,PI/2)
		var sleeve = actor.skeleton.get_bone_pose_rotation(actor.bone_ids[name])
		check(neutral.angle_to(sleeve)<deg_to_rad(30),"握把转腕 90 度时肘侧衣袖扭转小于 30 度："+suffix)
		var wrist_name = "wrist_"+suffix
		check(actor.bone_ids.has(wrist_name),"手套具有独立转腕蒙皮："+suffix)
		if actor.bone_ids.has(wrist_name):
			var wrist = actor.bone_ids[wrist_name]
			check(absf(neutral.angle_to(actor.skeleton.get_bone_pose_rotation(wrist))-PI/2)<.001,"手掌仍完成完整握把旋转："+suffix)
			var middle = actor.bone_ids["wrist_mid_"+suffix]
			var middle_rotation = actor.skeleton.get_bone_pose_rotation(middle)
			check(middle_rotation.angle_to(sleeve)<PI/4 and middle_rotation.angle_to(actor.skeleton.get_bone_pose_rotation(wrist))<PI/4,"相邻衣袖蒙皮旋转差小于 45 度，避免线性混合压瘪："+suffix)
			check(actor.skeleton.get_bone_pose_position(wrist).distance_to(elbow)<.001,"转腕不移动肘部或拉长袖子："+suffix)
			actor.bone(name,elbow,hand,0)
			check(actor.skeleton.get_bone_pose_rotation(wrist).angle_to(neutral)<.001,"摔车恢复的无 roll 姿态同步复位手套："+suffix)
		check(not actor.segments.has(wrist_name),"转腕不新增重叠物理碰撞体："+suffix)
	actor.queue_free()
	await process_frame
	print("RIDER_CLOTHING_RESULT: %d failures"%failures)
	quit(1 if failures else 0)
