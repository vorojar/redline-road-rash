extends SceneTree
const Race=preload("res://game/race.gd")
const Traffic=preload("res://game/systems/traffic.gd")
var failures=0
func check(ok: bool,label: String):
	if ok:print("[PASS] "+label)
	else:failures+=1;printerr("FAIL: "+label)
func _initialize():call_deferred("run")
func run():
	var race=Race.new();race.test_mode=true;root.add_child(race)
	race.set_process(false);race.set_physics_process(false);race.mode="racing"
	race.player.distance=100;race.player.lane=2;race.player.speed=15
	race.player.invulnerable=100
	for car in race.traffic:car.s=20000
	for rider in race.racers:rider.s=20000;rider.finished=true
	race.police.active=true;race.police.s=88;race.police.lane=2;race.police.speed=25;race.police.warning=0
	var flanked=false
	for frame in range(780):
		var previous=race.Contacts.snapshot(race)
		race.player.distance+=race.player.speed/60
		Traffic.update_police(race,1.0/60)
		race.Contacts.resolve(race,previous)
		flanked=flanked or absf(race.police.lane-race.player.lane)>1.7
		if race.mode=="finished":break
	check(absf(race.police.yaw)>.95 and absf(race.police.yaw)<1.15,"警车超车后斜转约 60 度逼停，不完全横置")
	var cars=race.Contacts.vehicles(race)
	var blocker=cars[cars.size()-1]
	check(blocker.half_width>2.2 and blocker.half_length<2.2,"斜停车碰撞范围随车身旋转，车侧可以实际截停")
	check(flanked,"警车先侧向超车，不沿骑手中心持续推行")
	check(race.police.s-race.player.distance>2.4 and race.police.s-race.player.distance<25,"追近后保持截停距离，不高速开走")
	check(absf(race.police.lane-race.player.lane)<1 and race.player.speed<8,"警车切入前方并通过真实接触减速别停")
	race.reset_race();race.mode="racing";race.player.distance=100;race.player.lane=2;race.player.speed=0
	race.police.active=true;race.police.s=105;race.police.lane=2;race.police.speed=0;race.police.warning=0
	for frame in range(90):Traffic.update_police(race,1.0/60)
	check(race.police.speed<.5 and absf(race.police.s-100)<9,"玩家停车后警车停留附近")
	check(race.result=="BUSTED","被近距离截停并持续停车触发逮捕")
	race.sound.stop_all();race.queue_free();await process_frame
	print("POLICE_INTERCEPT_RESULT: %d failures"%failures);quit(1 if failures else 0)
