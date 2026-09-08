extends SceneTree
const Race = preload("res://game/race.gd")
const AI = preload("res://game/systems/racer_ai.gd")
const Combat = preload("res://game/systems/combat.gd")
var race
var checks = 0
var failures = 0
func check(value: bool, label: String):
	checks+=1
	if value: print("[PASS] "+label)
	else:
		failures+=1
		printerr("FAIL: "+label)
func fresh():
	race.reset_race()
	race.mode="racing"
	race.elapsed=10 # These fixtures exercise combat after the launch phase.
	race.player.distance=100
	race.player.speed=40
	for r in race.racers:
		r.s=1000
		r.speed=40
func _initialize(): call_deferred("run")
func run():
	race=Race.new()
	race.test_mode=true
	root.add_child(race)
	race.set_process(false)
	race.set_physics_process(false)
	var results=[]
	for kind in range(3):
		fresh()
		var r=race.racers[0]
		r.s=100; r.lane=3.5
		race.player.weapon=1
		race.attack_target=0; race.pending_kind=kind; race.player.attack_side=1
		race.shake=0; race.flash=0; race.hit_stop=0
		check(race.resolve_attack(),"三类攻击实际命中 %d" % kind)
		results.append({"damage":100-r.hp,"push":r.lane-3.5,"stagger":r.stagger,"shake":race.shake,"stop":race.hit_stop})
		r.mesh.pose(race.elapsed+.08,0,0,0,0,-1,0)
		check(r.mesh.recoil_side==1 and r.mesh.segments.head[0].x>0,"受击朝远离攻击者方向偏移，不受自己出拳朝向影响 %d" % kind)
	check(results[0].damage==13 and results[1].damage==17 and results[2].damage==28,"保留既有三类伤害平衡")
	check(results[1].push>results[2].push*2 and results[2].push>results[0].push,"踢击推开最远，拳击推开最少")
	check(results[0].stagger<results[1].stagger and results[1].stagger<results[2].stagger,"拳击短硬直、棍击重硬直")
	check(results[0].stop<results[1].stop and results[1].stop<results[2].stop and results[0].shake<results[2].shake,"实际命中停顿与震动随攻击重量递增")
	fresh()
	var axel=race.racers[0]
	axel.s=120
	race.racers[1].s=101; race.racers[2].s=102
	check(AI.choose_target(race,0)>=0,"未结仇时 AXEL 不抢近处挑战位")
	Combat.remember_hit(axel,-1)
	check(AI.choose_target(race,0)==-1,"挨玩家打后 AXEL 优先追击玩家")
	axel.grudge_time=.01
	AI.update(race,.02)
	check(axel.grudge_time==0 and AI.choose_target(race,0)>=0,"复仇时限结束恢复普通目标选择")
	Combat.remember_hit(axel,2)
	check(AI.choose_target(race,0)==2,"被 AI 打后复仇锁定该 AI")
	race.racers[2].crash=2
	check(AI.choose_target(race,0)!=2,"不追打已经摔倒的仇家")
	fresh()
	var wounded=race.racers[0]
	wounded.s=100; wounded.lane=3.5; wounded.hp=30
	Combat.remember_hit(wounded,-1)
	var hp: float=wounded.hp
	var lane: float=wounded.lane
	AI.update(race,.1)
	check(wounded.retreat_time>0 and wounded.combat_target==-2 and wounded.windup==0,"重伤后暂时退出攻击")
	check(wounded.lane>lane and wounded.speed<40,"退避实际拉开横向距离并减速落后")
	for frame in range(180):
		race.player.distance+=40.0/60
		AI.update(race,1.0/60)
	check(wounded.retreat_time==0 and wounded.combat_target!=-2 and wounded.hp==hp,"退避结束重新参战，不凭空回血")
	Combat.remember_hit(wounded,-1)
	check(wounded.retreat_time==0,"退避冷却防止连续受击后无限逃跑")
	fresh()
	var rook=race.racers[2]
	rook.lane=3
	var car=race.traffic[0]
	car.s=110; car.lane=3.5
	check(AI.tactical_lane(race,rook,100,2)<2,"ROOK 绕到对手内侧向右侧车流踢击")
	car.lane=.5
	check(AI.tactical_lane(race,rook,100,2)>2,"车流在左侧时改从右侧进攻")
	fresh()
	var viper=race.racers[4]
	viper.weapon=0; viper.s=100; viper.lane=3.5; viper.cooldown=0
	for i in range(4): race.racers[i].finished=true
	race.player.weapon=2; race.player.attack_time=.8
	AI.update(race,1.0/60)
	check(viper.stealing and viper.windup>0,"VIPER 看到持械出手主动启动夺械前摇")
	for frame in range(36):
		race.player.distance+=40.0/60
		race.player.attack_time=maxf(0,race.player.attack_time-1.0/60)
		AI.update(race,1.0/60)
	check(viper.weapon==2 and race.player.weapon==0,"真实 AI 循环完成原子夺械")
	viper.weapon=0; viper.s=race.player.distance; viper.lane=3.5
	race.player.weapon=1; race.player.attack_time=.5; race.player.guarding=true
	check(not Combat.racer_grab(race,viper,-1) and race.player.weapon==1,"格挡阻止主动夺械")
	race.player.guarding=false; race.player.dodge_time=.3
	check(not Combat.racer_grab(race,viper,-1) and race.player.weapon==1,"闪避阻止主动夺械")
	race.player.dodge_time=0; race.player.attack_time=0
	check(not Combat.racer_grab(race,viper,-1),"无出手破绽时不能凭空夺械")
	fresh()
	viper=race.racers[4]
	viper.weapon=0; viper.s=100; viper.lane=3.5
	var victim=race.racers[0]
	victim.s=100; victim.lane=2; victim.weapon=2; victim.windup=.4
	check(Combat.racer_grab(race,viper,0) and viper.weapon==2 and victim.weapon==0 and victim.windup==0,"AI 之间也能夺械并打断挥击")
	viper.weapon=0; victim.weapon=1; victim.windup=.4; victim.crash=1
	check(not Combat.racer_grab(race,viper,0) and victim.weapon==1,"不会夺取摔倒目标的武器")
	victim.crash=0; victim.s=110
	check(not Combat.racer_grab(race,viper,0) and victim.weapon==1,"超出距离不能隔空夺械")
	fresh()
	victim=race.racers[0]
	victim.s=100; victim.lane=.5
	race.attack_target=0; race.pending_kind=0; race.player.attack_side=1
	check(not race.resolve_attack() and victim.hp==100,"对手换到另一侧后原方向挥击落空")
	victim.lane=3.5; victim.finished=true
	check(not race.resolve_attack() and victim.hp==100,"不攻击已经完赛的对手")
	fresh()
	var nova=race.racers[1]
	nova.s=100; nova.lane=3.5; nova.combat_target=-1; nova.windup=.01; nova.attack_side=-1; nova.kind=0
	AI.update(race,.02)
	check(nova.retreat_time>0 and race.player.health<100,"NOVA 命中后主动拉开距离")
	fresh()
	var jinx=race.racers[3]
	jinx.s=100; jinx.lane=3.5; jinx.combat_target=-1; jinx.windup=.01; jinx.attack_side=-1; jinx.kind=2
	AI.update(race,.02)
	check(jinx.retreat_time==0 and jinx.cooldown<3,"JINX 持械后保持较紧的进攻间隔")
	check(AI.PERSONALITIES.size()==5 and AI.intent_label(jinx)=="持械强攻","HUD 可显示五人各自战术")
	race.sound.stop_all()
	race.queue_free()
	await process_frame
	print("COMBAT_PERSONALITY_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
