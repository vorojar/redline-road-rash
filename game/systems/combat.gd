extends RefCounted

const WEAPONS = [
	{"name":"空手","damage":0.0},
	{"name":"木棒","damage":28.0},
	{"name":"钢管","damage":34.0}
]

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
		p.lateral_velocity += signf(p.lane-r.lane)*(2 if r.kind==1 else 1.1)
		race.feedback(false,race.player_mesh.global_position,r.kind,r.weapon)
		return "hit"
	return "immune"
