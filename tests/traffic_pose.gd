extends SceneTree
const Race = preload("res://game/race.gd")
var checks = 0
var failures = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("[PASS] "+label)
	else:
		failures += 1
		printerr("FAIL: "+label)
func _initialize(): call_deferred("run")
func run():
	var race = Race.new()
	race.test_mode = true
	root.add_child(race)
	race.set_process(false)
	race.set_physics_process(false)
	var uphill = 0.0
	var downhill = 0.0
	for s in range(40,2900,10):
		if race.route.slope(s)>race.route.slope(uphill): uphill=s
		if race.route.slope(s)<race.route.slope(downhill): downhill=s
	check(race.route.slope(uphill)>.02 and race.route.slope(downhill)<-.02,"复现赛道含真实上坡和下坡")
	for index in [0,5]:
		var car = race.traffic[index]
		for s in [uphill,downhill]:
			for direction in [-1.0,1.0]:
				for speed in [0.0,20.0]:
					car.s=s; car.driver.direction=direction; car.speed=direction*speed
					race.update_visuals(0)
					var forward: Vector3 = -car.mesh.basis.z
					var expected: Vector3 = race.route.tangent(s)*direction
					check(forward.dot(expected)>.9999,"车型 %d 坡度 %.3f 方向 %.0f 速度 %.0f 时车头沿道路切线" % [index,race.route.slope(s),direction,speed])
	race.sound.stop_all()
	race.queue_free()
	await process_frame
	print("TRAFFIC_POSE_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
