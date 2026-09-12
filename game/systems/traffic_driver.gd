extends RefCounted
const Contacts=preload("res://game/systems/vehicle_contacts.gd")

static func state(index: int, lane: float, speed: float) -> Dictionary:
	return {"home":lane,"origin":lane,"target":lane,"cruise":absf(speed),"direction":signf(speed),"decision":4.0+index*.7,"signal":0.0,"changing":false,"progress":0.0,"braking":false,"changes":0,"contact_hold":0.0,"contact_time":-100.0}

static func riders(race: Node3D) -> Array:
	var result: Array=[{"s":race.player.distance,"lane":race.player.lane,"speed":race.player.speed if race.player.crash_timer<=0 else 0.0}]
	var actors: Array=[race.player_mesh]
	for racer in race.racers:
		if racer.finished:continue
		result.append({"s":racer.s,"lane":racer.lane,"speed":racer.speed if racer.crash<=0 else 0.0})
		actors.append(racer.mesh)
	# A fallen person can slide away from the motorcycle's stored road position.
	for actor in actors:
		if is_instance_valid(actor.crash_rig):
			for key in ["spine","hips","head"]:
				var point: Vector2=race.crash_location(actor.crash_rig.bodies[key].global_position)
				result.append({"s":point.x,"lane":point.y,"speed":0.0})
	return result

static func lane_clear(race: Node3D, car: Dictionary, target: float, obstacles: Array = []) -> bool:
	# Include the whole merge corridor and relative closing speed, not just the
	# destination point. A driver must yield before the player enters that space.
	var lo = minf(car.lane,target)-1.45
	var hi = maxf(car.lane,target)+1.45
	if obstacles.is_empty():obstacles=riders(race)
	for rider in obstacles:
		var gap: float=(rider.s-car.s)*car.driver.direction
		if rider.lane<=lo or rider.lane>=hi:continue
		if absf(gap)<car.half_length+Contacts.BIKE_HALF.x+.1:return false
		# Leaving the blocked lane is safe after braking; reserve the
		# destination for approaching riders throughout the lane change.
		if absf(rider.lane-target)<1.45 and gap>-maxf(35,absf(rider.speed-car.speed)*2.5) and gap<50:return false
	for other in race.traffic:
		if other==car: continue
		if absf(other.lane-target)<1.7 and absf(other.s-car.s)<maxf(30,absf(other.speed-car.speed)*2.0): return false
	return true

static func update(race: Node3D, car: Dictionary, dt: float, obstacles: Array = []) -> void:
	var d: Dictionary=car.driver
	if obstacles.is_empty():obstacles=riders(race)
	d.contact_hold=maxf(0,d.contact_hold-dt)
	d.decision=maxf(0,d.decision-dt)
	var stage=race.endurance.section_at(car.s)
	var cruise: float=d.cruise if stage.is_empty() else stage.traffic_speed+(d.cruise-22)*.5
	var wanted=cruise
	var blocked=false
	for other in race.traffic:
		if other==car: continue
		var gap: float=(other.s-car.s)*d.direction
		if gap>0 and gap<65 and absf(other.lane-car.lane)<1.55:
			if signf(other.speed)==d.direction or other.speed==0:
				var stopping=maxf(0,absf(other.speed)+(gap-car.half_length-other.half_length-9)*.55)
				wanted=minf(wanted,stopping)
				blocked=blocked or gap<45
	var clearance=INF
	for rider in obstacles:
		var gap: float=(rider.s-car.s)*d.direction
		var extent: float=car.half_length+Contacts.BIKE_HALF.x
		var corridor_lo=minf(car.lane,d.target) if d.changing else float(car.lane)
		var corridor_hi=maxf(car.lane,d.target) if d.changing else float(car.lane)
		if rider.lane<corridor_lo-2.0 or rider.lane>corridor_hi+2.0:continue
		if gap<=-extent or gap>maxf(65,(absf(car.speed)+rider.speed)*2.2+extent):continue
		var following: float=maxf(0,rider.speed*d.direction)
		var room=maxf(0,gap-extent-2.0)
		var safe_speed=sqrt(2*9*room)+following
		if rider.speed*d.direction<0:safe_speed=0
		wanted=minf(wanted,safe_speed)
		if following<.1:clearance=minf(clearance,maxf(0,gap-extent-.5))
		blocked=true
	if d.contact_hold>0:wanted=0
	if d.changing:
		# Freeze a merge if a rider enters its remaining corridor mid-maneuver.
		if lane_clear(race,car,d.target,obstacles):d.progress=minf(1,d.progress+dt/2.3)
		car.lane=lerpf(d.origin,d.target,smoothstep(0,1,d.progress))
		if d.progress>=1:
			d.changing=false; d.signal=0; d.decision=10; d.changes+=1
	elif d.signal>0:
		if not lane_clear(race,car,d.target,obstacles):
			d.signal=0; d.target=car.lane; d.decision=3
		else:
			d.signal=maxf(0,d.signal-dt)
			if d.signal==0: d.changing=true; d.progress=0; d.origin=car.lane
	elif d.decision==0 and (blocked or car.half_length<3):
		var candidate=d.direction*(4.7 if absf(car.lane)<3 else 1.6)
		d.decision=8
		if lane_clear(race,car,candidate,obstacles):
			d.origin=car.lane; d.target=candidate; d.signal=1.25
	d.braking=absf(car.speed)>wanted+1 or d.contact_hold>0 or wanted<.1
	car.speed=d.direction*move_toward(absf(car.speed),wanted,dt*(9 if d.braking else 2.5))
	if dt>0 and clearance<INF:car.speed=d.direction*minf(absf(car.speed),clearance/dt)
	if d.contact_hold>0:car.speed=0
	if car.mesh.has_meta("lamps"):
		var lamps: Dictionary=car.mesh.get_meta("lamps")
		for brake in lamps.brake: brake.visible=d.braking
		var blink=(d.signal>0 or d.changing) and fmod(race.elapsed,.7)<.35
		lamps.left.visible=blink and (d.target-d.origin)*d.direction<0
		lamps.right.visible=blink and (d.target-d.origin)*d.direction>0
