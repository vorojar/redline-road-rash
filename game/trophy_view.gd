extends SubViewport
# A separate transparent studio keeps the award lit consistently on every track.
var pivot: Node3D

func _ready() -> void:
	own_world_3d = true
	transparent_bg = true
	size = Vector2i(720,720)
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	var stage = Node3D.new()
	add_child(stage)
	var world = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var sky_material = PanoramaSkyMaterial.new()
	var studio = Image.create(512,256,false,Image.FORMAT_RGBF)
	for y in range(256):
		for x in range(512):
			var uv = Vector2(x/512.0,y/256.0)
			var light = exp(-pow((uv.x-.22)/.045,8)-pow((uv.y-.43)/.24,8))*3.5
			light += exp(-pow((uv.x-.70)/.08,8)-pow((uv.y-.40)/.18,8))*2.5
			light += exp(-pow((uv.x-.48)/.20,8)-pow((uv.y-.17)/.04,8))*2.0
			studio.set_pixel(x,y,Color(.075+light,.085+light,.11+light))
	sky_material.panorama = ImageTexture.create_from_image(studio)
	env.sky = Sky.new()
	env.sky.sky_material = sky_material
	world.environment = env
	stage.add_child(world)
	for data in [[Vector3(-3,4,4),Color("ffe8c3"),2.4],[Vector3(3,2,-2),Color("c5ddff"),3.0]]:
		var lamp = OmniLight3D.new()
		lamp.position = data[0]
		lamp.light_color = data[1]
		lamp.light_energy = data[2]
		lamp.omni_range = 10
		stage.add_child(lamp)
	pivot = Node3D.new()
	stage.add_child(pivot)
	var gold = material(Color("e7ad3d"),.92,.21)
	var rim_gold = material(Color("ffdc80"),.95,.16)
	var bronze = material(Color("6d4615"),.8,.3)
	var stone = material(Color("111820"),.3,.25)
	lathe([Vector2(0,0),Vector2(.61,0),Vector2(.65,.045),Vector2(.65,.18),Vector2(.61,.23),Vector2(0,.23)],stone)
	lathe([Vector2(0,.23),Vector2(.6,.23),Vector2(.61,.26),Vector2(.57,.30),Vector2(0,.30)],rim_gold)
	lathe([Vector2(0,.30),Vector2(.45,.30),Vector2(.43,.36),Vector2(.25,.43),Vector2(.13,.55),Vector2(.105,.83),Vector2(.17,.93),Vector2(.24,.99),Vector2(0,.99)],gold)
	# Continuous outer wall, rounded lip and inner wall form a genuinely hollow cup.
	lathe([Vector2(0,.93),Vector2(.22,.93),Vector2(.32,1.02),Vector2(.47,1.17),Vector2(.60,1.39),Vector2(.70,1.68),Vector2(.78,2.06),Vector2(.78,2.12),Vector2(.755,2.145),Vector2(.725,2.12),Vector2(.72,2.06),Vector2(.64,1.69),Vector2(.54,1.41),Vector2(.40,1.19),Vector2(.25,1.07),Vector2(0,1.07)],gold)
	for side in [-1,1]:
		var handle = TorusMesh.new()
		handle.inner_radius = .31
		handle.outer_radius = .39
		handle.rings = 64
		handle.ring_segments = 16
		var mesh = add_mesh(handle,rim_gold,Vector3(side*.77,1.62,0))
		mesh.rotation.x = PI*.5
		mesh.scale = Vector3(.8,1,1.2)
	var rim = TorusMesh.new()
	rim.inner_radius = .725
	rim.outer_radius = .785
	rim.rings = 96
	rim.ring_segments = 16
	add_mesh(rim,rim_gold,Vector3(0,2.115,0))
	var seal = CylinderMesh.new()
	seal.top_radius = .22
	seal.bottom_radius = .22
	seal.height = .024
	seal.radial_segments = 64
	var medallion = add_mesh(seal,rim_gold,Vector3(0,1.70,.764))
	medallion.rotation.x = PI*.5
	var number = TextMesh.new()
	number.text = "1"
	number.font_size = 128
	number.pixel_size = .003
	number.depth = .012
	add_mesh(number,bronze,Vector3(0,1.70,.779))
	var plaque = BoxMesh.new()
	plaque.size = Vector3(.60,.12,.014)
	add_mesh(plaque,gold,Vector3(0,.125,.648))
	var nameplate = TextMesh.new()
	nameplate.text = "REDLINE"
	nameplate.font_size = 64
	nameplate.pixel_size = .0015
	nameplate.depth = .003
	add_mesh(nameplate,bronze,Vector3(0,.125,.660))
	var camera = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0,2.5,5.5)
	camera.look_at(Vector3(0,1.07,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.9
	camera.current = true

func material(color: Color, metal: float, roughness: float) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = roughness
	return m

func add_mesh(shape: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	mesh.mesh = shape
	mesh.material_override = mat
	mesh.position = pos
	pivot.add_child(mesh)
	return mesh

func lathe(profile: Array, mat: Material) -> void:
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments = 96
	for row in range(profile.size()-1):
		for col in range(segments):
			for corner in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var idx = row+corner.y
				var point: Vector2 = profile[idx]
				var angle = (col+corner.x)*TAU/segments
				var tangent: Vector2 = profile[mini(idx+1,profile.size()-1)]-profile[maxi(0,idx-1)]
				var normal = Vector3(tangent.y*cos(angle),-tangent.x,tangent.y*sin(angle)).normalized()
				tool.set_normal(normal)
				tool.add_vertex(Vector3(point.x*cos(angle),point.y,point.x*sin(angle)))
	tool.index()
	add_mesh(tool.commit(),mat)

func present(active: bool, age: float) -> void:
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if active:
		pivot.rotation.y = -.25+maxf(0,age-1.35)*.42
