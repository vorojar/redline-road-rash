extends SceneTree
const Actor = preload("res://game/vehicles/bike_actor.gd")
var failures = 0
var checks = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("[PASS] "+label)
	else:
		failures += 1
		printerr("FAIL: "+label)

func _initialize() -> void: call_deferred("run")

func vertices(node: Node3D) -> PackedVector3Array:
	var points = PackedVector3Array()
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		for surface in range(mesh.mesh.get_surface_count()):
			for point in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				points.append(node.to_local(mesh.to_global(point)))
	return points

func run() -> void:
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	var actor = Actor.new()
	root.add_child(actor)
	actor.set_model(catalog.bikes[0])
	var meshes = actor.bike.find_children("*","MeshInstance3D",true,false)
	var triangle_count = 0
	var textures_ok = true
	for mesh in meshes:
		for surface in range(mesh.mesh.get_surface_count()):
			triangle_count += mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()/3
			var material: StandardMaterial3D = mesh.mesh.surface_get_material(surface)
			for texture in [material.albedo_texture,material.normal_texture,material.roughness_texture,material.metallic_texture]:
				if texture!=null:
					textures_ok = textures_ok and maxi(texture.get_width(),texture.get_height())<=1024
	check(triangle_count==69908,"拆分轮组没有丢失原车身几何")
	check(meshes.size()<=12 and textures_ok,"运行模型最多 12 个 Mesh，全部贴图不超过 1K")
	for name in ["WheelFront","WheelRear"]:
		var wheel = actor.bike.find_child(name,true,false)
		check(wheel.get_child_count()==2,"轮胎与轮毂都挂在独立轮轴："+name)
		var local_points = vertices(wheel)
		var rolling_ok = true
		for angle in [0.0,PI/4,PI/2,PI,PI*1.5]:
			actor.pose(0,0,0,0,0,1,0,0,angle*.34)
			var bottom = INF
			var top = -INF
			for point in local_points:
				var height: float = (wheel.transform*point).y
				bottom = minf(bottom,height)
				top = maxf(top,height)
			rolling_ok = rolling_ok and absf(bottom)<.002 and absf(top-.68)<.002
		check(rolling_ok,"车轮旋转不绕车身公转、不椭圆跳动："+name)
	actor.front_compression=.085
	actor.rear_compression=.035
	actor.pose(0,0,0,0,0,1,0)
	check(is_equal_approx(actor.bike.find_child("WheelFront",true,false).position.y,.39) and
		is_equal_approx(actor.bike.find_child("WheelRear",true,false).position.y,.34),"前悬挂压缩只移动前轮")
	actor.front_compression=.035
	var body_points = vertices(actor.bike)
	for side in [-1,1]:
		var nearest = INF
		var grip: Vector3 = actor.riding_grip(side)
		for point in body_points: nearest=minf(nearest,point.distance_to(grip))
		check(nearest<.025,"车型握持点落在实际车把几何上：%d"%side)
		var hand_ok = true
		for speed in [0.0,34.0,55.0]:
			actor.ride_speed=speed
			actor.pose(0,0,0,0,0,1,0)
			var suffix = "L" if side<0 else "R"
			hand_ok = hand_ok and actor.segments["forearm_"+suffix][1].distance_to(grip)<.01
		check(hand_ok,"低速与高速骑姿都握住新车把：%d"%side)
	var paint: ShaderMaterial = actor.damage_visuals.paints[0]
	var source: StandardMaterial3D = actor.bike.find_child("Paint",true,false).mesh.surface_get_material(0)
	check(paint.get_shader_parameter("tint_warm_colors") and
		paint.get_shader_parameter("metallic_map")==source.metallic_texture and
		paint.get_shader_parameter("metallic_channel")==source.metallic_texture_channel,"新车换色和车损保留原金属度贴图通道")
	actor.queue_free()
	await process_frame
	print("STREET_BIKE_RESULT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
