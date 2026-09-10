extends Node3D

const V = preload("res://game/visuals.gd")
var mobile_quality: bool = false
var route: Path3D
var track: Dictionary
var asphalt: ShaderMaterial
var ground: ShaderMaterial
var roadside: ShaderMaterial
var hazards: Array[Dictionary] = []
var road_meshes: int = 0
var paint_tool: SurfaceTool
signal build_progress(value: float)
var cooperative: bool = false
var slice_started: int = 0

func checkpoint(progress: float) -> void:
	if cooperative and Time.get_ticks_usec()-slice_started >= 4000:
		build_progress.emit(progress)
		await get_tree().process_frame
		slice_started = Time.get_ticks_usec()

func build(path: Path3D, data: Dictionary, gradual: bool = false) -> void:
	cooperative = gradual
	slice_started = Time.get_ticks_usec()
	route = path
	track = data
	asphalt = texture_material("res://assets/textures/asphalt/Asphalt010_1K-JPG_Color.jpg", "res://assets/textures/asphalt/Asphalt010_1K-JPG_NormalGL.jpg", 0)
	ground = texture_material("res://assets/textures/ground/Ground037_1K-JPG_Color.jpg", "res://assets/textures/ground/Ground037_1K-JPG_NormalGL.jpg", 2)
	roadside = ground.duplicate()
	roadside.set_shader_parameter("surface_kind",1)
	var length = float(track.length)
	for section in range(-1, int(length / 100) + 3):
		var from = section * 100.0
		add_strip(from, from + 100, -6.5, 6.5, 0, asphalt, true, 4.0)
		for side in [-1,1]:
			add_strip(from, from + 100, side * 6.5, side * 8.8, -0.015, roadside, true, 3.0)
			add_terrain(from, from + 100, side)
		paint_tool = SurfaceTool.new()
		paint_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var white = V.material(Color("c9c6af").srgb_to_linear())
		var yellow = V.material(Color("ac963e").srgb_to_linear())
		for x in [-6.12,6.12]:
			add_strip(from, from + 100, x - 0.045, x + 0.045, 0.017, white, false, 1)
		for x in [-0.11,0.11]:
			add_strip(from, from + 100, x - 0.035, x + 0.035, 0.02, yellow, false, 1)
		for dash in range(10):
			for x in [-3.12,3.12]:
				add_strip(from+dash*10, from+dash*10+3.6, x-.035, x+.035, .023, white, false, 1)
		paint_tool.generate_normals()
		var markings = MeshInstance3D.new()
		markings.mesh = paint_tool.commit()
		var paint = StandardMaterial3D.new()
		paint.vertex_color_use_as_albedo = true
		paint.roughness = .9
		markings.material_override = paint
		markings.visibility_range_end = 750
		add_child(markings)
		await checkpoint(.05+.5*float(section+2)/(int(length/100)+4))
	if track.has("stages"):
		await build_corridor_landscape(length)
		await build_endurance_landmarks()
	else:
		await build_landscape(length)
	await build_props(length)
	build_hazards(length)
	build_race_gates(length)
	if track.theme == "coast":
		var sea = V.box(self, Vector3(2400,.05,6500), Vector3(-1050,-8,-1900), Color("27434b"))
		sea.material_override.roughness = .24

func texture_material(color_path: String, normal_path: String, kind: int) -> ShaderMaterial:
	var m = ShaderMaterial.new()
	m.shader = preload("res://game/world/land_surface.gdshader")
	m.set_shader_parameter("color_map",load(color_path))
	m.set_shader_parameter("normal_map",load(normal_path))
	m.set_shader_parameter("surface_kind",kind)
	return m

func add_strip(start: float, end: float, left: float, right: float, height: float, mat: Material, collide: bool, uv_scale: float) -> void:
	var st = SurfaceTool.new() if collide else paint_tool
	if collide:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if left > right:
		var tmp = left
		left = right
		right = tmp
	var count = maxi(1, int((end-start)/4.0))
	for i in range(count):
		var a = lerpf(start,end,float(i)/count)
		var b = lerpf(start,end,float(i+1)/count)
		var positions = [route.point(a,left),route.point(a,right),route.point(b,left),route.point(b,right)]
		var uvs = [Vector2(left/uv_scale,a/uv_scale),Vector2(right/uv_scale,a/uv_scale),Vector2(left/uv_scale,b/uv_scale),Vector2(right/uv_scale,b/uv_scale)]
		for index in [0,2,1,1,2,3]:
			if not collide:
				st.set_color(mat.albedo_color)
			st.set_uv(uvs[index])
			st.add_vertex(positions[index]+Vector3.UP*height)
	if not collide:
		return
	st.generate_normals()
	var mesh = MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = mat
	mesh.visibility_range_end = 750
	mesh.visibility_range_end_margin = 60
	add_child(mesh)
	if collide:
		mesh.create_trimesh_collision()
	road_meshes += 1

