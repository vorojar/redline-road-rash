extends SceneTree
const Career = preload("res://game/systems/career.gd")
var failures = 0
func check(ok: bool, label: String) -> void:
	if ok: print("[PASS] "+label)
	else:
		failures += 1
		printerr("FAIL: "+label)
func check_anatomical_body(mesh: MeshInstance3D) -> void:
	var ids: Dictionary = {}
	var adjacency: Array = []
	var blended = 0
	var finite = true
	for surface in range(mesh.mesh.get_surface_count()):
		var arrays = mesh.mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var mapped: Array[int] = []
		for i in range(positions.size()):
			var p = positions[i]
			finite = finite and p.is_finite()
			var key = Vector3i((p*100000).round())
			if not ids.has(key):
				ids[key] = adjacency.size()
				adjacency.append({})
			mapped.append(ids[key])
			var count = 0
			for influence in range(4):
				if weights[i*4+influence]>.05: count += 1
			if count>1: blended += 1
		for i in range(0,indices.size(),3):
			for edge in range(3):
				var a = mapped[indices[i+edge]]
				var b = mapped[indices[i+(edge+1)%3]]
				adjacency[a][b] = true;adjacency[b][a] = true
	var visited: Dictionary = {}
	var largest = 0
	for start in range(adjacency.size()):
		if visited.has(start): continue
		var pending = [start]
		visited[start] = true
		var count = 0
		while not pending.is_empty():
			var current = pending.pop_back()
			count += 1
			for neighbor in adjacency[current]:
				if not visited.has(neighbor):
					visited[neighbor] = true;pending.append(neighbor)
		largest = maxi(largest,count)
	check(finite and ids.size()>5000,"成熟人体保留完整解剖拓扑且无无效坐标")
	check(largest>=ids.size()*.99,"肩颈、躯干和四肢属于同一连续人体表面")
	check(blended>500,"人体关节使用平滑混合蒙皮，不是逐段刚性绑定")

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var profile = Career.new()
	profile.path = "user://quality_test_%d.json" % OS.get_process_id()
	profile.settings.render_quality = 2
	check(profile.save_profile(),"隔离测试存档成功")
	var restored = Career.new()
	restored.path = profile.path
	restored.load_profile()
	check(restored.settings.render_quality == 2,"精细画质跨重启保留")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile.path))
	data.settings.erase("render_quality")
	var file = FileAccess.open(profile.path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data));file.close()
	restored = Career.new();restored.path = profile.path;restored.load_profile()
	check(restored.settings.render_quality == 1,"旧存档默认均衡，不强制手机降分辨率")
	data.settings.render_quality = 99
	file = FileAccess.open(profile.path,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
	restored = Career.new();restored.path = profile.path;restored.load_profile()
	check(restored.settings.render_quality == 2,"损坏画质索引限制到可用档位")
	DirAccess.remove_absolute(profile.path)
	var race = load("res://game/race.gd").new()
	race.test_mode = true;root.add_child(race)
	race.set_process(false);race.set_physics_process(false)
	race.touch_device = true
	for level in range(3):
		race.career.settings.render_quality = level;race.apply_render_quality()
		check(is_equal_approx(root.scaling_3d_scale,.75 if level == 0 else 1.0) and root.msaa_3d == level,"手机画质实际改变分辨率与抗锯齿：%d"%level)
		check(race.sun.shadow_enabled == (level>0),"手机阴影跟随画质：%d"%level)
		check(race.hud.garage_view.viewport.msaa_3d == level,"车库使用相同画质档位：%d"%level)
	check_anatomical_body(race.player_mesh.rider.find_child("Continuous racing suit",true,false))
	for mesh in race.player_mesh.rider.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			var source = mesh.mesh.surface_get_material(surface)
			if source.resource_name in ["Jacket leather","Suit limbs","Helmet"]:
				var arrays = mesh.mesh.surface_get_arrays(surface)
				var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				check(uvs.size()>100 and uvs[0].distance_to(uvs[20])>.05,"赛车服和头盔有展开 UV："+source.resource_name)
				if source.resource_name == "Jacket leather":
					var pixel: Color = source.albedo_texture.get_image().get_pixel(0,0)
					check(pixel.a == 0 and pixel.r < .2,"不透明材质的零 alpha 区域保留黑色缝边，不做透明边缘填色")
				var material: ShaderMaterial = mesh.get_active_material(surface)
				check(material.get_shader_parameter("color_map")==source.albedo_texture and source.albedo_texture.get_width()>=512,"人物换色保留真实贴图："+source.resource_name)
				check(material.get_shader_parameter("normal_map")==source.normal_texture and source.normal_enabled,"法线细节接入："+source.resource_name)
				check(material.get_shader_parameter("roughness_channel")==source.roughness_texture_channel,"粗糙度读取导入后的正确通道")
			else:
				check(mesh.get_active_material(surface) is StandardMaterial3D,"面罩及金属保留独立 PBR 材质："+source.resource_name)

	for suffix in ["L","R"]:
		var axis: Vector3 = race.player_mesh.grip_axes[suffix]
		check(is_equal_approx(axis.length(),1),"模型携带解剖手掌方向："+suffix)
		var elbow = Vector3(.35,1.15,.0)
		var hand = Vector3(.39,1.09,-.51)
		var forearm_axis = (hand-elbow).normalized()
		var rest = race.player_mesh.skeleton.get_bone_global_rest(race.player_mesh.bone_ids["forearm_"+suffix])
		var width: Vector3 = Quaternion(rest.basis.y.normalized(),forearm_axis)*axis
		var target = Vector3.LEFT if suffix=="R" else Vector3.RIGHT
		var roll: float = race.player_mesh.hand_roll(suffix,elbow,hand,target)
		width = Basis(forearm_axis,roll)*(width-forearm_axis*width.dot(forearm_axis)).normalized()
		target = (target-forearm_axis*target.dot(forearm_axis)).normalized()
		check(width.dot(target)>.999,"手腕转动使闭合手掌沿实际握把方向："+suffix)
	for spec in race.career.catalog.bikes:
		race.player_mesh.set_model(spec)
		var paint = race.player_mesh.damage_visuals.paints[0]
		check(paint.get_shader_parameter("has_maps") and paint.get_shader_parameter("color_map").get_width()==1024,"车型载入涂装："+spec.id)
		race.player_mesh.damage_visuals.update(.3,false)
		race.player_mesh.tint(Color.BLUE)
		check(is_equal_approx(paint.get_shader_parameter("wear"),.7) and paint.get_shader_parameter("tint")==Color.BLUE,"再次换色保留受损材质引用："+spec.id)
		race.hud.garage_view.show_bike(spec)
		var mesh = race.hud.garage_view.displayed_model.find_child("Paint",true,false)
		check(mesh.material_override.get_shader_parameter("has_maps"),"车库涂装与比赛一致："+spec.id)
	race.sound.stop_all();race.queue_free();await process_frame
	print("RENDER_QUALITY_RESULT: %d failures"%failures)
	quit(1 if failures else 0)
