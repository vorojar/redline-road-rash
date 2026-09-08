extends SceneTree
const Race = preload("res://game/race.gd")
var checks = 0
var failures = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if value: print("[PASS] " + label)
	else:
		failures += 1
		printerr("FAIL: " + label)
func _initialize(): call_deferred("run")
func run():
	var race = Race.new()
	race.test_mode = true
	root.add_child(race)
	race.set_process(false)
	race.set_physics_process(false)
	for throttle in [0.0,1.0]:
		race.reset_race()
		race.mode = "racing"
		for frame in range(180):
			race.simulate(1.0/60,throttle,0,0,false)
			if frame==59:
				for r in race.racers:
					check(absf(r.lane-r.home_lane)<.1,"%s 起步首秒保持车道，不提前挤向交战目标" % r.name)
		for r in race.racers:
			print("LAUNCH_SAMPLE ",throttle," ",r.name," speed=",r.speed," distance=",r.s," lane=",r.lane)
			check(r.speed>20 and r.s>30 and r.crash==0,"%s 起步三秒正常加速且不摔车，玩家油门 %.0f" % [r.name,throttle])
	race.sound.stop_all()
	race.queue_free()
	await process_frame
	print("RACE_LAUNCH_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
