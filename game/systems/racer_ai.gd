extends RefCounted
const Bike = preload("res://game/bike_state.gd")
const Combat = preload("res://game/systems/combat.gd")

# A short contest after a natural catch-up; cooldown prevents endless speed matching.
static func update_duel(r: Dictionary, dt: float, available: bool, gap: float, speed_gap: float) -> bool:
	r.duel_cooldown = maxf(0,r.duel_cooldown-dt)
	if r.duel_time>0:
		r.duel_time = maxf(0,r.duel_time-dt)
		if not available or absf(gap)>6 or absf(speed_gap)>8 or r.duel_time==0:
			r.duel_time = 0.0
			r.duel_cooldown = 5.0
	elif available and absf(gap)<3.5 and absf(speed_gap)<6 and r.duel_cooldown==0:
		r.duel_time = 5.5
	return r.duel_time>0

# Keep a moving combat pack: speed changes use the normal acceleration below.
static func pack_speed(base: float, player_speed: float, gap: float) -> float:
	if gap < -12:
		return minf(base+22,maxf(base,player_speed+clampf((-gap-12)*.35,0,16)))
	if gap > 12:
		return minf(base,maxf(6,player_speed-clampf((gap-12)*.35,0,16)))
	return base

const PERSONALITIES = ["记仇反击","打完就撤","踢向车流","持械强攻","伺机夺械"]

static func intent_label(r: Dictionary) -> String:
	if r.retreat_time>0: return "退避调整"
	if r.stealing and r.windup>0: return "正在夺械"
	if r.style==0 and r.grudge_time>0: return "追击复仇"
	return PERSONALITIES[r.style]

static func challenge_score(race: Node3D, r: Dictionary) -> float:
	if r.retreat_time>0: return INF
	var distance: float = absf(r.s-race.player.distance)
	return distance-(22 if r.style==0 and r.grudge_time>0 and r.grudge_target==-1 and distance<60 else 0)

static func tactical_lane(race: Node3D, r: Dictionary, target_s: float, target_lane: float) -> float:
	var side = -1.0 if r.lane<target_lane else 1.0
	if r.style==2:
		# Approach from the opposite side so a kick pushes toward the nearby obstacle.
		var closest = 24.0
		for car in race.traffic:
			var ahead: float = car.s-target_s
			if ahead>2 and ahead<closest and absf(car.lane-target_lane)>.7 and absf(car.lane-target_lane)<4:
				closest = ahead
				side = -signf(car.lane-target_lane)
		if closest==24 and absf(target_lane)>4: side = -signf(target_lane)
	return clampf(target_lane+side*1.55,-5.7,5.7)

static func steal_opportunity(race: Node3D, r: Dictionary) -> bool:
	if r.style!=4 or r.weapon>0: return false
	if r.combat_target==-1:
		return race.player.weapon>0 and race.player.attack_time>0
	if r.combat_target<0: return false
	var opponent = race.racers[r.combat_target]
	return opponent.weapon>0 and (opponent.windup>0 or opponent.attack_time>0 or opponent.stagger>0)

# Two nearby challengers pursue the player; the rest seek each other.
static func choose_target(race: Node3D, index: int) -> int:
	var r = race.racers[index]
	if r.retreat_time>0: return -2
	if r.style==0 and r.grudge_time>0 and r.grudge_target>=0:
		var rival = race.racers[r.grudge_target]
		if rival.crash<=0 and not rival.finished and absf(rival.s-r.s)<60: return r.grudge_target
	var nearer = 0
	for j in range(race.racers.size()):
		var other = race.racers[j]
		if j!=index and other.crash<=0 and not other.finished and (challenge_score(race,other)<challenge_score(race,r) or (challenge_score(race,other)==challenge_score(race,r) and j<index)):
			nearer+=1
	var challengers = 0 if race.endurance.pressure()==0 else 1 if race.endurance.pressure()<.8 else 2
	if nearer<challengers and race.player.crash_timer<=0:
		return -1
	var target = -2
	var best = 45.0
	for j in range(race.racers.size()):
		var other = race.racers[j]
		var distance = absf(other.s-r.s)+absf(other.lane-r.lane)
		if j!=index and other.crash<=0 and not other.finished and distance<best:
			target=j
			best=distance
	return target

