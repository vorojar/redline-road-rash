extends SubViewportContainer

var viewport: SubViewport
var scene: Node3D
var pivot: Node3D
var camera: Camera3D
var displayed_model: Node3D
var model_path: String = ""
var auto_rotate: bool = true
var dragging: bool = false
var orbit: float = 2.35
var elevation: float = .38
var distance: float = 3.9
var rotation_amount: float = 0

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	scene = Node3D.new()
	viewport.add_child(scene)
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101513")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c3cec8")
	environment.environment.ambient_light_energy = .65
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	scene.add_child(environment)
	var floor_mesh = MeshInstance3D.new()
	var floor_shape = PlaneMesh.new()
	floor_shape.size = Vector2(60,60)
	floor_mesh.mesh = floor_shape
	floor_mesh.position.y = -.13
	floor_mesh.material_override = material(Color("141c19"),.1,.65)
	scene.add_child(floor_mesh)
	var stage = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 1.75
	cylinder.bottom_radius = 1.78
	cylinder.height = .12
	cylinder.radial_segments = 96
	stage.mesh = cylinder
	stage.position.y = -.065
	stage.material_override = material(Color("353d37"),.4,.44)
	scene.add_child(stage)
	var rim = MeshInstance3D.new()
	var ring = TorusMesh.new()
	ring.inner_radius = 1.725
	ring.outer_radius = 1.74
	rim.mesh = ring
	rim.position.y = -.015
	rim.material_override = material(Color("af9361"),.65,.35)
	scene.add_child(rim)
	for data in [[Vector3(3,5,-3),Color("ffe8c0"),2.4],[Vector3(-3,3,1),Color("9bbcc4"),2.0],[Vector3(0,4,4),Color("d5e1db"),2.8]]:
		var light = OmniLight3D.new()
		light.position = data[0]
		light.light_color = data[1]
		light.light_energy = data[2]
		light.omni_range = 12
		light.shadow_enabled = data[0].x>0 and not get_parent().race.touch_device
		scene.add_child(light)
	pivot = Node3D.new()
	scene.add_child(pivot)
	camera = Camera3D.new()
	camera.fov = 32
	camera.near = .1
	camera.far = 80
	scene.add_child(camera)
	camera.current = true
	update_camera()
	apply_render_quality()

func apply_render_quality() -> void:
	var level: int = get_parent().race.career.settings.render_quality
	preload("res://game/systems/render_quality.gd").apply(viewport,level)
	for light in scene.find_children("*","OmniLight3D",true,false):
		light.shadow_enabled = light.position.x>0 and level>0

func material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	return result

func show_bike(spec: Dictionary) -> void:
	if is_instance_valid(displayed_model): displayed_model.queue_free()
	model_path = spec.model
	displayed_model = load(model_path).instantiate()
	pivot.add_child(displayed_model)
	for mesh in displayed_model.find_children("*","MeshInstance3D",true,false):
		if mesh.name == "Paint":
			mesh.material_override = preload("res://game/vehicles/damage_visuals.gd").paint_material(mesh.mesh.surface_get_material(0),Color(spec.color))
	reset_view()

func reset_view() -> void:
	orbit = 2.35
	elevation = .38
	distance = 3.9
	rotation_amount = 0
	pivot.rotation.y = 0
	auto_rotate = true
	update_camera()

func update_camera() -> void:
	camera.position = Vector3(sin(orbit)*cos(elevation),sin(elevation),cos(orbit)*cos(elevation))*distance+Vector3.UP*.63
	camera.look_at(Vector3.UP*.65)

func _process(dt: float) -> void:
	if visible:
		var aspect = maxf(.5,size.x/maxf(1,size.y))
		camera.fov = rad_to_deg(2*atan(tan(deg_to_rad(32)*.5)*maxf(1,1.55/aspect))) if get_parent().race.touch.enabled else 32
	if dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): dragging = false
	if visible and auto_rotate and not dragging:
		rotation_amount += dt*.22
		pivot.rotation.y = rotation_amount

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if dragging: auto_rotate = false
			accept_event()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			distance = clampf(distance+(-.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .25),3.0,6.5)
			update_camera()
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		rotation_amount += event.relative.x*.012
		pivot.rotation.y = rotation_amount
		elevation = clampf(elevation+event.relative.y*.006,.08,.78)
		update_camera()
		accept_event()
