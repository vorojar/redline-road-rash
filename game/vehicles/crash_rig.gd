extends Node3D
# World-space bodies keep their momentum while the route controller stops driving.
var bodies: Dictionary = {}
var lengths: Dictionary = {}
var bike_body: RigidBody3D
var frozen: bool = false
var settled: bool = false

func body_at(key: String, a: Vector3, b: Vector3, radius: float, mass_value: float, initial_velocity: Vector3) -> RigidBody3D:
	var body = RigidBody3D.new()
	body.mass = mass_value
	body.collision_layer = 4
	body.collision_mask = 1 | 2 | 8
	body.continuous_cd = true
	body.linear_damp = .8
	body.angular_damp = 2.3
	body.physics_material_override = PhysicsMaterial.new()
	body.physics_material_override.friction = .8
	body.physics_material_override.bounce = .05
	var collider = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = radius
	shape.height = maxf(radius*2,(b-a).length())
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	body.global_position = (a+b)*.5
	body.global_basis = Basis(Quaternion(Vector3.UP,(b-a).normalized()))
	body.linear_velocity = initial_velocity
	bodies[key] = body
	lengths[key] = (b-a).length()
	return body

func launch(actor: Node3D, segments: Dictionary, motion: Vector3) -> void:
	motion = motion.limit_length(20)
	for key in segments:
		var endpoints: Array = segments[key]
		var a: Vector3 = actor.skeleton.global_transform*endpoints[0]+Vector3.UP*.12
		var b: Vector3 = actor.skeleton.global_transform*endpoints[1]+Vector3.UP*.12
		var radius = .16 if key in ["hips","spine"] else (.12 if key=="head" else .065)
		body_at(key,a,b,radius,18 if key=="spine" else 5,motion+Vector3.UP*1.6)
	for key in bodies:
		if key=="hips": continue
		var parent_key: String = "hips"
		if key=="head" or key.begins_with("upper_arm"): parent_key = "spine"
		elif key.begins_with("forearm"): parent_key = key.replace("forearm","upper_arm")
		elif key.begins_with("shin"): parent_key = key.replace("shin","thigh")
		var joint = ConeTwistJoint3D.new()
		add_child(joint)
		joint.global_position = actor.skeleton.global_transform*segments[key][0]+Vector3.UP*.12
		# ConeTwist constraint axis is local X; align it with the child's long axis.
		joint.global_basis = Basis(Quaternion(Vector3.RIGHT,(bodies[key].global_basis.y).normalized()))
		joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN,.65 if key=="head" else 1.05)
		joint.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN,.4)
		joint.node_a = joint.get_path_to(bodies[parent_key])
		joint.node_b = joint.get_path_to(bodies[key])
	bike_body = body_at("bike",actor.to_global(Vector3(0,.4,-.65)),actor.to_global(Vector3(0,.4,.65)),.22,150,motion*.82)
	bike_body.angular_velocity = actor.global_basis.z*2.6+actor.global_basis.x*.5
	bike_body.linear_damp = 1.1
	bodies["spine"].angular_velocity = actor.global_basis.x*3+actor.global_basis.z*motion.dot(actor.global_basis.x)*.2

func sync(actor: Node3D) -> void:
	actor.rider.transform = Transform3D.IDENTITY
	var inverse: Transform3D = actor.skeleton.global_transform.affine_inverse()
	for key in bodies:
		if key=="bike": continue
		var body: RigidBody3D = bodies[key]
		var half: Vector3 = body.global_basis.y*float(lengths[key])*.5
		actor.bone(key,inverse*(body.global_position-half),inverse*(body.global_position+half))
	# Bike collider's Y axis follows the motorcycle's longitudinal axis.
	actor.bike.global_transform = Transform3D(bike_body.global_basis*Basis(Vector3.RIGHT,-PI/2),bike_body.global_position)
	actor.bike.position -= actor.bike.basis*Vector3(0,.4,0)

func pause(value: bool) -> void:
	frozen = value
	for body in bodies.values(): body.freeze = value or settled

func settle() -> void:
	settled = true
	pause(frozen)