static func update(race: Node3D, dt: float) -> void:
	for i in range(race.racers.size()):
		var r = race.racers[i]
		r.grudge_time = maxf(0,r.grudge_time-dt)
		r.retreat_time = maxf(0,r.retreat_time-dt)
		r.retreat_cooldown = maxf(0,r.retreat_cooldown-dt)
		r.guard = maxf(0,r.guard-dt)
		r.dodge = maxf(0,r.dodge-dt)
		r.defense_cd = maxf(0,r.defense_cd-dt)
		r.stamina = minf(100,r.stamina+dt*14)
		var threatened: bool = race.pending_attack>0 and race.attack_target==i
		for attacker in race.racers:
			if attacker.windup>0 and attacker.combat_target==i and attacker.crash<=0:
				threatened = true
		if threatened and r.defense_cd<=0 and r.stagger<=0 and r.windup<=0 and r.stamina>=25:
			if (r.style==4 and r.weapon==0 and race.pending_attack>0 and race.attack_target==i and race.pending_kind==2) or race.rng.randf()<r.skill*.65:
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
		var target_speed = pack_speed(base_speed,race.player.speed,gap)
		var curve: float = absf(race.route.curvature(r.s))
		for ahead in [15,35,60]: curve=maxf(curve,absf(race.route.curvature(r.s+ahead)))
		if curve>.003:
			target_speed = minf(target_speed,Bike.corner_speed(curve,base_speed,spec.handling)*(.97+r.skill*.03))
		if r.windup<=0 and r.attack_time<=0:
			r.combat_target = choose_target(race,i)
		var dueling = update_duel(r,dt,r.combat_target==-1 and i==race.nearest_target() and r.retreat_time<=0 and race.player.speed>18 and race.player.crash_timer<=0 and (r.stagger<=0 or r.duel_time>0) and r.burst.remaining<=0 and race.burst.remaining<=0 and absf(r.lane-race.player.lane)<3.2,gap,r.speed-race.player.speed)
		var target_valid: bool = r.combat_target==-1 and race.player.crash_timer<=0
		var target_s: float = race.player.distance
		var target_lane: float = race.player.lane
		var opponent_speed: float = race.player.speed
		if r.combat_target>=0:
			var opponent = race.racers[r.combat_target]
			target_valid = opponent.crash<=0 and not opponent.finished
			target_s = opponent.s
			target_lane = opponent.lane
			opponent_speed = opponent.speed
		var combat_gap: float = r.s-target_s
		var desired = float(r.home_lane)
		if target_valid and absf(combat_gap)<35:
			desired = tactical_lane(race,r,target_s,target_lane)
			if absf(combat_gap)<12 and (r.combat_target==-1 or absf(gap)<25):
				target_speed = minf(target_speed,maxf(6,opponent_speed+clampf(-combat_gap*1.5,-7,7)))
		if r.combat_target==-1 and (dueling or (absf(gap)<14 and aggression>.55)) and race.player.crash_timer == 0:
			desired = tactical_lane(race,r,target_s,target_lane)
		if r.retreat_time>0:
			r.windup = 0
			r.stealing = false
			r.combat_target = -2
			target_valid = false
			desired = clampf(target_lane+(-3.5 if r.lane<target_lane else 3.5),-5.7,5.7)
			target_speed = minf(target_speed,maxf(6,race.player.speed-9))
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
		if dueling and open_road:
			target_speed = minf(target_speed,maxf(18,race.player.speed+clampf(-gap*.9,-3,3)))
		elif dueling:
			r.duel_time = 0.0
			r.duel_cooldown = 5.0
		var eligible: bool = not dueling and r.retreat_time<=0 and gap < -12 and r.speed>8 and r.stagger<=0 and open_road and curve<.003
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
		var player_under_attack = false
		for attacker in race.racers:
			if attacker!=r and attacker.combat_target==-1 and attacker.windup>0 and attacker.crash<=0:
				player_under_attack = true
		var close = target_valid and absf(r.s-target_s)<2.6 and absf(r.lane-target_lane)<2.25
		if r.windup>0:
			r.windup -= dt
			if r.windup<=0:
				r.attack_time = Combat.RECOVERY
				if close and r.stagger<=0 and (target_lane-r.lane)*r.attack_side>0:
					if r.stealing: Combat.racer_grab(race,r,r.combat_target)
					elif r.combat_target==-1: Combat.enemy_strike(race,r)
					else: Combat.racer_strike(race,r,r.combat_target)
					if r.style==1: r.retreat_time = 1.1
				r.cooldown = (1.8 if r.style==1 else 2.2 if r.style==3 and r.weapon>0 else 2.5)+(1-aggression)*2
		elif close and (r.combat_target!=-1 or not player_under_attack) and r.cooldown<=0 and r.stagger<=0 and r.guard<=0 and r.dodge<=0:
			r.stealing = steal_opportunity(race,r)
			r.kind = 0 if r.stealing else 1 if r.style==2 else 2 if r.weapon>0 else 0
			r.attack_side = -1.0 if target_lane<r.lane else 1.0
			r.windup = Combat.WINDUPS[r.kind]
			if r.combat_target==-1 and r.stealing: race.notify(r.name+" 伸手夺械！格挡或闪避",1.0)
			elif r.combat_target==-1: race.notify(r.name+[" 挥拳"," 抬腿"," 举起"+Combat.WEAPONS[r.weapon].name][r.kind]+"！U 格挡 / I 闪避",1.0)
		for car in race.traffic:
			if absf(r.s-car.s)<car.half_length+.7 and absf(r.lane-car.lane)<1.15:
				race.knock_out(i,r.last_hit_age<4.0)
				break
		if absf(r.lane)>7.9:
			race.knock_out(i,r.last_hit_age<4)
		if r.s>=race.track.length:
			r.finished = true
			r.finish_time = race.elapsed
