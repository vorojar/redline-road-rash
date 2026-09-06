extends RefCounted

const DELAYS = [.12,.20,.27]
const WINDUPS = [.55,.8,.72]
const RECOVERY = .44
const REACH = [2.05,2.55,2.25]

const WEAPONS = [
	{"name":"空手","damage":0.0},
	{"name":"木棒","damage":28.0},
	{"name":"钢管","damage":34.0}
]

# One impact profile drives physics, animation, camera and sound for each attack.
const IMPACTS = [
	{"stagger":.32,"push":.38,"shake":.14,"flash":.055,"stop":.022,"db":-13.0,"pitch":1.12,"recoil":.7},
	{"stagger":.55,"push":1.55,"shake":.27,"flash":.08,"stop":.045,"db":-10.0,"pitch":.82,"recoil":1.0},
	{"stagger":.85,"push":.72,"shake":.40,"flash":.12,"stop":.065,"db":-8.0,"pitch":.96,"recoil":1.3}
]

static func remember_hit(r: Dictionary, source: int) -> void:
	r.grudge_target = source
	r.grudge_time = 12.0 if r.style==0 else 6.0
	if r.hp>0 and r.hp<(20 if r.style==3 else 35) and r.retreat_cooldown<=0:
		r.retreat_time = 2.8
		r.retreat_cooldown = 12.0

static func racer_grab(race: Node3D, attacker: Dictionary, target: int) -> bool:
	if attacker.weapon>0 or attacker.crash>0 or attacker.stagger>0:
		return false
	if target==-1:
		var p = race.player
		if p.weapon==0 or p.crash_timer>0 or p.dodge_time>0 or p.guarding or p.attack_time<=0 or absf(p.distance-attacker.s)>2 or absf(p.lane-attacker.lane)>2.2:
			return false
		attacker.weapon = p.weapon
		p.weapon = 0
		p.attack_time = 0
		race.pending_attack = 0
		race.notify(attacker.name+" 夺走了武器！")
		return true
	if target<0: return false
	var r = race.racers[target]
	if r.weapon==0 or r.crash>0 or r.finished or r.dodge>0 or r.guard>0 or (r.windup<=0 and r.attack_time<=0 and r.stagger<=0) or absf(r.s-attacker.s)>2 or absf(r.lane-attacker.lane)>2.2:
		return false
	attacker.weapon = r.weapon
	r.weapon = 0
	r.windup = 0
	r.attack_time = 0
	r.stagger = .5
	remember_hit(r,race.racers.find(attacker))
	return true

static func grab(race: Node3D) -> bool:
	var p = race.player
	if p.cooldown > 0 or p.crash_timer > 0 or p.stamina < 20 or p.dodge_time > 0:
		return false
	p.cooldown = .65
	p.stamina -= 20
	var index: int = race.nearest_target()
	if index < 0:
		race.notify("夺械落空 · 靠近持械对手")
		return false
	var r = race.racers[index]
	if absf(r.s-p.distance)>2 or absf(r.lane-p.lane)>2.2 or r.weapon == 0 or (r.windup<=0 and r.stagger<=0):
		race.notify("夺械失败 · 等对手蓄力或硬直")
		return false
	p.weapon = r.weapon
	r.weapon = 0
	r.windup = 0
	r.stagger = .9
	r.cooldown = 1.4
	remember_hit(r,-1)
	p.attack_side = signf(r.lane-p.lane)
	p.attack_kind = 0
	p.attack_time = .44
	race.feedback(false,r.mesh.global_position+Vector3.UP)
	race.notify("夺得"+WEAPONS[p.weapon].name+("！点击攻击挥击" if race.touch.enabled else "！按 L 挥击"))
	return true

static func enemy_strike(race: Node3D, r: Dictionary) -> String:
	var p = race.player
	if p.dodge_time > .12:
		p.counter_time = 1.0
		race.notify("闪避成功 · 反击窗口")
		return "dodge"
	if p.guarding and p.stamina>=20:
		p.stamina -= 20 if r.kind != 1 else 35
		if p.guard_age<=.22:
			r.stagger = 1.1
			r.windup = 0
			p.counter_time = 1.2
			race.notify("精准格挡！按 O 夺械 / J K L 反击")
			return "parry"
		if r.kind != 1 and p.stamina>0:
			p.damage(2*race.difficulty().damage,5)
			race.notify("格挡 · 体力消耗")
			return "block"
		p.guarding = false
	var damage: float = [8,10,WEAPONS[r.weapon].damage*.48][r.kind]
	if p.damage(damage*race.difficulty().damage,34 if r.kind==1 else 25):
		p.apply_lateral_impulse(signf(p.lane-r.lane)*IMPACTS[r.kind].push*1.5)
		race.player_mesh.react_to_hit(signf(p.lane-r.lane),r.kind,race.elapsed)
		race.feedback(false,race.player_mesh.global_position,r.kind,r.weapon)
		return "hit"
	return "immune"

static func racer_strike(race: Node3D, attacker: Dictionary, target: int) -> String:
	var r = race.racers[target]
	if r.crash>0 or r.finished or absf(r.s-attacker.s)>2.6 or absf(r.lane-attacker.lane)>2.25:
		return "miss"
	if r.dodge>0:
		return "dodge"
	if r.guard>0 and r.stamina>=20 and attacker.kind!=1:
		r.stamina = maxf(0,r.stamina-20)
		r.hp -= 2
		r.last_hit_age = 999.0
		if r.hp<=0: race.knock_out(target,false)
		return "block"
	r.hp -= [8.0,10.0,WEAPONS[attacker.weapon].damage*.48][attacker.kind]
	r.stability -= 34 if attacker.kind==1 else 25
	r.lane += attacker.attack_side*IMPACTS[attacker.kind].push*.5
	r.stagger = IMPACTS[attacker.kind].stagger
	r.mesh.react_to_hit(attacker.attack_side,attacker.kind,race.elapsed)
	remember_hit(r,race.racers.find(attacker))
	r.windup = 0
	r.cooldown = 1.1
	# The most recent shove came from another racer, so its crash is not a player KO.
	r.last_hit_age = 999.0
	if absf(r.s-race.player.distance)<35:
		race.feedback(false,r.mesh.global_position+Vector3.UP,attacker.kind,attacker.weapon,.35)
	if r.hp<=0 or r.stability<=0 or absf(r.lane)>7.8:
		race.knock_out(target,false)
	return "hit"
