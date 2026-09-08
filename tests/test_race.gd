extends SceneTree
const BikeState=preload("res://game/bike_state.gd")
const Race=preload("res://game/race.gd")
const Career=preload("res://game/systems/career.gd")
const Controls=preload("res://game/systems/controls.gd")
var failures=0
var checks=0
func check(condition: bool,label: String) -> void:
	checks+=1
	if condition:print("[PASS] "+label)
	else:
		failures+=1
		printerr("FAIL: "+label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var bike=BikeState.new()
	for i in range(600):bike.drive(1.0/60,1,0,0,false)
	check(is_equal_approx(bike.speed,53),"基础摩托极速 190.8 km/h")
	check(bike.distance>380,"驾驶推进赛程")
	for i in range(140):bike.drive(1.0/60,0,1,0,false)
	check(bike.speed==0,"刹车停车无倒退")
	bike.damage(8,105)
	check(bike.crash_timer>0 and bike.health==92,"高生命但失稳摔车")
	check(bike.durability==82,"摔车扣耐久")
	bike.damage(20,40)
	check(bike.health==92,"摔车免疫重复伤害")
	for i in range(390):bike.drive(1.0/60,0,0,0,false)
	check(bike.crash_timer==0 and bike.stability>=80,"6.2 秒摔车回位恢复")
	check(BikeState.collision_severity(55,.1)<.3 and BikeState.collision_severity(55,1)==1,"擦碰与正撞分级")
	var career=Career.new()
	career.path="user://test_career_v2.json"
	check(not career.buy("phantom") and career.credits==0,"余额不足拒绝购买")
	career.credits=2000
	check(career.buy("revenant") and career.credits==200 and career.selected=="revenant","购买扣款且选择摩托")
	check(not career.buy("revenant") and career.credits==200,"重复购买不扣款")
	var payout=career.settle("pine",2,85.5,2,1)
	check(payout==1000 and career.credits==1200 and "coast" in career.unlocked,"奖金包含 KO 与环境奖励，前三解锁海岸")
	career.settings.difficulty=2
	check(career.save_profile(),"存档原子写入")
	var loaded=Career.new()
	loaded.path=career.path
	loaded.load_profile()
	check(loaded.credits==1200 and loaded.selected=="revenant" and loaded.records.pine.races==1,"存档重载保持车库、奖金和记录")
	check(int(loaded.settings.difficulty)==2,"难度设置跨重启保存")
	var broken=FileAccess.open(career.path,FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	var damaged=Career.new()
	damaged.path=career.path
	damaged.load_profile()
	check(not damaged.load_error.is_empty() and not damaged.save_profile() and FileAccess.get_file_as_string(career.path)=="{broken", "损坏存档拒绝覆盖原文件")
	Controls.setup({"punch":KEY_F})
	check(InputMap.action_get_events("punch")[0].physical_keycode==KEY_F,"键位映射应用")
	for item in [["throttle",KEY_W,KEY_UP,KEY_KP_8],["brake",KEY_S,KEY_DOWN,KEY_KP_2],["left",KEY_A,KEY_LEFT,KEY_KP_4],["right",KEY_D,KEY_RIGHT,KEY_KP_6]]:
		for key in item.slice(1):
			var input=InputEventKey.new()
			input.physical_keycode=key; input.pressed=true
			check(input.is_action_pressed(item[0]),"驾驶键 %s 对应 %s" % [OS.get_keycode_string(key),item[0]])
	Controls.setup({"cruise":KEY_SPACE,"punch":KEY_KP_8})
	var space=InputEventKey.new()
	space.physical_keycode=KEY_SPACE; space.pressed=true
	check(space.is_action_pressed("primary_attack") and not space.is_action_pressed("cruise"),"旧空格定速绑定自动避让攻击")
	check(Controls.key_label("cruise",{"cruise":KEY_SPACE})=="C","旧存档定速键提示与实际 C 绑定一致")
	check(InputMap.action_get_events("punch")[0].physical_keycode==KEY_J,"旧小键盘自定义绑定避让固定驾驶键")
	var joy=false
	for event in InputMap.action_get_events("throttle"):
		if event is InputEventJoypadMotion:joy=true
	check(joy,"手柄 RT 绑定油门")
	var race=Race.new()
	race.test_mode=true
	root.add_child(race)
	race.set_physics_process(false)
	race.set_process(false)
	race.mode="racing"
	check(race.racers.size()==5 and race.traffic.size()==18,"5 AI / 18 双向车流")
	check(race.player_mesh.bone_ids.has("head") and race.player_mesh.bone_ids.has("forearm_L") and race.player_mesh.bone_ids.has("shin_R"),"加载实际车手骨骼")
	race.player_mesh.pose(0,0,0,0,0,1,0,0,1.7)
	check(is_equal_approx(race.player_mesh.bike.find_child("WheelRear",true,false).rotation.x, -5.0), "后轮随 1.7 米赛程旋转 5 弧度")
	check(race.route.point(800).y!=race.route.point(0).y,"Spline 道路有起伏")
	for r in race.racers:r.s=1000.0
	var enemy=race.racers[0]
	enemy.s=0.0;enemy.lane=3.5
	check(race.attack(1) and enemy.hp==100,"攻击前摇期间不扣血")
	check(not race.attack(1),"冷却拒绝连续攻击")
	race.pending_attack=0
	check(race.resolve_attack() and enemy.hp==83 and enemy.stability==60,"踢击前摇后命中")
	check(is_equal_approx(enemy.lane,5.05) and enemy.revenge==1,"踢击横向位移与报复记忆")
	enemy.s=20.0
	check(not race.resolve_attack() and enemy.hp==83,"逃出攻击范围不会受伤")
	enemy.s=0;enemy.lane=3;enemy.stability=20
	race.resolve_attack()
	check(enemy.crash>0 and race.player.knockouts==1,"直接击倒计 KO")
	var e=race.racers[1]
	e.last_hit_age=1.0
	race.knock_out(1,true)
	check(race.player.knockouts==2 and race.player.environment_kos==1,"环境击倒归因")
	race.knock_out(1,true)
	check(race.player.knockouts==2,"同一摔车不重复计 KO")
	# Complete collision path, including upcoming traffic position.
	race.player.speed=53
	race.player.invulnerable=0
	race.traffic[0].s=.5
	race.traffic[0].lane=race.player.lane
	race.simulate(.016,1,0,0,false)
	check(race.player.crash_timer>0,"高速正面碰撞触发摔车")
	race.player.crash_timer=0;race.player.invulnerable=10
	race.heat=51
	race.simulate(.016,0,0,0,false)
	check(race.police.active and race.police.warning>4,"警察出现提供 5 秒预警")
	race.player.crash_timer=3;race.police.warning=0;race.police.s=race.player.distance
	for i in range(60):
		race.police.s=race.player.distance
		race.simulate(.016,0,0,0,false)
	check(race.mode=="finished" and race.result=="BUSTED","警方附近摔车持续截获")
	race.reset_race();race.mode="racing"
	race.player.distance=3000;race.player.invulnerable=10
	race.simulate(.016,0,0,0,false)
	check(race.mode=="finished" and race.result=="FINISH","终点触发结算")
	var total=race.career.credits
	race.finish("FINISH","again")
	check(race.career.credits==total,"重复结算不重复发奖")
	check(race.select_track(1) and race.track.id=="coast","已解锁海岸赛道可实际加载")
	race.start(true);race.mode="racing";race.heat=100
	race.simulate(.016,0,0,0,false)
	check(not race.police.active,"教学无警察追击")
	race.finish("FINISH","practice")
	check(race.career.credits==total,"教学不发放奖金")
	race.queue_free()
	await process_frame
	# This path is exclusively test-created and has no user save content.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(career.path))
	print("RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
