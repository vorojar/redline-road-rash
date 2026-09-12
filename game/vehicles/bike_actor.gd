extends CharacterBody3D

const WeaponMotion = preload("res://game/vehicles/weapon_motion.gd")
const Combat = preload("res://game/systems/combat.gd")
const RecoveryMotion = preload("res://game/vehicles/recovery_motion.gd")
const CrashRig = preload("res://game/vehicles/crash_rig.gd")
const BIKE = preload("res://assets/models/motorcycle.glb")
const RIDER = preload("res://assets/models/rider.glb")
const V = preload("res://game/visuals.gd")
var damage_visuals = preload("res://game/vehicles/damage_visuals.gd").new()
var bike: Node3D
var model_path: String = "res://assets/models/motorcycle.glb"
var ride_speed: float = 0.0
var celebration: float = 0.0
var sport_tuck: float = 0.0
var grip_height: float = 1.09
var grip_forward: float = .51
var grip_width: float = .39
var rider: Node3D
var skeleton: Skeleton3D
var bone_ids: Dictionary = {}
var grip_axes: Dictionary = {}
const LENGTHS = {"hips":.15,"spine":.46,"head":.37,"upper_arm":.312,"forearm":.281,"thigh":.43,"shin":.42}
var bat: MeshInstance3D
var front_probe: RayCast3D
var rear_probe: RayCast3D
var wheel_meshes: Array[Node3D] = []
var segments: Dictionary = {}
var crash_rig: Node3D
var crash_velocity: Vector3 = Vector3.ZERO
var recovery_motion = RecoveryMotion.new()
var recovery_blend: float = 1.0
var recovery_segments: Dictionary = {}
var held_weapon: int = 0
var guarding: bool = false
var dodging: float = 0
var contact_started: float = -100.0
var contact_strength: float = 0.0
var contact_side: float = 0.0
var recoil_side: float = 0
var recoil_strength: float = 0
var recoil_started: float = -100.0
var recoil_duration: float = 0
var windup: float = 0
var spring_height: float = 0
var spring_velocity: float = 0
var suspension_pitch: float = 0
var previous_speed: float = 0
var front_compression: float = .035
var rear_compression: float = .035
var front_spring_speed: float = 0
var rear_spring_speed: float = 0
var ground_normal: Vector3 = Vector3.UP

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 1.0
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(.43,.65,1.7)
	collision.shape = shape
	collision.position.y = .4
	add_child(collision)
	bike = BIKE.instantiate()
	add_child(bike)
	rider = RIDER.instantiate()
	add_child(rider)
	skeleton = rider.find_child("Skeleton3D",true,false)
	style_rider(Color("242622"))
	for i in range(skeleton.get_bone_count()):
		bone_ids[skeleton.get_bone_name(i).trim_suffix("_2")] = i
	for suffix in ["L","R"]:
		grip_axes[suffix] = rider.find_child("GripAxis_"+suffix,true,false).position.normalized()
	bat = V.cylinder(self,.03,.85,Vector3.ZERO,Color("745039"))
	V.cylinder(bat,.027,.18,Vector3(0,-.31,0),Color("262523"))
	bat.visible = false
	for z in [-.67,.67]:
		var probe = RayCast3D.new()
		probe.position = Vector3(0,1.5,z)
		probe.target_position = Vector3(0,-4,0)
		probe.collision_mask = 1
		add_child(probe)
		if z < 0:
			front_probe = probe
		else:
			rear_probe = probe
	pose(0,0,0,0,0,1,0)

