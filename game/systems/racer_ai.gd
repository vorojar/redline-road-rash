extends RefCounted
const Bike = preload("res://game/bike_state.gd")
const Combat = preload("res://game/systems/combat.gd")

static func update(race: Node3D, dt: float) -> void:
	for i in range(race.racers.size()):
		var r = race.racers[i]
		r.guard = maxf(0,r.guard-dt)
		r.dodge = maxf(0,r.dodge-dt)
		r.defense_cd = maxf(0,r.defense_cd-dt)
		r.stamina = minf(100,r.stamina+dt*14)
		if race.pending_attack>0 and race.attack_target==i and r.defense_cd<=0 and r.stagger<=0 and r.windup<=0 and r.stamina>=25:
			if race.rng.randf()<r.skill*.65:
				if r.style in [1,3]: r.dodge = .42
				else: r.guard = .5
				r.stamina -= 25
				r.defense_cd = 2.0
		r.cooldown = maxf(0,r.cooldown-dt)
		r.stagger = maxf(0,r.stagger-dt)
		r.last_hit_age += dt
		r.attack_time = maxf(0,r.attack_time-dt)
		if r.finished:
			continue
		if r.crash>0:
			if is_instance_valid(r.mesh.crash_rig):
				var location = race.crash_location(r.mesh.crash_rig.bike_body.global_position)
				r.s = location.x
				r.lane = location.y
			r.crash = maxf(0,r.crash-dt)
			if r.crash == 0:
				r.hp = 75.0
				r.stability = 85.0
				r.lane = clampf(r.lane,-5.6,5.6)
			continue
		var gap = r.s-race.player.distance
		var aggression = r.aggression + minf(.4,r.revenge*.06)
		var spec: Dictionary = race.career.bike(r.bike_id)
		var base_speed: float = spec.top_speed*(.985+i*.0075)*race.difficulty().speed
		var target_speed = base_speed
		var curve: float = absf(race.route.curvature(r.s))
		for ahead in [15,35,60]: curve=maxf(curve,absf(race.route.curvature(r.s+ahead)))
		if curve>.003:
			target_speed = minf(target_speed,Bike.corner_speed(curve,base_speed,spec.handling)*(.97+r.skill*.03))
		var desired = float(r.home_lane)
		if absf(gap)<14 and aggression>.55 and race.player.crash_timer == 0:
			desired = race.player.lane+(-1.55 if r.lane<race.player.lane else 1.55)
		var safest = desired
		var open_road = true
		for car in race.traffic:
			var ahead = car.s-r.s
			if ahead>0 and ahead<maxf(35,absf(r.speed-car.speed)*1.15) and absf(car.lane-r.lane)<1.8:
				open_road = false
				var left = clampf(car.lane-2.1,-5.7,5.7)
				var right = clampf(car.lane+2.1,-5.7,5.7)
				safest = left if absf(left-r.lane)<absf(right-r.lane) else right
				if absf(safest-car.lane)<1.6:
					target_speed = minf(target_speed,maxf(12,car.speed-2))
		var eligible: bool = r.speed>8 and r.stagger<=0 and open_road and curve<.003
		var charge_held: bool = eligible and r.burst.cooldown<=0 and r.burst.remaining<=0 and r.burst.charge<r.burst.CHARGE_SECONDS-.0001
		var sprint: bool = r.burst.update(dt,charge_held,eligible)
		if sprint: target_speed += 12
		if r.stagger<=0:
			r.lane = move_toward(r.lane,safest,dt*(2.8+r.skill*.7))
		r.speed = move_toward(r.speed,target_speed,dt*(32 if target_speed<r.speed else spec.acceleration*.9+(6 if sprint else 0)))
		r.s += r.speed*dt
		r.stability = minf(100,r.stability+dt*5)
		if r.stability<=0:
			race.knock_out(i,false)
			continue
		var close = absf(gap)<2.6 and absf(r.lane-race.player.lane)<2.25 and race.player.crash_timer<=0
		if r.windup>0:
			r.windup -= dt
			if r.windup<=0:
				r.attack_time = .44
				if close:
					Combat.enemy_strike(race,r)
				r.cooldown = 2.5+(1-aggression)*2
		elif close and r.cooldown<=0 and r.stagger<=0 and r.guard<=0 and r.dodge<=0:
			r.kind = 2 if r.weapon>0 else (1 if r.style in [2,4] else 0)
			r.windup = [.55,.8,.72][r.kind]
			race.notify(r.name+[" 挥拳"," 抬腿"," 举起"+Combat.WEAPONS[r.weapon].name][r.kind]+"！U 格挡 / I 闪避",1.0)
		for car in race.traffic:
			if absf(r.s-car.s)<car.half_length+.7 and absf(r.lane-car.lane)<1.15:
				race.knock_out(i,r.last_hit_age<4.0)
				break
		if absf(r.lane)>7.9:
			race.knock_out(i,r.last_hit_age<4)
		if r.s>=race.track.length:
			r.finished = true
			r.finish_time = race.elapsed
