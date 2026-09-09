extends SceneTree
const Traffic = preload("res://game/systems/traffic.gd")
const Details = preload("res://game/world/roadside_details.gd")
var failures = 0
var checks = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("[PASS] "+message)
	else:
		failures += 1
		printerr("FAIL: "+message)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for path in ["roadside_pine.png","asphalt/Asphalt010_1K-JPG_Color.jpg","asphalt/Asphalt010_1K-JPG_NormalGL.jpg","ground/Ground037_1K-JPG_Color.jpg","ground/Ground037_1K-JPG_NormalGL.jpg"]:
		var texture: Texture2D = load("res://assets/textures/"+path)
		check(texture.get_image().has_mipmaps(),"远景纹理具有实际 mipmaps："+path)
	for truck in [false,true]:
		var color = Color("436571")
		var car = Traffic.vehicle(color,truck)
		root.add_child(car)
		var paints = 0
		var concealed_windows = 0
		var triangles = 0
		for mesh in car.find_children("*","MeshInstance3D",true,false):
			for surface in range(mesh.mesh.get_surface_count()):
				triangles += mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()/3
				var material = mesh.get_active_material(surface)
				if material.resource_name in ["Window glass","Window sunstrip"]:
					concealed_windows += 1
					check(material is StandardMaterial3D and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.albedo_color.a==1.0,"车窗与遮阳带完全遮住空车厢："+str(truck))
				if mesh.mesh.surface_get_material(surface)!=null and mesh.mesh.surface_get_material(surface).resource_name=="Paint":
					paints += 1
					check(mesh.get_active_material(surface).albedo_color.is_equal_approx(color.srgb_to_linear()),"车型车漆使用指定颜色："+str(truck))
		check(concealed_windows==2,"两种交通车都有车窗与上沿遮阳带："+str(truck))
		check(paints==1,"轿车/货车均保留唯一可换色车身："+str(truck))
		check(triangles>1000 and triangles<40000,"交通模型三角面预算："+str(truck))
		var collider = car.get_node("VehicleSolid").get_child(0)
		check(collider.shape.size==Vector3(2.16,2.7 if truck else 1.6,6.1 if truck else 4.2) and collider.position==Vector3(0,1.35 if truck else .8,.9 if truck else 0),"视觉换模保留原碰撞盒和位置："+str(truck))
		var lamps: Dictionary = car.get_meta("lamps")
		check(lamps.brake.size()==2 and not lamps.brake[0].visible and lamps.left.get_child_count()==2 and lamps.right.get_child_count()==2,"两种车型保留独立刹车灯和双侧转向灯："+str(truck))
		car.queue_free()
	var billboard = Details.sponsor_board()
	root.add_child(billboard)
	var face = billboard.get_node("Sponsor Face")
	check(face.mesh.size==Vector2(4.8,1.6) and face.position.z>.08,"广告牌保持 EHAFO 3:1 比例且面板不与背板重叠")
	check(face.material_override.albedo_texture.resource_path=="res://assets/textures/sponsors/ehafo.png" and face.material_override.albedo_texture.get_image().has_mipmaps(),"路牌复用已有 EHAFO 主标与 mipmaps")
	check(billboard.find_children("*","CollisionObject3D",true,false).is_empty(),"路外广告牌不新增游戏碰撞障碍")
	billboard.queue_free()
	var highway_board = Details.sponsor_board(true)
	root.add_child(highway_board)
	var highway_face = highway_board.get_node("Sponsor Face")
	check(highway_face.mesh.size==Vector2(12,4) and is_equal_approx(highway_face.position.y,8.6),"OpenAI 高速广告牌使用 12×4 米高架画面")
	check(highway_face.material_override.albedo_texture.resource_path=="res://assets/textures/sponsors/openai.png" and highway_face.material_override.albedo_texture.get_image().has_mipmaps(),"OpenAI 贴图启用远景 mipmaps")
	check(highway_board.find_children("*","CollisionObject3D",true,false).is_empty(),"大型广告牌位于路外且不增加碰撞障碍")
	highway_board.queue_free()
	var tree = Details.crossed_tree()
	check(tree.get_faces().size()==18 and tree.get_aabb().size.y==1.0,"近景树使用三向交叉面且高度与远景一致")
	var rail = Details.rail_mesh()
	check(is_equal_approx(rail.get_aabb().size.z,8.15) and rail.get_aabb().size.y<=.38,"折面护栏维持原有分段长度并位于碰撞高度内")
	for end in [Vector3(24,7,5),Vector3(3,30,29)]:
		var start = Vector3(3,7,5)
		var transform = Details.segment_transform(start,end)
		check((transform*Vector3(0,-.5,0)).distance_to(start)<.001 and (transform*Vector3(0,.5,0)).distance_to(end)<.001,"斜向电缆准确连接端点且不会缩短成悬空板")
	await process_frame
	print("WORLD_VISUALS_RESULT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
