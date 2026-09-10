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
		var start_gate = world.get_node_or_null("Start Gate")
		var start_line = world.get_node_or_null("Start Line/Ground Checker/Cells")
		var finish_gate = world.get_node_or_null("Finish Gate")
		check(start_gate!=null and start_line!=null and start_gate.get_node_or_null("Start Label")!=null,"每条赛道有 START 旗门与地面棋盘起跑线："+world.track.id)
		check(finish_gate!=null and finish_gate.get_node_or_null("Finish Line/Cells")!=null and finish_gate.get_node_or_null("Finish Flag")!=null and finish_gate.get_node_or_null("Finish Label")!=null,"每条赛道有高架赛结旗与地面棋盘终点线："+world.track.id)
		check(start_line.get_child_count()==40 and finish_gate.get_node("Finish Flag").get_child_count()==64 and finish_gate.get_node("Finish Line/Cells").get_child_count()==40,"起终点棋盘格完整且横跨路面："+world.track.id)
		var counts = {"EHAFO":4,"OpenAI":2,"LEOSTO":3,"NVIDIA":1,"Microsoft":1,"Apple":1,"Amazon":1,"Anthropic":1,"Gemini":1,"Tesla":1}
		var occupied: Array[float] = []
		var left_count = 0
		var right_count = 0
		for brand in counts:
			var signs = world.find_children(brand+" *","Node3D",false,false)
			check(signs.size()==counts[brand],"每赛道品牌数量 %s × %d：%s" % [brand,counts[brand],world.track.id])
			for sign_node in signs:
				var s = float(String(sign_node.name).get_slice(" ",1))
				var lane = (sign_node.position-world.route.point(s)).dot(Basis(Vector3.UP,world.route.yaw(s)).x)
				if lane<0: left_count += 1
				else: right_count += 1
				check(absf(lane)-6.4>8.8 and world.section_kind(s) not in ["service","freight","bridge"],"大牌在两侧路肩外且避开特殊区域："+str(sign_node.name))
				check(sign_node.basis.z.dot(-world.route.tangent(s))>.98,"左右广告面都朝向玩家来车，不镜像："+str(sign_node.name))
				for other in occupied:
					check(absf(s-other)>=100,"广告牌沿赛道错开至少100米")
				occupied.append(s)
		check(left_count==8 and right_count==8,"每条赛道左右各八块广告："+world.track.id)
		var placements = preload("res://game/world/roadside_details.gd").sponsor_layout(world,float(world.track.length))
		var blocked_trees = 0
		for node in world.get_children():
			if not node is MultiMeshInstance3D: continue
			var material = node.material_override
			if not material is StandardMaterial3D or material.albedo_texture==null or not material.albedo_texture.resource_path.ends_with("roadside_pine.png"): continue
			for tree_index in range(node.multimesh.instance_count):
				var pos = node.multimesh.get_instance_transform(tree_index).origin
				for placement in placements:
					var delta = Basis(Vector3.UP,world.route.yaw(placement.distance)).inverse()*(pos-world.route.point(placement.distance,placement.lane))
					if absf(delta.x)<12 and delta.z>-10 and delta.z<65: blocked_trees += 1
		check(blocked_trees==0,"实际生成的树木不占用两侧广告视线："+world.track.id)

	var active = 0
	for entry in race.world_cache.values():
		if entry.world.is_inside_tree(): active += 1
	check(active==1 and race.world.is_inside_tree(),"仅当前地图的场景与碰撞生效")
	check(race.player.distance==0 and race.endurance.index==-1 and race.endurance.visited.is_empty(),"切图重置玩家与赛事进度")
	race.free()
	await process_frame
	print("MAP_LOADING_FAILURES ",failures)
	quit(1 if failures else 0)
