extends RefCounted

const CRASH_DURATION: float = 6.2
const STEERING_EXPONENT: float = 1.8
const HEADING_RETURN: float = 8.0
var distance: float = 0.0
var lane: float = 2.0
var speed: float = 0.0
var health: float = 100.0
var durability: float = 100.0
var max_durability: float = 100.0
var stability: float = 100.0
var lean: float = 0.0
var lateral_velocity: float = 0.0
var heading_offset: float = 0.0
var steering_rate: float = 0.0
var lateral_impulse: float = 0.0
var bend_direction: float = 0.0
var bend_lane: float = 0.0
var crash_timer: float = 0.0
var invulnerable: float = 0.0
var cooldown: float = 0.0
var attack_time: float = 0.0
var attack_side: float = 1.0
var attack_kind: int = 0
var knockouts: int = 0
var environment_kos: int = 0
var combo: int = 0
var best_combo: int = 0
var combo_timer: float = 0.0
var hits: int = 0
var crashes: int = 0
var top_speed: float = 53.0
var acceleration: float = 12.8
var handling: float = 5.0
var ground_slope: float = 0.0
var curve_force: float = 0.0
var assist: bool = false
var weapon: int = 0
var stamina: float = 100.0
var guarding: bool = false
var guard_age: float = 0.0
var dodge_time: float = 0.0
var dodge_cooldown: float = 0.0
var counter_time: float = 0.0
var crash_speed: float = 0.0
var crash_lateral: float = 0.0

func defend(dt: float, held: bool) -> void:
	guarding = held and crash_timer <= 0 and attack_time <= 0 and dodge_time <= 0 and stamina > 0
	guard_age = guard_age+dt if guarding else 0.0
	stamina = clampf(stamina + (-11.0 if guarding else 19.0)*dt,0,100)
	dodge_time = maxf(0,dodge_time-dt)
	dodge_cooldown = maxf(0,dodge_cooldown-dt)
	counter_time = maxf(0,counter_time-dt)

func dodge() -> bool:
	if dodge_cooldown > 0 or stamina < 25 or crash_timer > 0 or attack_time > 0:
		return false
	stamina -= 25
	dodge_time = .38
	dodge_cooldown = 1.2
	guarding = false
	return true

func configure(spec: Dictionary) -> void:
	top_speed = spec.top_speed
	acceleration = spec.acceleration
	handling = spec.handling
	max_durability = spec.durability
	durability = max_durability

