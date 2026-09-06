extends SceneTree
const Burst = preload("res://game/systems/burst.gd")
const BikeState = preload("res://game/bike_state.gd")
var failures = 0
var checks = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("[PASS] "+label)
	else:
		failures += 1
		printerr("FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var burst = Burst.new()
	burst.update(.5,true,true)
	check(not burst.update(.016,false,true) and burst.activations==0,"未蓄满松开不会冲刺")
	for i in range(300): burst.update(1.0/60,true,true)
	check(burst.activations==0 and burst.charge==1,"长按只蓄满，不能持续加速")
	check(burst.update(.016,false,true) and burst.activations==1,"蓄满后松开触发一次冲刺")
	check(not burst.update(2.2,false,true) and burst.cooldown==8,"2.2 秒后结束并冷却 8 秒")
	for i in range(600): burst.update(1.0/60,true,true)
	check(burst.activations==1 and burst.charge==0 and burst.cooldown==0,"冷却期间长按不会在冷却结束后自动触发")
	burst.update(.016,false,true)
	burst.update(1,true,true)
	check(burst.update(.016,false,true) and burst.activations==2,"恢复后重新蓄力松开可以再次冲刺")
	check(not burst.update(.016,false,false) and burst.cooldown==8,"刹车或摔车中止冲刺并进入冷却")
	var state = BikeState.new()
	for i in range(1200): state.drive(1.0/60,1,0,0,true)
	check(is_equal_approx(state.speed,65),"冲刺极速严格限制 65 m/s，不能无限净加速")
	for i in range(90): state.drive(1.0/60,1,0,0,false)
	check(is_equal_approx(state.speed,53),"冲刺结束回落到车型常规极速")
	var race = load("res://game/race.gd").new()
	race.test_mode = true
	root.add_child(race)
	race.set_process(false)
	race.set_physics_process(false)
	race.mode = "garage"
	race.hud.enter_garage()
	var names = []
	for i in range(3):
		race.hud.preview_bike(i)
		var spec: Dictionary = race.career.catalog.bikes[i]
		names.append(race.hud.garage_view.model_path)
		check(race.hud.garage_view.model_path==spec.model,"3D 展台切换 "+spec.name+" 对应资源")
	check(names[0]!=names[1] and names[1]!=names[2],"三款车使用独立几何模型")
	var view = race.hud.garage_view
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	view._gui_input(press)
	var drag = InputEventMouseMotion.new()
	drag.relative = Vector2(100,20)
	view._gui_input(drag)
	check(is_equal_approx(view.pivot.rotation.y,1.2) and not view.auto_rotate and view.elevation>.38,"展台拖动改变实际 3D 旋转与俯仰")
	press.pressed = false
	view._gui_input(press)
	var wheel = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	view._gui_input(wheel)
	check(view.distance<3.9 and not view.dragging,"滚轮缩放且松开鼠标结束拖动")
	view.reset_view()
	check(view.auto_rotate and view.pivot.rotation.y==0 and view.distance==3.9,"重置视角恢复展台相机与自动旋转")
	check(race.career.selected=="ratchet" and race.career.credits==0,"预览未购买车型不会修改选车或余额")
	race.career.credits = 2000
	race.hud.preview_bike(1)
	race.hud.purchase_bike()
	check(race.career.selected=="revenant" and race.career.credits==200 and race.player_mesh.model_path==race.hud.garage_view.model_path,"购买后实际比赛模型与展台一致")
	var first_top: float = race.career.bike(race.racers[0].bike_id).top_speed
	race.player.top_speed = 100
	check(race.career.bike(race.racers[0].bike_id).top_speed==first_top,"AI 车型性能不随玩家极速偷换")
	race.sound.stop_all()
	race.queue_free()
	await process_frame
	await create_timer(.25).timeout
	print("GARAGE_BURST_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
