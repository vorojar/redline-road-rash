extends RefCounted
const Driver = preload("res://game/systems/traffic_driver.gd")
const V = preload("res://game/visuals.gd")
const SEDAN = preload("res://assets/models/sedan.glb")

static func vehicle(color: Color, truck: bool = false, police: bool = false) -> Node3D:
	var car = SEDAN.instantiate()
	for mesh in car.find_children("*","MeshInstance3D",true,false):
		if mesh.name == "Paint":
			var mat = mesh.mesh.surface_get_material(0).duplicate()
			mat.albedo_color = color
			mesh.material_override = mat
	if police:
		V.box(car,Vector3(.5,.16,.28),Vector3(-.28,1.7,0),Color("c52223"))
		V.box(car,Vector3(.5,.16,.28),Vector3(.28,1.7,0),Color("2255b2"))
	var lamps={"brake":[]}
	for x in [-.62,.62]:
		var lamp=V.box(car,Vector3(.32,.16,.035),Vector3(x,.76,3.94 if truck else 2.09),Color("ff3322"))
		lamp.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		lamp.visible=false
		lamps.brake.append(lamp)
	for side in ["left","right"]:
		var group=Node3D.new();car.add_child(group)
		for z in [-2.09,3.94 if truck else 2.09]:
			var lamp=V.box(group,Vector3(.16,.13,.04),Vector3(-.88 if side=="left" else .88,.8,z),Color("ffb932"))
			lamp.material_override.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		group.visible=false
		lamps[side]=group
	car.set_meta("lamps",lamps)
	# Rounded trim, mirrors and bumpers give the traffic recognizable road proportions.
	for z in [-2.03,2.03]:
		V.box(car,Vector3(1.8,.13,.1),Vector3(0,.45,z),Color("737b7b"))
	for x in [-1,1]:
		V.box(car,Vector3(.21,.13,.21),Vector3(x,1.23,-.58),color)
	if truck:
		V.box(car,Vector3(2.15,2.35,5),Vector3(0,1.85,1.4),Color("b4b09d"))
		for x in [-1.08,1.08]:
			for z in range(-8,36,4):
				V.box(car,Vector3(.025,2.2,.025),Vector3(x,1.85,z*.1),Color("8a897b"))
	var solid=StaticBody3D.new()
	solid.name="VehicleSolid"
	solid.collision_layer=8; solid.collision_mask=4
	var collider=CollisionShape3D.new()
	var shape=BoxShape3D.new()
	shape.size=Vector3(2.16,2.7 if truck else 1.6,6.1 if truck else 4.2)
	collider.shape=shape
	collider.position=Vector3(0,1.35 if truck else .8,.9 if truck else 0)
	solid.add_child(collider); car.add_child(solid)
	return car

static func update(race: Node3D, dt: float) -> void:
	for car in race.traffic:
		if car.has("driver"): Driver.update(race,car,dt)
		car.s += car.speed*dt
		if car.s<race.player.distance-110 and car.has("driver"):
			car.s = race.player.distance+620+race.rng.randf_range(0,300)
			car.lane=car.driver.home
			car.driver.origin=car.lane; car.driver.target=car.lane
			car.driver.signal=0; car.driver.changing=false; car.driver.progress=0
	for hazard in race.world.hazards:
		if not hazard.hit and absf(hazard.s-race.player.distance)<.9 and absf(hazard.lane-race.player.lane)<.7:
			hazard.hit = true
			hazard.node.rotation.z = 1.3
			race.player.damage(3,15,true)
			race.player.speed *= .93
			race.feedback(false,hazard.node.global_position)
	update_police(race,dt)

static func update_police(race: Node3D,dt: float) -> void:
	if race.tutorial:
		return
	if race.heat>=50 and not race.police.active:
		race.police.active = true
		race.police.s = race.player.distance-95
		race.police.warning = 5.0
		race.notify("警笛从后方接近 · 尽快脱离追击",3)
	if not race.police.active:
		return
	race.police.warning = maxf(0,race.police.warning-dt)
	var gap = race.player.distance-race.police.s
	var cop_speed = clampf(43+gap*.13,28,59)
	race.police.speed=cop_speed
	race.police.s += cop_speed*dt
	race.police.lane = move_toward(race.police.lane,race.player.lane,dt*1.15)
	if gap>180:
		race.police.active = false
		race.heat = 15
		race.police.support_active=false
		race.notify("已甩开警方")
	elif absf(gap)<4 and race.police.warning<=0:
		if race.player.crash_timer>1.2:
			race.police.arrest += dt
			if race.police.arrest>.85:
				race.finish("BUSTED","警方截获，比赛结束")
		elif absf(race.player.lane-race.police.lane)<1.4 and race.player.invulnerable<=0:
			race.player.damage(4,18,true)
			race.player.apply_lateral_impulse(1.5 if race.player.lane>=0 else -1.5)
	else:
		race.police.arrest = 0.0
	if race.heat>=70 and not race.police.support_active:
		race.police.support_active=true
		race.police.support_s=race.player.distance-140
		race.police.support_lane=-2 if race.player.lane>0 else 2
		race.police.support_warning=6.0
		race.notify("增援警车接近 · 留意侧后方",3)
	if race.police.support_active:
		var support_gap: float=race.player.distance-race.police.support_s
		race.police.support_warning=maxf(0,race.police.support_warning-dt)
		race.police.support_speed=clampf(54+support_gap*.09,30,61)
		race.police.support_s+=race.police.support_speed*dt
		var flank=clampf(race.player.lane+(-2.1 if race.player.lane>0 else 2.1),-5.5,5.5)
		race.police.support_lane=move_toward(race.police.support_lane,flank,dt*.85)
		if support_gap>190: race.police.support_active=false
		elif absf(support_gap)<4 and absf(race.player.lane-race.police.support_lane)<1.3 and race.police.support_warning<=0:
			race.player.damage(4,18,true)
	# A predictable one-lane roadblock; a clear passage always remains.
	if race.heat>85 and not race.police.roadblock:
		race.police.roadblock = true
		var side=1 if race.endurance.index<0 or race.endurance.index%2==0 else -1
		for lane in ([1.6,4.7] if race.endurance.index>=0 else [4.7]):
			var barrier = vehicle(Color("d9d6c7"),false,true)
			race.add_child(barrier)
			race.traffic.append({"mesh":barrier,"s":race.player.distance+220,"lane":side*lane,"speed":0.0,"half_length":2.1})
		race.notify("前方 220 米右侧封锁 · 左侧通行" if side>0 else "前方 220 米左侧封锁 · 右侧通行",4)