func add_terrain(start: float, end: float, side: int) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offsets = [8.8, 13.0, 18.0, 24.0]
	for i in range(10):
		for j in range(offsets.size()-1):
			var corners: Array[Vector3] = []
			for pair in [[i,j],[i,j+1],[i+1,j],[i+1,j+1]]:
				var s = lerpf(start,end,float(pair[0])/10)
				var lateral = offsets[pair[1]]
				var pos = route.point(s,side*lateral)
				pos.y = lerpf(pos.y-.06,land_height(pos),smoothstep(8.8,24,lateral))
				corners.append(pos)
			for index in ([0,2,1,1,2,3] if side == 1 else [0,1,2,1,3,2]):
				st.set_uv(Vector2(corners[index].x,corners[index].z)/9)
				st.add_vertex(corners[index])
	st.generate_normals()
	var mesh = MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = ground
	mesh.visibility_range_end = 950
	add_child(mesh)
	mesh.create_trimesh_collision()

func land_height(pos: Vector3) -> float:
	# A world-space height field cannot fold over itself on hairpins.
	var offset = route.curve.get_closest_offset(Vector3(pos.x,0,pos.z))
	var center = route.point(offset)
	var delta = Vector2(pos.x-center.x,pos.z-center.z)
	var distance = delta.length()
	var relief = smoothstep(12,160,distance)
	var noise = sin(pos.x*.015+pos.z*.013)*11+cos(pos.z*.024-pos.x*.011)*7+sin(pos.x*.037)*3
	var height = center.y-1.2+relief*(noise+22)
	if track.theme=="coast":
		var direction = route.tangent(offset)
		var side = Vector3(-direction.z,0,direction.x).dot(pos-center)
		if side<0: height = lerpf(height,-16,smoothstep(12,95,distance))
	if section_kind(offset)=="bridge": height-=28*smoothstep(10,24,distance)
	return height

func section_kind(distance: float) -> String:
	if not track.has("stages"): return ""
	var kind: String=track.stages[0].kind
	for stage in track.stages:
		if stage.start>distance: break
		kind=stage.kind
	return kind

func build_landscape(length: float) -> void:
	var low = Vector2(INF,INF)
	var high = Vector2(-INF,-INF)
	for s in range(0,int(length)+150,50):
		var point = route.point(float(s))
		low = low.min(Vector2(point.x,point.z))
		high = high.max(Vector2(point.x,point.z))
	low -= Vector2(320,320)
	high += Vector2(320,320)
	var step = 12.0
	var cols = int((high.x-low.x)/step)+1
	var rows = int((high.y-low.y)/step)+1
	var vertices: Array[Vector3] = []
	for row in range(rows+1):
		for col in range(cols+1):
			var point = Vector3(low.x+col*step,0,low.y+row*step)
			point.y = land_height(point)
			vertices.append(point)
		await checkpoint(.55+.1*float(row+1)/(rows+1))
	for first in range(0,rows,4):
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row in range(first,mini(first+4,rows)):
			for col in range(cols):
				var a = row*(cols+1)+col
				for index in [a,a+1,a+cols+1,a+1,a+cols+2,a+cols+1]:
					var point = vertices[index]
					st.set_uv(Vector2(point.x,point.z)/9)
					st.add_vertex(point)
		st.generate_normals()
		var mesh = MeshInstance3D.new()
		mesh.mesh = st.commit()
		mesh.material_override = ground
		mesh.visibility_range_end = 1200
		add_child(mesh)
		await checkpoint(.65+.1*float(first+4)/rows)

func multi(mesh: Mesh, transforms: Array[Transform3D], mat: Material, distance: float, near: float = 0.0) -> void:
	# Split batches spatially so distant scenery is actually culled.
	for offset in range(0,transforms.size(),40):
		var node = MultiMeshInstance3D.new()
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = mini(40,transforms.size()-offset)
		for j in range(mm.instance_count):
			mm.set_instance_transform(j,transforms[offset+j])
		node.multimesh = mm
		node.material_override = mat
		node.visibility_range_begin = near
		node.visibility_range_begin_margin = 20
		node.visibility_range_end = distance
		node.visibility_range_end_margin = 50
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)

