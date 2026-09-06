extends SceneTree
const Race=preload("res://game/race.gd")
const Driver=preload("res://game/systems/traffic_driver.gd")
const Traffic=preload("res://game/systems/traffic.gd")
var checks=0
var failures=0
func check(value: bool,label: String):
	checks+=1
	if value: print("[PASS] "+label)
	else: failures+=1; printerr("FAIL: "+label)
func _initialize():call_deferred("run")
func run():
	var race=Race.new();race.test_mode=true;root.add_child(race)
	race.set_process(false);race.set_physics_process(false)
	for r in race.racers:r.s=10000
	for c in race.traffic:c.s=10000
	var car=race.traffic[2]
	car.s=100;car.lane=1.6;car.speed=22
	car.driver=Driver.state(0,1.6,22);car.driver.decision=0
	race.player.distance=0
	Driver.update(race,car,.1)
	check(car.driver.signal>1 and car.lane==1.6,"变道先亮灯，车辆不立即横移")
	race.player.distance=90;race.player.lane=4.7;race.player.speed=40
	Driver.update(race,car,.1)
	check(car.driver.signal==0 and not car.driver.changing and car.lane==1.6,"玩家逼近变道走廊时取消变道")
	race.player.distance=0;car.driver.decision=0
	for i in range(240):Driver.update(race,car,1.0/60)
	check(absf(car.lane-4.7)<.001 and car.driver.changes==1,"空闲车道完成一次连续变道，不越过中线")
	var leader=race.traffic[3];leader.s=112;leader.lane=4.7;leader.speed=0
	car.driver.decision=10
	Driver.update(race,car,.5)
	check(car.speed<20 and car.driver.braking,"前方堵车时减速并亮刹车灯")
	var p=race.player
	p.configure(race.career.bike());p.health=100;p.damage(10,5,true)
	check(is_equal_approx(p.durability,98.4),"碰撞造成真实车辆磨损")
	p.durability=25
	check(p.condition_power()<.9 and p.condition_power()>=.86,"严重车损降低动力，但保持基本可驾驶")
	p.configure(race.career.bike())
	check(p.condition_power()==1 and p.durability==p.max_durability,"重开/换车恢复完整动力")
	race.endurance.configure(race.career.catalog.tracks[2])
	p.distance=4150;p.lane=6.15;p.speed=0;p.health=25;p.durability=30
	race.endurance.update(race,1)
	check(p.health==25 and race.endurance.repair_time==1,"维修必须真实停车等待")
	race.endurance.update(race,1.1)
	check(p.health==65 and p.durability==65 and race.endurance.serviced.size()==1,"停车两秒恢复规定体力与车况")
	race.endurance.update(race,5)
	check(p.health==65 and p.durability==65,"同一维修站不能反复刷回复")
	p.distance=8110;p.speed=10
	race.endurance.update(race,3)
	check(p.health==65,"行驶经过维修站不会凭空修好")
	p.speed=0;p.lane=2
	race.endurance.update(race,3)
	check(p.health==65,"主车道停车不能触发路边维修")
	race.heat=75;race.police.active=false;race.police.support_active=false
	Traffic.update_police(race,.1)
	check(race.police.active and race.police.support_active and race.police.support_warning>5,"高热度增援先从后方出现并提供预警")
	var starting_gap: float=p.distance-race.police.support_s
	for i in range(600):
		p.distance+=53.0/60
		Traffic.update_police(race,1.0/60)
	check(p.distance-race.police.support_s<starting_gap-40,"侧翼增援能追近全速基础车型，不在远处永远跟随")
	race.police.s=p.distance-190
	Traffic.update_police(race,.01)
	check(not race.police.active and not race.police.support_active,"甩脱追捕时两辆警车同时退出")
	race.heat=90;race.police.active=false;race.police.roadblock=false
	var count=race.traffic.size()
	Traffic.update_police(race,.01)
	var block_a=race.traffic[count];var block_b=race.traffic[count+1]
	check(block_a.lane*block_b.lane>0 and block_a.s-p.distance>=219,"耐力赛封锁只占一侧且提前 220 米出现")
	var original_s: float=block_a.s
	p.distance=original_s+200;race.heat=0;race.police.active=false
	Traffic.update(race,.01)
	check(block_a.s==original_s,"通过的路障不会被循环搬回玩家前方")
	race.career.settle("coast",3,90,0,0)
	check("interstate" in race.career.unlocked,"海岸前三解锁耐力赛")
	race.career.path="user://test_endurance_unlock_v2.json"
	race.career.unlocked.erase("interstate")
	check(race.career.save_profile(),"旧生涯样例写入隔离测试路径")
	var legacy=load("res://game/systems/career.gd").new();legacy.path=race.career.path;legacy.load_profile()
	check("interstate" in legacy.unlocked,"旧存档已有海岸前三纪录时补齐耐力赛解锁")
	check(race.career.catalog.tracks[2].length==12000 and race.endurance.stages.size()==9,"耐力赛包含 12 公里与九个明确阶段")
	race.sound.stop_all();race.queue_free();await process_frame
	print("ENDURANCE_RESULT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
