extends SceneTree
const Race=preload("res://game/race.gd")
const Sound=preload("res://game/systems/sound.gd")
var failures=0
func check(ok: bool,label: String):
	if ok:print("[PASS] "+label)
	else:failures+=1;printerr("FAIL: "+label)
func _initialize():call_deferred("run")
func run():
	var tick: AudioStreamWAV=Sound.starting_tone(660,.12)
	var go: AudioStreamWAV=Sound.starting_tone(1046.5,.48)
	check(go.get_length()>tick.get_length()*3,"放行音明显长于准备短音")
	check(tick.data.decode_s16(200)!=0 and go.data.decode_s16(200)!=0,"准备音和放行音包含实际 PCM 波形")
	var race=Race.new();race.test_mode=true;root.add_child(race)
	race.set_process(false);race.set_physics_process(false)
	race.start()
	check(race.world.has_method("set_start_lights"),"起跑灯具有实际可切换状态")
	if race.world.has_method("set_start_lights"):
		for step in range(6):
			if step>0:race._physics_process(.6)
			var green=0
			for lamp in race.world.start_lamps:
				if lamp.material_override.albedo_color.g>lamp.material_override.albedo_color.r:green+=1
			check(green==step,"阶段 %d：依次点亮 %d 盏绿灯，其余保持红灯"%[step,step])
			if step==2:
				race.suspend_input();var remaining=race.countdown
				race._physics_process(1)
				check(race.countdown==remaining,"暂停冻结倒计时与起跑灯")
				race.menu_action("resume")
		check(race.mode=="racing" and race.sound.start_go_count==1 and race.sound.start_tick_count==5,"全绿时放行且只有一次长音，准备阶段五次短音")
		race._physics_process(.1)
		check(race.sound.start_go_count==1,"持续行驶不重复播放起跑长音")
		race.start()
		check(race.world.start_lamps[0].material_override.albedo_color.r>race.world.start_lamps[0].material_override.albedo_color.g and race.sound.start_tick_count==1,"重开恢复全红并重新开始节奏")
	race.sound.stop_all();race.queue_free();await process_frame
	print("START_LIGHTS_RESULT: %d failures"%failures);quit(1 if failures else 0)
