extends SceneTree
const Race=preload("res://game/race.gd")
const Traffic=preload("res://game/systems/traffic.gd")
const Driver=preload("res://game/systems/traffic_driver.gd")
var race
var failures=0
func check(ok: bool,label: String):
	if ok: print("[PASS] "+label)
	else: failures+=1;printerr("FAIL: "+label)
func _initialize(): call_deferred("run")
func clear_scene():
	race.reset_race();race.mode="racing";race.tutorial=true
	for c in race.traffic:c.s=20000
	for r in race.racers:r.s=20000;r.finished=true
	race.player.distance=100;race.player.lane=2;race.player.speed=0
func run():
	race=Race.new();race.test_mode=true;root.add_child(race)
	race.set_process(false);race.set_physics_process(false)
	for direction in [-1,1]:
		for ai in [false,true]:
			for down in [false,true]:
				clear_scene()
				if ai:
					race.player.lane=-5
					var r=race.racers[0];r.s=100;r.lane=2;r.speed=0;r.finished=false;r.crash=3 if down else 0
				else:race.player.crash_timer=3 if down else 0
				var car=race.traffic[0];car.s=100-direction*35;car.lane=2;car.speed=direction*20
				car.driver=Driver.state(0,2,car.speed);car.driver.decision=100
				for frame in range(240):
					Driver.update(race,car,1.0/60);car.s+=car.speed/60.0
				check((100-car.s)*direction>car.half_length+1.35 and absf(car.speed)<.2,"车辆在骑手前停车：方向 %d，AI %s，倒地 %s"%[direction,ai,down])
	clear_scene()
	var avoiding=race.traffic[0];avoiding.s=135;avoiding.lane=2;avoiding.speed=-20;avoiding.driver=Driver.state(0,2,-20)
	check(Driver.lane_clear(race,avoiding,-4.7),"前方骑手不阻止汽车向空车道避让")
	race.player.lane=-4.7
	check(not Driver.lane_clear(race,avoiding,-4.7),"目标车道有骑手时禁止并线")
	clear_scene()
	var car=race.traffic[0];car.s=102;car.lane=2;car.speed=-20;car.driver=Driver.state(0,2,-20)
	var previous=race.Contacts.snapshot(race)
	race.Contacts.resolve(race,previous)
	check(car.speed==0,"实际碰撞后汽车停车，不继续推骑手")
	var stopped=car.s
	for frame in range(60):Traffic.update(race,1.0/60)
	check(absf(car.s-stopped)<.05,"碰撞后至少一秒保持停车")
	race.player.distance=200;race.player.lane=-5
	for frame in range(240):Driver.update(race,car,1.0/60)
	check(car.speed< -1,"骑手离开后司机恢复行驶，不永久堵死")
	clear_scene()
	car=race.traffic[0];car.s=103;car.lane=2;car.speed=20;car.driver=Driver.state(0,2,20)
	race.player.invulnerable=100
	for frame in range(300):
		race.elapsed+=1.0/60
		previous=race.Contacts.snapshot(race)
		Driver.update(race,car,1.0/60);car.s+=car.speed/60
		race.player.speed=2;race.player.distance+=2.0/60
		race.Contacts.resolve(race,previous)
	check(car.s>110 and car.speed>2,"持续贴住车尾不会反复重置停车计时，前方安全时驶离")
	clear_scene()
	race.player.distance=70
	race.player_mesh.position=race.route.point(70,2)
	race.player_mesh.pose(0,0,0,5,0,1,0)
	for key in ["spine","hips","head"]:
		race.player_mesh.crash_rig.bodies[key].global_position=race.route.point(100,2)+Vector3.UP*.4
	car=race.traffic[0];car.s=135;car.lane=2;car.speed=-20;car.driver=Driver.state(0,2,-20);car.driver.decision=100
	for frame in range(240):Driver.update(race,car,1.0/60);car.s+=car.speed/60
	var body_s=race.crash_location(race.player_mesh.crash_rig.bodies.spine.global_position).x
	check(car.s-body_s>car.half_length+1.35 and absf(car.speed)<.2,"倒地人体与摩托相距 30 米时按人体真实位置停车")
	race.sound.stop_all();race.queue_free();await process_frame
	print("TRAFFIC_YIELD_RESULT: %d failures"%failures);quit(1 if failures else 0)
