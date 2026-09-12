extends RefCounted
const Driver = preload("res://game/systems/traffic_driver.gd")
const V = preload("res://game/visuals.gd")
const SEDAN = preload("res://assets/models/sedan.glb")
const TRUCK = preload("res://assets/models/truck.glb")

static func vehicle(color: Color, truck: bool = false, police: bool = false) -> Node3D:
	var car = (TRUCK if truck else SEDAN).instantiate()
	for mesh in car.find_children("*","MeshInstance3D",true,false):
		if mesh.name == "Paint":
			var mat = mesh.mesh.surface_get_material(0).duplicate()
			mat.albedo_color = color.srgb_to_linear()
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
	var obstacles=Driver.riders(race)
	for car in race.traffic:
		if car.has("driver"): Driver.update(race,car,dt,obstacles)
		car.s += car.speed*dt
		if car.s<race.player.distance-110 and car.has("driver"):
			car.s = race.player.distance+620+race.rng.randf_range(0,300)
			car.lane=car.driver.home
			car.driver.origin=car.lane; car.driver.target=car.lane
			car.driver.signal=0; car.driver.changing=false; car.driver.progress=0
			car.driver.contact_hold=0; car.driver.contact_time=-100
	for hazard in race.world.hazards:
		if not hazard.hit and absf(hazard.s-race.player.distance)<.9 and absf(hazard.lane-race.player.lane)<.7:
			hazard.hit = true
			hazard.node.rotation.z = 1.3
			race.player.damage(3,15,true)
			race.player.speed *= .93
			race.feedback(false,hazard.node.global_position)
	update_police(race,dt)

static func update_police(race: Node3D,dt: float) -> void:
	if race.tutorial or race.mode=="finished":
		return
	if race.heat>=50 and not race.police.active:
		race.police.active = true
		race.police.s = race.player.distance-95
		race.police.warning = 5.0
		race.police.phase="pursuit";race.police.yaw=0;race.police.hold=0;race.police.arrest=0
		race.police.speed=clampf(race.player.speed+8,43,59)
		race.notify("警笛从后方接近 · 尽快脱离追击",3)
	if not race.police.active:
		return
	race.police.warning = maxf(0,race.police.warning-dt)
	var gap = race.player.distance-race.police.s
	update_pursuer(race,"",dt)
	if gap>180:
		race.police.active = false
		race.heat = 15
		race.police.support_active=false
		race.notify("已甩开警方")
		return
	elif absf(race.player.distance-race.police.s)<9 and absf(race.player.lane-race.police.lane)<2.8 and race.police.warning<=0 and (race.player.crash_timer>1.2 or race.player.speed<2.5):
		race.police.arrest += dt
		if race.police.arrest>.85:
			race.police.speed=0;race.police.support_speed=0
			race.finish("BUSTED","警方截停，比赛结束")
			return
	else:
		race.police.arrest = 0.0
	if race.heat>=70 and not race.police.support_active:
		race.police.support_active=true
		race.police.support_s=race.player.distance-140
		race.police.support_lane=-2 if race.player.lane>0 else 2
		race.police.support_warning=6.0
		race.police.support_phase="pursuit";race.police.support_hold=0
		race.police.support_speed=clampf(race.player.speed+10,61,63)
		race.notify("增援警车接近 · 留意侧后方",3)
	if race.police.support_active:
		var support_gap: float=race.player.distance-race.police.support_s
		race.police.support_warning=maxf(0,race.police.support_warning-dt)
		update_pursuer(race,"support_",dt)
		if support_gap>190: race.police.support_active=false
	# A predictable one-lane roadblock; a clear passage always remains.
	if race.heat>85 and not race.police.roadblock:
		race.police.roadblock = true
		var side=1 if race.endurance.index<0 or race.endurance.index%2==0 else -1
		for lane in ([1.6,4.7] if race.endurance.index>=0 else [4.7]):
			var barrier = vehicle(Color("d9d6c7"),false,true)
			race.add_child(barrier)
			race.traffic.append({"mesh":barrier,"s":race.player.distance+220,"lane":side*lane,"speed":0.0,"half_length":2.1})
		race.notify("前方 220 米右侧封锁 · 左侧通行" if side>0 else "前方 220 米左侧封锁 · 右侧通行",4)

static func update_pursuer(race: Node3D, prefix: String, dt: float) -> void:
	var cop: Dictionary=race.police
	var p=race.player
	var lead: float=cop[prefix+"s"]-p.distance
	var phase: String=cop[prefix+"phase"]
	var stopped: bool=p.crash_timer>0 or p.speed<2.5
	var target_lane: float=p.lane
	var speed: float=0.0 if stopped else p.speed
	var limit=59.0 if prefix.is_empty() else 63.0
	var main=prefix.is_empty()
	var target_lead=maxf(18,p.speed*1.2+6) if main else 1.5
	if phase=="block" and lead< -12:phase="pursuit"
	if main and phase!="block":cop.yaw=move_toward(cop.yaw,0,dt*1.8)
	if phase=="pursuit" and lead> -22:
		phase="flank"
		var side=-1.0 if p.lane>3 else 1.0 if p.lane< -3 else signf(p.lane)
		if side==0:side=1
		cop[prefix+"side"]=side if prefix.is_empty() else -side
	if phase=="pursuit":
		speed=clampf(maxf(p.speed+9,43-lead*.13),0,limit)
	else:
		var flank=clampf(p.lane+cop[prefix+"side"]*2.3,-5.5,5.5)
		if phase=="flank" and lead>=target_lead-2 and main:phase="intercept"
		if phase=="intercept" and lead< -4:phase="flank"
		target_lane=flank if phase=="flank" else float(p.lane)
		speed=clampf(p.speed+(target_lead-lead)*1.4,0,limit)
		if phase=="intercept" and absf(cop[prefix+"lane"]-p.lane)<.6 and cop[prefix+"warning"]<=0:phase="block"
		if phase=="block":
			# Commit to the road position: turn diagonally and brake, leaving
			# an escape route instead of sliding sideways to mirror the rider.
			target_lane=cop[prefix+"lane"];speed=0
			cop.yaw=move_toward(cop.yaw,cop.side*PI/3,dt*1.8)
		if lead<0 and lead> -8 and absf(cop[prefix+"lane"]-p.lane)<2:speed=minf(speed,p.speed)
	if stopped and absf(lead)<9 and absf(cop[prefix+"lane"]-p.lane)<2.8:
		speed=0;cop[prefix+"speed"]=0;target_lane=cop[prefix+"lane"]
	else:cop[prefix+"lane"]=move_toward(cop[prefix+"lane"],target_lane,dt*1.6)
	cop[prefix+"hold"]=maxf(0,cop[prefix+"hold"]-dt)
	if cop[prefix+"hold"]>0:speed=0;cop[prefix+"speed"]=0
	cop[prefix+"speed"]=move_toward(cop[prefix+"speed"],speed,dt*(35 if phase=="block" else 14 if speed<cop[prefix+"speed"] else 8))
	cop[prefix+"s"]+=cop[prefix+"speed"]*dt
	cop[prefix+"phase"]=phase
	var lamps: Dictionary=cop[prefix+"mesh"].get_meta("lamps")
	for brake in lamps.brake:brake.visible=speed<p.speed or stopped or cop[prefix+"hold"]>0