func build_props(length: float) -> void:
	var details = preload("res://game/world/roadside_details.gd")
	var billboards = details.sponsor_layout(self,length)
	var rng = RandomNumberGenerator.new()
	rng.seed = 329 if track.id == "pine" else 827
	var tree_transforms: Array[Transform3D] = []
	var post_transforms: Array[Transform3D] = []
	var rail_transforms: Array[Transform3D] = []
	for i in range(-2,int(length/8)+12):
		var s = i*8.0
		for side in [-1,1]:
			var t = Transform3D(Basis(Vector3.UP,route.yaw(s)),route.point(s,side*8.5)+Vector3(0,.54,0))
			post_transforms.append(t)
			rail_transforms.append(Transform3D(t.basis,route.point(s,side*8.5)+Vector3(0,.96,0)))
			if track.theme == "coast" and side == -1:
				continue
			if section_kind(s) in ["freight","service","bridge"]: continue
			for k in range(2 if track.theme == "forest" else 1):
				var lane = side*rng.randf_range(12,65)
				var pos = route.point(s+rng.randf_range(-3,3),lane)
				var height = rng.randf_range(8,15)
				pos.y = lerpf(pos.y-.06,land_height(pos),smoothstep(8.8,24,absf(lane)))+height*.5
				var b = Basis.IDENTITY.scaled(Vector3(height*.65,height,height*.65))
				var blocks_billboard = details.blocks_sponsor_view(self,billboards,pos)
				if not blocks_billboard and (not mobile_quality or (i%2==0 and k==0)):
					tree_transforms.append(Transform3D(b,pos))
		await checkpoint(.78+.08*float(i+3)/(int(length/8)+14))
	var post = BoxMesh.new()
	post.size = Vector3(.10,1.08,.12)
	multi(post,post_transforms,V.material(Color("72716b"),.6),450)
	var rail_body = StaticBody3D.new()
	rail_body.collision_layer = 1
	add_child(rail_body)
	for transform_value in rail_transforms:
		var collider = CollisionShape3D.new()
		var rail_shape = BoxShape3D.new()
		rail_shape.size = Vector3(.12,.38,8.15)
		collider.shape = rail_shape
		collider.transform = transform_value
		rail_body.add_child(collider)
		await checkpoint(.89)
	var rail = preload("res://game/world/roadside_details.gd").rail_mesh()
	multi(rail,rail_transforms,V.material(Color("99988d"),.6),650)
	var quad = QuadMesh.new()
	quad.size = Vector2.ONE
	var leaf = StandardMaterial3D.new()
	leaf.albedo_texture = load("res://assets/textures/roadside_pine.png")
	leaf.albedo_color = Color(.68,.77,.59)
	leaf.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	leaf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	leaf.alpha_scissor_threshold = .45
	leaf.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	leaf.billboard_keep_scale = true
	leaf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	multi(quad,tree_transforms,leaf,500 if mobile_quality else 850,0 if mobile_quality else 175)
	if not mobile_quality:
		var near_leaf = leaf.duplicate()
		near_leaf.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		multi(preload("res://game/world/roadside_details.gd").crossed_tree(),tree_transforms,near_leaf,195)
	await preload("res://game/world/roadside_details.gd").build(self,length)
	for s in range(110,int(length),36):
		var curve = route.curvature(float(s))
		if absf(curve)>.009:
			sign_board(float(s), "<<" if curve>0 else ">>", Color("bba243"), 7.3 if curve>0 else -7.3, 1.55)
		await checkpoint(.96)
	for s in range(500,int(length),500):
		sign_board(float(s), "%s\n%d m" % ["COUNTY RUN" if track.id=="interstate" else "PINE COUNTY" if track.id == "pine" else "COAST HIGHWAY",int(length)-s], Color("244b3c"), 7.1, 2.4)

