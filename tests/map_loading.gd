extends SceneTree
const Race = preload("res://game/race.gd")
var failures = 0
func check(value: bool, label: String) -> void:
	if value: print("[PASS] "+label)
	else: failures += 1; printerr("FAIL: "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var race = Race.new()
	race.test_mode = true
	race.career.path = "user://map_loading_test_never_saved.json"
	root.add_child(race)
	race.set_physics_process(false)
	race.test_mode = false
	check(not race.select_track(2),"未解锁的地图不能加载")
	race.career.unlocked = ["pine","coast","interstate"]
	var first_world = race.world
	var first_curve = race.route.curve
	var total_start = Time.get_ticks_msec()
	check(race.select_track(2) and race.mode=="loading", "选图立即进入加载状态")
	check(Time.get_ticks_msec()-total_start<100,"选图调用不会同步阻塞地图构建")
	check(not race.select_track(1),"加载中重复选图不会启动第二次构建")
	race.start();race.menu_action("home");race.suspend_input()
	check(race.mode=="loading","开赛、返回和失焦不会打断加载状态")
	var frames = 0
	var last = Time.get_ticks_usec()
	var max_gap = 0
	var progress = 0.0
	var monotonic = true
	while race.mode=="loading" and frames<3000:
		await process_frame
		frames += 1
		max_gap = maxi(max_gap,Time.get_ticks_usec()-last)
		last = Time.get_ticks_usec()
		monotonic = monotonic and race.loading_progress>=progress
		progress = race.loading_progress
	check(race.mode=="ready" and race.track.id=="interstate" and race.track.length==12000,"长赛道完成后回到正确赛事菜单")
	check(frames>20 and monotonic and is_equal_approx(progress,1.0),"加载跨帧推进且进度单调到100%")
	check(not first_world.is_inside_tree() and first_world.route.curve==first_curve,"缓存地图离开场景树，不残留碰撞且保留独立路线")
	print("MAP_LOADING frames=",frames," total_ms=",Time.get_ticks_msec()-total_start," max_frame_ms=",max_gap/1000.0)
	var long_world = race.world
	race.world.hazards[0].hit = true
	race.world.hazards[0].node.rotation.z = 1.0
	for index in [0,2,1,0,2]:
		var begin = Time.get_ticks_msec()
		race.select_track(index)
		while race.mode=="loading": await process_frame
		print("MAP_SWITCH index=",index," ms=",Time.get_ticks_msec()-begin)
	check(race.world==long_world and race.world_cache.size()==3,"往返切图复用原地图，缓存不随切换次数增长")
	check(not race.world.hazards[0].hit and race.world.hazards[0].node.rotation==Vector3.ZERO,"缓存重新进入时重置路障状态")
	for entry in race.world_cache.values():
		var world = entry.world
		var signs = world.find_children("EHAFO *","Node3D",false,false)
		var distances = preload("res://game/world/roadside_details.gd").sponsor_distances(world,float(world.track.length))
		check(signs.size()==4 and distances.size()==4,"每条赛道有四块 EHAFO 广告牌："+world.track.id)
		for i in range(signs.size()):
			var s: float = distances[i]
			var right = Basis(Vector3.UP,world.route.yaw(s)).x
			var lane = (signs[i].position-world.route.point(s)).dot(right)
			check(lane-6.4>8.8 and world.section_kind(s) not in ["service","freight","bridge"],"广告牌在路肩外且避开特殊区域："+world.track.id)
		var openai_signs = world.find_children("OpenAI *","Node3D",false,false)
		var openai_distances = preload("res://game/world/roadside_details.gd").sponsor_distances(world,float(world.track.length),true)
		check(openai_signs.size()==2 and openai_distances.size()==2,"每条赛道新增两块 OpenAI 广告牌："+world.track.id)
		for i in range(openai_signs.size()):
			var s: float = openai_distances[i]
			check(world.section_kind(s) not in ["service","freight","bridge"] and (openai_signs[i].position-world.route.point(s)).dot(Basis(Vector3.UP,world.route.yaw(s)).x)-6.4>8.8,"OpenAI 广告牌位于普通路段路肩外："+world.track.id)
			check(is_equal_approx(openai_signs[i].rotation.y,world.route.yaw(s)),"OpenAI 广告面朝来车："+world.track.id)
			for other in distances:
				check(absf(s-other)>40,"OpenAI 与现有广告牌错开："+world.track.id)
	var active = 0
	for entry in race.world_cache.values():
		if entry.world.is_inside_tree(): active += 1
	check(active==1 and race.world.is_inside_tree(),"仅当前地图的场景与碰撞生效")
	check(race.player.distance==0 and race.endurance.index==-1 and race.endurance.visited.is_empty(),"切图重置玩家与赛事进度")
	race.free()
	await process_frame
	print("MAP_LOADING_FAILURES ",failures)
	quit(1 if failures else 0)
