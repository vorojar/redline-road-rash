extends SceneTree
const Bike = preload("res://game/bike_state.gd")
var failures = 0
var checks = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("[PASS] "+label)
	else:
		failures += 1
		printerr("FAIL: "+label)
func _initialize() -> void:
	for hz in [30,60,120]:
		for initial_speed in [0.0,25.0,53.0]:
			var bike = Bike.new()
			bike.lane = -4.7
			bike.speed = initial_speed
			bike.curve_force = -.017
			bike.apply_lateral_impulse(-3)
			for frame in range(hz*5): bike.drive(1.0/hz,1,0,1,false)
			check(bike.lane>1 and bike.lane<2.3 and bike.crashes==0,"%d Hz 撞入对向车道后 %.0f m/s 起步，持续右转回到本方车道（%.2f m）" % [hz,initial_speed,bike.lane])
			for frame in range(hz*5): bike.drive(1.0/hz,1,0,1,false)
			check(bike.lane<2.3 and absf(bike.heading_offset)<.03,"持续压弯返回后不横穿至另一侧护栏")
		for side in [-1,1]:
			var shoulder = Bike.new()
			shoulder.lane = side*7.5
			shoulder.speed = 40
			shoulder.curve_force = side*.017
			for frame in range(hz*3): shoulder.drive(1.0/hz,1,0,-side,false)
			check(absf(shoulder.lane)<5 and shoulder.crashes==0,"%d Hz 从 %d 侧路肩持续转回路面（%.2f m）" % [hz,side,shoulder.lane])
	print("LANE_RECOVERY_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
