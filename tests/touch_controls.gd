extends SceneTree

var failures: int = 0
func check(ok: bool, label: String) -> void:
	if ok: print("[PASS] "+label)
	else:
		failures += 1
		printerr("FAIL: "+label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	load("res://game/systems/controls.gd").setup({})
	var touch = load("res://game/touch_controls.gd").new()
	var rects = touch.layout(540)
	touch.enabled = true
	check(not touch.contains(rects.attack,rects.attack.position+Vector2(1,1)),"圆形按钮外的方框角落不误触")
	check(touch.contains(rects.attack,rects.attack.get_center()),"圆形按钮中心可点击")
	check(touch.driving(false).throttle==1.0,"触屏默认自动油门")
	touch.press(41,rects.steer.get_center(),rects,false)
	touch.drag(41,rects.steer.get_center()+Vector2(47.5,0))
	touch.press(99,rects.brake.get_center(),rects,false)
	check(is_equal_approx(touch.steer,.5) and touch.driving(false).brake==1.0 and touch.driving(false).throttle==0.0,"多指半幅转向和刹车同时生效")
	touch.release(99)
	check(touch.driving(false).throttle==1.0 and is_equal_approx(touch.steer,.5),"刹车松开恢复油门且不丢失另一个手指")
	touch.press(73,rects.steer.get_center(),rects,false)
	check(not touch.fingers.has(73),"第二个转向手指不抢占第一个")
	touch.drag(41,Vector2(-2000,0))
	check(touch.steer==-1.0,"转向拖出区域仍跟随且限制在有效范围")
	touch.release(41,true)
	check(touch.steer==0.0 and touch.fingers.is_empty(),"触摸取消释放转向")
	touch.press(17,rects.boost.get_center(),rects,false)
	touch.release(17,true)
	check(touch.cancel_boost and not touch.held("boost"),"取消蓄力触摸不会视为主动松手")
	check(touch.press(1,rects.grab.get_center(),rects,false)=="","无机会时夺械区域不响应")
	check(touch.press(1,rects.grab.get_center(),rects,true)=="grab","可夺械时按钮响应")
	touch.clear()
	var mirrored = touch.layout(540,true)
	check(mirrored.steer.position.x>600 and mirrored.attack.position.x<100,"右手转向布局镜像全部驾驶按钮")
	for height in [432.0,540.0,720.0]:
		for left in [false,true]:
			var layout: Dictionary = touch.layout(height,left)
			for key in layout:
				var rect: Rect2 = layout[key]
				check(rect.position.x>=0 and rect.end.x<=960 and rect.position.y>=0 and rect.end.y<=height,"触控区域在屏幕内 %s / %s / %s" % [height,left,key])
	var race = load("res://game/race.gd").new()
	race.test_mode = true
	root.add_child(race)
	race.set_process(false)
	race.set_physics_process(false)
	race.touch.enabled = true
	race.mode = "racing"
	for racer in race.racers: racer.s = 20000.0
	for car in race.traffic: car.s = 20000.0
	for i in range(120): race._physics_process(1.0/60)
	check(race.player.speed>10 and race.player.distance>10,"实际赛车无需键盘即可自动前进")
	var speed: float = race.player.speed
	race.touch.press(1,rects.brake.get_center(),rects,false)
	for i in range(30): race._physics_process(1.0/60)
	check(race.player.speed<speed and race.throttle_value==0,"触屏刹车真实减速并松开油门")
	race.touch.release(1)
	race._physics_process(1.0/60)
	check(race.throttle_value==1,"刹车释放恢复真实油门")
	race.touch.press(2,rects.boost.get_center(),rects,false)
	for i in range(66): race._physics_process(1.0/60)
	check(race.burst.charging and race.burst.activations==0,"按住触屏蓄力不提前冲刺")
	race.touch.release(2)
	race._physics_process(1.0/60)
	check(race.burst.activations==1 and race.burst.remaining>0,"蓄满松手触发一次真实冲刺")
	race.burst = race.Burst.new()
	race.touch.press(3,rects.boost.get_center(),rects,false)
	for i in range(66): race._physics_process(1.0/60)
	race.touch.release(3,true)
	race._physics_process(1.0/60)
	check(race.burst.activations==0 and not race.burst.charging,"取消蓄满触摸不会误冲刺")
	race.touch.press(4,rects.guard.get_center(),rects,false)
	race._physics_process(1.0/60)
	check(race.player.guarding,"触屏格挡驱动战斗防御")
	race.touch.press(5,rects.boost.get_center(),rects,false)
	race.suspend_input()
	check(race.mode=="paused" and race.touch.fingers.is_empty() and not race.burst.charging,"切后台暂停并清除全部触摸与蓄力")
	race.menu_action("resume")
	race._physics_process(1.0/60)
	check(not race.player.guarding and race.burst.activations==0,"恢复后不残留格挡或误触发冲刺")
	race.mode = "countdown"
	race.countdown = 1.5
	race.suspend_input()
	race.menu_action("resume")
	check(race.mode=="countdown" and race.countdown==1.5,"倒计时暂停恢复不跳过发车")
	race.mode = "racing"
	race.touch.enabled = true
	race.player.cooldown = 0
	race.player.guarding = false
	race.player.weapon = 0
	var event = InputEventScreenTouch.new()
	event.index = 25
	event.pressed = true
	var screen_rects: Dictionary = race.touch.layout(race.hud.mobile_height())
	event.position = race.hud.mobile_origin()+screen_rects.attack.get_center()*race.hud.mobile_scale()
	race._input(event)
	check(race.pending_attack>0 and race.pending_kind==0,"真实触摸事件触发空手攻击")
	event.pressed = false
	race._input(event)
	race.pending_attack = 0
	race.player.cooldown = 0
	race.player.weapon = 1
	event.pressed = true
	race._input(event)
	check(race.pending_attack>0 and race.pending_kind==2,"同一触摸按钮在持械后切换武器攻击")
	event.pressed = false
	race._input(event)
	race.player.weapon = 0
	race.player.cooldown = 0
	race.target_index = 0
	race.racers[0].weapon = 1
	race.racers[0].windup = .5
	race.racers[0].s = race.player.distance+1
	race.racers[0].lane = race.player.lane+1
	check(race.can_touch_grab(),"近身对手蓄力时提供夺械按钮")
	race.racers[0].s += 6
	check(not race.can_touch_grab(),"超过夺械距离时隐藏按钮")
	race.career.settings.control_mode = 2
	race.apply_control_mode()
	check(not race.touch.enabled and race.touch.driving(false).throttle==0,"手动键盘模式没有自动油门")
	Input.action_press("throttle")
	Input.action_press("right",.6)
	check(race.touch.driving(false).throttle==1 and is_equal_approx(race.touch.driving(false).steer,.6),"键盘与手柄强度回归")
	Input.action_release("throttle")
	Input.action_release("right")
	race.sound.stop_all()
	race.queue_free()
	await process_frame
	await create_timer(.2).timeout
	quit(1 if failures else 0)