func drive(dt: float, throttle: float, brake: float, steer: float, boost: bool) -> void:
	cooldown = maxf(0,cooldown-dt)
	attack_time = maxf(0,attack_time-dt)
	invulnerable = maxf(0,invulnerable-dt)
	combo_timer = maxf(0,combo_timer-dt)
	if combo_timer == 0:
		combo = 0
	if crash_timer > 0:
		crash_timer = maxf(0,crash_timer-dt)
		speed = move_toward(speed,0,dt*38)
		if crash_timer == 0:
			stability = 80
			lane = clampf(lane,-5.8,5.8)
			invulnerable = 2.5
			lateral_velocity = 0
			heading_offset = 0
			steering_rate = 0
			lateral_impulse = 0
			bend_direction = 0
		return
	var motor = condition_power()
	var cap = corner_speed(curve_force,top_speed*motor+(12 if boost else 0),handling)
	var target_accel = throttle*(acceleration*motor+(6 if boost else 0)) - brake*32 - 1.8 - ground_slope*8
	if speed<=cap:
		speed = clampf(speed+target_accel*dt,0,cap)
	else:
		speed = maxf(0,speed+minf(target_accel,0)*dt)
		speed = move_toward(speed,cap,dt*12)
	# Straight-road input remains a gentle, self-centering lane change.
	var shaped_steer = signf(steer)*pow(absf(steer),STEERING_EXPONENT)
	var desired_rate = -shaped_steer*turn_rate()
	# Build steering gently, but remove it promptly when releasing or countersteering.
	if steering_rate*desired_rate<0:
		steering_rate = move_toward(steering_rate,0,dt*30)
	else:
		steering_rate = move_toward(steering_rate,desired_rate,dt*(30 if absf(desired_rate)<absf(steering_rate) else 10))
	var forward_speed = speed*maxf(0,cos(heading_offset))/maxf(.35,1+curve_force*lane)
	var advance = forward_speed*dt
	var road_turn_rate = curve_force*forward_speed
	var bend_weight = smoothstep(.00015,.0015,absf(curve_force))
	var turning_into_bend = steer*curve_force<0 and absf(steer)>.1 and bend_weight>0
	var relative_turn_rate = steering_rate-heading_offset*HEADING_RETURN*(1-bend_weight)-road_turn_rate*bend_weight
	if turning_into_bend:
		if bend_direction!=signf(curve_force):
			bend_direction=signf(curve_force)
			bend_lane=lane
		# One bounded inward adjustment per press, never an accumulating turn angle.
		var target_lane = bend_lane+steer*.6
		var target_heading = clampf((lane-target_lane)*.10,-.10,.10)
		relative_turn_rate = lerpf(relative_turn_rate,(target_heading-heading_offset)*HEADING_RETURN,bend_weight)
	else:
		bend_direction=0
	var heading_change = relative_turn_rate*dt
	var midpoint_heading = heading_offset+heading_change*.5
	lateral_velocity = -sin(midpoint_heading)*speed+lateral_impulse
	lane += lateral_velocity*dt
	heading_offset = wrapf(heading_offset+heading_change,-PI,PI)
	lateral_impulse = move_toward(lateral_impulse,0,dt*15)
	# Lean includes the road turn as well as the player's lane change.
	var world_turn_rate = curve_force*forward_speed+relative_turn_rate
	lean = lerpf(lean,clampf(atan(world_turn_rate*speed/9.8)*.65,-.78,.78),minf(dt*8,1))
	if absf(lane)>6.5:
		speed = move_toward(speed,25,dt*(8 if assist else 12))
	stability = minf(100,stability+dt*7)
	if absf(lane)>8.1:
		lane = clampf(lane,-8.1,8.1)
		damage(5,26,true)
		lateral_impulse = -lateral_velocity*.35
		heading_offset *= -.35
		steering_rate = 0
	distance += advance
	if stability <= 0:
		crash()

func apply_lateral_impulse(amount: float) -> void:
	lateral_impulse += amount
	lateral_velocity += amount

func condition_power() -> float:
	return 1.0-.14*smoothstep(.2,.8,1-durability/max_durability)

func damage(amount: float, instability: float, vehicle_impact: bool = false) -> bool:
	if invulnerable>0 or crash_timer>0:
		return false
	health = maxf(0,health-amount)
	if vehicle_impact: durability=maxf(0,durability-amount*.16)
	stability -= instability
	invulnerable = .65
	if stability<=0 or health<=0:
		crash()
	return true

func crash() -> void:
	if crash_timer>0:
		return
	crash_speed = speed
	crash_lateral = lateral_velocity
	weapon = 0
	guarding = false
	dodge_time = 0
	crash_timer = CRASH_DURATION
	durability = maxf(0,durability-18)
	crashes += 1
	invulnerable = 1

func credit_ko(environment: bool) -> void:
	knockouts += 1
	if environment:
		environment_kos += 1
	combo += 1
	best_combo = maxi(best_combo,combo)
	combo_timer = 10

func turn_rate() -> float:
	var high_speed_damping = lerpf(1.0,.85,clampf((speed-25)/40,0,1))
	return handling*.5*clampf(speed/12,0,1)*high_speed_damping

# Arcade cornering trades a little speed for grip; impacts own the fall penalty.
static func corner_speed(curvature: float, maximum: float, agility: float) -> float:
	return maximum/sqrt(1.0+absf(curvature)*60.0/agility)

static func collision_severity(relative_speed: float, overlap: float) -> float:
	return clampf(relative_speed/55 * lerpf(.18,1.0,clampf(overlap,0,1)),0,1)
