extends SceneTree
const Driver = preload("res://tests/drive_controller.gd")
var race
var frames=0
var lane_target=2.0
var samples=[]
var max_frames=26000
var closing=false
func _initialize():call_deferred("start")
func start():
	race=load("res://game/race.gd").new()
	race.test_mode=true
	root.add_child(race)
	if "--coast" in OS.get_cmdline_user_args():
		race.career.unlocked.append("coast")
		race.select_track(1)
	if "--endurance" in OS.get_cmdline_user_args():
		race.career.unlocked.append("interstate")
		race.select_track(2)
	if "--casual" in OS.get_cmdline_user_args(): race.career.settings.difficulty=0
	if "--hard" in OS.get_cmdline_user_args(): race.career.settings.difficulty=2
	race.start()
	race.mode="racing"
	race.set_physics_process(false)
	print("SOAK_START "+race.difficulty().name)
func _physics_process(dt):
	if race==null or closing:return false
	if race.mode=="finished":
		print("SOAK_FINISH ",race.result," distance=",race.player.distance," time=",race.elapsed," crashes=",race.player.crashes," health=",race.player.health," rank=",race.rank," bursts=",race.burst.activations," stages=",race.endurance.visited," services=",race.endurance.serviced)
		var suffix = str(race.track.id)+"-"+str(race.career.settings.difficulty)+( "-charge" if "--charge" in OS.get_cmdline_user_args() else "-cruise")
		var f=FileAccess.open("res://outputs/soak-"+suffix+".json",FileAccess.WRITE)
		f.store_string(JSON.stringify({"result":race.result,"distance":race.player.distance,"seconds":race.elapsed,"crashes":race.player.crashes,"rank":race.rank,"frame_count":frames,"fps_samples":samples,"telemetry":race.telemetry}))
		for r in race.racers: print("OPPONENT ",r.name," finished=",r.finished," time=",r.finish_time," distance=",r.s," bursts=",r.burst.activations)
		if "--endurance" in OS.get_cmdline_user_args():
			if race.endurance.visited.size()!=9 or race.endurance.serviced.size()!=2 or race.elapsed<240 or race.elapsed>420:
				printerr("FAIL: 耐力赛必须经历九段、实际停车维修两次且在 4–7 分钟完成");call_deferred("shutdown",1);closing=true;return false
		closing=true
		call_deferred("shutdown",0 if race.result=="FINISH" else 1)
		return false
	var player=race.player
	# Match collision detection: the test driver must also see pursuing police.
	var vehicles=race.Contacts.vehicles(race)
	var safest=2.0
	var best_score=-INF
	for candidate in [-4.8,-1.6,1.6,4.8]:
		var score= -absf(candidate-player.lane)*.35 + (2.0 if candidate>0 else -100.0)
		for car in vehicles:
			var gap=car.s-player.distance
			if gap>-5 and gap<maxf(32,absf(player.speed-car.speed)*1.5):
				score-= maxf(0,3-absf(candidate-car.lane))*12*(1-gap/120)
		for r in race.racers:
			if absf(r.s-player.distance)<9 and r.crash<=0:score-=maxf(0,2.4-absf(candidate-r.lane))*2
		for hazard in race.world.hazards:
			if hazard.s-player.distance>0 and hazard.s-player.distance<40:score-=maxf(0,1.4-absf(candidate-hazard.lane))*5
		if score>best_score:best_score=score;safest=candidate
	var service=race.endurance.index>=0 and race.endurance.stages[race.endurance.index].kind=="service" and race.endurance.index not in race.endurance.serviced and player.distance<race.endurance.stages[race.endurance.index].start+450
	lane_target=6.15 if service else safest
	player.curve_force=race.route.curvature(player.distance)
	var steer=Driver.steer(player,lane_target)
	var clear_road = absf(steer)<.6
	for car in vehicles:
		if car.s>player.distance and car.s-player.distance<maxf(45,absf(player.speed+12-car.speed)*3.4) and absf(car.lane-player.lane)<2.0: clear_road=false
	var upcoming_curve = absf(race.route.curvature(player.distance))
	for ahead in [15,30,50,70]: upcoming_curve=maxf(upcoming_curve,absf(race.route.curvature(player.distance+ahead)))
	var safe_speed = player.corner_speed(upcoming_curve,player.top_speed,player.handling)
	var brake = clampf((player.speed-safe_speed)*.22,0,1)
	for car in vehicles:
		var gap=car.s-player.distance
		var closing=maxf(0,player.speed-car.speed)
		if car.speed>=0 and gap>0 and gap<maxf(12,closing*closing/50+8) and absf(car.lane-player.lane)<2.1:
			brake=maxf(brake,clampf(closing*.18,0,1))
	if service: brake=1.0 if player.lane>5.8 else maxf(brake,clampf((player.speed-15)*.2,0,1))
	var throttle = 1.0 if brake<.05 else 0.0
	clear_road = clear_road and upcoming_curve<.003
	var held = clear_road and "--charge" in OS.get_cmdline_user_args() and race.burst.cooldown<=0 and race.burst.remaining<=0 and race.burst.charge<race.burst.CHARGE_SECONDS-.0001
	# Combat-focused opponents now keep up: exercise real defense rather than tanking hits.
	var guard = false
	for r in race.racers:
		if r.combat_target==-1 and r.windup>0 and r.windup<.18 and absf(r.s-player.distance)<3 and absf(r.lane-player.lane)<2.5:
			if r.kind==1: player.dodge()
			else: guard = true
	if guard: Input.action_press("guard")
	else: Input.action_release("guard")
	race.simulate(dt,throttle,brake,steer,held)
	race.player_mesh.ground_move(race.route.point(player.distance,player.lane),race.route.yaw(player.distance)+player.heading_offset,dt)
	frames+=1
	if frames%60==0:samples.append({"fps":Engine.get_frames_per_second(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	if frames%600==0:print("SOAK ",frames," distance=",player.distance," health=",player.health," FPS=",Engine.get_frames_per_second()," draw=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if frames>max_frames:
		printerr("SOAK_TIMEOUT");quit(1)

	return false

func shutdown(code: int):
	Input.action_release("guard")
	race.sound.stop_all()
	race.queue_free()
	race=null
	await create_timer(.25).timeout
	quit(code)