func style_rider(jacket: Color, helmet_pattern: int = 0) -> void:
	for mesh in rider.find_children("*","MeshInstance3D",true,false):
		mesh.material_override = null
		for surface in range(mesh.mesh.get_surface_count()):
			var source: Material = mesh.mesh.surface_get_material(surface)
			var material_name: String = source.resource_name
			if material_name == "Racing helmet":
				var livery = ShaderMaterial.new()
				livery.shader = preload("res://game/vehicles/helmet_livery.gdshader")
				livery.set_shader_parameter("tint",jacket)
				livery.set_shader_parameter("color_map",source.albedo_texture)
				livery.set_shader_parameter("pattern",helmet_pattern)
				mesh.set_surface_override_material(surface,livery)
				continue
			if not source is StandardMaterial3D or source.albedo_texture == null or material_name not in ["Jacket leather","Suit limbs","Helmet"]:
				mesh.set_surface_override_material(surface,source.duplicate())
				continue
			var material = ShaderMaterial.new()
			material.shader = preload("res://game/vehicles/worn_surface.gdshader")
			var color = jacket
			material.set_shader_parameter("tint",color)
			material.set_shader_parameter("color_map",source.albedo_texture)
			material.set_shader_parameter("normal_map",source.normal_texture)
			material.set_shader_parameter("roughness_map",source.roughness_texture)
			material.set_shader_parameter("roughness_channel",source.roughness_texture_channel)
			material.set_shader_parameter("metal",source.metallic)
			material.set_shader_parameter("sponsor_layout",1 if material_name=="Jacket leather" else 2 if material_name=="Suit limbs" else 0)
			material.set_shader_parameter("sponsor_sheet",preload("res://assets/textures/sponsors/brand-sheet.png"))
			material.set_shader_parameter("ehafo_patch",preload("res://assets/textures/sponsors/ehafo.png"))
			mesh.set_surface_override_material(surface,material)

func set_model(spec: Dictionary) -> void:
	sport_tuck = 1.0 if spec.id == "phantom" else (.15 if spec.id == "revenant" else .55)
	grip_height = spec.grip_height
	grip_forward = spec.grip_forward
	grip_width = spec.grip_width
	front_probe.position.z = -.67*spec.wheelbase
	rear_probe.position.z = .67*spec.wheelbase
	if model_path != spec.model:
		bike.queue_free()
		model_path = spec.model
		bike = load(model_path).instantiate()
		add_child(bike)
	tint(Color(spec.color))
	damage_visuals.attach(self)

func riding_grip(side: float) -> Vector3:
	return Vector3(side*grip_width,grip_height,-grip_forward)

func tint(color: Color) -> void:
	for mesh in bike.find_children("*","MeshInstance3D",true,false):
		if mesh.name == "Paint":
			if mesh.material_override is ShaderMaterial:
				mesh.material_override.set_shader_parameter("tint",color)
			else:
				mesh.material_override = damage_visuals.paint_material(mesh.mesh.surface_get_material(0),color)

func ground_move(target: Vector3, yaw: float, dt: float) -> void:
	if global_position.distance_to(target) > 20:
		global_position = target + Vector3.UP*.05
	rotation.y = yaw
	var delta_pos = target - global_position
	velocity = Vector3(delta_pos.x/maxf(dt,.001), -3.0, delta_pos.z/maxf(dt,.001))
	move_and_slide()
	var speed_now = Vector2(velocity.x,velocity.z).length()
	var acceleration = clampf((speed_now-previous_speed)/maxf(dt,.001),-32,20)
	previous_speed = speed_now
	front_probe.force_raycast_update()
	rear_probe.force_raycast_update()
	if front_probe.is_colliding() and rear_probe.is_colliding():
		ground_normal = (front_probe.get_collision_normal()+rear_probe.get_collision_normal()).normalized()
		var height = (front_probe.get_collision_point().y + rear_probe.get_collision_point().y)*.5
		global_position.y = lerpf(global_position.y,height, minf(dt*20,1))
	else:
		global_position.y = lerpf(global_position.y,target.y, minf(dt*12,1))
	var front_target = .035
	var rear_target = .035
	if front_probe.is_colliding() and rear_probe.is_colliding():
		front_target += (front_probe.get_collision_point().y-global_position.y)*.3-acceleration*.0015
		rear_target += (rear_probe.get_collision_point().y-global_position.y)*.3+acceleration*.0015
	else:
		front_target = 0
		rear_target = 0
	front_target = clampf(front_target,0,.12)
	rear_target = clampf(rear_target,0,.12)
	# Independent front/rear sprung travel: force = k*x - damping*v.
	front_spring_speed += ((front_target-front_compression)*145-front_spring_speed*18)*dt
	rear_spring_speed += ((rear_target-rear_compression)*125-rear_spring_speed*17)*dt
	front_compression = clampf(front_compression+front_spring_speed*dt,0,.12)
	rear_compression = clampf(rear_compression+rear_spring_speed*dt,0,.12)
	spring_height = .035-(front_compression+rear_compression)*.5
	suspension_pitch = atan2(rear_compression-front_compression,1.34)

