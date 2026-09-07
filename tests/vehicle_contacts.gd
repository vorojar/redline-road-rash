extends SceneTree
var checks=0
var failures=0
var race
func check(value: bool,label: String):
	checks+=1
	if value: print("[PASS] "+label)
	else:
		failures+=1
		printerr("FAIL: "+label)
func _initialize(): call_deferred("run")
func clear_track():
	race.reset_race(); race.mode="racing"; race.tutorial=true
	for r in race.racers: r.s=20000.0; r.finished=true
	for car in race.traffic: car.s=20000.0
func run():
	race=load("res://game/race.gd").new(); race.test_mode=true
	root.add_child(race); race.set_process(false); race.set_physics_process(false)
	clear_track()
	var a=race.racers[0]; var b=race.racers[1]
	a.finished=false; b.finished=false
	a.s=100; b.s=100; a.lane=2; b.lane=2; a.speed=30; b.speed=30
	race.simulate(1.0/60,0,0,0,false)
	check(absf(a.s-b.s)>=2.5 or absf(a.lane-b.lane)>=1.15,"两个 AI 完全重合时被实体分开")
	clear_track()
	a=race.racers[0]; a.finished=false; a.s=0; a.lane=2; a.speed=30
	race.player.speed=30; race.player.invulnerable=10
	race.simulate(1.0/60,1,0,0,false)
	check(absf(a.s-race.player.distance)>=2.5 or absf(a.lane-race.player.lane)>=1.15,"玩家免伤也不能与 AI 合并")
	for immune in [false,true]:
		clear_track()
		var car=race.traffic[0]
		car.erase("driver")
		car.s=4; car.lane=2; car.speed=15
		race.player.speed=45; race.player.invulnerable=10 if immune else 0
		for frame in range(12): race.simulate(1.0/60,1,0,0,false)
		check(absf(car.s-race.player.distance)>=car.half_length+1.2 or absf(car.lane-race.player.lane)>=1.6,"追尾阻挡位置，免伤 %s" % immune)
		check(race.player.speed<20,"追尾速度受前车限制，免伤 %s" % immune)
		if not immune:
			check(race.player.health<100 and race.shake>.3,"追尾产生实际伤害与明显镜头反馈")
	clear_track()
	for r in race.racers:
		r.finished=false; r.s=100; r.lane=2; r.speed=30; r.stagger=10
	race.simulate(1.0/60,0,0,0,false)
	var separated=true
	for i in range(5):
		for j in range(i+1,5):
			var one=race.racers[i]; var two=race.racers[j]
			if absf(one.s-two.s)<2.68 and absf(one.lane-two.lane)<1.28: separated=false
	check(separated,"五名 AI 密集重合仍逐对分离")
	for hz in [30,60,120]:
		clear_track()
		var car=race.traffic[0]
		car.erase("driver"); car.s=3.8; car.lane=2; car.speed=-25
		race.player.speed=60
		race.simulate(1.0/hz,1,0,0,false)
		check(race.player.distance<car.s-car.half_length-1.2 and race.player.crash_timer>0,"%d Hz 迎头撞车在车外摔落" % hz)
	clear_track()
	var car=race.traffic[0]
	car.erase("driver"); car.s=4; car.lane=2; car.speed=15
	race.player.speed=40
	for frame in range(6): race.simulate(1.0/60,1,0,0,false)
	var pose=race.player_mesh.contact_pose(race.player_mesh.contact_started+.06)
	var rebound=race.player_mesh.contact_pose(race.player_mesh.contact_started+.20)
	check(pose.x<-.08 and rebound.x>0,"追尾车身前倾后反向回弹")
	check(race.player_mesh.contact_pose(race.player_mesh.contact_started+.8)==Vector3.ZERO,"撞击动作结束恢复骑行姿态")
	clear_track()
	check(race.player_mesh.contact_started<0,"重开清除上局撞击冷却")
	clear_track()
	race.police.active=true; race.police.s=4; race.police.lane=2; race.police.speed=0
	race.player.speed=45; race.player.invulnerable=10
	for i in range(3): race.simulate(1.0/60,1,0,0,false)
	check(race.player.distance<race.police.s-3.4 and race.player.speed<1,"警车同样挡住免伤玩家")
	race.police.active=false; race.update_visuals(.016)
	check(race.police.mesh.get_node("VehicleSolid").collision_layer==0,"未出现的警车没有隐形碰撞体")
	var size=Vector2(3.45,1.73)
	var push=race.Contacts.correction(Vector2(-10,0),Vector2(10,0),size)
	check(10+push.x < -size.x,"单帧穿越整辆车的扫掠仍停在原来一侧")
	check(race.Contacts.correction(Vector2(-10,2),Vector2(10,2),size)==Vector2.ZERO,"邻道安全超车不会被扫掠误拦")
	clear_track()
	a=race.racers[0]; a.finished=false; a.s=0; a.lane=2; a.speed=30
	race.player.speed=30
	race.simulate(1.0/60,0,0,0,false)
	check(race.player.health==100,"同速轻挤分离但不凭空扣血")
	race.sound.stop_all(); race.queue_free(); await process_frame
	print("VEHICLE_CONTACTS_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