func sign_board(s: float, words: String, color: Color, lane: float, width: float) -> void:
	var root = Node3D.new()
	add_child(root)
	root.position = route.point(s,lane)
	root.rotation.y = route.yaw(s)
	V.box(root,Vector3(.08,3.8,.08),Vector3(0,1.9,0),Color("8b8a80"))
	V.box(root,Vector3(width,1.25,.09),Vector3(0,3.6,0),color.srgb_to_linear())
	var label = Label3D.new()
	label.font = load("res://assets/fonts/RedlineUI.ttf")
	label.text = words
	label.font_size = 60
	var text_width = 1.0
	for line in words.split("\n"):
		text_width = maxf(text_width,label.font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size).x)
	label.pixel_size = minf(.008,width*.88/text_width)
	label.modulate = Color("242723") if color.r>color.b*1.5 else Color("e7e2cc")
	label.outline_size = 0
	label.position = Vector3(0,3.6,.06)
	root.add_child(label)

func build_hazards(length: float) -> void:
	for s in [650.0,1490.0,2410.0]:
		if s > length:
			continue
		sign_board(s-90,"ROAD WORK\n80 m",Color("b36527"),7,2.2)
		for j in range(5):
			var lane = 5.5-j*.15
			var pos = route.point(s+j*4,lane)
			var cone = Node3D.new()
			add_child(cone)
			cone.position = pos
			V.box(cone,Vector3(.55,.06,.55),Vector3(0,.03,0),Color("292821"))
			var top = V.cylinder(cone,.21,.65,Vector3(0,.37,0),Color("c2652a"))
			(top.mesh as CylinderMesh).top_radius = .035
			hazards.append({"s":s+j*4,"lane":lane,"radius":.5,"hit":false,"node":cone})

func build_race_gates(length: float) -> void:
	build_start_gate()
	build_finish_gate(length)

func build_start_gate() -> void:
	var line_root = race_gate_root(0.0,"Start Line")
	add_ground_checker(line_root,"Ground Checker")
	# Place the gantry ahead of the staggered rider grid so it stays in the
	# chase-camera view during the countdown instead of sitting above the camera.
	var root = race_gate_root(12.0,"Start Gate")
	add_gate_frame(root,Color("a72528"))
	V.box(root,Vector3(14.7,.92,.16),Vector3(0,5.2,0),Color("171918"))
	add_gate_label(root,"S T A R T",Color("f1eee0"))
	# Five high-contrast starting lamps make the grid readable from the chase camera.
	for i in range(5):
		var housing = V.cylinder(root,.24,.16,Vector3((i-2)*.72,4.47,.08),Color("242725"))
		housing.rotation.x = PI*.5
		var lens = V.cylinder(root,.16,.18,Vector3((i-2)*.72,4.47,.18),Color("b92e28") if i<4 else Color("4fa64e"))
		lens.rotation.x = PI*.5

func build_finish_gate(length: float) -> void:
	var root = race_gate_root(length,"Finish Gate")
	add_ground_checker(root,"Finish Line")
	add_gate_frame(root,Color("494b46"))
	add_checkerboard(root,Vector3(0,5.2,0),Vector2(14.7,1.2),16,4,"Finish Flag",true)
	V.box(root,Vector3(5.2,.62,.18),Vector3(0,6.18,0),Color("a72528"))
	add_gate_label(root,"F I N I S H",Color("f1eee0"),6.18,.0042)

func race_gate_root(distance: float, node_name: String) -> Node3D:
	var root = Node3D.new()
	root.name = node_name
	add_child(root)
	root.position = route.point(distance)
	root.rotation.y = route.yaw(distance)
	return root

func add_gate_frame(root: Node3D, accent: Color) -> void:
	for side in [-1,1]:
		V.box(root,Vector3(.20,5.6,.20),Vector3(side*7.2,2.8,0),Color("494b46"))
		V.box(root,Vector3(.34,.76,.34),Vector3(side*7.2,.38,0),accent)

func add_gate_label(root: Node3D, words: String, color: Color, height: float = 5.2, pixel_size: float = .005) -> void:
	var label = Label3D.new()
	label.name = words.replace(" ","").capitalize()+" Label"
	label.text = words
	label.font_size = 120
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 0
	label.position = Vector3(0,height,.11)
	root.add_child(label)

func add_ground_checker(root: Node3D, node_name: String) -> void:
	var line = Node3D.new()
	line.name = node_name
	root.add_child(line)
	add_checkerboard(line,Vector3(0,.045,0),Vector2(13,3.0),10,4,"Cells")

