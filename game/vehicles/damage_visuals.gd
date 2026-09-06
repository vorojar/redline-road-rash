extends RefCounted
const SHADER=preload("res://game/vehicles/damage.gdshader")
var paints: Array[ShaderMaterial] = []
var smoke: CPUParticles3D
var condition: float = 1

func attach(actor: Node3D) -> void:
	paints.clear()
	for mesh in actor.bike.find_children("*","MeshInstance3D",true,false):
		if mesh.name=="Paint":
			var source=mesh.get_active_material(0)
			var mat=ShaderMaterial.new()
			mat.shader=SHADER
			mat.set_shader_parameter("tint",source.albedo_color)
			mesh.material_override=mat
			paints.append(mat)
	if not is_instance_valid(smoke):
		smoke=CPUParticles3D.new()
		smoke.amount=18
		smoke.lifetime=1.8
		smoke.emitting=false
		smoke.local_coords=false
		smoke.position=Vector3(.15,.65,.0)
		smoke.direction=Vector3(0,1,.3)
		smoke.spread=24
		smoke.gravity=Vector3(0,.1,.4)
		smoke.initial_velocity_min=.4; smoke.initial_velocity_max=.9
		smoke.scale_amount_min=.15; smoke.scale_amount_max=.3
		var fade=Gradient.new()
		fade.set_color(0,Color(.15,.17,.18,.24));fade.set_color(1,Color(.17,.18,.19,0))
		smoke.color_ramp=fade
		var quad=QuadMesh.new();quad.size=Vector2.ONE
		var m=StandardMaterial3D.new()
		m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo=true
		m.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES
		m.cull_mode=BaseMaterial3D.CULL_DISABLED
		var texture=GradientTexture2D.new()
		texture.width=32;texture.height=32;texture.fill=GradientTexture2D.FILL_RADIAL
		texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(1,.5)
		texture.gradient=Gradient.new()
		texture.gradient.set_color(0,Color.WHITE);texture.gradient.set_color(1,Color(1,1,1,0))
		m.albedo_texture=texture
		quad.material=m;smoke.mesh=quad
		actor.add_child(smoke)
	update(1,false)

func update(value: float, running: bool) -> void:
	condition=clampf(value,0,1)
	for paint in paints: paint.set_shader_parameter("wear",1-condition)
	if is_instance_valid(smoke): smoke.emitting=running and condition<.45
