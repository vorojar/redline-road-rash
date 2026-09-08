extends SceneTree
const Race = preload("res://game/race.gd")
const AI = preload("res://game/systems/racer_ai.gd")
const Combat = preload("res://game/systems/combat.gd")
var checks = 0
var failures = 0
func check(value: bool, label: String):
	checks+=1
	if value: print("[PASS] "+label)
	else:
		failures+=1
		printerr("FAIL: "+label)
func _initialize(): call_deferred("run")
func run():
	check(AI.pack_speed(50,55,-80)>55,"后方对手比领先玩家更快")
	check(AI.pack_speed(50,25,80)<25,"前方对手减速等待慢速玩家")
	check(AI.pack_speed(50,0,80)>=6,"玩家停车时对手仍缓慢前进")
	check(AI.pack_speed(50,90,-200)<=72,"追赶加速有上限")
	var race = Race.new()
	race.test_mode=true
	root.add_child(race)
	race.set_process(false)
	race.set_physics_process(false)
	race.mode="racing"
	race.elapsed=10 # These fixtures exercise combat after the launch phase.
	race.player.distance=100
	race.player.speed=40
	for i in range(5):
		race.racers[i].s=101+i*3
	check(AI.choose_target(race,0)==-1 and AI.choose_target(race,1)==-1,"最近两人主动挑战玩家")
	check(AI.choose_target(race,2)>=0 and AI.choose_target(race,3)>=0,"其他对手彼此寻找交战目标")
	var a = race.racers[2]
	var b = race.racers[3]
	a.s=110; b.s=110; a.lane=-1; b.lane=.5
	a.kind=1; a.attack_side=1
	var hp: float = b.hp
	check(Combat.racer_strike(race,a,3)=="hit" and b.hp==hp-10 and b.stability==66,"AI 踢击造成真实伤害与失衡")
	check(b.lane>.5 and b.stagger>0,"AI 踢击推开目标并打断动作")
	b.lane=.5; b.dodge=.3; hp=b.hp
	check(Combat.racer_strike(race,a,3)=="dodge" and b.hp==hp,"AI 闪避阻止伤害")
	b.dodge=0; b.guard=.3; a.kind=0; hp=b.hp
	check(Combat.racer_strike(race,a,3)=="block" and b.hp==hp-2,"AI 格挡削减拳击伤害")
	b.guard=0; b.hp=1; b.last_hit_age=0
	var kos = race.player.knockouts
	check(Combat.racer_strike(race,a,3)=="hit" and b.crash>0,"AI 可击倒另一个 AI")
	check(race.player.knockouts==kos and b.last_hit_age>4,"AI 击倒不误记玩家奖励")
	hp=b.hp
	check(Combat.racer_strike(race,a,3)=="miss" and b.hp==hp,"不继续殴打已摔倒目标")
	for r in race.racers:
		r.finished=true
	a.finished=false; a.s=20; a.speed=40; a.lane=0
	var previous: float = a.s
	AI.update(race,.1)
	check(a.s>previous and a.s-previous<5,"追赶只经正常速度积分，不瞬移")
	check(a.speed>40,"真实 AI 更新加速追赶")
	a.s=180; a.speed=40
	AI.update(race,.1)
	check(a.speed<40,"真实 AI 更新制动等待")
	# Exercise targeting, telegraph, defense and damage through the actual update loop.
	a.s=200; a.speed=30; a.lane=-1; a.hp=100; a.cooldown=0; a.stagger=0; a.windup=0; a.attack_time=0
	b.finished=false; b.crash=0; b.s=200; b.speed=30; b.lane=.55; b.hp=100; b.stability=100; b.cooldown=0; b.stagger=0; b.windup=0; b.guard=0; b.dodge=0
	race.player.crash_timer=100
	var saw_windup = false
	for frame in range(480):
		race.player.distance= a.s-20
		AI.update(race,1.0/60)
		if a.windup>0 or b.windup>0: saw_windup=true
	check(saw_windup and (a.hp<100 or b.hp<100),"真实 AI 循环主动互殴并命中")
	check(a.combat_target==3 and b.combat_target==2,"AI 互殴锁定真实对手")
	check(a.attack_side==1 and b.attack_side==-1,"两名 AI 攻击动作朝向彼此")
	race.sound.stop_all()
	race.queue_free()
	await process_frame
	print("COMBAT_PACK_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
