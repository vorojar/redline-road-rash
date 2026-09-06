extends RefCounted
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
	return car

static func update(race: Node3D, dt: float) -> void:
	for car in race.traffic:
		car.s += car.speed*dt
		if car.s<race.player.distance-110:
			car.s = race.player.distance+620+race.rng.randf_range(0,300)
		if absf(car.s-race.player.distance)<car.half_length+.8 and absf(car.lane-race.player.lane)<1.34 and race.player.invulnerable<=0 and race.player.crash_timer<=0:
			var overlap = 1.0-absf(car.lane-race.player.lane)/1.34
			var severity = race.player.collision_severity(absf(race.player.speed-car.speed),overlap)
			var side = signf(race.player.lane-car.lane)
			if side == 0: side = 1
			race.player.lateral_velocity += side*(1+severity*3)
			race.player.damage(6+severity*20,18+severity*110)
			race.player.speed *= 1-severity*.65
			race.player.lateral_velocity += signf(race.player.lane-car.lane)*2
			race.feedback(severity>.65,race.player_mesh.global_position)
			race.notify(("迎头碰撞！" if car.speed<0 else "追尾撞击！") if overlap>.55 else "侧面擦碰 · 稳住车身")
	for hazard in race.world.hazards:
		if not hazard.hit and absf(hazard.s-race.player.distance)<.9 and absf(hazard.lane-race.player.lane)<.7:
			hazard.hit = true
			hazard.node.rotation.z = 1.3
			race.player.damage(3,15)
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
	race.police.s += cop_speed*dt
	race.police.lane = move_toward(race.police.lane,race.player.lane,dt*1.15)
	if gap>180:
		race.police.active = false
		race.heat = 15
		race.notify("已甩开警方")
	elif absf(gap)<4 and race.police.warning<=0:
		if race.player.crash_timer>1.2:
			race.police.arrest += dt
			if race.police.arrest>.85:
				race.finish("BUSTED","警方截获，比赛结束")
		elif absf(race.player.lane-race.police.lane)<1.4 and race.player.invulnerable<=0:
			race.player.damage(4,18)
			race.player.lateral_velocity += 1.5 if race.player.lane>=0 else -1.5
	else:
		race.police.arrest = 0.0
	# A predictable one-lane roadblock; a clear passage always remains.
	if race.heat>85 and not race.police.roadblock:
		race.police.roadblock = true
		var barrier = vehicle(Color("d9d6c7"),false,true)
		race.add_child(barrier)
		race.traffic.append({"mesh":barrier,"s":race.player.distance+180,"lane":4.7,"speed":0.0,"half_length":2.1})
		race.notify("前方 180 米警车封锁 · 左侧可通行",4)