func contact_hit(time: float, strength: float, side: float) -> void:
	if time-contact_started<.3: return
	contact_started=time
	contact_strength=strength
	contact_side=side

func contact_pose(time: float) -> Vector3:
	var age=time-contact_started
	if age<0 or age>.65: return Vector3.ZERO
	var envelope=exp(-age*6)*sin(age*22)
	return Vector3(-.24*envelope,0,contact_side*.15*envelope)*contact_strength

func bone(name: String, a: Vector3, b: Vector3, roll: float = 0) -> void:
	if not bone_ids.has(name):
		return
	if recovery_blend<1 and recovery_segments.has(name):
		var inverse = skeleton.global_transform.affine_inverse()
		a = (inverse*recovery_segments[name][0]).lerp(a,recovery_blend)
		b = (inverse*recovery_segments[name][1]).lerp(b,recovery_blend)
	segments[name] = [a,b]
	var index = int(bone_ids[name])
	var rest = skeleton.get_bone_global_rest(index)
	var rotation_to = Quaternion(rest.basis.y.normalized(), (b-a).normalized())
	var length_key = name.trim_suffix("_L").trim_suffix("_R")
	skeleton.set_bone_pose_scale(index,Vector3(1,(b-a).length()/float(LENGTHS[length_key]),1))
	skeleton.set_bone_pose_position(index,a)
	var alignment = Basis(rotation_to)*rest.basis
	if name.begins_with("forearm_"):
		# A visual twist bone shares the forearm endpoints but adds no ragdoll body.
		# Every pose path (riding, recovery, crash) updates it through this method.
		var wrist = int(bone_ids[name.replace("forearm_","wrist_")])
		skeleton.set_bone_pose_position(wrist,a)
		skeleton.set_bone_pose_scale(wrist,skeleton.get_bone_pose_scale(index))
		skeleton.set_bone_pose_rotation(wrist,(Basis((b-a).normalized(),roll)*alignment).get_rotation_quaternion())
		var middle = int(bone_ids[name.replace("forearm_","wrist_mid_")])
		skeleton.set_bone_pose_position(middle,a)
		skeleton.set_bone_pose_scale(middle,skeleton.get_bone_pose_scale(index))
		skeleton.set_bone_pose_rotation(middle,(Basis((b-a).normalized(),roll*.60)*alignment).get_rotation_quaternion())
		roll *= .20
	skeleton.set_bone_pose_rotation(index,(Basis((b-a).normalized(),roll)*alignment).get_rotation_quaternion())

func hand_roll(suffix: String, elbow: Vector3, hand: Vector3, grip_axis: Vector3) -> float:
	var axis = (hand-elbow).normalized()
	var rest = skeleton.get_bone_global_rest(bone_ids["forearm_"+suffix])
	var width: Vector3 = Quaternion(rest.basis.y.normalized(),axis)*grip_axes[suffix]
	width = (width-axis*width.dot(axis)).normalized()
	var target = (grip_axis-axis*grip_axis.dot(axis)).normalized()
	return width.signed_angle_to(target,axis)

func set_combat(weapon: int, guard: bool, dodge: float, charge: float) -> void:
	held_weapon = weapon
	guarding = guard
	dodging = dodge
	windup = charge

func clear_crash() -> void:
	if is_instance_valid(crash_rig): crash_rig.queue_free()
	crash_rig = null
	recovery_blend = 1.0
	recovery_segments.clear()

func _exit_tree() -> void:
	clear_crash()

func pause_crash(value: bool) -> void:
	if is_instance_valid(crash_rig): crash_rig.pause(value)

func react_to_hit(direction: float, kind: int, time: float) -> void:
	recoil_side = direction
	recoil_strength = Combat.IMPACTS[kind].recoil
	recoil_duration = Combat.IMPACTS[kind].stagger
	recoil_started = time

