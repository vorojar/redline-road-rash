extends RefCounted
const V = preload("res://game/visuals.gd")

static func rail_mesh() -> ArrayMesh:
	# Folded W-beam profile catches light; collision remains the existing box.
	var profile = [Vector2(0,-.14),Vector2(.035,-.11),Vector2(-.025,-.055),Vector2(.025,0),Vector2(-.025,.055),Vector2(.035,.11),Vector2(0,.14)]
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(profile.size()-1):
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i+1]
		var points = [Vector3(a.x,a.y,-4.075),Vector3(b.x,b.y,-4.075),Vector3(a.x,a.y,4.075),Vector3(b.x,b.y,4.075)]
		for index in [0,1,2,1,3,2,2,1,0,2,3,1]: tool.add_vertex(points[index])
	tool.generate_normals()
	return tool.commit()

static func crossed_tree() -> ArrayMesh:
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for plane in range(3):
		var basis = Basis(Vector3.UP,plane*PI/3)
		var points = [Vector3(-.5,-.5,0),Vector3(.5,-.5,0),Vector3(-.5,.5,0),Vector3(.5,.5,0)]
		var uvs = [Vector2(0,1),Vector2(1,1),Vector2(0,0),Vector2(1,0)]
		for index in [0,1,2,1,3,2]:
			tool.set_uv(uvs[index])
			tool.add_vertex(basis*points[index])
	tool.generate_normals()
	return tool.commit()

static func segment_transform(a: Vector3, b: Vector3) -> Transform3D:
	var delta = b-a
	# Scale the cylinder in its local Y axis before rotating it onto the span.
	return Transform3D(Basis(Quaternion(Vector3.UP,delta.normalized()))*Basis.from_scale(Vector3(1,delta.length(),1)),(a+b)*.5)

static func sponsor_distances(world: Node3D, length: float, openai: bool = false) -> PackedFloat32Array:
	var distances = PackedFloat32Array()
	for anchor in ([length*.15,length*.71] if openai else [220.0,length*.32,length*.58,length*.84]):
		var found = false
		for step in range(ceili(length/40)):
			for side in [-1,1]:
				var s: float = anchor+step*40*side
				if s>60 and s<length-60 and world.section_kind(s) not in ["service","freight","bridge"]:
					distances.append(s)
					found = true
					break
			if found: break
		assert(found,"Sponsor billboard needs an ordinary roadside section")
	return distances

static func sponsor_board(openai: bool = false) -> Node3D:
	var board = Node3D.new()
	board.name = "OpenAI Billboard" if openai else "EHAFO Billboard"
	if openai:
		# Highway-scale monopole, rear steelwork and maintenance catwalk.
		V.box(board,Vector3(2.2,.6,2.2),Vector3(0,.3,0),Color("777b77"))
		V.cylinder(board,.48,6.4,Vector3(0,3.2,0),Color("636b6c"))
		V.box(board,Vector3(12.4,4.4,.38),Vector3(0,8.6,0),Color("333b40"))
		for x in [-5.6,-2.8,0,2.8,5.6]:
			V.box(board,Vector3(.15,4.2,.3),Vector3(x,8.6,-.38),Color("687176"))
		for y in [6.65,8.6,10.55]:
			V.box(board,Vector3(12.1,.16,.3),Vector3(0,y,-.42),Color("687176"))
		V.box(board,Vector3(12.8,.16,1.25),Vector3(0,5.45,.2),Color("51595d"))
		for x in [-6.3,-4.2,-2.1,0,2.1,4.2,6.3]:
			V.box(board,Vector3(.055,.8,.055),Vector3(x,5.9,.8),Color("6c7477"))
		V.box(board,Vector3(12.65,.055,.055),Vector3(0,6.3,.8),Color("6c7477"))
	else:
		for x in [-1.8,1.8]:
			V.box(board,Vector3(.12,3.6,.12),Vector3(x,1.8,0),Color("62665e"))
		V.box(board,Vector3(5.0,1.8,.16),Vector3(0,3.5,0),Color("252b29"))
	var face = MeshInstance3D.new()
	face.name = "Sponsor Face"
	var quad = QuadMesh.new()
	quad.size = Vector2(12,4) if openai else Vector2(4.8,1.6)
	face.mesh = quad
	face.position = Vector3(0,8.6,.2) if openai else Vector3(0,3.5,.085)
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = StandardMaterial3D.new()
	material.albedo_texture = preload("res://assets/textures/sponsors/openai.png") if openai else preload("res://assets/textures/sponsors/ehafo.png")
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	face.material_override = material
	board.add_child(face)
	return board

