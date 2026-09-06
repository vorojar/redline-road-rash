extends RefCounted

const CRASH_DURATION: float = 6.2
var distance: float = 0.0
var lane: float = 2.0
var speed: float = 0.0
var health: float = 100.0
var durability: float = 100.0
var max_durability: float = 100.0
var stability: float = 100.0
var lean: float = 0.0
var lateral_velocity: float = 0.0
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
		return
	var cap = top_speed+12 if boost else top_speed
	var target_accel = throttle*(acceleration+(6 if boost else 0)) - brake*32 - 1.8 - ground_slope*8
	if speed<=cap:
		speed = clampf(speed+target_accel*dt,0,cap)
	else:
		speed = maxf(0,speed+minf(target_accel,0)*dt)
		speed = move_toward(speed,cap,dt*12)
	var response = handling*lerpf(1.12,.80,clampf(speed/65,0,1))
	var desired_lateral = steer*response*clampf(speed/8,0,1)
	lateral_velocity = move_toward(lateral_velocity,desired_lateral,dt*15)
	lane += (lateral_velocity+curve_force*speed*speed*.055)*dt
	if assist and absf(steer) < .1:
		lane = move_toward(lane,clampf(lane,-5.7,5.7),dt*1.5)
	var corner_load = absf(curve_force)*speed*speed
	lean = lerpf(lean,clampf(atan(curve_force*speed*speed/9.8)*.65-lateral_velocity/handling*.25,-.78,.78),minf(dt*8,1))
	if corner_load>19:
		stability -= (corner_load-19)*dt*1.6
	if absf(lane)>6.5:
		speed = move_toward(speed,25,dt*12)
		stability -= dt*16
	else:
		stability = minf(100,stability+dt*(7 if corner_load<19 else 0))
	if absf(lane)>8.1:
		lane = clampf(lane,-8.1,8.1)
		damage(5,26)
		lateral_velocity *= -.35
	distance += speed*dt
	if stability <= 0:
		crash()

func damage(amount: float, instability: float) -> bool:
	if invulnerable>0 or crash_timer>0:
		return false
	health = maxf(0,health-amount)
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

static func collision_severity(relative_speed: float, overlap: float) -> float:
	return clampf(relative_speed/55 * lerpf(.18,1.0,clampf(overlap,0,1)),0,1)
