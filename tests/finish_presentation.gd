extends SceneTree
const Race=preload("res://game/race.gd")
var checks=0
var failures=0
func check(value: bool,label: String):
	checks+=1
	if value: print("[PASS] "+label)
	else:
		failures+=1
		printerr("FAIL: "+label)
func _initialize(): call_deferred("run")
func run():
	var race=Race.new(); race.test_mode=true
	root.add_child(race)
	race.set_process(false); race.set_physics_process(false)
	race.mode="racing"; race.rank=1; race.elapsed=64.25; race.player.distance=3000; race.player.speed=50
	race.finish("FINISH","第 1 名完赛")
	var reward: int=race.career.credits
	check(race.mode=="finished" and race.settled and reward==1200,"冲线立即一次性结算奖金")
	check(race.finish_presentation.champion and not race.finish_presentation.buttons_ready() and race.finish_presentation.reveal()==0,"冠军先冲线，不立即弹成绩与按钮")
	var key=InputEventKey.new(); key.pressed=true; key.keycode=KEY_ENTER
	race._unhandled_input(key)
	check(race.mode=="finished","揭晓前按 Enter 不跳过庆祝")
	key.keycode=KEY_R; key.physical_keycode=KEY_R
	race._unhandled_input(key)
	check(race.mode=="finished","揭晓前按 R 不误重开")
	race._process(.5)
	check(race.finish_presentation.distance>3000 and race.finish_presentation.speed<24,"结果揭晓前车辆视觉上减速滑行")
	check(race.player.distance==3000 and race.elapsed==64.25,"滑行不改写真实完赛距离与计时")
	check(race.sound.victory_count==0,"冲线瞬间不抢播领奖音效")
	race._process(.5)
	check(race.sound.victory_count==1 and race.player_mesh.celebration>0,"冠军揭晓时举手并播放一次庆祝音效")
	race.finish("FINISH","duplicate")
	check(race.career.credits==reward and race.finish_presentation.age==1,"重复触发不重复发奖或重播揭晓")
	for i in range(120): race._process(1.0/60)
	check(race.finish_presentation.buttons_ready() and race.sound.victory_count==1,"庆祝之后开放按钮，不重复播放音效")
	check(race.finish_presentation.distance<=3026 and race.finish_presentation.speed==0,"完赛滑行距离有限且最终停车")
	race._unhandled_input(key)
	check(race.mode=="countdown" and not race.finish_presentation.active and race.player_mesh.celebration==0,"揭晓后 R 正常重开并清理庆祝状态")
	for outcome in ["FINISH","WRECKED","BUSTED"]:
		race.reset_race(); race.mode="racing"; race.rank=3
		var before: int=race.sound.victory_count
		race.finish(outcome,"test")
		for i in range(180): race._process(1.0/60)
		check(not race.finish_presentation.champion and race.sound.victory_count==before,outcome+" 非冠军不误播夺冠或举杯")
		check(race.finish_presentation.buttons_ready(),outcome+" 最终能操作结果按钮")
	race.reset_race(); race.mode="racing"; race.tutorial=true; race.rank=1
	race.finish("FINISH","练习")
	check(not race.finish_presentation.champion and race.reward==0,"练习赛不冒充正式冠军奖励")
	race.sound.stop_all(); race.queue_free()
	await process_frame
	print("FINISH_PRESENTATION_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