func pose(time: float, lean: float, slope: float, crash_time: float, attack: float, side: float, kind: int, stagger: float = 0, travel: float = 0) -> void:
	collision_layer=0 if crash_time>0 else 2
	if crash_time > 4.2:
		if not is_instance_valid(crash_rig):
			crash_rig = CrashRig.new()
			get_parent().add_child(crash_rig)
			crash_rig.launch(self,segments,crash_velocity)
		crash_rig.sync(self)
		bat.visible = false
		return
	var just_recovered = crash_time<=0 and is_instance_valid(crash_rig)
	if just_recovered: clear_crash()
	for wheel_name in ["WheelFront","WheelRear"]:
		var wheel = bike.find_child(wheel_name,true,false)
		if wheel != null:
			wheel.rotation.x = -fmod(travel/.34,TAU)
			wheel.position.y = .34 + (front_compression if wheel_name=="WheelFront" else rear_compression)-.035-spring_height
	bike.rotation = Vector3(slope+suspension_pitch,0,lean)+contact_pose(time)
	rider.rotation = bike.rotation
	rider.position = Vector3(0,spring_height,0)
	bike.position = Vector3(0,spring_height,0)
	bat.visible = false
	var anchors = riding_anchors(lean)
	var hip: Vector3 = anchors[0]
	var shoulder: Vector3 = anchors[1]
	var head_start: Vector3 = anchors[2]
	if crash_time > 0 and is_instance_valid(crash_rig):
		if not crash_rig.settled:
			crash_rig.sync(self)
			recovery_motion.configure(self)
			for key in crash_rig.bodies:
				if key=="bike": continue
				var body: RigidBody3D = crash_rig.bodies[key]
				var half: Vector3 = body.global_basis.y*crash_rig.lengths[key]*.5
				recovery_segments[key] = [body.global_position-half,body.global_position+half]
			crash_rig.settle()
		var passed = 4.2-crash_time
		recovery_blend = smoothstep(0,.38,passed)
		recovery_motion.apply(self,passed)
		return
	var body_recoil=contact_pose(time)
	shoulder.z+=body_recoil.x*.85
	head_start.z+=body_recoil.x*1.15
	var duck = sin(clampf(dodging/.38,0,1)*PI) if dodging>0 else 0.0
	shoulder += Vector3(0,-.12*duck,-.07*duck)
	head_start += Vector3(0,-.15*duck,-.07*duck)
	var delay: float = Combat.DELAYS[kind]
	var moving = attack>0 or windup>0
	var age = delay*(1-clampf(windup/Combat.WINDUPS[kind],0,1)) if windup>0 else delay+Combat.RECOVERY-attack
	var prepare = smoothstep(0,delay*.55,age) if moving else 0.0
	var strike = smoothstep(delay*.55,delay,age) if moving else 0.0
	var recover = smoothstep(delay+.08,delay+Combat.RECOVERY,age) if moving else 0.0
	var effort = prepare*(1-recover)
	var twist = side*lerpf(-.22 if kind==0 else -.28,.42 if kind==0 else .38,strike)*effort if kind!=1 else side*.18*effort
	var shoulder_basis = Basis((shoulder-hip).normalized(),twist)
	shoulder += Vector3(side*.025*strike,.025*effort,-.12*effort)
	head_start += Vector3(side*.03*strike,.025*effort,-.12*effort)
	var recoil_age = time-recoil_started
	if recoil_age>=0 and recoil_age<recoil_duration and not just_recovered:
		var impact_recoil = sin(clampf(recoil_age/.07,0,1)*PI*.5)*pow(1-recoil_age/recoil_duration,2)*recoil_strength
		shoulder += Vector3(recoil_side*.18*impact_recoil,-.055*impact_recoil,.09*impact_recoil)
		head_start += Vector3(recoil_side*.24*impact_recoil,-.08*impact_recoil,.10*impact_recoil)
	elif stagger>0 and not just_recovered:
		var recoil = sin(clampf(stagger/.6,0,1)*PI)
		shoulder += Vector3(-side*.13*recoil,-.055*recoil,.09*recoil)
		head_start += Vector3(-side*.17*recoil,-.08*recoil,.10*recoil)
	bone("hips",hip,hip+riding_pelvis_axis(hip,shoulder))
	bone("spine",hip+Vector3(0,.06,-.04),shoulder,twist)
	bone("head",head_start,head_start+Vector3(0,.33,-.04))
	for sign_value in [-1,1]:
		var suffix = "L" if sign_value < 0 else "R"
		var arm_start = shoulder+shoulder_basis*Vector3(sign_value*.21,-.025,0)
		var hand = riding_grip(sign_value)
		var leg_start = hip+Vector3(sign_value*.14,0,0)
		var ankle = Vector3(sign_value*.33,.40,.18)
		var weapon_direction = Vector3(side*.15,.80,-.28).normalized()
		if celebration>0:
			hand = hand.lerp(arm_start+Vector3(sign_value*.27,.50,-.08),celebration)
		elif guarding:
			hand = head_start+Vector3(sign_value*.15,.1,-.21)
		elif held_weapon>0 and sign_value==1 and (kind==2 or not moving):
			var motion = WeaponMotion.sample(arm_start,side,age,moving and kind==2)
			hand = motion.hand
			weapon_direction = motion.axis
		elif windup>0 and sign_value==side:
			hand = hand.lerp(arm_start+Vector3(side*.13,.28,.22),smoothstep(0,.35,Combat.WINDUPS[kind]-windup))
		elif attack>0 and sign_value==side and kind!=2:
			if kind==1:
				ankle = ankle.lerp(Vector3(side*.91,.79,-.14),effort*strike)
			else:
				var chamber = arm_start+Vector3(side*.12,.19,.25)
				var contact = arm_start+(Vector3(side*.56,.07,-.20) if kind==0 else Vector3(side*.46,.16,-.10))
				var follow = arm_start+(Vector3(side*.36,.02,-.24) if kind==0 else Vector3(side*.31,-.16,-.32))
				hand = hand.lerp(chamber,prepare)
				hand = hand.lerp(contact,strike)
				hand = hand.lerp(follow,smoothstep(delay,delay+.13,age))
				hand = hand.lerp(riding_grip(sign_value),recover)
				weapon_direction = Vector3(side*.12,.85,.45).normalized().slerp(Vector3(side*.95,.10,-.16).normalized(),strike)
				weapon_direction = weapon_direction.slerp(Vector3(side*.42,-.48,-.74).normalized(),smoothstep(delay,delay+.16,age))
				weapon_direction = weapon_direction.slerp(Vector3(side*.15,.80,-.28).normalized(),recover)
		# Two-segment IK keeps the elbow bent without telescoping forearms.
		hand = arm_start+(hand-arm_start).limit_length(.585)
		var elbow = RecoveryMotion.bend(arm_start,hand,.312,.281,Vector3(sign_value*.8,-.5,.5))
		ankle = leg_start+(ankle-leg_start).limit_length(.842)
		var knee = RecoveryMotion.bend(leg_start,ankle,.43,.42,Vector3(sign_value*.5,-.1,-1))
		if held_weapon>0 and sign_value==1:
			bat.visible = true
			bat.mesh.top_radius = .043 if held_weapon==1 else .027
			bat.mesh.bottom_radius = .024 if held_weapon==1 else .027
			bat.material_override.albedo_color = Color("856044") if held_weapon==1 else Color("9babad")
			bat.material_override.metallic = 0.0 if held_weapon==1 else .85
			bat.position = rider.transform*(hand+weapon_direction*.32)
			bat.basis = rider.basis*Basis(Quaternion(Vector3.UP,weapon_direction))
		bone("upper_arm_"+suffix,arm_start,elbow)
		var grip_axis = weapon_direction if held_weapon>0 and sign_value==1 else Vector3(-sign_value,0,0)
		bone("forearm_"+suffix,elbow,hand,hand_roll(suffix,elbow,hand,grip_axis))
		bone("thigh_"+suffix,leg_start,knee)
		bone("shin_"+suffix,knee,ankle)

func riding_anchors(lean: float = 0) -> Array[Vector3]:
	var tuck = smoothstep(8,55,ride_speed)*lerpf(.70,1.0,sport_tuck)
	var hip = Vector3(-lean*.065,.94,.29+tuck*.045)
	var shoulder = Vector3(-lean*.16,lerpf(1.36,1.17,tuck),lerpf(-.04,-.15,tuck))
	var head = shoulder+Vector3(0,-.005,-.065)
	return [hip,shoulder,head]

func riding_pelvis_axis(hip: Vector3, shoulder: Vector3) -> Vector3:
	# A seated pelvis tips forward with the torso instead of staying bolt upright.
	return Vector3.UP.slerp((shoulder-hip).normalized(),.35)*LENGTHS.hips
