extends SceneTree
const Race=preload("res://game/race.gd")
var checks=0
var failures=0
var race
func check(value: bool,label: String):
	checks+=1
	if value: print("[PASS] "+label)
	else:
		failures+=1
		printerr("FAIL: "+label)
func click(pressed: bool=true,button: int=MOUSE_BUTTON_LEFT,device: int=0):
	var event=InputEventMouseButton.new()
	event.button_index=button; event.pressed=pressed; event.position=Vector2(600,320); event.device=device
	race.hud._gui_input(event)
func ready_attack():
	race.player.cooldown=0
	race.player.attack_time=0
	race.pending_attack=0
func _initialize(): call_deferred("run")
func run():
	root.size=Vector2i(1280,800)
	race=Race.new(); race.test_mode=true
	root.add_child(race)
	race.set_process(false); race.set_physics_process(false)
	race.touch.enabled=false; race.mode="racing"
	race.hud.clicks.clear()
	for r in race.racers: r.s=1000
	click()
	check(race.pending_kind==0 and race.pending_attack>0,"左键通过真实 HUD 入口空手出拳")
	var pending: float=race.pending_attack
	click()
	check(race.pending_attack==pending and not race.primary_punch,"冷却期间连点不会重开攻击或跳过拳脚顺序")
	ready_attack(); click(false)
	check(race.pending_attack==0,"松开鼠标不重复攻击")
	click()
	check(race.pending_kind==1 and race.pending_attack>0,"下次空手左键自动踢击")
	ready_attack(); race.player.weapon=1; click()
	check(race.pending_kind==2 and race.pending_attack>0,"持木棒时左键挥击")
	ready_attack(); race.player.weapon=2; click()
	check(race.pending_kind==2 and race.pending_attack>0,"持钢管时左键挥击")
	ready_attack(); race.player.weapon=0
	var r=race.racers[0]
	r.s=0; r.lane=3.5; r.weapon=1; r.windup=.4
	click()
	check(race.player.weapon==1 and r.weapon==0 and race.pending_attack==0,"空手左键优先夺械且不会同次挥击")
	ready_attack(); race.player.weapon=0; r.weapon=2; r.windup=0; r.stagger=0
	click()
	check(race.player.weapon==0 and r.weapon==2 and race.pending_attack>0,"没有夺械破绽时仍正常拳脚进攻")
	ready_attack(); r.windup=.4; race.player.guarding=true; click()
	check(race.pending_attack==0 and race.player.weapon==0,"格挡时点击不误攻击或夺械")
	race.player.guarding=false
	click(true,MOUSE_BUTTON_RIGHT)
	check(race.pending_attack==0,"右键不触发攻击")
	click(true,MOUSE_BUTTON_LEFT,InputEvent.DEVICE_ID_EMULATION)
	check(race.pending_attack==0 and race.player.weapon==0,"忽略触摸模拟的鼠标事件")
	race.touch.enabled=true; click()
	check(race.pending_attack==0 and race.player.weapon==0,"触屏模式鼠标点击不会双触发")
	race.touch.enabled=false
	for mode in ["ready","paused","garage","settings","countdown","finished"]:
		race.mode=mode; click()
		check(race.pending_attack==0 and race.player.weapon==0,mode+" 界面点击不攻击")
	race.mode="paused"
	race.hud.clicks.append({"rect":Rect2(0,0,2000,2000),"callback":func():race.mode="racing"})
	click()
	check(race.mode=="racing" and race.pending_attack==0 and race.player.weapon==0,"点击继续比赛只执行按钮，不穿透触发攻击")
	race.hud.clicks.clear()
	ready_attack(); race.player.weapon=1
	var routed=InputEventMouseButton.new()
	routed.position=Vector2(600,320); routed.global_position=routed.position
	routed.button_index=MOUSE_BUTTON_LEFT; routed.pressed=true; routed.button_mask=MOUSE_BUTTON_MASK_LEFT
	await process_frame
	root.push_input(routed)
	await process_frame
	check(race.pending_attack>0 and race.pending_kind==2,"完整 Viewport 鼠标事件穿过 GUI 路由触发挥棍")
	var space=InputEventKey.new()
	space.physical_keycode=KEY_SPACE; space.keycode=KEY_SPACE; space.pressed=true
	ready_attack(); race.player.weapon=0; race.primary_punch=true
	for opponent in race.racers: opponent.s=1000
	var cruise_before: bool=race.cruise
	root.push_input(space)
	check(race.pending_attack>0 and race.pending_kind==0 and race.cruise==cruise_before,"完整 Viewport 空格出拳且不切换定速")
	ready_attack(); space.echo=true; root.push_input(space)
	check(race.pending_attack==0 and not race.primary_punch,"长按空格重复事件不连击或跳过拳脚")
	space.echo=false; space.pressed=false; root.push_input(space)
	check(race.pending_attack==0,"松开空格不攻击")
	space.pressed=true; root.push_input(space)
	check(race.pending_attack>0 and race.pending_kind==1,"再次空格交替踢击")
	ready_attack(); race.player.weapon=2; root.push_input(space)
	check(race.pending_attack>0 and race.pending_kind==2,"空格持械挥击")
	ready_attack(); race.player.weapon=0; race.player.stamina=100
	r.s=race.player.distance; r.lane=race.player.lane; r.weapon=1; r.windup=.4
	root.push_input(space)
	check(race.player.weapon==1 and r.weapon==0 and race.pending_attack==0,"空格与左键一样优先夺械")
	for mode in ["ready","paused","garage","settings","countdown","finished"]:
		race.mode=mode; ready_attack(); root.push_input(space)
		check(race.pending_attack==0,mode+" 界面空格不攻击")
	race.sound.stop_all(); race.queue_free()
	await process_frame
	print("MOUSE_COMBAT_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
