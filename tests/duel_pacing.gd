extends SceneTree
const Race = preload("res://game/race.gd")
const AI = preload("res://game/systems/racer_ai.gd")
var checks = 0
var failures = 0
func check(value: bool, label: String) -> void:
	checks+=1
	if value: print("[PASS] "+label)
	else:
		failures+=1
		printerr("FAIL: "+label)
func _initialize(): call_deferred("run")
func run():
	var state = {"duel_time":0.0,"duel_cooldown":0.0}
	check(not AI.update_duel(state,.1,true,10,2),"远处对手不被拉近")
	check(not AI.update_duel(state,.1,true,2,12),"高速超车不会被强制拖入格斗")
	check(AI.update_duel(state,.1,true,2,2),"自然追近开启交手窗口")
	for i in range(40): AI.update_duel(state,.1,true,1,1)
	check(state.duel_time>1,"窗口支持多次攻防")
	for i in range(20): AI.update_duel(state,.1,true,1,1)
	check(state.duel_time==0 and state.duel_cooldown>3,"窗口结束后不无限锁速")
	check(not AI.update_duel(state,.1,true,1,1),"冷却期间不会立即重开")
	state.duel_cooldown=0
	AI.update_duel(state,.1,true,1,1)
	check(not AI.update_duel(state,.1,false,1,1),"冲刺或路况不允许时退出")
	state.duel_cooldown=0
	AI.update_duel(state,.1,true,1,1)
	check(not AI.update_duel(state,.1,true,1,10),"明显速度差允许脱离交手")
	var race = Race.new()
	race.test_mode=true
	root.add_child(race)
	race.set_process(false)
	race.set_physics_process(false)
	race.mode="racing"
	race.player.distance=50
	race.player.speed=45
	for r in race.racers: r.s=1000
	var rival = race.racers[0]
	rival.s=62; rival.lane=3.5; rival.speed=47
	check(race.nearest_target()==-1 and race.nearest_target(18)==0,"可见对手体力不会扩大攻击选取距离")
	rival.crash=1
	check(race.nearest_target(18)==-1,"摔倒对手不显示为战斗目标")
	rival.crash=0; rival.finished=true
	check(race.nearest_target(18)==-1,"已完赛对手不显示为战斗目标")
	rival.finished=false; rival.s=52
	var close_frames=0
	for i in range(240):
		race.player.distance+=race.player.speed/60
		AI.update(race,1.0/60)
		if absf(rival.s-race.player.distance)<2.6: close_frames+=1
	check(close_frames>180,"实际 AI 连续至少三秒处于纵向交手距离")
	check(race.player.speed==45,"交手节奏不修改玩家速度")
	race.attack_target=0
	race.pending_kind=0
	race.player.attack_side=signf(rival.lane-race.player.lane)
	rival.guard=0; rival.dodge=0
	check(race.resolve_attack(),"并排窗口内拳击真实命中")
	AI.update(race,1.0/60)
	check(rival.duel_time>0 and rival.stagger>0,"拳击硬直不会立即结束后续交手机会")
	race.burst.remaining=1
	AI.update(race,1.0/60)
	check(rival.duel_time==0,"真实玩家冲刺解除交手限速")
	race.sound.stop_all()
	race.queue_free()
	await process_frame
	print("DUEL_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
