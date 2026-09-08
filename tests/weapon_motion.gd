extends SceneTree
const Actor = preload("res://game/vehicles/bike_actor.gd")
var failures = 0
var checks = 0
func check(value: bool, label: String):
	checks+=1
	if value: print("[PASS] "+label)
	else: failures+=1; printerr("FAIL: "+label)
func _initialize(): call_deferred("run")
func run():
	var actor = Actor.new()
	root.add_child(actor)
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	actor.set_model(catalog.bikes[0])
	for side in [-1,1]:
		actor.set_combat(1,false,0,0)
		actor.pose(0,0,0,0,.44,side,2)
		var grip = actor.bat.position-actor.bat.basis.y*.32
		check(grip.distance_to(actor.rider.transform*actor.segments.forearm_R[1])<.005,"向 %d 侧挥击始终右手握住棍柄" % side)
		check(actor.segments.forearm_L[1].distance_to(actor.riding_grip(-1))<.015,"持械挥击时左手留在车把")
		actor.set_combat(1,false,0,.001)
		actor.pose(0,0,0,0,0,side,2)
		var before = actor.bat.position+actor.bat.basis.y*.425
		actor.set_combat(1,false,0,0)
		actor.pose(0,0,0,0,.44,side,2)
		var after = actor.bat.position+actor.bat.basis.y*.425
		check(before.distance_to(after)<.035,"AI 蓄力结束至命中时棍头连续，不跳变")
		var bones_ok = true
		for frame in range(72):
			actor.pose(0,0,0,0,maxf(0,.71-frame*.01),side,2)
			for name in ["upper_arm_L","upper_arm_R","forearm_L","forearm_R"]:
				var length: float = .312 if name.begins_with("upper") else .281
				bones_ok = bones_ok and absf(actor.segments[name][0].distance_to(actor.segments[name][1])-length)<.01
		check(bones_ok,"整次挥击双臂长度稳定")
	actor.queue_free(); await process_frame
	print("WEAPON_MOTION_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
