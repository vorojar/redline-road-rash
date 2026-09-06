extends RefCounted
# Recovery is authored in actor space; walking cadence follows travelled metres.
var origin: Vector3
var approach: Vector3
var facing: float
var side: float
var bike_rest: Transform3D

func configure(actor: Node3D) -> void:
	origin = actor.to_local(actor.crash_rig.bodies.hips.global_position)
	origin.y = ground(actor,origin)
	side = -1.0 if origin.x<0 else 1.0
	approach = Vector3(side*.66,0,.25)
	approach.y = ground(actor,approach)
	var direction = approach-origin
	facing = atan2(-direction.x,-direction.z) if direction.length()>.1 else 0.0
	bike_rest = actor.bike.transform

func ground(actor: Node3D, position: Vector3) -> float:
	var start: Vector3 = actor.to_global(position+Vector3.UP*3)
	var query = PhysicsRayQueryParameters3D.create(start,start-Vector3.UP*8,1)
	var hit = actor.get_world_3d().direct_space_state.intersect_ray(query)
	return actor.to_local(hit.position).y if not hit.is_empty() else 0.0

static func bend(a: Vector3, b: Vector3, upper: float, lower: float, hint: Vector3) -> Vector3:
	var delta = b-a
	var distance = clampf(delta.length(),.05,upper+lower-.008)
	var axis = delta.normalized()
	var along = (upper*upper-lower*lower+distance*distance)/(2*distance)
	var outward = (hint-axis*hint.dot(axis)).normalized()
	return a+axis*along+outward*sqrt(maxf(.001,upper*upper-along*along))

func apply(actor: Node3D, t: float) -> void:
	var walk = smoothstep(.95,2.65,t)
	var lift = smoothstep(2.85,3.45,t)
	var mount = smoothstep(3.45,4.2,t)
	var crouch = 1.0-smoothstep(.35,.95,t)
	var root = origin.lerp(approach,walk)
	root.y = ground(actor,root)
	var turn = smoothstep(2.35,2.85,t)
	var yaw = lerp_angle(facing,0,turn)
	actor.rider.position = root.lerp(Vector3.ZERO,mount)
	actor.rider.rotation = Vector3(0,yaw,0)
	actor.bike.transform = bike_rest.interpolate_with(Transform3D.IDENTITY,lift)
	var travelled = Vector2(root.x-origin.x,root.z-origin.z).length()
	var gait = smoothstep(.95,1.15,t)*(1-smoothstep(2.4,2.65,t))
	var walking = gait>0
	var stride = .52
	var phase = travelled/(stride*2)*TAU
	var weight = sin(phase)*.025*gait if walking else 0.0
	var bob = absf(sin(phase))*.035*gait if walking else 0.0
	var reach = smoothstep(2.65,2.90,t)*(1-mount)
	var hip = Vector3(weight,.91-crouch*.45+bob,0)
	var shoulder = hip+Vector3(-weight*.6-side*reach*.16,.47-crouch*.16,-.045-crouch*.25-reach*.12)
	var head = shoulder+Vector3(0,.065,-.025)
	var anchors = actor.riding_anchors()
	hip = hip.lerp(anchors[0],mount)
	shoulder = shoulder.lerp(anchors[1],mount)
	head = head.lerp(anchors[2],mount)
	actor.bone("hips",hip,hip+Vector3(0,.15,0))
	actor.bone("spine",hip+Vector3(0,.06,-.04),shoulder)
	actor.bone("head",head,head+Vector3(0,.33,-.04))
	for sign_value in [-1,1]:
		var suffix = "L" if sign_value<0 else "R"
		var cycle = fposmod(travelled/(stride*2)+(0 if sign_value<0 else .5),1.0)
		var ankle = Vector3(sign_value*.14,.13,0)
		if walking:
			if cycle<.5:
				ankle.z = -stride*.5+cycle*stride*2
			else:
				var swing = (cycle-.5)*2
				ankle.z = lerpf(stride*.5,-stride*.5,smoothstep(0,1,swing))
				ankle.y += sin(swing*PI)*.14
		else:
			ankle.z = .16 if sign_value==side else -.16
		ankle = Vector3(sign_value*.14,.13,.16 if sign_value==side else -.16).lerp(ankle,gait)
		var foot_world = actor.rider.transform*ankle
		ankle.y += ground(actor,foot_world)-actor.rider.position.y
		var leg = hip+Vector3(sign_value*.14,0,0)
		var knee = bend(leg,ankle,.43,.42,Vector3(0,0,-1))
		var arm = shoulder+Vector3(sign_value*.23,-.025,0)
		var swing_arm = sin(phase+(0 if sign_value<0 else PI))*.16 if walking else 0.0
		var hand = arm+Vector3(sign_value*.025,-.49,-.10+swing_arm)
		# Push off with one hand, then reach for the real handlebar before lifting.
		var support = Vector3(sign_value*.26,.22,-.30)
		hand = hand.lerp(support,crouch*(1.0 if sign_value==side else .35))
		var contact = actor.riding_grip(side) if sign_value==side else Vector3(side*.15,.86,.27)
		var grip = actor.rider.transform.affine_inverse()*(actor.bike.transform*contact)
		hand = hand.lerp(grip,reach)
		hand = arm+(hand-arm).limit_length(.585)
		var elbow = bend(arm,hand,.312,.281,Vector3(sign_value*.7,0,.4))
		# The far leg crosses over the saddle; planted leg supports the mount.
		var riding_ankle = Vector3(sign_value*.33,.40,.18)
		var riding_knee = bend(leg,riding_ankle,.43,.42,Vector3(sign_value*.5,-.1,-1))
		if mount>0:
			ankle = ankle.lerp(riding_ankle,mount)
			if sign_value!=side:
				ankle.y += sin(mount*PI)*.85
				ankle.z += sin(mount*PI)*.40
			ankle = leg+(ankle-leg).limit_length(.842)
			knee = bend(leg,ankle,.43,.42,Vector3(sign_value*.7,0,-1)).lerp(riding_knee,mount)
			hand = hand.lerp(actor.riding_grip(sign_value),mount)
			elbow = bend(arm,hand,.312,.281,Vector3(sign_value*.7,0,.4)).lerp(bend(arm,actor.riding_grip(sign_value),.312,.281,Vector3(sign_value*.8,-.5,.5)),mount)
		actor.bone("upper_arm_"+suffix,arm,elbow)
		actor.bone("forearm_"+suffix,elbow,hand)
		actor.bone("thigh_"+suffix,leg,knee)
		actor.bone("shin_"+suffix,knee,ankle)
