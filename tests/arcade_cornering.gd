extends SceneTree
const Bike = preload("res://game/bike_state.gd")
const Route = preload("res://game/world/route.gd")
var checks = 0
var failures = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("[PASS] "+label)
	else:
		failures += 1
		printerr("FAIL: "+label)
func _initialize() -> void:
	for hz in [30,60,120]:
		for bend in [-.03,-.017,.017,.03]:
			for boosted in [false,true]:
				var bike = Bike.new()
				bike.speed = bike.top_speed+12 if boosted else bike.top_speed
				bike.curve_force = bend
				var largest_offset = 0.0
				for frame in range(hz*10):
					var steer = clampf((2-bike.lane)*1.8-bike.lateral_velocity*.22,-1,1)
					bike.drive(1.0/hz,1,0,steer,boosted)
					largest_offset = maxf(largest_offset,absf(bike.lane-2))
				check(bike.crashes==0 and bike.stability==100,"%d Hz 弯道 %.3f 冲刺 %s 不无故失稳" % [hz,bend,boosted])
				check(largest_offset<1.5 and bike.speed>40,"高速弯仍能修正路线并保持速度感")
	var shoulder = Bike.new()
	shoulder.lane = 7
	shoulder.speed = 53
	for frame in range(180): shoulder.drive(1.0/60,1,0,0,false)
	check(shoulder.crashes==0 and shoulder.stability==100 and shoulder.speed<53,"路肩减速但不凭空摔车")
	for frame in range(30): shoulder.drive(1.0/60,1,0,-1,false)
	check(shoulder.lane<6.5 and shoulder.crashes==0,"压路肩后可转回路面")
	var barrier = Bike.new()
	barrier.speed = 53
	for frame in range(600): barrier.drive(1.0/60,1,0,1,false)
	check(barrier.crashes>0,"持续撞护栏仍会摔车")
	var struck = Bike.new()
	struck.damage(8,110)
	check(struck.crashes==1,"受击失衡仍会摔车")
	for track in ["pine","coast"]:
		var route = Route.new()
		route.curve = load("res://data/tracks/"+track+".tres")
		var bike = Bike.new()
		var max_offset = 0.0
		var length = 3000 if track=="pine" else 3600
		for frame in range(12000):
			bike.curve_force = route.curvature(bike.distance)
			var steer = clampf((2-bike.lane)*1.8-bike.lateral_velocity*.22,-1,1)
			bike.drive(1.0/60,1,0,steer,false)
			max_offset = maxf(max_offset,absf(bike.lane-2))
			if bike.distance>=length: break
		check(bike.distance>=length and bike.crashes==0 and max_offset<1.5,track+" 全程不刹车可完成空赛道，不靠重置车道")
		route.free()
	print("ARCADE_CORNERING_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
