extends SceneTree
const Route = preload("res://game/world/route.gd")
const Bike = preload("res://game/bike_state.gd")
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
	for direction in [-1,1]:
		var bike=Bike.new()
		bike.lane=0
		bike.speed=53
		bike.curve_force=.017*direction
		for i in range(15): bike.drive(1.0/60,1,0,0,false)
		check(absf(bike.lane)<.001 and absf(bike.heading_offset)<.001,"松开方向自动沿弯道保持车道")
		check(bike.lean*direction>.1,"没有转向输入也会随道路压弯")
	var straight=Bike.new()
	straight.speed=40
	for i in range(12): straight.drive(1.0/60,1,0,.25,false)
	for i in range(30): straight.drive(1.0/60,1,0,0,false)
	var lane_before=straight.lane
	for i in range(6): straight.drive(1.0/60,1,0,0,false)
	check(absf(straight.heading_offset)<.005 and absf(straight.lane-lane_before)<.03,"变道后松手自动回正并停止横移")
	for track in ["pine","coast"]:
		var route=Route.new()
		route.curve=load("res://data/tracks/"+track+".tres")
		for sign_value in [-1,1]:
			var start=0.0
			for s in range(100,2500,5):
				if route.curvature(s)*sign_value>.012:
					start=float(s)
					break
			check(start>0,track+" 找到实际双向弯道")
			for assisted in [false,true]:
				var free=Bike.new()
				free.distance=start
				free.lane=0
				free.speed=45
				free.assist=assisted
				var initial_heading=route.yaw(start)
				for frame in range(120):
					free.curve_force=route.curvature(free.distance)
					free.drive(1.0/60,1,0,0,false)
				var heading_change=absf(wrapf(route.yaw(free.distance)-initial_heading,-PI,PI))
				check(heading_change>.05 and absf(free.heading_offset)<.001 and absf(free.lane)<.001,track+" 车头自动跟随真实弯道且车道不漂移，辅助 %s" % assisted)
		route.free()
	var pushed=Bike.new()
	pushed.speed=40
	pushed.apply_lateral_impulse(3)
	pushed.drive(.1,1,0,0,false)
	check(pushed.lane>2.2 and pushed.lateral_impulse<3 and pushed.heading_offset==0,"擦碰侧推保留且衰减，不改写车头方向")
	var race=load("res://game/race.gd").new()
	race.test_mode=true
	root.add_child(race)
	race.set_process(false)
	race.set_physics_process(false)
	for control in ["keyboard","touch"]:
		race.reset_race()
		race.mode="racing"
		race.player.speed=30
		for racer in race.racers: racer.s=20000.0
		for car in race.traffic: car.s=20000.0
		race.touch.enabled=control=="touch"
		if control=="keyboard":
			Input.action_press("throttle")
			Input.action_press("left")
		else:
			var rects=race.touch.layout(race.hud.mobile_height())
			var point=race.hud.mobile_origin()+rects.steer.get_center()*race.hud.mobile_scale()
			var event=InputEventScreenTouch.new()
			event.index=17; event.position=point; event.pressed=true
			race._input(event)
			var drag=InputEventScreenDrag.new()
			drag.index=17; drag.position=point-Vector2(95,0)*race.hud.mobile_scale()
			race._input(drag)
		for frame in range(8): race._physics_process(1.0/60)
		check(race.player.heading_offset>.03 and race.player.lane<2,control+" 输入真实改变车头并向左行驶")
		check(absf(wrapf(race.player_mesh.rotation.y-race.route.yaw(race.player.distance)-race.player.heading_offset,-PI,PI))<.001,control+" 车体实际朝向与驾驶方向一致")
		Input.action_release("left")
		race.touch.clear()
		for frame in range(60): race._physics_process(1.0/60)
		for frame in range(8): race._physics_process(1.0/60)
		check(absf(race.player.heading_offset)<.001,control+" 松手后自动对齐道路朝向")
		Input.action_release("throttle")
	race.sound.stop_all()
	race.queue_free()
	await process_frame
	print("ROAD_FOLLOW_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
