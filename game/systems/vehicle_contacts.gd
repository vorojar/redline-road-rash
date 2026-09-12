extends RefCounted

# Road-space solids cover the visible bike/rider, independent of damage immunity.
const BIKE_HALF = Vector2(1.35,.65)
const CAR_HALF_WIDTH = 1.08
const SKIN = .015

static func vehicles(race) -> Array:
	var cars=race.traffic.duplicate()
	if race.police.active:
		cars.append({"s":race.police.s,"lane":race.police.lane,"speed":race.police.speed,"half_length":2.1})
		if race.police.support_active:
			cars.append({"s":race.police.support_s,"lane":race.police.support_lane,"speed":race.police.support_speed,"half_length":2.1})
	return cars

static func snapshot(race) -> Array[Vector2]:
	var result: Array[Vector2] = [Vector2(race.player.distance,race.player.lane)]
	for r in race.racers: result.append(Vector2(r.s,r.lane))
	for car in vehicles(race): result.append(Vector2(car.s,car.lane))
	return result

static func correction(previous: Vector2, current: Vector2, size: Vector2) -> Vector2:
	# Swept boxes catch high closing speeds, even if both centers cross in one tick.
	if absf(previous.x)>=size.x or absf(previous.y)>=size.y:
		var delta=current-previous
		var entry=0.0
		var leave=1.0
		var normal=Vector2.ZERO
		for axis in [0,1]:
			if absf(delta[axis])<.00001:
				if absf(previous[axis])>=size[axis]: return Vector2.ZERO
				continue
			var near=(-size[axis]-previous[axis])/delta[axis]
			var far=(size[axis]-previous[axis])/delta[axis]
			if near>far:
				var swap=near; near=far; far=swap
			if near>=entry:
				entry=near
				normal=Vector2.ZERO
				normal[axis]=-signf(delta[axis])
			leave=minf(leave,far)
			if entry>leave: return Vector2.ZERO
		if normal!=Vector2.ZERO and entry>=0 and entry<=1:
			var at_contact=previous+delta*entry
			var axis=0 if normal.x!=0 else 1
			var push=Vector2.ZERO
			push[axis]=at_contact[axis]+normal[axis]*SKIN-current[axis]
			return push
	if absf(current.x)>=size.x or absf(current.y)>=size.y: return Vector2.ZERO
	var axis=0 if (size.x-absf(current.x))/size.x<(size.y-absf(current.y))/size.y else 1
	var push=Vector2.ZERO
	push[axis]=(1 if current[axis]>=0 else -1)*(size[axis]+SKIN)-current[axis]
	return push

static func resolve(race, previous: Array[Vector2]) -> void:
	var cars=vehicles(race)
	var bikes: Array[Dictionary] = []
	if race.player.crash_timer<=0:
		bikes.append({"index":0,"s":race.player.distance,"lane":race.player.lane,"speed":race.player.speed,"mesh":race.player_mesh})
	for i in range(race.racers.size()):
		var r=race.racers[i]
		if r.crash<=0 and not r.finished:
			bikes.append({"index":i+1,"s":r.s,"lane":r.lane,"speed":r.speed,"mesh":r.mesh})
	# Iteration resolves a pack, including a bike trapped between another bike and a car.
	for iteration in range(12):
		var moved=false
		for i in range(bikes.size()):
			var a=bikes[i]
			for j in range(i+1,bikes.size()):
				var b=bikes[j]
				var current=Vector2(a.s-b.s,a.lane-b.lane)
				var old=previous[a.index]-previous[b.index] if iteration==0 else current
				var push=correction(old,current,BIKE_HALF*2)
				if push==Vector2.ZERO: continue
				moved=true
				a.s+=push.x*.5; b.s-=push.x*.5
				a.lane+=push.y*.5; b.lane-=push.y*.5
				var closing=absf(a.speed-b.speed)
				if push.x!=0:
					var shared=(a.speed+b.speed)*.5
					a.speed=shared; b.speed=shared
				impact(race,a,closing,signf(push.y),false)
				impact(race,b,closing,-signf(push.y),false)
			for j in range(cars.size()):
				var car=cars[j]
				var current=Vector2(a.s-car.s,a.lane-car.lane)
				var old=previous[a.index]-previous[1+race.racers.size()+j] if iteration==0 and 1+race.racers.size()+j<previous.size() else current
				# Traffic recycling is a spawn, not a sweep through the whole road.
				if absf(current.x-old.x)>100: old=current
				var push=correction(old,current,Vector2(car.half_length+BIKE_HALF.x,CAR_HALF_WIDTH+BIKE_HALF.y))
				if push==Vector2.ZERO: continue
				moved=true
				a.s+=push.x; a.lane+=push.y
				var closing=absf(a.speed-car.speed)
				impact(race,a,closing,signf(push.y),true)
				if car.has("driver"):
					# One stop per contact episode; a bike touching the rear must
					# not keep resetting the timer and pin both vehicles forever.
					if race.elapsed-car.driver.contact_time>.3:car.driver.contact_hold=2.0
					car.driver.contact_time=race.elapsed
					if car.driver.contact_hold>0 or (a.s-car.s)*car.driver.direction>=0:
						car.speed=0
						car.driver.braking=true
				if push.x<0: a.speed=minf(a.speed,maxf(0,car.speed)*.85)
				elif push.x>0 and car.speed<0: a.speed=0
				elif push.y!=0: a.speed*=.96
		if not moved: break
	for b in bikes:
		if b.index==0:
			race.player.distance=b.s; race.player.lane=b.lane; race.player.speed=b.speed
		else:
			var r=race.racers[b.index-1]
			r.s=b.s; r.lane=b.lane; r.speed=b.speed

static func impact(race, bike: Dictionary, closing: float, side: float, car: bool) -> void:
	if closing<2 and side==0: return
	var severity=clampf(closing/(42.0 if car else 65.0),.08,1)
	if side!=0: severity*=.35
	if race.elapsed-bike.mesh.contact_started<.3: return
	bike.mesh.contact_hit(race.elapsed,.45+severity,side)
	if bike.index==0:
		var p=race.player
		if car: p.damage(5+severity*24,12+severity*115,true)
		elif closing>=10: p.damage(severity*9,severity*35,true)
		p.apply_lateral_impulse(side*(.8+severity*2))
		race.feedback(severity>.65,race.route.point(bike.s,bike.lane)+Vector3.UP*.5,1,0,.65+severity)
	else:
		var r=race.racers[bike.index-1]
		r.stagger=maxf(r.stagger,.18+severity*.3)
		r.stability-=severity*(110 if car else 25)
		if r.stability<=0: race.knock_out(bike.index-1,r.last_hit_age<4)