static func build(world: Node3D, length: float) -> void:
	for openai in [false,true]:
		for s in sponsor_distances(world,length,openai):
			var board = sponsor_board(openai)
			board.name = ("%s %d" % ["OpenAI" if openai else "EHAFO",roundi(s)])
			world.add_child(board)
			var lane = 17.0 if openai else 11.8
			board.position = world.route.point(s,lane)
			board.position.y = lerpf(board.position.y-.06,world.land_height(board.position),smoothstep(8.8,24,lane))
			board.rotation.y = world.route.yaw(s)
	var markers: Array[Transform3D] = []
	var reflectors: Array[Transform3D] = []
	var stones: Array[Transform3D] = []
	var bushes: Array[Transform3D] = []
	var poles: Array[Transform3D] = []
	var arms: Array[Transform3D] = []
	var wires: Array[Transform3D] = []
	var rng = RandomNumberGenerator.new()
	rng.seed = 9102
	for s in range(0,int(length)+1,32):
		if s%96==0 and not world.section_kind(s) in ["service","freight","bridge"]:
			var origin = world.route.point(s,13)
			origin.y = lerpf(origin.y-.06,world.land_height(origin),smoothstep(8.8,24,13.0))
			var pole_basis = Basis(Vector3.UP,world.route.yaw(s))
			poles.append(Transform3D(pole_basis,origin+Vector3.UP*3.5))
			arms.append(Transform3D(pole_basis,origin+Vector3.UP*6.65))
			if not world.mobile_quality and s+96<length and world.section_kind(s+96)==world.section_kind(s):
				var next = world.route.point(s+96,13)
				next.y = lerpf(next.y-.06,world.land_height(next),smoothstep(8.8,24,13.0))
				for side in [-1,1]:
					var a = origin+Vector3.UP*6.8+pole_basis.x*side*.85
					var b = next+Vector3.UP*6.8+Basis(Vector3.UP,world.route.yaw(s+96)).x*side*.85
					for part in range(4):
						var t0 = part/4.0
						var t1 = (part+1)/4.0
						var p0 = a.lerp(b,t0)-Vector3.UP*sin(t0*PI)*.6
						var p1 = a.lerp(b,t1)-Vector3.UP*sin(t1*PI)*.6
						wires.append(segment_transform(p0,p1))
		for side in [-1,1]:
			var basis = Basis(Vector3.UP,world.route.yaw(s))
			markers.append(Transform3D(basis,world.route.point(s,side*7.8)+Vector3.UP*.52))
			reflectors.append(Transform3D(basis,world.route.point(s,side*7.8)+Vector3.UP*.92))
			if world.section_kind(s) in ["service","freight","bridge"]: continue
			if world.track.theme=="coast" and side<0: continue
			for i in range(1 if world.mobile_quality else 3):
				var lane = side*rng.randf_range(10.2,18.0)
				var pos = world.route.point(s+rng.randf_range(-12,12),lane)
				pos.y = lerpf(pos.y-.06,world.land_height(pos),smoothstep(8.8,24,absf(lane)))
				var size = rng.randf_range(.25,.65)
				stones.append(Transform3D(basis.scaled(Vector3(size*1.5,size*.6,size)),pos+Vector3.UP*size*.2))
				if i==0:
					var height = rng.randf_range(1.6,2.5)
					bushes.append(Transform3D(basis.scaled(Vector3(height*1.5,height,height*1.5)),pos+Vector3.UP*height*.40))
		await world.checkpoint(.90)
	var marker = BoxMesh.new()
	marker.size = Vector3(.12,1.04,.10)
	world.multi(marker,markers,V.material(Color("cecbb8")),280)
	var reflector = BoxMesh.new()
	reflector.size = Vector3(.125,.13,.11)
	world.multi(reflector,reflectors,V.material(Color("d8a452"),.12),280)
	var stone = SphereMesh.new()
	stone.radial_segments = 8
	stone.rings = 4
	stone.radius = .5
	stone.height = 1.0
	world.multi(stone,stones,V.material(Color("656559")),180)
	var foliage = StandardMaterial3D.new()
	foliage.albedo_texture = load("res://assets/textures/roadside_pine.png")
	foliage.albedo_color = Color(.46,.57,.32)
	foliage.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	foliage.alpha_scissor_threshold = .4
	foliage.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	foliage.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foliage.cull_mode = BaseMaterial3D.CULL_DISABLED
	world.multi(crossed_tree(),bushes,foliage,180)
	var pole = CylinderMesh.new()
	pole.top_radius = .09
	pole.bottom_radius = .14
	pole.height = 7
	pole.radial_segments = 8
	world.multi(pole,poles,V.material(Color("544b39")),400)
	var arm = BoxMesh.new()
	arm.size = Vector3(2.2,.12,.14)
	world.multi(arm,arms,V.material(Color("554c3e")),400)
	var wire = CylinderMesh.new()
	wire.top_radius = .012
	wire.bottom_radius = .012
	wire.height = 1
	wire.radial_segments = 4
	world.multi(wire,wires,V.material(Color("252b2c")),180)
