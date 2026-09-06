extends SceneTree
const Driver = preload("res://tests/drive_controller.gd")
const Race = preload("res://game/race.gd")
const Bike = preload("res://game/bike_state.gd")
var checks = 0
var failures = 0
func check(value: bool, label: String) -> void:
	checks+=1
	if value: print("[PASS] "+label)
	else:
		failures+=1
		printerr("FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var race = Race.new()
	race.test_mode = true
	root.add_child(race)
	race.set_process(false)
	race.set_physics_process(false)
	var actor = race.player_mesh
	for spec in race.career.catalog.bikes:
		actor.set_model(spec)
		actor.ride_speed = 0
		var upright = actor.riding_anchors()
		actor.ride_speed = 55
		var tucked = actor.riding_anchors()
		check(tucked[1].y<upright[1].y-.1 and tucked[1].z<upright[1].z-.06,spec.id+" 高速伏低并前移")
		var good = true
		for i in range(44):
			actor.pose(i/60.0,0,0,0,.71-i/60.0,1,2)
			for side in ["L","R"]:
				good = good and absf(actor.segments["upper_arm_"+side][0].distance_to(actor.segments["upper_arm_"+side][1])-.312)<.01
				good = good and absf(actor.segments["forearm_"+side][0].distance_to(actor.segments["forearm_"+side][1])-.281)<.01
		check(good,spec.id+" 挥击全程肘臂长度稳定")
	actor.pose(0,0,0,0,.70,1,2)
	var chamber: Vector3 = actor.segments.forearm_R[1]
	actor.pose(0,0,0,0,.44,1,2)
	var contact: Vector3 = actor.segments.forearm_R[1]
	actor.pose(0,0,0,0,.02,1,2)
	var returned: Vector3 = actor.segments.forearm_R[1]
	check(contact.x>chamber.x+.2 and returned.distance_to(actor.riding_grip(1))<.04,"挥棒在判定时刻外展，随后收回车把")
	for id in ["pine","coast"]:
		race.route.curve=load("res://data/tracks/"+id+".tres")
		var left = 0
		var right = 0
		var limit = 3000 if id=="pine" else 3600
		for s in range(90,limit,10):
			var curve = race.route.curvature(s)
			if curve>.01:left+=1
			if curve<-.01:right+=1
		check(left>20 and right>20,id+" 有持续且双向的紧弯")
		check(race.route.curve.get_baked_length()>limit,id+" 终点仍在完整道路内")
	var fast = Bike.new()
	fast.speed=53
	fast.curve_force=.017
	for i in range(180):
		fast.drive(1.0/60,1,0,Driver.steer(fast,2),false)
	check(fast.crashes==0 and fast.speed<53 and fast.speed>40,"紧弯全油门轻微减速且可保持路线")
	var controlled = Bike.new()
	controlled.speed=28
	controlled.curve_force=.017
	for i in range(120):controlled.drive(1.0/60,.14,0,Driver.steer(controlled,2),false)
	check(controlled.crashes==0 and controlled.stability>95,"合理入弯速度保持抓地")
	check(controlled.lean>.2,"持续弯道显示倾车而非直立")
	var shifts = 0
	for i in range(300):
		var old: int = race.sound.gear
		race.sound.update(15+sin(i)*.6,1,0,true,.7)
		if old!=race.sound.gear: shifts+=1
	check(shifts<=1,"换挡滞回避免临界速度反复跳挡")
	race.sound.stop_all()
	race.queue_free()
	await process_frame
	await create_timer(.25).timeout
	print("EXPERIENCE_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