func add_checkerboard(parent: Node3D, center: Vector3, size: Vector2, columns: int, rows: int, node_name: String, vertical: bool = false) -> Node3D:
	var board = Node3D.new()
	board.name = node_name
	parent.add_child(board)
	var cell = Vector2(size.x/columns,size.y/rows)
	for row in range(rows):
		for column in range(columns):
			var color = Color("eeeadd") if (row+column)%2==0 else Color("151716")
			var offset = Vector3(-size.x*.5+cell.x*(column+.5),-size.y*.5+cell.y*(row+.5),0) if vertical else Vector3(-size.x*.5+cell.x*(column+.5),0,-size.y*.5+cell.y*(row+.5))
			V.box(board,Vector3(cell.x,cell.y,.14) if vertical else Vector3(cell.x,.035,cell.y),center+offset,color)
	return board

func build_corridor_landscape(length: float) -> void:
	# Long routes use terrain along the road corridor. A world-sized rectangular
	# grid grows with the bounding box and wastes most of its mesh off screen.
	for start in range(-100,int(length)+200,100):
		for side in [-1,1]:
			var tool=SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for row in range(5):
				for col in range(6):
					for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
						var distance=float(start+(row+corner.y)*20)
						var lane=side*(24+(col+corner.x)*35.0)
						var pos=route.point(distance,lane)
						pos.y=land_height(pos) if col+corner.x==0 else route.point(distance).y+sin(distance*.015+lane*.02)*18+cos(lane*.025)*12
						tool.set_uv(Vector2(pos.x,pos.z)/9)
						tool.add_vertex(pos)
			tool.generate_normals()
			var mesh=MeshInstance3D.new()
			mesh.mesh=tool.commit();mesh.material_override=ground
			mesh.visibility_range_end=1000
			# The terrain shader renders both corridor sides.
			add_child(mesh)
		await checkpoint(.55+.2*float(start+200)/(length+300))

func build_endurance_landmarks() -> void:
	for stage in track.stages:
		await checkpoint(.77)
		sign_board(stage.start+30,stage.name,Color("244b3c"),7.2,3.6)
		if stage.kind=="service":
			for s in range(int(stage.start),int(stage.start)+450,50):
				sign_board(s,"SERVICE / STOP",Color("355f84"),7.2,2.8)
			var station=Node3D.new();add_child(station)
			station.position=route.point(stage.start+130,13)
			station.position.y=land_height(station.position)
			station.rotation.y=route.yaw(stage.start+130)
			V.box(station,Vector3(7,3.2,12),Vector3(0,1.6,0),Color("756f5a"))
			V.box(station,Vector3(9,.3,14),Vector3(0,3.4,0),Color("303b40"))
			for z in [-3,3]: V.box(station,Vector3(.08,1.8,2.4),Vector3(-3.55,1.1,z),Color("283d41"))
		elif stage.kind=="freight":
			for i in range(7):
				var depot=Node3D.new();add_child(depot)
				depot.position=route.point(stage.start+120+i*140,(-1 if i%2 else 1)*20)
				depot.position.y=land_height(depot.position)
				depot.rotation.y=route.yaw(stage.start+120+i*140)
				V.box(depot,Vector3(16,7,28),Vector3(0,3.5,0),Color("858a83"))
				V.box(depot,Vector3(17,.3,29),Vector3(0,7.1,0),Color("3e484b"))
				for z in [-8,0,8]: V.box(depot,Vector3(.1,4,5),Vector3(-8.05,2,z),Color("39434a"))
		elif stage.kind=="bridge":
			for s in range(int(stage.start)+150,int(stage.start)+1000,25):
				for side in [-1,1]:
					var a=route.point(s,side*7.7)
					var b=route.point(s+25,side*7.7)
					bridge_beam(a,a+Vector3.UP*5,.28)
					bridge_beam(a+Vector3.UP*4.9,b+Vector3.UP*4.9,.18)
					bridge_beam(a+Vector3.UP*.8,b+Vector3.UP*4.9,.14)
				bridge_beam(route.point(s,-7.7)+Vector3.UP*5,route.point(s,7.7)+Vector3.UP*5,.20)
				await checkpoint(.77)

func bridge_beam(a: Vector3,b: Vector3,width: float) -> void:
	var beam=V.box(self,Vector3(width,width,a.distance_to(b)),(a+b)*.5,Color("62787b"))
	beam.look_at(b,Vector3.FORWARD if absf((b-a).normalized().dot(Vector3.UP))>.99 else Vector3.UP)
