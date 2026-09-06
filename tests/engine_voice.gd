extends SceneTree
const Voice=preload("res://game/systems/engine_voice.gd")
const Sound=preload("res://game/systems/sound.gd")
var checks=0
var failures=0
func check(value: bool,label: String):
	checks+=1
	if value: print("[PASS] "+label)
	else:
		failures+=1
		printerr("FAIL: "+label)
func _initialize():
	for id in Voice.VOICES.data:
		var voice=Voice.new()
		voice.configure(id)
		for i in range(120): voice.update(1.0/60,0,0,1,true)
		check(voice.rpm==voice.spec.idle_rpm and voice.gains.idle>.65 and voice.gains.high<.001,id+" 静止保持有声怠速，不靠车速才能发声")
		for i in range(60): voice.update(1.0/60,0,1,1,true)
		check(voice.rpm>voice.spec.idle_rpm*2 and voice.gains.low+voice.gains.high>.4,id+" 原地拧油门转速和工作声层上升")
		for i in range(120): voice.update(1.0/60,42,1,3,true)
		check(voice.gains.high>.65 and voice.rpm<voice.spec.redline,id+" 高转层接管且转速不越红线")
		var pops=voice.pops
		check(voice.update(1.0/60,42,0,3,true),id+" 高转收油触发一次回火")
		for i in range(60): voice.update(1.0/60,40,0,3,true)
		check(voice.gains.coast>.6 and voice.pops==pops+1,id+" 收油持续低沉尾音，不连续放炮")
		voice.update(.1,40,1,3,true)
		check(not voice.update(.1,40,0,3,true),id+" 快速反复拧油门受回火间隔限制")
		for i in range(120): voice.update(1.0/60,0,0,1,false)
		check(voice.gains.values().max()<.001,id+" 暂停后发动机平滑静音")
		voice.configure(id)
		check(not voice.update(.1,0,0,1,true),id+" 低转怠速不误放炮")
		for layer in ["idle","low","high","coast","pop","start"]:
			var sample=load("res://assets/audio/engines/"+id+"_"+layer+".wav")
			check(sample.get_length()>.5 and sample.mix_rate==44100,id+" 声层可加载且采样率正确 "+layer)
	var sound=Sound.new()
	sound.configure_engine("revenant")
	for i in range(60): sound.update(0,0,0,false,.7,false,1.0/60,.65,0,true)
	check(sound.engine_voice.gains.idle>.65,"倒计时入口实际启用怠速")
	sound.configure_engine("phantom")
	check(sound.engine_voice.spec.idle_rpm==1350 and sound.gear==1,"换车切换声浪并重置档位")
	sound.free()
	print("ENGINE_VOICE_RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
