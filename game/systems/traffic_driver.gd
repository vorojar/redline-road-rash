extends RefCounted

static func state(index: int, lane: float, speed: float) -> Dictionary:
	return {"home":lane,"origin":lane,"target":lane,"cruise":absf(speed),"direction":signf(speed),"decision":4.0+index*.7,"signal":0.0,"changing":false,"progress":0.0,"braking":false,"changes":0}

static func lane_clear(race: Node3D, car: Dictionary, target: float) -> bool:
	# Include the whole merge corridor and relative closing speed, not just the
	# destination point. A driver must yield before the player enters that space.
	var lo = minf(car.lane,target)-1.45
	var hi = maxf(car.lane,target)+1.45
	var p=race.player
	var gap: float=(p.distance-car.s)*car.driver.direction
	if p.lane>lo and p.lane<hi and gap>-maxf(35,absf(p.speed-car.speed)*2.5) and gap<50: return false
	for other in race.traffic:
		if other==car: continue
		if absf(other.lane-target)<1.7 and absf(other.s-car.s)<maxf(30,absf(other.speed-car.speed)*2.0): return false
	for racer in race.racers:
		if racer.crash<=0 and racer.lane>lo and racer.lane<hi and absf(racer.s-car.s)<25: return false
	return true

static func update(race: Node3D, car: Dictionary, dt: float) -> void:
	var d: Dictionary=car.driver
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
	var p=race.player
	var player_gap: float=(p.distance-car.s)*d.direction
	if d.direction>0 and player_gap>0 and player_gap<50 and absf(p.lane-car.lane)<1.5:
		wanted=minf(wanted,maxf(0,p.speed+(player_gap-12)*.6))
	if d.changing:
		d.progress=minf(1,d.progress+dt/2.3)
		car.lane=lerpf(d.origin,d.target,smoothstep(0,1,d.progress))
		if d.progress>=1:
			d.changing=false; d.signal=0; d.decision=10; d.changes+=1
	elif d.signal>0:
		if not lane_clear(race,car,d.target):
			d.signal=0; d.target=car.lane; d.decision=3
		else:
			d.signal=maxf(0,d.signal-dt)
			if d.signal==0: d.changing=true; d.progress=0; d.origin=car.lane
	elif d.decision==0 and (blocked or car.half_length<3):
		var candidate=d.direction*(4.7 if absf(car.lane)<3 else 1.6)
		d.decision=8
		if lane_clear(race,car,candidate):
			d.origin=car.lane; d.target=candidate; d.signal=1.25
	d.braking=absf(car.speed)>wanted+1
	car.speed=d.direction*move_toward(absf(car.speed),wanted,dt*(9 if d.braking else 2.5))
	if car.mesh.has_meta("lamps"):
		var lamps: Dictionary=car.mesh.get_meta("lamps")
		for brake in lamps.brake: brake.visible=d.braking
		var blink=(d.signal>0 or d.changing) and fmod(race.elapsed,.7)<.35
		lamps.left.visible=blink and (d.target-d.origin)*d.direction<0
		lamps.right.visible=blink and (d.target-d.origin)*d.direction>0
